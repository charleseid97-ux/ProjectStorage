import { LightningElement, api, wire } from 'lwc';
import { reduceError, showToast, LABELS } from 'c/gridBuilderUtils';
import getStandardGridData from '@salesforce/apex/StandardGridProductAndRulesController.getStandardGridData';

export default class StandardGridProductsAndRules extends LightningElement {
    @api recordId;
    labels = LABELS;

    groups = [];
    isLoading = true;
    isOpen = true; // section starts expanded (like native SF)

    @wire(getStandardGridData, { gridId: '$recordId' })
    wiredData({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.groups = data;
        } else if (error) {
            this.groups = [];
            showToast(this, this.labels.UI_Error, reduceError(error), 'error');
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

    get hasGroups() {
        return (this.groups || []).length > 0;
    }
}