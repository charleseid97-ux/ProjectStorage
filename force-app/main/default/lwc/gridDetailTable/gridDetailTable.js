import { LightningElement, api } from 'lwc';
import { reduceError } from 'c/gridBuilderUtils';
import getGridDetails from '@salesforce/apex/GridDetailTableController.getGridDetails';
import { LABELS } from 'c/gridBuilderUtils';

const COLUMNS = [
    { key: 'assetType',         label: 'Asset Type',        group: '' },
    { key: 'strategy',          label: 'Strategy',          group: '' },
    { key: 'legalStatus',       label: 'Legal Status',      group: '' },
    { key: 'internalShortName', label: 'Code',              group: '' },
    { key: 'portfolio',         label: 'Portfolio',         group: 'blue' },
    { key: 'shareClass',        label: 'Class',             group: 'blue' },
    { key: 'shareType',         label: 'Type',              group: '' },
    { key: 'scCurrency',        label: 'Currency',          group: '' },
    { key: 'isin',              label: 'ISIN',              group: 'blue' },
    { key: 'aum',               label: 'AUM',               group: 'blue' },
    { key: 'effMgtFeeDate',     label: 'Eff. Mgt Fee Date', group: '' },
    { key: 'effMgtFee',         label: 'Eff. Mgt Fee',      group: 'blue' },
    { key: 'rebateRate',        label: 'Rebate Rate',       group: 'blue' },
    { key: 'netMargin',         label: 'Net Margin',        group: 'orange' },
    { key: 'profitability',     label: 'Profitability',     group: 'orange' },
    { key: 'gridRule',          label: 'Grid Rule',         group: 'orange' },
    { key: 'ruleValue',         label: 'Rule Value',        group: 'orange' }
];

const SORTED_BY_LABEL = 'Eff Mgt Fee Date';

export default class GridDetailTable extends LightningElement {
    @api iconName = 'custom:custom63';

    labels = LABELS;
    rows = [];
    errors = [];
    isLoading = false;
    _recordId;

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
            headerClass: col.group ? `th-${col.group}` : 'th-default'
        }));
    }

    get processedRows() {
        return (this.rows || []).map(row => ({
            rowKey: row.id,
            cells: COLUMNS.map(col => ({
                key: `${row.id}-${col.key}`,
                value: row[col.key] ?? '',
                cellClass: col.group ? `td-${col.group}` : ''
            }))
        }));
    }

    async loadRows() {
        this.isLoading = true;
        this.errors = [];
        try {
            const result = await getGridDetails({ gridId: this._recordId });
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
}