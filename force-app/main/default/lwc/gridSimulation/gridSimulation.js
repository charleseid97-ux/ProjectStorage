import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LABELS } from 'c/gridBuilderUtils';
import XlsxJsStyle from '@salesforce/resourceUrl/xlsxjsstyle';
import ExcelJs     from '@salesforce/resourceUrl/exceljs';
import getSimulationData    from '@salesforce/apex/GridSimulationController.getSimulationData';
import getAgreementRegion  from '@salesforce/apex/GridSimulationController.getAgreementRegion';
import getSimulationInitData from '@salesforce/apex/GridSimulationController.getSimulationInitData';

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
    labels                     = LABELS;
    sheetJsLoaded              = false;
    sheetJsReady               = false;
    excelJsLoaded              = false;
    agreementRegion            = null;

    // ── Step 1: raw numbers — base for all derived getters ───────────────────
    get rawRows() {
        const globalPct = parseFloat(this.aumChangePercent) || 0;
        return [...this.rows, ...this.customRows].map(r => {
            const curAum     = parseFloat(r.aum)        || 0;
            const effFee     = parseFloat(r.effMgtFees) || 0;
            const curRebRate = parseFloat(r.rebateRate) || 0;
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
        const sum = key => rr.reduce((acc, r) => acc + (parseFloat(r[key]) || 0), 0);
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
                // Record page: single round-trip
                const init = await getSimulationInitData({ gridId: this.recordId });
                this.rows            = (init.rows || []).map(r => ({ ...r, newMoney: 0 }));
                this.agreementRegion = init.agreementRegion;
            } else {
                // customGridBuilder: props-driven path
                const shareClassIds = (this.selectedShareClasses || []).map(sc => sc.id);
                const scGridMap = {};
                const map = this.gridShareClassMap || {};
                Object.keys(map).forEach(gridId => {
                    (map[gridId] || []).forEach(scId => { scGridMap[scId] = gridId; });
                });
                const [raw, region] = await Promise.all([
                    getSimulationData({
                        shareClassIds: shareClassIds,
                        agreementIds: this.selectedAgreements || [],
                        shareClassGridIdMapJson: JSON.stringify(scGridMap)
                    }),
                    getAgreementRegion({ agreementIds: this.selectedAgreements || [] })
                ]);
                this.rows            = (raw || []).map(r => ({ ...r, newMoney: 0 }));
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
            console.log('ExcelJS resource URL:', ExcelJs);
            if (!ExcelJs) {
                console.error('ExcelJS static resource URL is undefined — make sure the resource is deployed to the org with the name "exceljs"');
            } else {
                loadScript(this, ExcelJs)
                    .then(() => { console.log('ExcelJS loaded successfully, window.ExcelJS:', !!window.ExcelJS); })
                    .catch(e => { console.error('Failed to load ExcelJS script:', e); });
            }
        }
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
            range: '', ptfCode: '', name: '', isin: '',
            effMgtFees: 0, rebateRate: 0, aum: 0, newMoney: 0
        }];
    }

    handleCustomField(e) {
        const id    = e.target.dataset.id;
        const field = e.target.dataset.field;
        const numericFields = ['effMgtFees', 'rebateRate', 'newMoney'];
        const value = numericFields.includes(field) ? (field === 'newMoney' ? parseNewMoney(e.target.value) : (parseFloat(e.target.value) || 0)) : (e.target.value || '');
        this.customRows = this.customRows.map(r => r.shareClassId === id ? { ...r, [field]: value } : r );
    }

    handleRemoveRow(e) {
        const id = e.currentTarget.dataset.id;
        this.customRows = this.customRows.filter(r => r.shareClassId !== id);
    }

    // ── Excel export (ALLEGATO template) ─────────────────────────────────────
    handleExport() {
        if (!window.XLSX) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Export not ready',
                message: 'Excel library is still loading. Please try again.',
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

        // 1. Header block — each line becomes its own row, merged A–E
        const headerLines = L('Grid_SimExport_Header').split('\n');
        headerLines.forEach((line, i) => {
            aoa.push([line, null, null, null, null]);
            styles[`${i},0`] = (i === 0) ? { alignment: { wrapText: true, vertical: 'center', horizontal: 'center' }, font: { bold: true, sz: 13 } } : textStyle;
            merges.push({ s: { r: i, c: 0 }, e: { r: i, c: COLS - 1 } });
        });

        // 2. Blank separator
        aoa.push([null, null, null, null, null]);

        // 3. Column header row
        const colHdrRow = aoa.length;
        aoa.push([
            L('Grid_SimExport_Col_FundName'),
            L('Grid_SimExport_Col_ShareClass'),
            L('Grid_SimExport_Col_ISIN'),
            L('Grid_SimExport_Col_EffMgtFees'),
            L('Grid_SimExport_Col_Rebate')
        ]);
        for (let c = 0; c < COLS; c++) styles[`${colHdrRow},${c}`] = hdrStyle;

        // 4. Data rows (real + custom rows, non-custom only for the official export)
        this.rawRows.filter(r => !r.isCustom).forEach(r => {
            const row = aoa.length;
            aoa.push([
                r.name           || '',
                r.shareClassName || '',
                r.isin           || '',
                r.effMgtFees != null ? r.effMgtFees / 100 : '',
                r.rebateRate  != null ? r.rebateRate  / 100 : ''
            ]);
            for (let c = 0; c < COLS; c++) {
                styles[`${row},${c}`] = (c >= 3) ? numStyle : dataStyle;
            }
        });

        // 5. Blank separator
        aoa.push([null, null, null, null, null]);

        // 6. Footer block — each line merged A–E
        const footerStart = aoa.length;
        const footerLines = L('Grid_SimExport_Footer').split('\n');
        footerLines.forEach((line, i) => {
            aoa.push([line, null, null, null, null]);
            styles[`${footerStart + i},0`] = (i === 0) ? { ...textStyle, font: { bold: true } } : textStyle;
            merges.push({ s: { r: footerStart + i, c: 0 }, e: { r: footerStart + i, c: COLS - 1 } });
        });

        // Dynamic column widths: measure only from the column header row down to the footer gap
        const colWidths = Array(COLS).fill(10);
        aoa.slice(colHdrRow, footerStart - 1).forEach(rowData => {
            rowData.forEach((cell, ci) => {
                if (cell != null) colWidths[ci] = Math.max(colWidths[ci], String(cell).length);
            });
        });

        // Build worksheet
        const ws = window.XLSX.utils.aoa_to_sheet(aoa);
        ws['!merges'] = merges;
        ws['!cols'] = colWidths.map(w => ({ wch: w + 4 }));
        ws['!views'] = [{ state: 'frozen', ySplit: colHdrRow + 1, xSplit: 0, topLeftCell: 'A' + (colHdrRow + 2) }];

        // Apply cell styles
        Object.keys(styles).forEach(key => {
            const [r, c] = key.split(',').map(Number);
            const addr = window.XLSX.utils.encode_cell({ r, c });
            if (!ws[addr]) ws[addr] = { v: '', t: 's' };
            ws[addr].s = styles[key];
        });

        // Apply percentage number format to fee/rebate columns
        this.rawRows.filter(r => !r.isCustom).forEach((_, ri) => {
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

        // Step 1: write to buffer with xlsxjsstyle (preserves cell styles)
        const buffer = window.XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });

        // Step 2: re-open with ExcelJS to add freeze pane, then write
        this.freezeExcelExport(buffer, colHdrRow + 1);
    }

    async freezeExcelExport(buffer, ySplit) {
        const workbook = new window.ExcelJS.Workbook();
        await workbook.xlsx.load(buffer);

        const sheet = workbook.getWorksheet('Allegato');
        sheet.views = [{ state: 'frozen', xSplit: 0, ySplit: ySplit }];

        const finalBuffer = await workbook.xlsx.writeBuffer();
        const blob = new Blob([finalBuffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'GridSimulation_Allegato.xlsx';
        a.click();
        URL.revokeObjectURL(url);
    }
}