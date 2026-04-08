import { LightningElement, api, track } from 'lwc';
import getSimulationData from '@salesforce/apex/GridSimulationController.getSimulationData';

const FMT     = new Intl.NumberFormat('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const FMT_INT = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 });
const fmt     = (v, suffix = '') => (v == null ? '—' : FMT.format(v) + suffix);
const fmtInt  = (v, suffix = '') => (v == null ? '—' : FMT_INT.format(Math.trunc(v)) + suffix);

export default class GridSimulation extends LightningElement {

    @api selectedShareClasses = [];
    @api selectedAgreements   = [];
    @api gridShareClassMap    = {};

    @track rows                = [];
    @track customRows          = [];
    @track aumChangePercent    = 0;
    @track isLoading           = false;
    @track error               = null;
    @track editingNewMoneyId   = null;
    _focusNewMoney             = false;

    // ── Step 1: raw numbers — base for all derived getters ───────────────────
    get rawRows() {
        const globalPct = parseFloat(this.aumChangePercent) || 0;
        return [...this.rows, ...this.customRows].map(r => {
            const curAum     = r.aum        || 0;
            const effFee     = r.effMgtFees || 0;
            const curRebRate = r.rebateRate || 0;
            const curGross   = effFee * curAum / 100;
            const curRebates = curRebRate * curAum / 100;
            const curNet     = curGross - curRebates;
            const simAum     = curAum * (1 + globalPct / 100);
            const newMoney   = r.newMoney || 0;
            const newAum     = simAum + newMoney;
            const simGross   = effFee * newAum / 100;
            const simRebates = curRebRate * newAum / 100;   // uses original rate
            const simNet     = simGross - simRebates;
            return { ...r, curAum, curGross, curRebates, curNet, simAum, newMoney, newAum, simGross, simRebates, simNet };
        });
    }

    // ── Step 2: formatted rows for the main tbody (real rows only) ───────────
    get processedRows() {
        return this.rawRows.filter(r => !r.isCustom).map(r => ({
            key:               r.shareClassId,
            shareClassId:      r.shareClassId,
            range:             r.range   || '—',
            ptfCode:           r.ptfCode || '—',
            name:              r.name    || '—',
            isin:              r.isin    || '—',
            effMgtFeesFmt:     fmt(r.effMgtFees, '%'),
            curAumFmt:         fmtInt(r.curAum),
            curGrossFmt:       fmtInt(r.curGross),
            curRebRateFmt:     fmt(r.rebateRate, '%'),
            curRebatesFmt:     fmtInt(r.curRebates),
            curNetFmt:         fmtInt(r.curNet),
            newMoney:          r.newMoney,
            newMoneyFmt:       fmtInt(r.newMoney),
            isEditingNewMoney: this.editingNewMoneyId === r.shareClassId,
            newMoneyCellClass: this.editingNewMoneyId === r.shareClassId ? 'td-sim td-input' : 'td-sim td-right',
            simAumFmt:         fmtInt(r.simAum),
            newAumFmt:         fmtInt(r.newAum),
            simGrossFmt:       fmtInt(r.simGross),
            simRebRateFmt:     fmt(r.rebateRate, '%'),  // read-only display
            simRebatesFmt:     fmtInt(r.simRebates),
            simNetFmt:         fmtInt(r.simNet)
        }));
    }

    // ── Step 2b: formatted custom rows for the custom tbody ──────────────────
    get processedCustomRows() {
        return this.rawRows.filter(r => r.isCustom).map(r => ({
            key:               r.shareClassId,
            shareClassId:      r.shareClassId,
            range:             r.range      || '',
            ptfCode:           r.ptfCode    || '',
            name:              r.name       || '',
            isin:              r.isin       || '',
            effMgtFees:        r.effMgtFees || 0,
            rebateRate:        r.rebateRate || 0,
            newMoney:          r.newMoney   || 0,
            newMoneyFmt:       fmtInt(r.newMoney || 0),
            isEditingNewMoney: this.editingNewMoneyId === r.shareClassId,
            newMoneyCellClass: this.editingNewMoneyId === r.shareClassId ? 'td-sim td-input' : 'td-sim td-right',
            newAumFmt:         fmtInt(r.newAum),
            simGrossFmt:       fmtInt(r.simGross),
            simRebatesFmt:     fmtInt(r.simRebates),
            simNetFmt:         fmtInt(r.simNet)
        }));
    }

    // ── Step 3: totals ────────────────────────────────────────────────────────
    get totals() {
        const rr = this.rawRows;
        const sum = key => rr.reduce((acc, r) => acc + (r[key] || 0), 0);
        const curAum=sum('curAum');
        const curGross=sum('curGross');
        const curRebates=sum('curRebates');
        const curNet=sum('curNet');
        const simAum=sum('simAum');
        const newMoney=sum('newMoney');
        const newAum=sum('newAum')
        const simGross=sum('simGross');
        const simRebates=sum('simRebates');
        const simNet=sum('simNet');
        return {
            curAum, curGross, curRebates, curNet, simAum, newMoney, newAum, simGross, simRebates, simNet,
            curAumFmt:fmtInt(curAum), curGrossFmt:fmtInt(curGross), curRebatesFmt:fmtInt(curRebates), curNetFmt:fmtInt(curNet),
            simAumFmt:fmtInt(simAum), newMoneyFmt:fmtInt(newMoney), newAumFmt:fmtInt(newAum), simGrossFmt:fmtInt(simGross), simRebatesFmt:fmtInt(simRebates), simNetFmt:fmtInt(simNet)
        };
    }

    // ── Step 4: summary (% of AUM) ────────────────────────────────────────────
    get summary() {
        const t = this.totals;
        const curGrossPct   = t.curAum ? t.curGross   / t.curAum : 0;
        const curRebatesPct = t.curAum ? t.curRebates / t.curAum : 0;
        const curNetPct     = t.curAum ? t.curNet     / t.curAum : 0;
        const simGrossPct   = t.newAum ? t.simGross   / t.newAum : 0;
        const simRebatesPct = t.newAum ? t.simRebates / t.newAum : 0;
        const simNetPct     = t.newAum ? t.simNet     / t.newAum : 0;
        return {
            curGrossPct, curRebatesPct, curNetPct, simGrossPct, simRebatesPct, simNetPct,
            curGrossFmt: fmt(curGrossPct * 100, '%'), curRebatesFmt: fmt(curRebatesPct * 100, '%'), curNetFmt: fmt(curNetPct * 100, '%'),
            simGrossFmt: fmt(simGrossPct * 100, '%'), simRebatesFmt: fmt(simRebatesPct * 100, '%'), simNetFmt: fmt(simNetPct * 100, '%')
        };
    }

    // ── Step 5: analysis (delta vs CURRENT) ───────────────────────────────────
    get analysis() {
        const t = this.totals;
        const s = this.summary;
        const aumEvo       = t.curAum ? (t.newAum / t.curAum - 1) * 100 : 0;
        const grossChgBP   = (s.simGrossPct   - s.curGrossPct)   * 100 * 100;
        const rebatesChgBP = (s.simRebatesPct - s.curRebatesPct) * 100 * 100;
        const netChgBP     = (s.simNetPct     - s.curNetPct)     * 100 * 100;
        return {
            aumEvoFmt:        fmt(aumEvo, '%'),
            grossChgFmt:      fmt(grossChgBP, ' bp'),
            rebatesChgFmt:    fmt(rebatesChgBP, ' bp'),
            netChgFmt:        fmt(netChgBP, ' bp'),
            aumChgAbsFmt:     fmtInt(t.newAum    - t.curAum),
            grossChgAbsFmt:   fmtInt(t.simGross  - t.curGross),
            rebatesChgAbsFmt: fmtInt(t.simRebates - t.curRebates),
            netChgAbsFmt:     fmtInt(t.simNet    - t.curNet)
        };
    }

    get hasRows()  { return this.rows.length > 0 || this.customRows.length > 0; }
    get hasError() { return !!this.error; }

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        this.error = null;
        try {
            const shareClassIds = (this.selectedShareClasses || []).map(sc => sc.id);

            // Invert gridShareClassMap (gridId → [scId]) to scId → gridId
            const scGridMap = {};
            const map = this.gridShareClassMap || {};
            Object.keys(map).forEach(gridId => {
                (map[gridId] || []).forEach(scId => { scGridMap[scId] = gridId; });
            });

            const raw = await getSimulationData({
                shareClassIds: shareClassIds,
                agreementIds: this.selectedAgreements || [],
                shareClassGridIdMapJson: JSON.stringify(scGridMap)
            });

            this.rows = (raw || []).map(r => ({ ...r, newMoney: 0 }));
        }
        catch (e) {
            this.error = e?.body?.message || e?.message || 'Unknown error';
        }
        finally {
            this.isLoading = false;
        }
    }

    renderedCallback() {
        if (this._focusNewMoney && this.editingNewMoneyId) {
            this._focusNewMoney = false;
            const input = this.template.querySelector(`input[data-id="${this.editingNewMoneyId}"][data-field="newMoney"]`);
            if (input) input.focus();
        }
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    // ── Global AUM % change ───────────────────────────────────────────────────
    handleAumChange(e) {
        this.aumChangePercent = e.target.value;
    }

    // ── New Money click-to-edit ───────────────────────────────────────────────
    handleNewMoneyClick(e) {
        this.editingNewMoneyId = e.currentTarget.dataset.id;
        this._focusNewMoney = true;
    }

    handleNewMoneyBlur() {
        this.editingNewMoneyId = null;
    }

    // ── Per-row inputs (real rows) ────────────────────────────────────────────
    handleNewMoney(e) {
        const id = e.target.dataset.id;
        this.rows = this.rows.map(r =>
            r.shareClassId === id ? { ...r, newMoney: parseFloat(e.target.value) || 0 } : r
        );
    }

    // ── Custom row handlers ───────────────────────────────────────────────────
    handleAddRow() {
        this.customRows = [...this.customRows, {
            shareClassId: `custom-${Date.now()}`,
            isCustom: true,
            range: '', ptfCode: '', name: '', isin: '',
            effMgtFees: 0, rebateRate: 0, aum: 0, newMoney: 0
        }];
    }

    handleCustomField(e) {
        const id    = e.target.dataset.id;
        const field = e.target.dataset.field;
        const numericFields = ['effMgtFees', 'rebateRate', 'newMoney'];
        const value = numericFields.includes(field) ? (parseFloat(e.target.value) || 0) : (e.target.value || '');
        this.customRows = this.customRows.map(r => r.shareClassId === id ? { ...r, [field]: value } : r );
    }

    handleRemoveRow(e) {
        const id = e.currentTarget.dataset.id;
        this.customRows = this.customRows.filter(r => r.shareClassId !== id);
    }
}