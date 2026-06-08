import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { LABELS, exportGridDetailsExcel, fmtAmt, fmtNum } from 'c/gridBuilderUtils';
import XlsxJsStyle from '@salesforce/resourceUrl/xlsxjsstyle';
import ExcelJs     from '@salesforce/resourceUrl/exceljs';
import getSimulationData           from '@salesforce/apex/GridSimulationController.getSimulationData';
import getAgreementRegion          from '@salesforce/apex/GridSimulationController.getAgreementRegion';
import getSimulationInitData       from '@salesforce/apex/GridSimulationController.getSimulationInitData';
import getActiveGridSimulationData from '@salesforce/apex/GridSimulationController.getActiveGridSimulationData';

function parseNewMoney(raw) {
    if (raw == null) return 0;
    const s = String(raw).trim().replace(/\s/g, '').replace(',', '.').toUpperCase();
    if (!s) return 0;
    const m = s.match(/^(-?\d+(?:\.\d+)?)\s*([KM]?)$/);
    if (!m) return parseFloat(s) || 0;
    const n = parseFloat(m[1]);
    if (m[2] === 'K') return n * 1_000;
    if (m[2] === 'M') return n * 1_000_000;
    return n;
}

export default class GridSimulation extends LightningElement {

    @api recordId;
    @api agreementId;
    @api selectedShareClasses = [];
    @api selectedAgreements   = [];
    @api gridShareClassMap    = {};
    @track rows                = [];
    @track customRows          = [];
    @track currentGridRows     = [];   // previous active grid data (CURRENT section)
    @track hasCurrentGrid      = false;
    @track aumChangePercent    = 0;
    @track isLoading           = false;
    @track error               = null;
    @track editingNewMoneyId   = null;
    @track sortField           = 'curAum';
    @track sortDir             = 'desc';
    focusNewMoney             = false;
    manualOverrideIds         = new Set();
    labels                     = LABELS;
    sheetJsLoaded              = false;
    sheetJsReady               = false;
    excelJsLoaded              = false;
    agreementRegion            = null;

    // ── Step 1a: merged raw rows when previous active grid exists ─────────────
    get mergedRawRows() {
        const simMap = {};
        this.rows.forEach(r => { simMap[r.shareClassId] = r; });
        const curMap = {};
        this.currentGridRows.forEach(r => { curMap[r.shareClassId] = r; });

        const allIds = [...new Set([...Object.keys(simMap), ...Object.keys(curMap)])];
        const merged = [];

        allIds.forEach(id => {
            const sim = simMap[id];
            const cur = curMap[id];
            const status = (sim && cur) ? 'both' : sim ? 'simulated-only' : 'current-only';

            // CURRENT section — from the active grid row
            const curAum     = parseFloat(cur?.aum)        || 0;
            const curEffFee  = parseFloat(cur?.effMgtFees) || 0;
            const curRebRate = parseFloat(cur?.rebateRate) || 0;
            const curGross   = curEffFee * curAum / 100;
            const curRebates = curRebRate * curAum / 100;
            const curNet     = curGross - curRebates;

            // SIMULATED section — from the new grid row
            const simEffFee       = parseFloat(sim?.effMgtFees) || 0;
            const simRebRate      = parseFloat(sim?.rebateRate) || 0;
            const baseAum         = parseFloat(sim?.aum)        || 0;
            const additionalMoney = sim?.newMoney || 0;
            const newAum          = baseAum + additionalMoney;
            const simGross        = simEffFee * newAum / 100;
            const simRebates      = simRebRate * newAum / 100;
            const simNet          = simGross - simRebates;

            merged.push({
                shareClassId:      id,
                isCustom:          false,
                range:             sim?.range          || cur?.range          || '—',
                ptfCode:           sim?.ptfCode        || cur?.ptfCode        || '—',
                productName:       sim?.name           || cur?.name           || '',
                shareClassType:    sim?.shareClassType || cur?.shareClassType || '—',
                isin:              sim?.isin           || cur?.isin           || '',
                effMgtFees:        simEffFee || curEffFee,
                newMoney:          additionalMoney,
                rowStatus:         status,
                hasCurrentData:    status !== 'simulated-only',
                hasSimulatedData:  status !== 'current-only',
                // CURRENT computed
                curAum, curEffFee, curRebRate, curGross, curRebates, curNet,
                // SIMULATED computed
                simEffFee, simRebRate, additionalMoney, newAum, simGross, simRebates, simNet
            });
        });

        // Custom rows are always SIMULATED-only
        this.customRows.forEach(r => {
            const simEffFee       = parseFloat(r.effMgtFees) || 0;
            const simRebRate      = parseFloat(r.rebateRate)  || 0;
            const additionalMoney = r.newMoney || 0;
            const newAum          = additionalMoney;
            merged.push({
                shareClassId:      r.shareClassId,
                isCustom:          true,
                range:             r.range   || '',
                ptfCode:           r.ptfCode || '',
                type:              r.type    || '',
                effMgtFees:        simEffFee,
                rebateRate:        simRebRate,
                newMoney:          r.newMoney,
                rowStatus:         'simulated-only',
                hasCurrentData:    false,
                hasSimulatedData:  true,
                curAum: 0, curEffFee: 0, curRebRate: 0, curGross: 0, curRebates: 0, curNet: 0,
                simEffFee, simRebRate, additionalMoney, newAum,
                simGross:   simEffFee * newAum / 100,
                simRebates: simRebRate * newAum / 100,
                simNet:     (simEffFee - simRebRate) * newAum / 100
            });
        });

        return merged;
    }

