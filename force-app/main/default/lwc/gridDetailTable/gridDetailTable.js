import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { reduceError } from 'c/gridBuilderUtils';
import getGridDetails from '@salesforce/apex/GridDetailTableController.getGridDetails';
import { LABELS } from 'c/gridBuilderUtils';
import XlsxJsStyle from '@salesforce/resourceUrl/xlsxjsstyle';

const COLUMNS = [
    { key: 'assetType',         label: 'Asset Type',        group: '' },
    { key: 'strategy',          label: 'Strategy',          group: '' },
    { key: 'legalStatus',       label: 'Legal Status',      group: '' },
    { key: 'internalShortName', label: 'Code',              group: '' },
    { key: 'portfolio',         label: 'Portfolio',         group: 'blue' },
    { key: 'shareClass',        label: 'Class',             group: 'blue' },
    { key: 'isin',              label: 'ISIN',              group: 'blue' },
    { key: 'aum',               label: 'AUM',               group: 'blue',   numeric: true },
    { key: 'effMgtFeeDate',     label: 'Start Date',        group: '' },
    { key: 'endDate',           label: 'End Date',          group: '' },
    { key: 'effMgtFee',         label: 'Eff. Mgt Fee',      group: 'blue',   numeric: true },
    { key: 'rebateRate',        label: 'Rebate Rate',       group: 'blue',   numeric: true },
    { key: 'netMargin',         label: 'Net Margin',        group: 'orange', numeric: true },
    { key: 'profitability',     label: 'Profitability',     group: 'orange', numeric: true },
    { key: 'gridRule',          label: 'Grid Rule',         group: 'orange' },
    { key: 'ruleValue',         label: 'Rule Value',        group: 'orange', numeric: true }
];

const SORTED_BY_LABEL  = 'Eff Mgt Fee Date';
const EXPORT_COLUMNS   = ['portfolio', 'shareClass', 'isin', 'aum', 'effMgtFee', 'rebateRate'];

export default class GridDetailTable extends LightningElement {
    @api iconName = 'custom:custom63';

    labels = LABELS;
    rows = [];
    errors = [];
    isLoading = false;
    _recordId;
    sheetJsLoaded = false;
    sheetJsReady  = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadRows();
        } else {
            this.rows = [];
            this.errors = [];
        }
    }

    get hasErrors() {
        return this.errors && this.errors.length > 0;
    }

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    get rowCountLabel() {
        const count = this.rows ? this.rows.length : 0;
        return `${count} item${count === 1 ? '' : 's'}`;
    }

    get sortedByLabel() {
        return SORTED_BY_LABEL;
    }

    get headerCells() {
        return COLUMNS.map(col => ({
            key: col.key,
            label: col.label,
            headerClass: (col.group ? `th-${col.group}` : 'th-default') + (col.numeric ? ' td-right' : '')
        }));
    }

    get processedRows() {
        return (this.rows || []).map(row => ({
            rowKey: row.id,
            rowClass: row.isExpired ? 'row-expired' : '',
            cells: COLUMNS.map(col => ({
                key: `${row.id}-${col.key}`,
                value: row[col.key] ?? '',
                cellClass: (col.group ? `td-${col.group}` : '') + (col.numeric ? ' td-right' : '')
            }))
        }));
    }

    async loadRows() {
        this.isLoading = true;
        this.errors = [];
        try {
            const result = await getGridDetails({ gridId: this._recordId, activeOnly: false });
            this.rows = result?.rows || [];
            this.errors = result?.errors || [];
        } catch (error) {
            this.rows = [];
            this.errors = [reduceError(error)];
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        if (this._recordId) {
            this.loadRows();
        }
    }

    // ── XlsxJsStyle ──
    renderedCallback() {
        if (this.sheetJsLoaded) return;
        this.sheetJsLoaded = true;
        loadScript(this, XlsxJsStyle).then(() => { this.sheetJsReady = true; }).catch(() => {});
    }

    handleExport() {
        if (!window.XLSX) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Export not ready', message: 'Excel library is still loading. Please try again.', variant: 'warning' }));
            return;
        }

        const exportCols = COLUMNS.filter(c => EXPORT_COLUMNS.includes(c.key));
        const border     = { top: { style: 'thin', color: { rgb: 'DDDBDA' } }, bottom: { style: 'thin', color: { rgb: 'DDDBDA' } }, left: { style: 'thin', color: { rgb: 'DDDBDA' } }, right: { style: 'thin', color: { rgb: 'DDDBDA' } } };
        const hdrStyle   = { fill: { fgColor: { rgb: 'F3F2F2' } }, font: { bold: true }, alignment: { horizontal: 'center' }, border };
        const rowStyle   = { fill: { fgColor: { rgb: 'FFFFFF' } }, alignment: { horizontal: 'left' },  border };

        const aoa    = [];
        const styles = {};

        // Header row
        aoa.push(exportCols.map(c => c.label));
        exportCols.forEach((_, ci) => { styles[`0,${ci}`] = hdrStyle; });

        // Data rows
        (this.rows || []).forEach((row, ri) => {
            aoa.push(exportCols.map(c => row[c.key] ?? ''));
            exportCols.forEach((_, ci) => { styles[`${ri + 1},${ci}`] = rowStyle; });
        });

        const ws = window.XLSX.utils.aoa_to_sheet(aoa);
        ws['!cols'] = exportCols.map(() => ({ wch: 20 }));
        Object.keys(styles).forEach(key => {
            const [r, c] = key.split(',').map(Number);
            const addr = window.XLSX.utils.encode_cell({ r, c });
            if (!ws[addr]) ws[addr] = { v: '', t: 's' };
            ws[addr].s = styles[key];
        });

        const wb = window.XLSX.utils.book_new();
        window.XLSX.utils.book_append_sheet(wb, ws, 'Grid Details');
        window.XLSX.writeFile(wb, 'GridDetails.xlsx');
    }
}