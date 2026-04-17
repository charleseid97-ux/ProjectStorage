import { LightningElement, api, wire } from 'lwc';
import { reduceError, showToast, LABELS } from 'c/gridBuilderUtils';
import getRecap from '@salesforce/apex/AgreementGridRecapController.getRecap';

const DATE_TYPE_ATTRS = { day: '2-digit', month: '2-digit', year: 'numeric' };
const TIMELINE_COLUMNS = [
    { label: 'Name',       fieldName: 'recordUrl',  type: 'url',        typeAttributes: { label: { fieldName: 'timelineName' }, target: '_self' } },
    { label: 'Grid',       fieldName: 'gridUrl',    type: 'url',        typeAttributes: { label: { fieldName: 'gridName' }, target: '_self' } },
    { label: 'Status',     fieldName: 'status',     type: 'text',       initialWidth: 130 },
    { label: 'Start Date', fieldName: 'startDate',  type: 'date-local', typeAttributes: DATE_TYPE_ATTRS, initialWidth: 115 },
    { label: 'End Date',   fieldName: 'endDate',    type: 'date-local', typeAttributes: DATE_TYPE_ATTRS, initialWidth: 115 }
];

export default class AgreementGridRecap extends LightningElement {
    @api recordId;
    labels = LABELS;
    timelineColumns = TIMELINE_COLUMNS;

    recap = null;
    error = null;
    isLoading = true;
    isOpen = true; // section starts expanded (like native SF)
    _leftPct = 50;
    _dragging = false;

    get leftColStyle() {
        return `width: ${this._leftPct}%; flex-shrink: 0;`;
    }

    get overlayStyle() {
        return this._dragging ? 'display: block;' : 'display: none;';
    }

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

    handleResizerMouseDown(event) {
        event.preventDefault();
        this._dragging = true;
        const container = this.template.querySelector('.col-container');
        const containerRect = container.getBoundingClientRect();

        const onMouseMove = (e) => {
            const pct = ((e.clientX - containerRect.left) / containerRect.width) * 100;
            this._leftPct = Math.min(80, Math.max(20, pct));
            this.template.querySelector('.col-left').style.width = `${this._leftPct}%`;
        };

        const onMouseUp = () => {
            this._dragging = false;
            document.removeEventListener('mousemove', onMouseMove);
            document.removeEventListener('mouseup', onMouseUp);
        };

        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
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

    get timelineRows() {
        return (this.recap?.timelineRows || []).map(row => ({
            ...row,
            recordUrl: `/lightning/r/AgreementGridTimeline__c/${row.recordId}/view`,
            gridUrl: row.gridId ? `/lightning/r/Grid__c/${row.gridId}/view` : null
        }));
    }

    get hasTimeline() {
        return this.timelineRows.length > 0;
    }

    get timelineCount() {
        return this.timelineRows.length;
    }
}