    // ── Step 1b: raw rows — fallback when no previous active grid ─────────────
    get rawRows() {
        if (this.hasCurrentGrid) return this.mergedRawRows;

        return [...this.rows, ...this.customRows].map(r => {
            const curAum          = parseFloat(r.aum)        || 0;
            const effFee          = parseFloat(r.effMgtFees) || 0;
            const curRebRate      = parseFloat(r.rebateRate) || 0;
            const curGross        = effFee * curAum / 100;
            const curRebates      = curRebRate * curAum / 100;
            const curNet          = curGross - curRebates;
            const additionalMoney = r.newMoney || 0;
            const newAum          = curAum + additionalMoney;
            const simGross        = effFee * newAum / 100;
            const simRebates      = curRebRate * newAum / 100;
            const simNet          = simGross - simRebates;
            return {
                ...r,
                rowStatus: 'both', hasCurrentData: true, hasSimulatedData: true,
                curAum, curEffFee: effFee, curRebRate, curGross, curRebates, curNet,
                simEffFee: effFee, simRebRate: curRebRate,
                additionalMoney, newAum, simGross, simRebates, simNet
            };
        });
    }

    // ── Column sort state ─────────────────────────────────────────────────────
    get sortIndicators() {
        const cols = ['range','ptfCode','type','effMgtFees','curAum','curRebRate','curGross','curRebates','curNet','additionalMoney','newAum','simRebRate','simGross','simRebates','simNet'];
        return Object.fromEntries(
            cols.map(c => [c, this.sortField === c ? (this.sortDir === 'asc' ? '↑' : '↓') : ''])
        );
    }

