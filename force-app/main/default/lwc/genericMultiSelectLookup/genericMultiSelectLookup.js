import { LightningElement, api, track } from 'lwc';
import getOptions from '@salesforce/apex/GenericMultiSelectCtrl.getOptions';

export default class GenericMultiSelectLookup extends LightningElement {
    // ===== FLOW INPUTS =====
    @api objectApiName;        // e.g. 'Contact'
    @api labelFieldApiName;    // e.g. 'Name'
    @api valueFieldApiName;    // e.g. 'Id'

    @api picklistLabel = 'Select values';
    @api limitSize = 200;

    // Optional single-field filter (safe approach from Apex side)
    @api filterFieldApiName;   // e.g. 'AccountId'
    @api filterOperator = '='; // '=', '!=', 'IN'
    @api filterValue;          // e.g. '001...' or CSV for IN

    // Optional preselection (useful when editing an existing record)
    @api preselectedIdsJson;   // e.g. '["003...","003..."]'

    // ===== FLOW OUTPUTS =====
    @api selectedIdsJson = '[]'; // JSON array string of selected ids
    @api selectedIdsCsv = '';    // CSV string of selected ids (optional convenience)

    // ===== UI / STATE =====
    @track options = [];       // [{label, value}]
    @track selectedIds = [];   // ['003..', '003..']
    @track selectedPills = []; // [{label,name,iconName}]

    isLoading = false;
    lastError = null;

    // Used to avoid multiple loads / infinite loops in renderedCallback
    _lastLoadSignature = null;

    // Used to apply preselection only once
    _initializedFromPreselected = false;

    // ===== COMPUTED =====
    get inputMissing() {
        return !this.objectApiName || !this.labelFieldApiName || !this.valueFieldApiName;
    }

    // ===== LIFECYCLE =====
    connectedCallback() {
        // Preselection can be applied even before options arrive
        this._initFromPreselectedIfNeeded();
        this._syncOutputs();
    }

    renderedCallback() {
        // In Flow, inputs may arrive AFTER first render.
        // Reload options whenever the "signature" of relevant inputs changes.
        const sig = this._signature();
        if (sig === this._lastLoadSignature) return;

        this._lastLoadSignature = sig;

        // If required inputs are missing, don't call Apex
        if (this.inputMissing) return;

        // Load options from Apex
        this._loadOptions();
    }

    // ===== APEX (imperative, Flow-friendly) =====
    async _loadOptions() {
        this.isLoading = true;
        this.lastError = null;

        try {
            const data = await getOptions({
                objectApiName: this.objectApiName,
                labelFieldApiName: this.labelFieldApiName,
                valueFieldApiName: this.valueFieldApiName,
                limitSize: this.limitSize,
                filterFieldApiName: this.filterFieldApiName,
                filterOperator: this.filterOperator,
                filterValue: this.filterValue
            });

            this.options = data || [];

            // Apply preselected ids once options exist (so pills can display labels)
            this._initFromPreselectedIfNeeded();

            // Refresh pills + outputs
            this._rebuildPills();
            this._syncOutputs();
        } catch (e) {
            this.options = [];
            this.lastError = this._reduceError(e);

            this._rebuildPills();
            this._syncOutputs();
        } finally {
            this.isLoading = false;
        }
    }

    // ===== EVENTS =====
    handleMultiSelection = (event) => {
        const values = event?.detail?.selectedValues || [];
        this.selectedIds = [...values];

        this._rebuildPills();
        this._syncOutputs();
    };

    handlePillRemove = (event) => {
        const idToRemove = event?.detail?.item?.name;
        if (!idToRemove) return;

        this.selectedIds = (this.selectedIds || []).filter((x) => x !== idToRemove);

        this._rebuildPills();
        this._syncOutputs();
    };

    // ===== HELPERS =====
    _initFromPreselectedIfNeeded() {
        if (this._initializedFromPreselected) return;

        if (!this.preselectedIdsJson) {
            this._initializedFromPreselected = true;
            return;
        }

        try {
            const parsed = JSON.parse(this.preselectedIdsJson);
            if (Array.isArray(parsed)) {
                this.selectedIds = parsed.filter((x) => !!x);
            }
        } catch (e) {
            // ignore invalid JSON
        }

        this._initializedFromPreselected = true;
    }

    _rebuildPills() {
        // Build pills based on selectedIds and current options labels
        const set = new Set(this.selectedIds || []);
        this.selectedPills = (this.options || [])
            .filter((opt) => set.has(opt.value))
            .map((opt) => ({
                label: opt.label,
                name: opt.value,
                iconName: 'standard:record'
            }));
    }

    _syncOutputs() {
        const arr = this.selectedIds || [];
        this.selectedIdsJson = JSON.stringify(arr);
        this.selectedIdsCsv = arr.join(',');
    }

    _signature() {
        // Any change here triggers a reload
        return JSON.stringify({
            objectApiName: this.objectApiName,
            labelFieldApiName: this.labelFieldApiName,
            valueFieldApiName: this.valueFieldApiName,
            limitSize: this.limitSize,
            filterFieldApiName: this.filterFieldApiName,
            filterOperator: this.filterOperator,
            filterValue: this.filterValue
        });
    }

    _reduceError(err) {
        try {
            if (Array.isArray(err?.body)) return err.body.map((e) => e.message).join(' | ');
            return err?.body?.message || err?.message || 'Unknown error';
        } catch (e) {
            return 'Unknown error';
        }
    }
}