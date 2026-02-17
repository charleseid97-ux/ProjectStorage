import { LightningElement, api } from 'lwc';
import { reduceError } from 'c/gridBuilderUtils';
import getGridDetails from '@salesforce/apex/GridDetailTableController.getGridDetails';
import { LABELS } from 'c/gridBuilderUtils';

const COLUMNS = [
    { label: 'AssetType', fieldName: 'assetType', type: 'text' },
    { label: 'Strategy', fieldName: 'strategy', type: 'text' },
    { label: 'LegalStatus', fieldName: 'legalStatus', type: 'text' },
    { label: 'Code', fieldName: 'internalShortName', type: 'text' },
    { label: 'Portfolio', fieldName: 'portfolio', type: 'text' },
    { label: 'Class', fieldName: 'shareClass', type: 'text' },
    { label: 'Type', fieldName: 'shareType', type: 'text' },
    { label: 'Currency', fieldName: 'scCurrency', type: 'text' },
    { label: 'ISIN', fieldName: 'isin', type: 'text' },
    { label: 'AUM', fieldName: 'aum', type: 'text' },
    { label: 'EffMgtFeeDate', fieldName: 'effMgtFeeDate', type: 'date' },
    { label: 'EffMgtFee', fieldName: 'effMgtFee', type: 'text' },
    { label: 'RebateRate', fieldName: 'rebateRate', type: 'text' },
    { label: 'NetMargin', fieldName: 'netMargin', type: 'text' },
    { label: 'Profitability', fieldName: 'profitability', type: 'text' },
    { label: 'GridRule', fieldName: 'gridRule', type: 'text' },
    { label: 'RuleValue', fieldName: 'ruleValue', type: 'text' }
];

const SORTED_BY_LABEL = 'Eff Mgt Fee Date';

export default class GridDetailTable extends LightningElement {
    @api iconName = 'custom:custom63';

    labels = LABELS;
    columns = COLUMNS;
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