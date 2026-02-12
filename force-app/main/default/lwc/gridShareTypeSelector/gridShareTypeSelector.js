import { LightningElement, api, track } from 'lwc';

export default class GridShareTypeSelector extends LightningElement {
    _allShareTypeOptions = [];
    _selectedShareTypes = [];
    _refreshScheduled = false;
    @api enabledShareTypeValues = [];

    @track displayShareTypeOptions = [];
    @track restrictedShareTypeOptions = [];
    @track selectedRestrictedShareTypes = [];
    @track showRestrictedShareTypePicker = false;

    @api
    get allShareTypeOptions() {
        return this._allShareTypeOptions;
    }
    set allShareTypeOptions(value) {
        this._allShareTypeOptions = Array.isArray(value) ? value : [];
        this.scheduleRefresh();
    }

    @api
    get selectedShareTypes() {
        return this._selectedShareTypes;
    }
    set selectedShareTypes(value) {
        this._selectedShareTypes = Array.isArray(value) ? value : [];
        this.scheduleRefresh();
    }

    scheduleRefresh() {
        if (!this._refreshScheduled) {
            this._refreshScheduled = true;
            Promise.resolve().then(() => {
                this._refreshScheduled = false;
                this.refreshOptions();
            });
        }
    }

    get hasRestrictedShareTypes() {
        return this.restrictedShareTypeOptions && this.restrictedShareTypeOptions.length > 0;
    }

    get disableRestrictedShareTypesButton() {
        return !this.hasRestrictedShareTypes;
    }

    get addRestrictedShareTypesDisabled() {
        return !this.selectedRestrictedShareTypes || this.selectedRestrictedShareTypes.length === 0;
    }

    refreshOptions() {
        const options = this._allShareTypeOptions || [];
        const selected = this._selectedShareTypes || [];

        const enabled = new Set(this.enabledShareTypeValues.length > 0 ? this.enabledShareTypeValues : selected.filter(value => options.some(opt => opt.value === value)));
        selected.forEach(value => enabled.add(value));
        this.enabledShareTypeValues = Array.from(enabled);
        this.displayShareTypeOptions = options.filter(opt => enabled.has(opt.value));
        this.restrictedShareTypeOptions = options.filter(opt => !enabled.has(opt.value));

        if (!this.hasRestrictedShareTypes) {
            this.showRestrictedShareTypePicker = false;
            this.selectedRestrictedShareTypes = [];
        }
    }

    handleShareTypeSelection(event) {
        this._selectedShareTypes = event.detail.value;
        this.enabledShareTypeValues = this.displayShareTypeOptions.map(opt => opt.value);
        this.dispatchEnabledChanged();
        this.dispatchChanged();
    }

    toggleRestrictedShareTypePicker() {
        if (!this.hasRestrictedShareTypes) {
            return;
        }
        this.showRestrictedShareTypePicker = !this.showRestrictedShareTypePicker;
        if (!this.showRestrictedShareTypePicker) {
            this.selectedRestrictedShareTypes = [];
        }
    }

    handleRestrictedShareTypeSelection(event) {
        this.selectedRestrictedShareTypes = event.detail.value;
    }

    handleAddRestrictedShareTypes() {
        const toAdd = this.selectedRestrictedShareTypes || [];
        if (!toAdd.length) {
            return;
        }
        const enabled = new Set(this.enabledShareTypeValues || []);
        toAdd.forEach(value => enabled.add(value));
        this.enabledShareTypeValues = Array.from(enabled);
        this.displayShareTypeOptions = this._allShareTypeOptions.filter(opt => enabled.has(opt.value));
        this.restrictedShareTypeOptions = this._allShareTypeOptions.filter(opt => !enabled.has(opt.value));
        this.selectedRestrictedShareTypes = [];
        this.showRestrictedShareTypePicker = false;
        this.dispatchEnabledChanged();
    }

    dispatchChanged() {
        this.dispatchEvent(new CustomEvent('sharetypeschanged', {
            detail: { value: this._selectedShareTypes }
        }));
    }

    dispatchEnabledChanged() {
        this.dispatchEvent(new CustomEvent('enabledchanged', {
            detail: { value: this.enabledShareTypeValues }
        }));
    }

    handleCancelRestrictedShareTypes() {
        this.selectedRestrictedShareTypes = [];
        this.showRestrictedShareTypePicker = false;
    }
}