import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import previewLine from '@salesforce/apex/PMTMatrixExplorerController.previewLine';
import checkCondition from '@salesforce/apex/PMTMatrixExplorerController.checkCondition';
import saveLine from '@salesforce/apex/PMTMatrixExplorerController.saveLine';

// US-20194 V1.6: pop-up of the PMT Matrix Explorer creating or editing one rule line; PMTMatrixExplorerController reuses or creates its PMTField and PMTFieldRule
const FORM_FIELDS = ['team', 'stage', 'objectName', 'fieldApiName', 'isModifiable', 'dependentFields', 'requirement', 'condition', 'requiredCondition', 'isActive'];
// Custom metadata field behind each input, whose inline help is the input's tooltip
const HELP_FIELDS = {
    team: 'PMTFieldRule__mdt.Team__c',
    stage: 'PMTFieldRule__mdt.Stage__c',
    objectName: 'PMTField__mdt.Object__c',
    fieldApiName: 'PMTField__mdt.FieldApiName__c',
    isModifiable: 'PMTField__mdt.IsModifiable__c',
    dependentFields: 'PMTField__mdt.DependentFields__c',
    requirement: 'PMTFieldRuleLine__mdt.Requirement__c',
    condition: 'PMTFieldRuleLine__mdt.Condition__c',
    requiredCondition: 'PMTFieldRuleLine__mdt.RequiredCondition__c',
    isActive: 'PMTFieldRuleLine__mdt.IsActive__c'
};
const CONDITIONAL = 'Conditional';
const PREVIEW_DELAY = 400;
const MAX_FIELD_MATCHES = 50;

export default class PmtRuleLineEditor extends LightningModal {
    // { teamOptions, stageOptions, levelOptions, requirementOptions, fieldOptionsByLevel, helpTextByField }
    @api editorModel;
    // Edit: the line's values, with lineId and developerName. Create: null
    @api line;
    // Create: values prefilled from the explorer's filters
    @api defaults;

    team;
    stage;
    objectName;
    fieldApiName;
    isModifiable = false;
    dependentFields = [];
    requirement;
    condition = '';
    requiredCondition = '';
    isActive = true;
    // Text typed in the field picker while its list is open; null when closed
    fieldQuery = null;
    dependentFilter = '';
    preview;
    previewedFieldKey;
    conditionCheck;
    requiredConditionCheck;
    saveError;
    isSaving = false;
    previewTimeout;

    connectedCallback() {
        this.requirement = this.editorModel.requirementOptions[0]?.value;
        const values = this.line || this.defaults || {};
        FORM_FIELDS.filter(name => values[name] !== undefined && values[name] !== null).forEach(name => {
            this[name] = values[name];
        });
        this.previewedFieldKey = this.isEdit ? this.fieldKey : undefined;
        this.refreshPreview();
    }

    get isEdit() {
        return !!this.line;
    }

    get title() {
        return this.isEdit ? `Edit ${this.line.developerName}` : 'New rule line';
    }

    get help() {
        const help = {};
        Object.entries(HELP_FIELDS).forEach(([name, field]) => {
            help[name] = this.editorModel.helpTextByField?.[field];
        });
        return help;
    }

    get fieldKey() {
        return `${this.objectName}.${this.fieldApiName}`;
    }

    get isLevelMissing() {
        return !this.objectName;
    }

    get isFieldDisabled() {
        return this.isEdit || this.isLevelMissing;
    }

    get isConditional() {
        return this.requirement === CONDITIONAL;
    }

    get levelFieldOptions() {
        return this.editorModel.fieldOptionsByLevel[this.objectName] || [];
    }

    // Field picker: shows the chosen field, or the text typed while searching
    get fieldInputValue() {
        if (this.fieldQuery !== null) return this.fieldQuery;
        return this.levelFieldOptions.find(option => option.value === this.fieldApiName)?.label ?? this.fieldApiName ?? '';
    }

    get fieldPlaceholder() {
        return this.isLevelMissing ? 'Choose an object first' : 'Search a field by label or API name';
    }

    get isFieldListOpen() {
        return this.fieldQuery !== null && !this.isFieldDisabled;
    }

    get fieldListExpanded() {
        return String(this.isFieldListOpen);
    }

