import { LightningElement, api, track, wire } from 'lwc';
import { LABELS } from 'c/gridBuilderUtils';
import getGridPicklistOptions from '@salesforce/apex/GridBuilderController.getGridPicklistOptions';

export default class GridAgreementsSelection extends LightningElement {
    @api hasTeamSelection = false;
    @api multiAgreementSelection = false;
    @api agreementSelectionMode;

    @api availableTeams = [];
    @api primaryTeam;
    @api selectedTeam;
    @api recId;

    labels = LABELS;
    _options = [];
    optionsByValue = {};
    @api
    set options(val) {
        this._options = Array.isArray(val) ? val : [];
        this.optionsByValue = this.getOptionsByValue();
        this.finalOptionsList = this.getFinalOptionsList();
        this.pills = this.getPills();
    }
    get options() {
        return this._options;
    }

    @track selectedValues = [];
    @track finalOptionsList = [];
    @track pills = [];

    @api
    set value(val) {
        this.selectedValues = Array.isArray(val) ? [...val] : [];
        this.pills = this.getPills();
    }
    get value() {
        return this.selectedValues;
    }

    // ── AG data: picklist options from Apex ──
    @track kindOptions = [];
    @track typeOptions = [];
    @track ccyOptions  = [];
    @track freqOptions = [];

    // ── AG data fields ──
    @track agKind           = '';    // AG2 — Kind__c
    @track agType           = '';    // AG3 — Type__c
    @track isAutoGridUpdate = true;  // AG4 — AutomaticGridUpdate__c
    @track agStartDate      = '';    // AG5 — StartDate__c
    @track agEndDate        = '';    // AG6 — EndDate__c
    @track agThreshold      = null;  // AG7 — ThresholdAmount__c
    @track agThreshCcy      = '';    // AG8 — ThresholdAmountCurrency__c
    @track agMin            = null;  // AG9 — MinimumAmount__c
    @track agMinCcy         = '';    // AG10 — MinimumAmountCurrency__c
    @track agMinFreq        = '';    // AG11 — MinimumAmountFrequency__c

    @api
    set gridData(val) {
        if (!val || !Object.keys(val).length) return;
        this.agKind           = val.kind || '';
        this.agType           = val.gridType || '';
        this.isAutoGridUpdate = val.isAutoGridUpdate ?? true;
        this.agStartDate      = val.startDate || '';
        this.agEndDate        = val.endDate || '';
        this.agThreshold      = val.thresholdAmount;
        this.agThreshCcy      = val.thresholdAmountCurrency || '';
        this.agMin            = val.minimumAmount;
        this.agMinCcy         = val.minimumAmountCurrency || '';
        this.agMinFreq        = val.minimumAmountFrequency || '';
    }
    get gridData() { return null; }

    @api hasExistingGrid = false;
    @api existingGridEndDate = null;

    @api
    set existingGridKind(val) {
        // Only apply on first load (gridData handles back-navigation)
        if (val && !this.agKind) {
            this.agKind = val;
        }
    }
    get existingGridKind() { return this._existingGridKind; }
    _existingGridKind = null;

    get isMultiAgreementSelection() {
        return this.agreementSelectionMode === 'Multiple' || this.multiAgreementSelection;
    }

    get effectiveHasTeamSelection() {
        return this.hasTeamSelection || this.isMultiAgreementSelection;
    }

    get isMonoSelect() {
        return !this.isMultiAgreementSelection;
    }

    get showTeamPicker() {
        return this.effectiveHasTeamSelection && (this.availableTeams || []).length > 1;
    }

    get gridNamePreview() {
        const firstId  = (this.selectedValues && this.selectedValues.length) ? this.selectedValues[0] : null;
        const opt      = firstId ? this.findOptionById(firstId) : null;
        const region   = (opt && opt.regionCode)  ? opt.regionCode : '…';
        const agCode   = (opt && opt.name)         ? opt.name       : '…';
        const kind     = this.agKind  || '…';
        const type     = this.agType  || '…';
        const update   = this.isAutoGridUpdate ? 'AUTOMATIC' : 'MANUAL';
        const date     = this.agStartDate || '…';
        return kind + ' – ' + region + ' – ' + agCode + ' – ' + type + ' – ' + update + ' – ' + date;
    }