    // ── Step 2: formatted rows for the main tbody ─────────────────────────────
    get processedRows() {
        const TEXT_FIELDS = new Set(['range', 'ptfCode', 'type']);
        let rows = this.rawRows.filter(r => !r.isCustom);

        if (this.sortField) {
            const field  = this.sortField;
            const dir    = this.sortDir === 'asc' ? 1 : -1;
            const rawKey = field === 'type' ? 'shareClassType' : field;
            rows = [...rows].sort((a, b) => {
                const va = a[rawKey];
                const vb = b[rawKey];
                if (TEXT_FIELDS.has(field)) {
                    return dir * String(va || '').localeCompare(String(vb || ''), 'fr');
                }
                return dir * (Math.abs(+va || 0) - Math.abs(+vb || 0));
            });
        }

        return rows.map(r => ({
            key:               r.shareClassId,
            shareClassId:      r.shareClassId,
            range:             r.range          || '—',
            ptfCode:           r.ptfCode        || '—',
            productName:       r.productName    || r.name || '',
            type:              r.shareClassType || '—',
            isin:              r.isin           || '',
            effMgtFeesFmt:     fmtNum(r.effMgtFees, '%'),
            rowStatus:         r.rowStatus,
            rowClass:          r.rowStatus === 'current-only'   ? 'row-current-only'
                             : r.rowStatus === 'simulated-only' ? 'row-simulated-only' : '',
            hasCurrentData:    r.hasCurrentData,
            hasSimulatedData:  r.hasSimulatedData,
            // CURRENT
            curAumFmt:         r.hasCurrentData   ? fmtAmt(r.curAum)    ?? '—' : '—',
            curRebRateFmt:     r.hasCurrentData   ? fmtNum(r.curRebRate, '%')  : '—',
            curGrossFmt:       r.hasCurrentData   ? fmtAmt(r.curGross)  ?? '—' : '—',
            curRebatesFmt:     r.hasCurrentData   ? fmtAmt(r.curRebates)?? '—' : '—',
            curNetFmt:         r.hasCurrentData   ? fmtAmt(r.curNet)    ?? '—' : '—',
            // SIMULATED
            additionalMoney:      r.additionalMoney,
            additionalMoneyFmt:   r.hasSimulatedData ? fmtAmt(r.additionalMoney) ?? '—' : '—',
            isEditingNewMoney:    r.hasSimulatedData && this.editingNewMoneyId === r.shareClassId,
            newMoneyCellClass:    r.hasSimulatedData
                                    ? (this.editingNewMoneyId === r.shareClassId ? 'td-sim td-input' : 'td-sim td-right')
                                    : 'td-sim',
            newAumFmt:            r.hasSimulatedData ? fmtAmt(r.newAum)     ?? '—' : '—',
            simGrossFmt:          r.hasSimulatedData ? fmtAmt(r.simGross)   ?? '—' : '—',
            simRebRateFmt:        r.hasSimulatedData ? fmtNum(r.simRebRate, '%')   : '—',
            simRebatesFmt:        r.hasSimulatedData ? fmtAmt(r.simRebates) ?? '—' : '—',
            simNetFmt:            r.hasSimulatedData ? fmtAmt(r.simNet)     ?? '—' : '—'
        }));
    }

    // ── Step 2b: formatted custom rows ────────────────────────────────────────
    get processedCustomRows() {
        return this.rawRows.filter(r => r.isCustom).map(r => ({
            key:                  r.shareClassId,
            shareClassId:         r.shareClassId,
            range:                r.range      || '',
            ptfCode:              r.ptfCode    || '',
            type:                 r.type       || '',
            effMgtFees:           r.effMgtFees || 0,
            rebateRate:           r.simRebRate || 0,
            additionalMoney:      r.additionalMoney || 0,
            additionalMoneyFmt:   fmtAmt(r.additionalMoney || 0) ?? '—',
            isEditingNewMoney:    this.editingNewMoneyId === r.shareClassId,
            newMoneyCellClass:    this.editingNewMoneyId === r.shareClassId ? 'td-sim td-input' : 'td-sim td-right',
            newAumFmt:            fmtAmt(r.newAum)     ?? '—',
            simGrossFmt:          fmtAmt(r.simGross)   ?? '—',
            simRebatesFmt:        fmtAmt(r.simRebates) ?? '—',
            simNetFmt:            fmtAmt(r.simNet)     ?? '—'
        }));
    }

