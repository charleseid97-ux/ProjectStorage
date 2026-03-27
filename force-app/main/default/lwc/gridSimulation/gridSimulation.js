import { LightningElement, api, track } from 'lwc';
import getSimulationData from '@salesforce/apex/GridSimulationController.getSimulationData';

const FMT  = new Intl.NumberFormat('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const fmt  = (v, suffix = '') => (v == null ? '—' : FMT.format(v) + suffix);

export default class GridSimulation extends LightningElement {

    @api selectedShareClasses = [];
    @api selectedAgreements   = [];
    @api gridShareClassMap    = {};

    @track rows             = [];
    @track customRows       = [];
    @track aumChangePercent = 0;
    @track isLoading        = false;
    @track error            = null;

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
            key:            r.shareClassId,
            shareClassId:   r.shareClassId,
            range:          r.range   || '—',
            ptfCode:        r.ptfCode || '—',
            name:           r.name    || '—',
            isin:           r.isin    || '—',
            effMgtFeesFmt:  fmt(r.effMgtFees, '%'),
            curAumFmt:      fmt(r.curAum),
            curGrossFmt:    fmt(r.curGross),
            curRebRateFmt:  fmt(r.rebateRate, '%'),
            curRebatesFmt:  fmt(r.curRebates),
            curNetFmt:      fmt(r.curNet),
            newMoney:       r.newMoney,
            simAumFmt:      fmt(r.simAum),
            newAumFmt:      fmt(r.newAum),
            simGrossFmt:    fmt(r.simGross),
            simRebRateFmt:  fmt(r.rebateRate, '%'),  // read-only display
            simRebatesFmt:  fmt(r.simRebates),
            simNetFmt:      fmt(r.simNet)
        }));
    }

    // ── Step 2b: formatted custom rows for the custom tbody ──────────────────
    get processedCustomRows() {
        return this.rawRows.filter(r => r.isCustom).map(r => ({
            key:           r.shareClassId,
            shareClassId:  r.shareClassId,
            range:         r.range      || '',
            ptfCode:       r.ptfCode    || '',
            name:          r.name       || '',
            isin:          r.isin       || '',
            effMgtFees:    r.effMgtFees || 0,
            rebateRate:    r.rebateRate || 0,
            newMoney:      r.newMoney   || 0,
            newAumFmt:     fmt(r.newAum),
            simGrossFmt:   fmt(r.simGross),
            simRebatesFmt: fmt(r.simRebates),
            simNetFmt:     fmt(r.simNet)
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
            curAumFmt:fmt(curAum), curGrossFmt:fmt(curGross), curRebatesFmt:fmt(curRebates), curNetFmt:fmt(curNet),
            simAumFmt:fmt(simAum), newMoneyFmt:fmt(newMoney), newAumFmt:fmt(newAum), simGrossFmt:fmt(simGross), simRebatesFmt:fmt(simRebates), simNetFmt:fmt(simNet)
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
        return { aumEvoFmt: fmt(aumEvo, '%'), grossChgFmt: fmt(grossChgBP, ' bp'), rebatesChgFmt: fmt(rebatesChgBP, ' bp'), netChgFmt: fmt(netChgBP, ' bp') };
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

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    // ── Global AUM % change ───────────────────────────────────────────────────
    handleAumChange(e) {
        this.aumChangePercent = e.target.value;
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