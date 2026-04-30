import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LABELS, reduceError, exportGridExcel } from 'c/gridBuilderUtils';
import getGridDetails from '@salesforce/apex/GridDetailTableController.getGridDetails';
import XlsxJsStyle from '@salesforce/resourceUrl/xlsxjsstyle';
import ExcelJs     from '@salesforce/resourceUrl/exceljs';

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
    sheetJsLoaded  = false;
    sheetJsReady   = false;
    excelJsLoaded  = false;

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

    // ── Script loading ──
    renderedCallback() {
        if (!this.sheetJsLoaded) {
            this.sheetJsLoaded = true;
            loadScript(this, XlsxJsStyle).then(() => { this.sheetJsReady = true; }).catch(() => {});
        }
        if (!this.excelJsLoaded) {
            this.excelJsLoaded = true;
            loadScript(this, ExcelJs).catch(() => {});
        }
    }

    async handleExport() {
        if (!window.XLSX || !window.ExcelJS) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Export not ready', message: 'Excel libraries are still loading. Please try again.', variant: 'warning' }));
            return;
        }
        await exportGridExcel({
            rows:      this.rows,
            columns:   COLUMNS.filter(c => EXPORT_COLUMNS.includes(c.key)),
            sheetName: 'Grid Details',
            filename:  'GridDetails.xlsx'
        });
    }
}