    // ── Step 3: totals ────────────────────────────────────────────────────────
    get totals() {
        const rr = this.rawRows;
        const sumIf = (key, flag) => rr.reduce((acc, r) => acc + (r[flag] ? (parseFloat(r[key]) || 0) : 0), 0);
        const sum   = key        => rr.reduce((acc, r) => acc + (parseFloat(r[key]) || 0), 0);

        const useMerged = this.hasCurrentGrid;
        const curAum          = useMerged ? sumIf('curAum',          'hasCurrentData')   : sum('curAum');
        const curGross        = useMerged ? sumIf('curGross',        'hasCurrentData')   : sum('curGross');
        const curRebates      = useMerged ? sumIf('curRebates',      'hasCurrentData')   : sum('curRebates');
        const curNet          = useMerged ? sumIf('curNet',          'hasCurrentData')   : sum('curNet');
        const additionalMoney = useMerged ? sumIf('additionalMoney', 'hasSimulatedData') : sum('additionalMoney');
        const newAum          = useMerged ? sumIf('newAum',          'hasSimulatedData') : sum('newAum');
        const simGross        = useMerged ? sumIf('simGross',        'hasSimulatedData') : sum('simGross');
        const simRebates      = useMerged ? sumIf('simRebates',      'hasSimulatedData') : sum('simRebates');
        const simNet          = useMerged ? sumIf('simNet',          'hasSimulatedData') : sum('simNet');
        return {
            curAum, curGross, curRebates, curNet, additionalMoney, newAum, simGross, simRebates, simNet,
            curAumFmt:          fmtAmt(curAum)          ?? '—',
            curGrossFmt:        fmtAmt(curGross)        ?? '—',
            curRebatesFmt:      fmtAmt(curRebates)      ?? '—',
            curNetFmt:          fmtAmt(curNet)          ?? '—',
            additionalMoneyFmt: fmtAmt(additionalMoney) ?? '—',
            newAumFmt:          fmtAmt(newAum)          ?? '—',
            simGrossFmt:        fmtAmt(simGross)        ?? '—',
            simRebatesFmt:      fmtAmt(simRebates)      ?? '—',
            simNetFmt:          fmtAmt(simNet)          ?? '—'
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
            curGrossFmt:   fmtNum(curGrossPct * 100, '%'),
            curRebatesFmt: fmtNum(curRebatesPct * 100, '%'),
            curNetFmt:     fmtNum(curNetPct * 100, '%'),
            simGrossFmt:   fmtNum(simGrossPct * 100, '%'),
            simRebatesFmt: fmtNum(simRebatesPct * 100, '%'),
            simNetFmt:     fmtNum(simNetPct * 100, '%')
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
            aumEvoFmt:        fmtNum(aumEvo, '%'),
            grossChgFmt:      fmtNum(grossChgBP, ' bp'),
            rebatesChgFmt:    fmtNum(rebatesChgBP, ' bp'),
            netChgFmt:        fmtNum(netChgBP, ' bp'),
            aumChgAbsFmt:     fmtAmt(t.newAum     - t.curAum)     ?? '—',
            grossChgAbsFmt:   fmtAmt(t.simGross   - t.curGross)   ?? '—',
            rebatesChgAbsFmt: fmtAmt(t.simRebates - t.curRebates) ?? '—',
            netChgAbsFmt:     fmtAmt(t.simNet     - t.curNet)     ?? '—'
        };
    }