    get fieldComboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click${this.isFieldListOpen ? ' slds-is-open' : ''}`;
    }

    get fieldMatches() {
        return this.levelFieldOptions.filter(option => this.matchesText(option, this.fieldQuery)).slice(0, MAX_FIELD_MATCHES).map(option => {
            const isSelected = option.value === this.fieldApiName;
            return { ...option, ariaSelected: String(isSelected), className: `slds-media slds-listbox__option slds-listbox__option_plain slds-media_small${isSelected ? ' slds-is-selected' : ''}` };
        });
    }

    get hasNoFieldMatch() {
        return this.fieldMatches.length === 0;
    }

    get fieldMatchesNote() {
        const total = this.levelFieldOptions.filter(option => this.matchesText(option, this.fieldQuery)).length;
        return total > MAX_FIELD_MATCHES ? `${MAX_FIELD_MATCHES} of ${total} fields shown: keep typing to narrow the list` : null;
    }

    // The chosen dependent fields stay in the options whatever the search: a dual listbox only shows values present in its options
    get dependentFieldOptions() {
        return this.levelFieldOptions.filter(option => option.value !== this.fieldApiName && (this.matchesText(option, this.dependentFilter) || this.dependentFields.includes(option.value)));
    }

    get ruleStatus() {
        if (!this.preview) return null;
        return this.preview.ruleDeveloperName ? `Existing rule ${this.preview.ruleDeveloperName}` : 'New rule: it will be created for this team and stage';
    }

    get fieldStatus() {
        if (!this.preview) return null;
        if (!this.preview.fieldDeveloperName) return 'New field: it will be added to the PMT field dictionary';
        return `Existing field ${this.preview.fieldDeveloperName}, used by ${this.preview.fieldLineCount} line(s): Modifiable and Dependent fields apply to all of them`;
    }

    get errorMessages() {
        return [...(this.preview?.errors || []), this.saveError].filter(Boolean).map((message, index) => ({ key: `error-${index}`, message }));
    }

    get hasErrors() {
        return this.errorMessages.length > 0;
    }

    get hasConflict() {
        return !!this.preview?.conflictLineId;
    }

    get isSaveDisabled() {
        return this.isSaving || !this.preview || this.preview.errors.length > 0;
    }

    get saveLabel() {
        return this.isSaving ? 'Sending…' : 'Save';
    }

    get request() {
        const request = { lineId: this.line?.lineId };
        FORM_FIELDS.forEach(name => {
            request[name] = this[name];
        });
        request.requiredCondition = this.isConditional ? this.requiredCondition : null;
        return request;
    }

    matchesText(option, text) {
        return !text || option.label.toLowerCase().includes(text.toLowerCase());
    }

    handleIdentityChange(event) {
        const name = event.target.dataset.name;
        this[name] = event.detail.value;
        if (name === 'objectName') {
            this.fieldApiName = undefined;
            this.dependentFields = [];
            this.dependentFilter = '';
            this.conditionCheck = undefined;
            this.requiredConditionCheck = undefined;
        }
        this.schedulePreview();
    }

    handleFieldFocus() {
        this.fieldQuery = '';
    }

    handleFieldInput(event) {
        this.fieldQuery = event.target.value;
    }

    handleFieldBlur() {
        this.fieldQuery = null;
    }

    // mousedown runs before the input's blur closes the list
    handleFieldPick(event) {
        event.preventDefault();
        this.fieldApiName = event.currentTarget.dataset.value;
        this.dependentFields = this.dependentFields.filter(field => field !== this.fieldApiName);
        this.fieldQuery = null;
        this.template.querySelector('.field-input').blur();
        this.schedulePreview();
    }

    handleDependentFilterChange(event) {
        this.dependentFilter = event.detail.value;
    }

    handleValueChange(event) {
        this[event.target.dataset.name] = event.detail.value;
        this.schedulePreview();
    }

    handleCheckboxChange(event) {
        this[event.target.dataset.name] = event.target.checked;
        this.schedulePreview();
    }

    handleRequirementChange(event) {
        this.requirement = event.detail.value;
        if (!this.isConditional) {
            this.requiredCondition = '';
            this.requiredConditionCheck = undefined;
        }
        this.schedulePreview();
    }

    // A check is cleared as soon as its text changes
    handleConditionChange(event) {
        const name = event.target.dataset.name;
        this[name] = event.detail.value;
        this[`${name}Check`] = undefined;
        this.schedulePreview();
    }

    async handleCheckCondition(event) {
        const name = event.target.dataset.name;
        try {
            const result = await checkCondition({ condition: this[name], objectName: this.objectName, isRequired: name === 'requiredCondition' });
            this[`${name}Check`] = this.buildCheck(result);
        }
        catch (error) {
            this[`${name}Check`] = { className: 'check check_error', text: this.getErrorMessage(error) };
        }
    }

    // Shown at once: Apex checks the line again and queues the deployment before the explorer can announce it; a pending preview is dropped so it does not delay the save
    async handleSave() {
        clearTimeout(this.previewTimeout);
        this.isSaving = true;
        this.saveError = undefined;
        try {
            const jobId = await saveLine({ requestJson: JSON.stringify(this.request) });
            this.close({ jobId });
        }
        catch (error) {
            this.saveError = this.getErrorMessage(error);
        }
        finally {
            this.isSaving = false;
        }
    }

    handleEditConflict() {
        this.close({ editLineId: this.preview.conflictLineId });
    }

    handleCancel() {
        this.close();
    }

    schedulePreview() {
        clearTimeout(this.previewTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.previewTimeout = setTimeout(() => this.refreshPreview(), PREVIEW_DELAY);
    }

    // Once the identity is complete, Apex tells which records are reused or created and what blocks the save; a newly chosen existing field brings its field-wide values
    async refreshPreview() {
        if (!(this.team && this.stage && this.objectName && this.fieldApiName)) {
            this.preview = undefined;
            return;
        }
        try {
            const preview = await previewLine({ requestJson: JSON.stringify(this.request) });
            if (this.fieldKey !== this.previewedFieldKey) {
                this.isModifiable = preview.fieldIsModifiable;
                this.dependentFields = preview.fieldDependentFields;
                this.previewedFieldKey = this.fieldKey;
            }
            this.preview = preview;
        }
        catch (error) {
            this.preview = undefined;
            this.saveError = this.getErrorMessage(error);
        }
    }

    buildCheck(result) {
        if (result.error) return { className: 'check check_error', text: result.error };
        const reads = [
            result.projectFields.length && `ProjectProduct__c: ${result.projectFields.join(', ')}`,
            result.shareClassFields.length && `ProjectShareclass__c: ${result.shareClassFields.join(', ')} (evaluated per share class)`
        ].filter(Boolean);
        return { className: 'check check_valid', text: reads.length ? `Valid condition, reads ${reads.join(' · ')}` : 'No condition: always applies' };
    }

    getErrorMessage(error) {
        return error.body?.message ?? error.message;
    }
}
