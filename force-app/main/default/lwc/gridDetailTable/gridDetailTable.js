import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LABELS, reduceError, exportGridExcel } from 'c/gridBuilderUtils';
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
        const lang = this.agreementRegion === 'BP_IT' ? 'IT' : this.agreementRegion === 'BP_FR' ? 'FR' : 'EN';
        const L    = key => this.labels[`${key}_${lang}`] || '';

        const rows = (this.rows || []).map(r => ({
            name:           r.portfolio  || '',
            shareClassName: r.shareClass || '',
            isin:           r.isin       || '',
            effMgtFee:      r.effMgtFee  != null ? r.effMgtFee  / 100 : '',
            rebateRate:     r.rebateRate != null ? r.rebateRate / 100 : ''
        }));
        const columns = [
            { key: 'name',           label: L('Grid_SimExport_Col_FundName') },
            { key: 'shareClassName', label: L('Grid_SimExport_Col_ShareClass') },
            { key: 'isin',           label: L('Grid_SimExport_Col_ISIN') },
            { key: 'effMgtFee',      label: L('Grid_SimExport_Col_EffMgtFees'), numeric: true, numFormat: '0.000%' },
            { key: 'rebateRate',     label: L('Grid_SimExport_Col_Rebate'),     numeric: true, numFormat: '0.000%' }
        ];
        await exportGridExcel({
            rows, columns,
            sheetName: 'Allegato', filename: 'GridDetails.xlsx',
            header: L('Grid_SimExport_Header'),
            footer: L('Grid_SimExport_Footer')
        });
    }
}