    get hasRows()      { return this.rows.length > 0 || this.customRows.length > 0; }
    get hasError()     { return !!this.error; }
    get isRecordPage() { return !!this.recordId; }

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        this.error = null;
        try {
            if (this.recordId) {
                // Record page: single round-trip, no change in behavior
                const init = await getSimulationInitData({ gridId: this.recordId });
                this.rows            = (init.rows || []).map(r => ({ ...r, newMoney: 0 }));
                this.agreementRegion = init.agreementRegion;
            } else {
                // Grid Builder: fetch new grid rows + previous active grid rows concurrently
                const shareClassIds = (this.selectedShareClasses || []).map(sc => sc.id);
                const scGridMap = {};
                const map = this.gridShareClassMap || {};
                Object.keys(map).forEach(gridId => {
                    (map[gridId] || []).forEach(scId => { scGridMap[scId] = gridId; });
                });

                const [raw, region, currentRaw] = await Promise.all([
                    getSimulationData({
                        shareClassIds: shareClassIds,
                        agreementIds: this.selectedAgreements || [],
                        shareClassGridIdMapJson: JSON.stringify(scGridMap)
                    }),
                    getAgreementRegion({ agreementIds: this.selectedAgreements || [] }),
                    this.agreementId
                        ? getActiveGridSimulationData({ agreementId: this.agreementId })
                        : Promise.resolve([])
                ]);

                this.rows            = (raw        || []).map(r => ({ ...r, newMoney: 0 }));
                this.currentGridRows = (currentRaw || []).map(r => ({ ...r, newMoney: 0 }));
                this.hasCurrentGrid  = this.currentGridRows.length > 0;
                this.agreementRegion = region;
            }
        }
        catch (e) {
            this.error = e?.body?.message || e?.message || 'Unknown error';
        }
        finally {
            this.isLoading = false;
        }
    }

    renderedCallback() {
        if (!this.sheetJsLoaded) {
            this.sheetJsLoaded = true;
            loadScript(this, XlsxJsStyle)
                .then(() => { this.sheetJsReady = true; })
                .catch(e => { console.error('Failed to load XlsxJsStyle:', e); });
        }
        if (!this.excelJsLoaded) {
            this.excelJsLoaded = true;
            if (!ExcelJs) {
                console.error('ExcelJS static resource URL is undefined — make sure the resource is deployed to the org with the name "exceljs"');
            } else {
                loadScript(this, ExcelJs)
                    .then(() => { console.log('ExcelJS loaded successfully'); })
                    .catch(e => { console.error('Failed to load ExcelJS script:', e); });
            }
        }
        if (this.focusNewMoney && this.editingNewMoneyId) {
            this.focusNewMoney = false;
            const input = this.template.querySelector(`input[data-id="${this.editingNewMoneyId}"][data-field="newMoney"]`);
            if (input) input.focus();
        }
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    // ── Save Grid / Submit for Approval ───────────────────────────────────────
    handleSaveGrid() {
        this.dispatchEvent(new CustomEvent('savegrid'));
    }

    handleSubmitForApproval() {
        this.dispatchEvent(new CustomEvent('submitforapproval'));
    }

    // ── Column sorting ────────────────────────────────────────────────────────
    handleSort(e) {
        const field = e.currentTarget.dataset.sort;
        if (this.sortField === field) {
            this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDir   = 'asc';
        }
    }

    // ── Global AUM % change → updates Additional Money on non-overridden new-grid rows ─
    handleAumChange(e) {
        this.aumChangePercent = parseFloat(e.target.value) || 0;
        const pct = this.aumChangePercent;
        this.rows = this.rows.map(r => {
            if (this.manualOverrideIds.has(r.shareClassId)) return r;
            const curAum = parseFloat(r.aum) || 0;
            return { ...r, newMoney: curAum * pct / 100 };
        });
    }

    // ── Additional Money click-to-edit ────────────────────────────────────────
    handleNewMoneyClick(e) {
        this.editingNewMoneyId = e.currentTarget.dataset.id;
        this.focusNewMoney = true;
    }

    handleNewMoneyBlur() {
        this.editingNewMoneyId = null;
    }

    // ── Per-row inputs (real rows) ────────────────────────────────────────────
    handleNewMoney(e) {
        const id = e.target.dataset.id;
        this.manualOverrideIds.add(id);
        this.rows = this.rows.map(r =>
            r.shareClassId === id ? { ...r, newMoney: parseNewMoney(e.target.value) } : r
        );
    }

    handleNewMoneyFocus(e) {
        e.target.select();
    }

    // ── Custom row handlers ───────────────────────────────────────────────────
    handleAddRow() {
        this.customRows = [...this.customRows, {
            shareClassId: `custom-${Date.now()}`,
            isCustom: true,
            range: '', ptfCode: '', type: '',
            effMgtFees: 0, rebateRate: 0, aum: 0, newMoney: 0
        }];
    }

    handleCustomField(e) {
        const id    = e.target.dataset.id;
        const field = e.target.dataset.field;
        const numericFields = ['effMgtFees', 'rebateRate', 'newMoney'];
        const value = numericFields.includes(field)
            ? (field === 'newMoney' ? parseNewMoney(e.target.value) : (parseFloat(e.target.value) || 0))
            : (e.target.value || '');
        if (field === 'newMoney') this.manualOverrideIds.add(id);
        this.customRows = this.customRows.map(r => r.shareClassId === id ? { ...r, [field]: value } : r);
    }

    handleRemoveRow(e) {
        const id = e.currentTarget.dataset.id;
        this.manualOverrideIds.delete(id);
        this.customRows = this.customRows.filter(r => r.shareClassId !== id);
    }

    // ── Excel export ──────────────────────────────────────────────────────────
    async handleExport() {
        await exportGridDetailsExcel({
            component: this,
            agreementRegion: this.agreementRegion,
            rows: this.rawRows,
            source: 'simulation',
            labels: this.labels
        });
    }
}