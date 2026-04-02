import { LightningElement, api, wire } from 'lwc';
import { reduceError, showToast, LABELS } from 'c/gridBuilderUtils';
import getStandardGridData from '@salesforce/apex/StandardGridProductAndRulesController.getStandardGridData';
import getShareClassComposition from '@salesforce/apex/StandardGridProductAndRulesController.getShareClassComposition';

export default class StandardGridProductsAndRules extends LightningElement {
    @api recordId;
    labels = LABELS;

    groups = [];
    composition = null;
    isLoading = true;
    isCompositionLoading = true;
    isOpen = true; // section starts expanded (like native SF)
    _leftPct = 50;
    _dragging = false;

    get leftColStyle() {
        return `width: ${this._leftPct}%; flex-shrink: 0;`;
    }

    get overlayStyle() {
        return this._dragging ? 'display: block;' : 'display: none;';
    }

    get isAnyLoading() {
        return this.isLoading || this.isCompositionLoading;
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

    get hasComposition() {
        return this.composition != null;
    }

    get hasRestricted() {
        return (this.composition?.restricted || []).length > 0;
    }

    get hasUnrestricted() {
        return (this.composition?.unrestricted || []).length > 0;
    }

    get hasExcluded() {
        return (this.composition?.excludedFundShortNames || []).length > 0;
    }

    get restrictedHelpText() {
        return `All unauthorized share types from the Grid Builder or the Grid Validation (is not ${this.composition?.defaultShareTypeInclusion || ''})`;
    }

    get unrestrictedHelpText() {
        return `Only share types selected in the Grid Builder (within ${this.composition?.defaultShareTypeInclusion || ''})`;
    }

    @wire(getStandardGridData, { gridId: '$recordId' })
    wiredData({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.groups = data;
        } 
        else if (error) {
            this.groups = [];
            showToast(this, this.labels.UI_Error, reduceError(error), 'error');
        }
    }

    @wire(getShareClassComposition, { gridId: '$recordId' })
    wiredComposition({ data, error }) {
        this.isCompositionLoading = false;
        if (data) {
            this.composition = data;
        }
        else if (error) {
            this.composition = { restricted: [], unrestricted: [], excludedFundShortNames: [], defaultShareTypeInclusion: '' };
            showToast(this, this.labels.UI_Error, reduceError(error), 'error');
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

    handleFundHover(event) {
        this._applyHighlight(event.detail);
    }

    handleRightBadgeEnter(event) {
        this._applyHighlight(event.currentTarget.dataset.fund);
    }

    handleFundLeave() {
        this._applyHighlight(null);
    }

    _applyHighlight(fund) {
        this.template.querySelectorAll('[data-fund]').forEach(el => {
            el.classList.remove('badge-fund-highlight');
            if (fund && el.dataset.fund === fund) el.classList.add('badge-fund-highlight');
        });
        this.template.querySelector('c-standard-grid-group-list')?.applyHighlight(fund);
    }
}