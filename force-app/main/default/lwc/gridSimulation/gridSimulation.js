import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LABELS } from 'c/gridBuilderUtils';
import XlsxJsStyle from '@salesforce/resourceUrl/xlsxjsstyle';
import ExcelJs     from '@salesforce/resourceUrl/exceljs';
import getSimulationData         from '@salesforce/apex/GridSimulationController.getSimulationData';
import getAgreementRegion        from '@salesforce/apex/GridSimulationController.getAgreementRegion';
import getSimulationInitData     from '@salesforce/apex/GridSimulationController.getSimulationInitData';
import getActiveGridSimulationData from '@salesforce/apex/GridSimulationController.getActiveGridSimulationData';

const FMT     = new Intl.NumberFormat('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const FMT_INT = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 });
const fmt     = (v, suffix = '') => (v == null ? '—' : FMT.format(v) + suffix);
const fmtInt  = (v, suffix = '') => {
    if (v == null) return '—';
    const n = +v;
    if (!isFinite(n)) return '—';
    const abs = Math.abs(n);
    if (abs >= 1_000_000_000) return FMT_INT.format(Math.trunc(n / 1_000_000)) + ' M';
    if (abs > 1_000_000)     return FMT.format(n / 1_000_000) + ' M';
    return FMT_INT.format(Math.trunc(n)) + suffix;
};

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

    // ── Step 2: formatted rows for the main tbody ─────────────────────────────
    get processedRows() {
        return this.rawRows.filter(r => !r.isCustom).map(r => ({
            key:               r.shareClassId,
            shareClassId:      r.shareClassId,
            range:             r.range          || '—',
            ptfCode:           r.ptfCode        || '—',
            productName:       r.productName    || r.name || '',
            type:              r.shareClassType || '—',
            isin:              r.isin           || '',
            effMgtFeesFmt:     fmt(r.effMgtFees, '%'),
            rowStatus:         r.rowStatus,
            rowClass:          r.rowStatus === 'current-only'   ? 'row-current-only'
                             : r.rowStatus === 'simulated-only' ? 'row-simulated-only' : '',
            hasCurrentData:    r.hasCurrentData,
            hasSimulatedData:  r.hasSimulatedData,
            // CURRENT
            curAumFmt:         r.hasCurrentData   ? fmtInt(r.curAum)       : '—',
            curRebRateFmt:     r.hasCurrentData   ? fmt(r.curRebRate, '%')  : '—',
            curGrossFmt:       r.hasCurrentData   ? fmtInt(r.curGross)     : '—',
            curRebatesFmt:     r.hasCurrentData   ? fmtInt(r.curRebates)   : '—',
            curNetFmt:         r.hasCurrentData   ? fmtInt(r.curNet)       : '—',
            // SIMULATED
            additionalMoney:      r.additionalMoney,
            additionalMoneyFmt:   r.hasSimulatedData ? fmtInt(r.additionalMoney) : '—',
            isEditingNewMoney:    r.hasSimulatedData && this.editingNewMoneyId === r.shareClassId,
            newMoneyCellClass:    r.hasSimulatedData
                                    ? (this.editingNewMoneyId === r.shareClassId ? 'td-sim td-input' : 'td-sim td-right')
                                    : 'td-sim',
            newAumFmt:            r.hasSimulatedData ? fmtInt(r.newAum)          : '—',
            simGrossFmt:          r.hasSimulatedData ? fmtInt(r.simGross)        : '—',
            simRebRateFmt:        r.hasSimulatedData ? fmt(r.simRebRate, '%')    : '—',
            simRebatesFmt:        r.hasSimulatedData ? fmtInt(r.simRebates)      : '—',
            simNetFmt:            r.hasSimulatedData ? fmtInt(r.simNet)          : '—'
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
            additionalMoneyFmt:   fmtInt(r.additionalMoney || 0),
            isEditingNewMoney:    this.editingNewMoneyId === r.shareClassId,
            newMoneyCellClass:    this.editingNewMoneyId === r.shareClassId ? 'td-sim td-input' : 'td-sim td-right',
            newAumFmt:            fmtInt(r.newAum),
            simGrossFmt:          fmtInt(r.simGross),
            simRebatesFmt:        fmtInt(r.simRebates),
            simNetFmt:            fmtInt(r.simNet)
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
            curAumFmt:          fmtInt(curAum),
            curGrossFmt:        fmtInt(curGross),
            curRebatesFmt:      fmtInt(curRebates),
            curNetFmt:          fmtInt(curNet),
            additionalMoneyFmt: fmtInt(additionalMoney),
            newAumFmt:          fmtInt(newAum),
            simGrossFmt:        fmtInt(simGross),
            simRebatesFmt:      fmtInt(simRebates),
            simNetFmt:          fmtInt(simNet)
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
            curGrossFmt:   fmt(curGrossPct * 100, '%'),
            curRebatesFmt: fmt(curRebatesPct * 100, '%'),
            curNetFmt:     fmt(curNetPct * 100, '%'),
            simGrossFmt:   fmt(simGrossPct * 100, '%'),
            simRebatesFmt: fmt(simRebatesPct * 100, '%'),
            simNetFmt:     fmt(simNetPct * 100, '%')
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
            aumChgAbsFmt:     fmtInt(t.newAum     - t.curAum),
            grossChgAbsFmt:   fmtInt(t.simGross   - t.curGross),
            rebatesChgAbsFmt: fmtInt(t.simRebates - t.curRebates),
            netChgAbsFmt:     fmtInt(t.simNet     - t.curNet)
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

    // ── Excel export (ALLEGATO template) ─────────────────────────────────────
    handleExport() {
        if (!window.XLSX || !window.ExcelJS) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Export not ready',
                message: 'Excel libraries are still loading. Please try again.',
                variant: 'warning'
            }));
            return;
        }

        const COLS = 5;
        const aoa = [], styles = {}, merges = [];
        const lang = this.agreementRegion === 'BP_IT' ? 'IT' : this.agreementRegion === 'BP_FR' ? 'FR' : 'EN';
        const L = key => this.labels[`${key}_${lang}`] || '';

        const border = {
            top:    { style: 'thin', color: { rgb: 'CCCCCC' } },
            bottom: { style: 'thin', color: { rgb: 'CCCCCC' } },
            left:   { style: 'thin', color: { rgb: 'CCCCCC' } },
            right:  { style: 'thin', color: { rgb: 'CCCCCC' } }
        };
        const textStyle = { alignment: { wrapText: true, vertical: 'top' } };
        const hdrStyle  = { fill: { fgColor: { rgb: 'E8E8E8' } }, font: { bold: true }, alignment: { horizontal: 'center', vertical: 'center' }, border };
        const dataStyle = { alignment: { vertical: 'center' }, border };
        const numStyle  = { alignment: { horizontal: 'right', vertical: 'center' }, border };

        const headerLines = L('Grid_SimExport_Header').split('\n');
        headerLines.forEach((line, i) => {
            aoa.push([line, null, null, null, null]);
            styles[`${i},0`] = (i === 0) ? { alignment: { wrapText: true, vertical: 'center', horizontal: 'center' }, font: { bold: true, sz: 13 } } : textStyle;
            merges.push({ s: { r: i, c: 0 }, e: { r: i, c: COLS - 1 } });
        });

        aoa.push([null, null, null, null, null]);

        const colHdrRow = aoa.length;
        aoa.push([
            L('Grid_SimExport_Col_FundName'),
            L('Grid_SimExport_Col_ShareClass'),
            L('Grid_SimExport_Col_ISIN'),
            L('Grid_SimExport_Col_EffMgtFees'),
            L('Grid_SimExport_Col_Rebate')
        ]);
        for (let c = 0; c < COLS; c++) styles[`${colHdrRow},${c}`] = hdrStyle;

        // Export uses the SIMULATED (new grid) rows for the allegato
        this.rawRows.filter(r => !r.isCustom && r.hasSimulatedData).forEach(r => {
            const row = aoa.length;
            aoa.push([
                r.name           || r.productName || '',
                r.shareClassName || r.shareClassType || '',
                r.isin           || '',
                r.simEffFee != null ? r.simEffFee / 100 : '',
                r.simRebRate != null ? r.simRebRate / 100 : ''
            ]);
            for (let c = 0; c < COLS; c++) {
                styles[`${row},${c}`] = (c >= 3) ? numStyle : dataStyle;
            }
        });

        aoa.push([null, null, null, null, null]);

        const footerStart = aoa.length;
        const footerLines = L('Grid_SimExport_Footer').split('\n');
        footerLines.forEach((line, i) => {
            aoa.push([line, null, null, null, null]);
            styles[`${footerStart + i},0`] = (i === 0) ? { ...textStyle, font: { bold: true } } : textStyle;
            merges.push({ s: { r: footerStart + i, c: 0 }, e: { r: footerStart + i, c: COLS - 1 } });
        });

        const colWidths = Array(COLS).fill(10);
        aoa.slice(colHdrRow, footerStart - 1).forEach(rowData => {
            rowData.forEach((cell, ci) => {
                if (cell != null) colWidths[ci] = Math.max(colWidths[ci], String(cell).length);
            });
        });

        const ws = window.XLSX.utils.aoa_to_sheet(aoa);
        ws['!merges'] = merges;
        ws['!cols'] = colWidths.map(w => ({ wch: w + 4 }));

        Object.keys(styles).forEach(key => {
            const [r, c] = key.split(',').map(Number);
            const addr = window.XLSX.utils.encode_cell({ r, c });
            if (!ws[addr]) ws[addr] = { v: '', t: 's' };
            ws[addr].s = styles[key];
        });

        this.rawRows.filter(r => !r.isCustom && r.hasSimulatedData).forEach((_, ri) => {
            const row = colHdrRow + 1 + ri;
            [3, 4].forEach(c => {
                const addr = window.XLSX.utils.encode_cell({ r: row, c });
                if (ws[addr] && ws[addr].v !== '') {
                    ws[addr].t = 'n';
                    ws[addr].z = '0.000%';
                }
            });
        });

        const wb = window.XLSX.utils.book_new();
        window.XLSX.utils.book_append_sheet(wb, ws, 'Allegato');

        const buffer = window.XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
        this.freezeExcelExport(buffer, colHdrRow + 1);
    }

    async freezeExcelExport(buffer, ySplit) {
        const workbook = new window.ExcelJS.Workbook();
        await workbook.xlsx.load(buffer);

        const sheet = workbook.getWorksheet('Allegato');
        sheet.views = [{ state: 'frozen', xSplit: 0, ySplit: ySplit }];

        const finalBuffer = await workbook.xlsx.writeBuffer();
        const uint8 = new Uint8Array(finalBuffer);
        let binary = '';
        for (let i = 0; i < uint8.length; i += 8192) {
            binary += String.fromCharCode(...uint8.subarray(i, i + 8192));
        }
        const base64 = btoa(binary);
        const a = document.createElement('a');
        a.href = 'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,' + base64;
        a.download = 'GridSimulation.xlsx';
        a.click();
    }
}