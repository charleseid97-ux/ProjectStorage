import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import XlsxJsStyle from '@salesforce/resourceUrl/xlsxjsstyle';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMatrixData from '@salesforce/apex/CustomReportMatrixController.getMatrixData';
import LABEL_CONFIG_NOT_FOUND from '@salesforce/label/c.Matrix_ConfigNotFound';
import LABEL_QUERY_ERROR from '@salesforce/label/c.Matrix_QueryError';
import LABEL_NO_DATA from '@salesforce/label/c.Matrix_NoData';

function parseBgColor(inlineStyle) {
    if (!inlineStyle) return null;
    const m = inlineStyle.match(/background-color\s*:\s*(#[0-9a-fA-F]{6})/i);
    return m ? m[1].slice(1).toUpperCase() : null;
}

export default class CustomReportMatrix extends LightningElement {
    @api configName;

    @track matrixData = null;
    @track isLoading = false;
    @track errors = [];
    @track displayRows = [];
    @track allowExcelExport = false;

    sheetJsLoaded = false;
    sheetJsReady = false;

    labels = {
        configNotFound: LABEL_CONFIG_NOT_FOUND,
        queryError: LABEL_QUERY_ERROR,
        noData: LABEL_NO_DATA
    };

    connectedCallback() {
        this.loadMatrix();
    }

    renderedCallback() {
        if (this.sheetJsLoaded) return;
        this.sheetJsLoaded = true;
        loadScript(this, XlsxJsStyle).then(() => { this.sheetJsReady = true; }).catch(() => {});
    }

    async loadMatrix() {
        if (!this.configName) {
            this.errors = [this.labels.configNotFound];
            return;
        }
        this.isLoading = true;
        this.errors = [];
        this.matrixData = null;
        try {
            const result = await getMatrixData({ configName: this.configName });
            this.matrixData = result;
            this.displayRows = this.getDisplayRows();
            this.allowExcelExport = result.allowExcelExport;
        }
        catch (error) {
            const msg = error?.body?.message || error?.message || this.labels.queryError;
            this.errors = [msg];
            this.dispatchEvent(new ShowToastEvent({title: 'Error', message: msg, variant: 'error'}));
        }
        finally {
            this.isLoading = false;
        }
    }

    getDisplayRows() {
        const rows = [];
        (this.matrixData?.rowGroups || []).forEach((rg, rgIdx) => {
            rg.rows.forEach((rd, rdIdx) => {
                rows.push({
                    key: 'row-' + rgIdx + '-' + rdIdx,
                    isFirstRow: rdIdx === 0,
                    rowGroup1Label: rg.label,
                    rowspan: rg.rowspan,
                    rowGroup2Label: rd.label,
                    values: rd.values.map((v, vi) => ({
                        key: 'cell-' + rgIdx + '-' + rdIdx + '-' + vi,
                        value: v.value || '',
                        cssClass: 'value-cell cell-r' + rgIdx + ' cell-c' + vi,
                        inlineStyle: v.inlineStyle || ''
                    }))
                });
            });
        });
        return rows;
    }

    handleRefresh() {
        this.loadMatrix();
    }

    handleExport() {
        if (!this.matrixData) return;
        if (!window.XLSX) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Export not ready', message: 'Excel library is still loading. Please try again.', variant: 'warning' }));
            return;
        }
        const d             = this.matrixData;
        const hasColGroup2  = d.hasColGroup2;
        const hasRowGroup2  = d.hasRowGroup2;
        const leftColCount  = hasRowGroup2 ? 2 : 1;
        const headerRowCount = hasColGroup2 ? 2 : 1;

        const aoa    = [];
        const styles = {};
        const merges = [];

        const border    = { top: { style: 'thin', color: { rgb: 'DDDBDA' } }, bottom: { style: 'thin', color: { rgb: 'DDDBDA' } }, left: { style: 'thin', color: { rgb: 'DDDBDA' } }, right: { style: 'thin', color: { rgb: 'DDDBDA' } } };
        const hdrStyle1 = { fill: { fgColor: { rgb: 'E8E8E8' } }, font: { bold: true }, alignment: { horizontal: 'center', vertical: 'center', wrapText: true }, border };
        const hdrStyle2 = { fill: { fgColor: { rgb: 'F0F0F0' } }, font: { bold: true }, alignment: { horizontal: 'center', vertical: 'center', wrapText: true }, border };
        const rg1Style  = { fill: { fgColor: { rgb: 'F3F2F2' } }, font: { bold: true }, alignment: { horizontal: 'left',   vertical: 'center', wrapText: true }, border };
        const rg2Style  = { fill: { fgColor: { rgb: 'F9F9F9' } },                       alignment: { horizontal: 'left',   vertical: 'center', wrapText: true }, border };

        // ── Header Row 0 (only when hasColGroup2) ──
        if (hasColGroup2) {
            aoa.push(this.buildColGroupHeaderRow(d, hasRowGroup2, leftColCount, hdrStyle1, styles, merges));
        }

        // ── Header Row 1 (always: row-group labels + sub-column labels) ──
        aoa.push(this.buildSubColumnHeaderRow(d, hasColGroup2, hasRowGroup2, leftColCount, hdrStyle2, styles));

        // ── Data Rows ──
        this.buildDataRows(d, hasRowGroup2, leftColCount, headerRowCount, rg1Style, rg2Style, border, aoa, styles, merges);

        // ── Build Worksheet ──
        const ws = this.buildWorksheet(aoa, merges, styles, d, leftColCount);

        const wb = window.XLSX.utils.book_new();
        window.XLSX.utils.book_append_sheet(wb, ws, (d.title || 'Matrix').slice(0, 31));
        window.XLSX.writeFile(wb, `${d.title || this.configName || 'matrix'}.xlsx`);
    }

    buildColGroupHeaderRow(d, hasRowGroup2, leftColCount, hdrStyle1, styles, merges) {
        const row = new Array(leftColCount + (d.subColumnLabels || []).length).fill(null);
        row[0] = (d.colGroup1Label || '') + ' \u2192';
        styles['0,0'] = hdrStyle1;
        if (hasRowGroup2) {
            merges.push({ s: { r: 0, c: 0 }, e: { r: 0, c: 1 } });
            styles['0,1'] = hdrStyle1;
        }
        let cur = leftColCount;
        (d.columnGroups || []).forEach(cg => {
            row[cur] = cg.label;
            for (let c = 0; c < cg.colspan; c++) styles[`0,${cur + c}`] = hdrStyle1;
            if (cg.colspan > 1) merges.push({ s: { r: 0, c: cur }, e: { r: 0, c: cur + cg.colspan - 1 } });
            cur += cg.colspan;
        });
        return row;
    }

    buildSubColumnHeaderRow(d, hasColGroup2, hasRowGroup2, leftColCount, hdrStyle2, styles) {
        const hr  = hasColGroup2 ? 1 : 0;
        const row = [];
        row.push((d.rowGroup1Label || '') + ' \u2193');
        styles[`${hr},0`] = hdrStyle2;
        if (hasRowGroup2) {
            row.push((d.rowGroup2Label || '') + ' \u2193');
            styles[`${hr},1`] = hdrStyle2;
        }
        (d.subColumnLabels || []).forEach((lbl, i) => {
            row.push(lbl);
            styles[`${hr},${leftColCount + i}`] = hdrStyle2;
        });
        return row;
    }

    buildDataRows(d, hasRowGroup2, leftColCount, headerRowCount, rg1Style, rg2Style, border, aoa, styles, merges) {
        let currentRow = headerRowCount;
        (d.rowGroups || []).forEach(rg => {
            const firstRowInGroup = currentRow;
            rg.rows.forEach((rd, rdIdx) => {
                const row = [];
                row.push(rdIdx === 0 ? rg.label : null);
                styles[`${currentRow},0`] = rg1Style;
                if (hasRowGroup2) {
                    row.push(rd.label || '');
                    styles[`${currentRow},1`] = rg2Style;
                }
                (rd.values || []).forEach((v, vi) => {
                    row.push(v.value || '');
                    const bg = parseBgColor(v.inlineStyle) || 'FFFFFF';
                    styles[`${currentRow},${leftColCount + vi}`] = {
                        fill: { fgColor: { rgb: bg } },
                        alignment: { horizontal: 'center', vertical: 'center' },
                        border
                    };
                });
                aoa.push(row);
                currentRow++;
            });
            if (rg.rowspan > 1) {
                merges.push({ s: { r: firstRowInGroup, c: 0 }, e: { r: firstRowInGroup + rg.rowspan - 1, c: 0 } });
            }
        });
    }

    buildWorksheet(aoa, merges, styles, d, leftColCount) {
        const ws = window.XLSX.utils.aoa_to_sheet(aoa);
        ws['!merges'] = merges;
        const totalCols = leftColCount + (d.subColumnLabels || []).length;
        ws['!cols'] = Array.from({ length: totalCols }, (_, i) => ({ wch: i < leftColCount ? 25 : 12 }));
        Object.keys(styles).forEach(key => {
            const [r, c] = key.split(',').map(Number);
            const addr = window.XLSX.utils.encode_cell({ r, c });
            if (!ws[addr]) ws[addr] = { v: '', t: 's' };
            ws[addr].s = styles[key];
        });
        return ws;
    }

    // ------------------------------------ GETTERS ------------------------------------
    get isExportDisabled() {
        return !this.hasData;
    }

    get title() {
        return this.matrixData?.title || this.configName || '';
    }

    get hasErrors() {
        return this.errors && this.errors.length > 0;
    }

    get hasData() {
        return this.matrixData && this.matrixData.rowGroups && this.matrixData.rowGroups.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.hasErrors && !this.hasData;
    }

    get hasColGroup2() {
        return this.matrixData?.hasColGroup2 || false;
    }

    get hasRowGroup2() {
        return this.matrixData?.hasRowGroup2 || false;
    }

    get columnGroups() {
        return this.matrixData?.columnGroups || [];
    }

    get subColumnLabels() {
        return (this.matrixData?.subColumnLabels || []).map((label, idx) => ({
            key: 'sub-' + idx,
            label: label
        }));
    }

    get colGroup1Label() {
        return this.matrixData?.colGroup1Label || '';
    }

    get colGroup2Label() {
        return this.matrixData?.colGroup2Label || '';
    }

    get rowGroup1Label() {
        return this.matrixData?.rowGroup1Label || '';
    }

    get rowGroup2Label() {
        return this.matrixData?.rowGroup2Label || '';
    }

    get cornerColspan() {
        return this.hasRowGroup2 ? 2 : 1;
    }
}