import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { LABELS, reduceError, exportGridDetailsExcel } from 'c/gridBuilderUtils';
import getGridDetails from '@salesforce/apex/GridDetailTableController.getGridDetails';
import getGridAgreementRegion from '@salesforce/apex/GridDetailTableController.getGridAgreementRegion';
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

const SORTED_BY_LABEL = 'Eff Mgt Fee Date';

export default class GridDetailTable extends LightningElement {
    @api iconName   = 'custom:custom63';
    agreementRegion = null;

    labels = LABELS;
    rows = [];
    errors = [];
    isLoading = false;
    showActiveOnly = true;
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

    get filteredRows() {
        return this.showActiveOnly ? (this.rows || []).filter(r => !r.isExpired) : (this.rows || []);
    }

    get rowCountLabel() {
        const count = this.filteredRows.length;
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
        return this.filteredRows.map(row => ({
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
            const [result, region] = await Promise.all([
                getGridDetails({ gridId: this._recordId, activeOnly: false }),
                getGridAgreementRegion({ gridId: this._recordId })
            ]);
            this.rows            = result?.rows || [];
            this.errors          = result?.errors || [];
            this.agreementRegion = region;
        } catch (error) {
            this.rows = [];
            this.errors = [reduceError(error)];
        } finally {
            this.isLoading = false;
        }
    }

    handleActiveOnlyToggle(event) {
        this.showActiveOnly = event.target.checked;
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
        await exportGridDetailsExcel({
            component: this,
            agreementRegion: this.agreementRegion,
            rows: (this.rows || []).filter(r => !r.isExpired),
            source: 'detail',
            labels: this.labels
        });
    }
}