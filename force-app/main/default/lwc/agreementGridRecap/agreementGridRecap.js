import { LightningElement, api, wire } from 'lwc';
import { reduceError, showToast, LABELS } from 'c/gridBuilderUtils';
import getRecap from '@salesforce/apex/AgreementGridRecapController.getRecap';

const DATE_TYPE_ATTRS = { day: '2-digit', month: '2-digit', year: 'numeric' };
const HISTORY_COLUMNS = [
    { label: 'Name', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'historyName' }, target: '_self' } },
    { label: 'Grid', fieldName: 'gridUrl', type: 'url', typeAttributes: { label: { fieldName: 'gridName' }, target: '_self' } },
    { label: 'Start Date', fieldName: 'startDate', type: 'date-local', typeAttributes: DATE_TYPE_ATTRS, initialWidth: 115 },
    { label: 'End Date',   fieldName: 'endDate',   type: 'date-local', typeAttributes: DATE_TYPE_ATTRS, initialWidth: 115 }
];

export default class AgreementGridRecap extends LightningElement {
    @api recordId;
    labels = LABELS;
    historyColumns = HISTORY_COLUMNS;

    recap = null;
    error = null;
    isLoading = true;
    isOpen = true; // section starts expanded (like native SF)

    @wire(getRecap, { agreementId: '$recordId' })
    wiredRecap({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.recap = data;
            this.error = null;
        } else if (error) {
            this.recap = null;
            this.error = reduceError(error);
            showToast(this, this.labels.UI_Error, this.error, 'error');
        }
    }

    handleToggle() {
        this.isOpen = !this.isOpen;
    }

    // aria-hidden must be a string ('true'/'false')
    get sectionHidden() {
        return this.isOpen ? 'false' : 'true';
    }

    // Dynamic CSS class — slds-is-open drives the chevron rotation
    get sectionClass() {
        return this.isOpen ? 'slds-section slds-is-open' : 'slds-section';
    }

    get hasGrid() {
        return this.recap?.hasGrid;
    }

    get automaticUpdateLabel() {
        return this.recap?.automaticGridUpdate ? this.labels.UI_On : this.labels.UI_Off;
    }

    get gridUrl() {
        return `/lightning/r/Grid__c/${this.recap?.gridId}/view`;
    }

    get standardGridCount() {
        return (this.recap?.standardGridGroups || []).length;
    }

    get rawStandardGridGroups() {
        return this.recap?.standardGridGroups || [];
    }

    get historyRows() {
        return (this.recap?.historyRows || []).map(row => ({
            ...row,
            recordUrl: `/lightning/r/Agreement_Grid_History__c/${row.recordId}/view`,
            gridUrl: row.gridId ? `/lightning/r/Grid__c/${row.gridId}/view` : null
        }));
    }

    get hasHistory() {
        return this.historyRows.length > 0;
    }

    get historyCount() {
        return this.historyRows.length;
    }
}