    get isThreshAboveZero()    { return this.agThreshold != null && parseFloat(this.agThreshold) > 0; }
    get isMinAboveZero()       { return this.agMin != null && parseFloat(this.agMin) > 0; }
    get isAutoUpdateDisabled() { return this.agType === 'MULTI RULE'; }

    get isStartDateConflict() {
        if (!this.hasExistingGrid || !this.existingGridEndDate || !this.agStartDate) return false;
        return new Date(this.existingGridEndDate) >= new Date(this.agStartDate);
    }

    get isNextDisabled() {
        const hasAgreements  = (this.selectedValues || []).length > 0;
        const hasDate        = this.agStartDate != null;
        const hasTeam        = !this.showTeamPicker || !!this.selectedTeam;
        const hasMeta        = !!this.agKind && !!this.agType;
        const hasThreshCcy   = !this.isThreshAboveZero || !!this.agThreshCcy;
        const hasMinFields   = !this.isMinAboveZero || (!!this.agMinCcy && !!this.agMinFreq);
        return !(hasAgreements && hasDate && hasTeam && hasMeta && hasThreshCcy && hasMinFields && !this.isStartDateConflict);
    }

    get isAgreementDisabled()   { return !!this.recId; }
    get agreementSectionClass() { return this.isAgreementDisabled ? 'agreement-section agreement-section--disabled' : 'agreement-section'; }
    get isThreshCcyDisabled()   { return !this.isThreshAboveZero; }
    get isMinCcyDisabled()      { return !this.isMinAboveZero; }
    get isMinFreqDisabled()     { return !this.isMinAboveZero; }
    get toggleLabel()           { return this.isAutoGridUpdate ? this.labels.UI_On : this.labels.UI_Off; }

    @wire(getGridPicklistOptions)
    wiredPicklists({ data }) {
        if (data) {
            this.kindOptions = data['Kind__c']                    || [];
            this.typeOptions = data['Type__c']                    || [];
            this.ccyOptions  = data['ThresholdAmountCurrency__c'] || [];
            this.freqOptions = data['MinimumAmountFrequency__c']  || [];
            if (this.kindOptions.length === 1 && !this.agKind) { // Auto-select Kind if only one option and not yet set
                this.agKind = this.kindOptions[0].value;
            }
        }
    }

    connectedCallback() {
        if (this.recId) {
            this.selectedValues = [this.recId];
            this.pills = this.getPills();
        }
    }

    getOptionsByValue() {
        let optionsByValue = {};
        for (let i = 0; i < (this._options || []).length; i++) {
            let o = this._options[i];
            if (o && o.value) {
                optionsByValue[o.value] = o;
            }
        }
        return optionsByValue;
    }

    findOptionById(id) {
        if (!id) return null;
        if (this.optionsByValue[id]) { // Direct match (same length IDs)
            return this.optionsByValue[id];
        }
        const id15 = id.substring(0, 15); // Fallback: compare first 15 characters (handles 15 vs 18 char ID mismatch)
        for (const key of Object.keys(this.optionsByValue)) {
            if (key.substring(0, 15) === id15) {
                return this.optionsByValue[key];
            }
        }
        return null;
    }

    getFinalOptionsList() {
        let finalOptionsList = [];
        if (this.effectiveHasTeamSelection) {
            let team = this.selectedTeam || this.primaryTeam || (this.availableTeams && this.availableTeams[0]);
            if (!team) {
                finalOptionsList = this._options || [];
            }
            else { // Filter can stay as-is; it's O(n) once per team change, which is fine
                finalOptionsList = (this._options || []).filter(function (opt) {
                    return opt.teamCountry === team;
                });
            }
            if(refreshChild) {
                let child = this.template.querySelector('c-multi-select-search-list');
                if (child) {
                    child.refreshOptions(finalOptionsList);
                }
            }
        }
        else {
            finalOptionsList = this._options || [];
        }
        return finalOptionsList;
    }

