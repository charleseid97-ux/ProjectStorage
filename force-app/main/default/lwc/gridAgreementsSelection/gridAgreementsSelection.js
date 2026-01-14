import { LightningElement, api, track } from 'lwc';

export default class GridAgreementsSelection extends LightningElement {
    @api hasTeamSelection = false;
    @api multiAgreementSelection = false;
    @api agreementSelectionMode;

    @api startDate;
    @api availableTeams = [];
    @api primaryTeam;
    @api selectedTeam;

    _options = [];
    optionsByValue = {};
    @api
    set options(val) {
        this._options = Array.isArray(val) ? val : [];
        this.optionsByValue = this.getOptionsByValue();
        this.finalOptionsList = this.getFinalOptionsList();
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

    get isNextDisabled() {
        var hasAgreements = this.selectedValues && this.selectedValues.length;
        var hasDate = this.startDate != null;
        var hasTeam = !this.showTeamPicker || !!this.selectedTeam;
        return !(hasAgreements && hasDate && hasTeam);
    }

    getOptionsByValue() {
        var optionsByValue = {};
        for (var i = 0; i < (this._options || []).length; i++) {
            var o = this._options[i];
            if (o && o.value) {
                optionsByValue[o.value] = o;
            }
        }
        return optionsByValue;
    }

    getFinalOptionsList() {
        var finalOptionsList = [];
        if (this.effectiveHasTeamSelection) {
            var team = this.selectedTeam || this.primaryTeam || (this.availableTeams && this.availableTeams[0]);
            if (!team) {
                finalOptionsList = this._options || [];
            } 
            else {
                // Filter can stay as-is; it’s O(n) once per team change, which is fine
                finalOptionsList = (this._options || []).filter(function (opt) {
                    return opt.teamCountry === team;
                });
            }
            if(refreshChild) {
                var child = this.template.querySelector('c-multi-select-search-list');
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
        var res = [];
        var selected = this.selectedValues || [];

        for (var i = 0; i < selected.length; i++) {
            var val = selected[i];
            var opt = this.optionsByValue ? this.optionsByValue[val] : null;

            res.push({
                type: 'icon',
                label: opt ? opt.label : val,
                name: val,
                iconName: 'custom:custom16',
                alternativeText: 'Agreement',
                isLink: true,
                href: '/' + val
            });
        }
        return res;
    }

    handleAgreementsChange(event) {
        var isSearchChange = event.detail && event.detail.isSearchChange;
        var selected = (event.detail && event.detail.selectedValues) ? event.detail.selectedValues : [];
        if (!isSearchChange) {
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
        var name = event.detail?.item?.name;
        if (!name) return;
        this.selectedValues = (this.selectedValues || []).filter(v => v !== name);
        this.pills = this.getPills();
    }

    handleDateChange(event) {
        this.startDate = event.detail.value;
    }

    handleNext() {
        var derivedTeam = null;
        if (!this.effectiveHasTeamSelection) {
            var firstId = (this.selectedValues && this.selectedValues.length) ? this.selectedValues[0] : null;
            derivedTeam = firstId && this.optionsByValue[firstId] ? this.optionsByValue[firstId].teamCountry : null;
        }

        this.dispatchEvent(new CustomEvent('agreementsnext', {
            detail: {
                agreements: this.selectedValues,
                startDate: this.startDate,
                team: this.effectiveHasTeamSelection ? this.selectedTeam : derivedTeam
            }
        }));
    }
}