    getPills() {
        let res = [];
        let selected = this.selectedValues || [];

        for (let i = 0; i < selected.length; i++) {
            let val = selected[i];
            let opt = this.findOptionById(val);

            res.push({
                type: 'icon',
                label: opt ? opt.label : val,
                name: val,
                iconName: 'custom:custom16',
                alternativeText: this.labels.Grid_Agreements,
                isLink: true,
                href: '/' + val
            });
        }
        return res;
    }

    handleAgreementsChange(event) {
        let isSearchChange = event.detail && event.detail.isSearchChange;
        if (!isSearchChange) {
            let selected = (event.detail && event.detail.selectedValues) ? event.detail.selectedValues : [];
            this.selectedValues = selected? (Array.isArray(selected)? selected : [selected]) : [];
            this.pills = this.getPills();
        }
    }

    handleTeamChange(event) {
        this.selectedTeam = event.detail.value;
        this.selectedValues = [];
        this.finalOptionsList = this.getFinalOptionsList();
        this.pills = this.getPills();
    }

    handlePillRemove(event) {
        let name = event.detail?.item?.name;
        if (!name) return;
        this.selectedValues = (this.selectedValues || []).filter(v => v !== name);
        this.pills = this.getPills();
    }

    // ── AG field handlers ──
    handleAgKind(e)           { this.agKind = e.detail.value; }
    handleAgType(e)           { this.agType = e.detail.value; if (this.agType === 'MULTI RULE') { this.isAutoGridUpdate = false; } }
    handleAutoUpdateToggle(e) { this.isAutoGridUpdate = e.target.checked; }
    handleAgStartDate(event)  { this.agStartDate = event.detail.value; }
    handleAgEndDate(e)        { this.agEndDate = e.detail.value; }
    handleAgThreshold(e)      { this.agThreshold = e.detail.value; if (!this.isThreshAboveZero) { this.agThreshCcy = ''; } }
    handleAgThreshCcy(e)      { this.agThreshCcy = e.detail.value; }
    handleAgMin(e)            { this.agMin = e.detail.value; if (!this.isMinAboveZero) { this.agMinCcy = ''; this.agMinFreq = ''; } }
    handleAgMinCcy(e)         { this.agMinCcy = e.detail.value; }
    handleAgMinFreq(e)        { this.agMinFreq = e.detail.value; }

    handleNext() {
        let derivedTeam = null;
        if (!this.effectiveHasTeamSelection) {
            let firstId = (this.selectedValues && this.selectedValues.length) ? this.selectedValues[0] : null;
            let option = this.findOptionById(firstId);
            derivedTeam = option ? option.teamCountry : '';
        }

        let countriesOfDistribution = this.buildCountriesOfDistribution();

        this.dispatchEvent(new CustomEvent('agreementsnext', {
            detail: {
                agreements:              this.selectedValues,
                team:                    this.effectiveHasTeamSelection ? this.selectedTeam : derivedTeam,
                countriesOfDistribution: countriesOfDistribution,
                kind:                    this.agKind,
                gridType:                this.agType,
                isAutoGridUpdate:        this.isAutoGridUpdate,
                startDate:               this.agStartDate,
                endDate:                 this.agEndDate,
                thresholdAmount:         this.agThreshold,
                thresholdAmountCurrency: this.agThreshCcy,
                minimumAmount:           this.agMin,
                minimumAmountCurrency:   this.agMinCcy,
                minimumAmountFrequency:  this.agMinFreq,
                gridName:                this.gridNamePreview
            }
        }));
    }

    buildCountriesOfDistribution() {
        let allCountries = new Set();
        let selected = this.selectedValues || [];
        for (let i = 0; i < selected.length; i++) {
            let option = this.findOptionById(selected[i]);
            if (option && option.countriesOfDistribution) {
                let parts = option.countriesOfDistribution.split(';');
                for (let j = 0; j < parts.length; j++) {
                    let trimmed = parts[j].trim();
                    if (trimmed) {
                        allCountries.add(trimmed);
                    }
                }
            }
        }
        return Array.from(allCountries).join(';');
    }
}