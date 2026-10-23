import { LightningElement, api, wire, track } from 'lwc';
import { getRecordUi } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getEditableFieldsFromSourceField from '@salesforce/apex/PageLayoutController.getEditableFieldsFromSourceField';
import getFieldStates from '@salesforce/apex/PageLayoutController.getFieldStates';
import getPMTConfigurationWarning from '@salesforce/apex/PageLayoutController.getPMTConfigurationWarning';
import getRecordTypeId from '@salesforce/apex/PageLayoutController.getRecordTypeId';
import checkModificationConidtions from '@salesforce/apex/PageLayoutController.checkModificationConidtions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import BEFORE_UNLOAD_HANDLER from '@salesforce/resourceUrl/handleBeforeUnload';
import { loadScript } from 'lightning/platformResourceLoader';
import { NavigationMixin } from 'lightning/navigation';
import ProjectProductChildOBJ from '@salesforce/schema/ProjectProductChild__c';
import ProjectShareclassChildOBJ from '@salesforce/schema/ProjectShareclassChild__c';
import getAllFieldsByRecordId from '@salesforce/apex/PageLayoutController.getAllFieldsByRecordId';
import LightningConfirm from 'lightning/confirm';

// US-20194 V1.3: color states of an empty field (PRIIPs/KID style)
const REQUIRED_EMPTY_CLASS = 'field-state-required-empty';
const OPTIONAL_EMPTY_CLASS = 'field-state-optional-empty';

export default class LayoutEditableFields extends NavigationMixin(LightningElement) {

    @api recordId;
    @api objectApiName;
    @track sections = [];
    @track isEditMode = false;
    @api editableFields;
    @track fieldsInfo;
    @track currentObject ;
    fieldMetadata = {};
    newRecordUiData = null;
    doNotProcess;
    parentRecordType;
    displayEmptyMessage = false; 
    isLoading = true;
    teamParam;
    noEdit = false;
    allSectionIds = [];
    allData;
    editableFieldList = [];
    checkModificationConidtions ;
    // US-20194 V1.2: fields of the team's screen {apiName (lowercase): {required, editable}} and the fields whose change re-evaluates them (getFieldStates)
    fieldStates = null;
    conditionFields = new Set();
    draftValues = {};
    recordUiData = null;
    recordTypeId = null;
    userHasEditPermission = false;
    isHandlingTaxTransparencyChange = false;
    lastTaxTransparencySignature = null;
    

    get tabClass() { 
        return this.isEditMode ? 'edit-content' : '';
    }    
    get hasFields() {
        return this.sections && this.sections.length > 0;
    }

    get filteredSections() {
        if (!this.sections) return [];

        return this.sections.filter(section =>
            section.fields.some(field => field.isEditable)
        );
    }

   

    connectedCallback() {
        this.currentObject = this.objectApiName == 'ProjectProductChild__c'? ProjectProductChildOBJ : this.objectApiName == 'ProjectShareclassChild__c'? ProjectShareclassChildOBJ : null;
        this.showConfigurationWarning();
    }

    // US-20194 V1.2: PMT lines pointing to fields missing in this org (configuration to fix); an invalid condition is reported by the screen's own calls
    showConfigurationWarning() {
        getPMTConfigurationWarning()
            .then(message => { if (message) this.showToast('Warning', message, 'warning', 'sticky'); })
            .catch(() => {});
    }

    // US-20194 V1.2: the team's fields on this stage record (PMT lines and their conditions), evaluated by Apex with the unsaved values of the screen
    loadFieldStates() {
        if (!this.recordId) return;
        getFieldStates({ recordId: this.recordId, teamView: this.teamParam, draftValues: this.draftValues })
            .then(data => {
                const states = {};
                Object.entries(data.fields).forEach(([apiName, state]) => { states[apiName.toLowerCase()] = state; });
                this.fieldStates = states;
                this.conditionFields = new Set(data.conditionFields.map(field => field.toLowerCase()));
                this.userHasEditPermission = Object.values(states).some(state => state.editable);
                this.noEdit = !this.userHasEditPermission;
                this.updateSections();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', error?.body?.message || 'Unable to load the fields of this stage', 'error');
            });
    }

    showToast(title, message, variant, mode = 'dismissible') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }

    @wire(getAllFieldsByRecordId, { recordId: '$recordId' })
    wiredAllFields({ error, data }) {
        if (data) {
            console.log('getAllFieldsByRecordId',data);
            this.allData = data;
            this.updateSections();

        } else if (error) {
            console.error('❌ Erreur chargement règles dynamiques :', error);
        }
    }
    

    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredObjectInfo({ data, error }) {
        if (data) {
            this.fieldMetadata = {};
            Object.keys(data.fields).forEach(apiName => {
                this.fieldMetadata[apiName] = {
                    dataType: data.fields[apiName].dataType,
                    helptext: data.fields[apiName].inlineHelpText
                };
            });
            this.updateSections(); // Pour relancer le build des sections
        } else if (error) {
            console.error('Error fetching object info:', error);
        }

    }

    getColumnClass(field) {
        return field.isMultiPicklist
        ? 'slds-col slds-size_3-of-3 slds-p-right_medium slds-p-bottom_medium'
        : 'slds-col slds-size_1-of-3 slds-p-right_medium slds-p-bottom_medium';

    }

    renderedCallback() {
        const style = document.createElement('style');
        style.innerText = ".edit-input div.slds-form-element__icon { display: none; }";
        let qs = this.template.querySelectorAll('.edit-input');

        for (let i = 0; i < qs.length; i++) {
            const element = qs[i];
            element.appendChild(style);
        }
        console.log('this.objectApiName',this.objectApiName);
        console.log('editableFieldSource',this.editableFields);
    }
    
    @wire(checkModificationConidtions, {recordId :'$recordId', objectApiName: '$objectApiName'})
    checkEditableConidtions({ error, data }) {
        if (data) {
            this.parentRecordType = data.TECH_ProjectRecordType__c;
            this.doNotProcess = data.TECH_DoNotProcess__c && data.TECH_ProjectRecordType__c !== 'FundCreation';

            this.checkModificationConidtions = data;
        } else {
            console.error('❌ Error fetching editable fields:', error);
        }
    }
    
    @wire(getEditableFieldsFromSourceField, {recordId :'$recordId' ,editableFieldSource: '$editableFields' , objectApiName: '$objectApiName'})
    getEditableFieldsFromSourceField({ error, data }) {
        if (data) {
            this.editableFieldList = data;
        } else {
            console.error('❌ Error fetching editable fields:', error);
        }
    }
    disconnectedCallback() {
        if (this.isEditMode && window.preventNavigationHandlers) {
            
            window.removeEventListener('beforeunload', window.preventNavigationHandlers.beforeUnload);
            // window.removeEventListener('popstate', window.preventNavigationHandlers.popState);
        }
        
    }
    

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.teamParam = currentPageReference.state?.c__team || null;
            this.loadFieldStates();

        }
    }

    handleSectionToggle(event) {
        event.preventDefault(); // ✅ Prevent page refresh
        event.stopPropagation(); // ✅ Stop event from bubbling
    
        const sectionId = event.currentTarget.dataset.sectionId;
        const section = event.currentTarget.closest('.slds-section');
    
        if (section.classList.contains('slds-is-open')) {
            section.classList.remove('slds-is-open');
            event.currentTarget.setAttribute('aria-expanded', 'false');
        } else {
            section.classList.add('slds-is-open');
            event.currentTarget.setAttribute('aria-expanded', 'true');
        }
    }
    
    @wire(getRecordTypeId, { objectApiName: '$objectApiName', recordId: '$recordId' })
    wiredRecordType({ error, data }) {
        if (data) {
            this.recordTypeId = data;
        } else if (error) {
            console.error('Error fetching Record Type Id:', error);
        }
    }

    @wire(getRecordUi, { layoutTypes: ['Full'], modes: ['View'], recordIds: '$recordId' })
    wiredRecordUi({ error, data }) {
        if (data) {
            console.log('recordUiData',data);
            this.recordUiData = data;
            this.updateSections();
        } else {
            console.error('❌ Error fetching Record UI:', error);
        }
    }

    updateSections() {

        if (this.recordTypeId && this.fieldStates && this.recordUiData && this.allData) {
            this.sections = this.extractSections(this.recordUiData);
            if(this.sections.length <= 0) {
                this.displayEmptyMessage = true;
            } else {
                this.displayEmptyMessage = false;
            }
            this.isLoading = false;
        }
    }

    async handleFieldChange(event) {
        const fieldName = event.target.fieldName;
        let fieldValue = event.target.value;

        console.log('🟡 Field changed:', fieldName, '➡️', fieldValue);

        if (!this.fieldMetadata || !fieldName) {
            console.warn('⚠️ Missing metadata or field name');
            return;
        }

        if (fieldName === 'TaxTransparency__c' && this.isHandlingTaxTransparencyChange) {
            return;
        }

        let clonedAllData = { ...this.allData };

        if (fieldName === 'TaxTransparency__c') {
            this.isHandlingTaxTransparencyChange = true;

            try {
                const oldValues = this.normalizeMultiPicklistValues(this.allData?.TaxTransparency__c);
                const newValues = this.normalizeMultiPicklistValues(fieldValue);
                const countryRegValues = this.normalizeMultiPicklistValues(this.allData?.CountryRegNeeded__c);

                const signature = JSON.stringify(newValues.slice().sort());
                if (this.lastTaxTransparencySignature === signature) {
                    return;
                }

                const addedValues = newValues.filter(v => !oldValues.includes(v));

                let invalidAddedValues = [];
                let missingCountries = [];

                for (const addedValue of addedValues) {
                    const requiredCountry = this.getRequiredCountryForTaxTransparency(addedValue);

                    if (!requiredCountry) {
                        continue;
                    }

                    const isRegistered = countryRegValues.includes(requiredCountry);

                    if (!isRegistered) {
                        invalidAddedValues.push(addedValue);
                        if (!missingCountries.includes(requiredCountry)) {
                            missingCountries.push(requiredCountry);
                        }
                    }
                }

                if (invalidAddedValues.length > 0) {
                    await LightningConfirm.open({
                        label: 'Confirmation required',
                        theme: 'warning',
                        message:
                            `This fund/share class is not registered in ${missingCountries.join(', ')}. ` +
                            `Please review Country Reg Needed if you still want to keep: ${invalidAddedValues.join(', ')}.`
                    });
                }

                this.lastTaxTransparencySignature = signature;
            } finally {
                this.isHandlingTaxTransparencyChange = false;
            }
        }

        clonedAllData[fieldName] = fieldValue;
        this.allData = clonedAllData;
        this.draftValues = { ...this.draftValues, [fieldName]: fieldValue };
        if (this.conditionFields.has(fieldName.toLowerCase())) this.loadFieldStates();
        else this.sections = this.extractSections(this.recordUiData);
    }

    normalizeMultiPicklistValues(value) {
        if (!value) {
            return [];
        }

        if (Array.isArray(value)) {
            return value.filter(v => !!v);
        }

        if (typeof value === 'string') {
            return value
                .split(';')
                .map(v => v.trim())
                .filter(v => !!v);
        }

        return [];
    }

    getRequiredCountryForTaxTransparency(taxValue) {
        if (!taxValue) {
            return null;
        }

        

        // Règle générique basée sur le préfixe
        if (taxValue.startsWith('BE') || taxValue.startsWith('Belgium')) return 'Belgium';
        if (taxValue.startsWith('CH')) return 'Switzerland';
        if (taxValue.startsWith('UK')) return 'United Kingdom';
        if (taxValue.startsWith('IT')) return 'Italy';
        if (taxValue.startsWith('AT')) return 'Austria';

        return null;
    }

    extractSections(data) {
        let sections = [];
        let sectionIds = [];
        if (!data.layouts[this.objectApiName] || !data.layouts[this.objectApiName][this.recordTypeId]) {
            console.error('❌ Layout data not found for object:', this.objectApiName);
            return sections;
        }
        const recordLayout = data.layouts[this.objectApiName][this.recordTypeId]?.Full?.View

        const fieldsValues  = data.records[this.recordId]?.fields;
        if (recordLayout?.sections) {
            recordLayout.sections.forEach(section => {
                let fields = [];

                section.layoutRows.forEach(row => {
                    row.layoutItems.forEach(item => {
                        if (item.layoutComponents && item.layoutComponents.length > 0) {
                            let fieldApiName = item.layoutComponents[0].apiName;
                            if (fieldApiName) {
                                const state = this.fieldStates[fieldApiName.toLowerCase()];
                                if (state) {
                                    const isMultiPicklist = this.fieldMetadata?.[fieldApiName]?.dataType === 'MultiPicklist';
                                    const isRichTextArea = this.fieldMetadata?.[fieldApiName]?.dataType === 'TextArea';
                                    const currentValue = Object.prototype.hasOwnProperty.call(this.draftValues, fieldApiName) ? this.draftValues[fieldApiName] : fieldsValues[fieldApiName]?.value;
                                    const stateClass = this.getFieldStateClass(state.required, currentValue);
                                    const width = isMultiPicklist || isRichTextArea ? 'slds-size_3-of-3' : 'slds-size_1-of-3';
                                    fields.push({
                                        apiName: fieldApiName,
                                        label: item.label,
                                        isEditable: state.editable && (this.parentRecordType == 'FundCreation' || this.parentRecordType == 'ShareclassCreation' || this.editableFieldList.includes(fieldApiName)),
                                        isMultiPicklist: isMultiPicklist,
                                        isRichTextArea: isRichTextArea,
                                        helptext : this.fieldMetadata?.[fieldApiName]?.helptext,
                                        isRequired: state.required,
                                        isRequiredEmpty: stateClass === REQUIRED_EMPTY_CLASS,
                                        labelClass: stateClass === REQUIRED_EMPTY_CLASS ? 'slds-form-element__label field-label-required-empty' : 'slds-form-element__label',
                                        value: isMultiPicklist ? fieldsValues[fieldApiName]?.value?.split(';') : fieldsValues[fieldApiName]?.value,
                                        columnClass: `slds-col ${width} slds-p-right_medium slds-p-bottom_medium ${stateClass}`.trim()
                                    });
                                }
                            }
                        }
                    });
                });

                if (fields.length > 0) {
                    const requiredMissing = fields.filter(field => field.isRequiredEmpty).length;
                    sections.push({
                        id: section.id,
                        label: section.heading,
                        fields: fields,
                        requiredMissingLabel: requiredMissing > 0 ? `${requiredMissing} required missing` : null
                    });
                    sectionIds.push(section.id);
                }
            });
        }
        console.log('sections'  ,sections);
        this.allSectionIds = sectionIds;

        return sections;
    }

    // US-20194 V1.3: only an empty field is colored, red when required, orange when optional. A checkbox is never empty (false is a value), as in countFilledFields.
    getFieldStateClass(required, value) {
        const isEmpty = value === null || value === undefined || value === '' || (Array.isArray(value) && value.length === 0);
        if (!isEmpty) return '';
        return required ? REQUIRED_EMPTY_CLASS : OPTIONAL_EMPTY_CLASS;
    }

    enableEditMode() {
        this.isEditMode = true;
        loadScript(this, BEFORE_UNLOAD_HANDLER)
        .then(() => {
            document.addEventListener('click', this.handleNavigationAttempt);

            window.preventNavigationHandlers.setUnsavedChanges(true);

        })
        .catch(error => {
            console.error('Error loading beforeUnloadHandler:', error);
        });
    }

    disableEditMode() {
        this.isEditMode = false;
        window.preventNavigationHandlers.setUnsavedChanges(false);
        this.draftValues = {};
        this.loadFieldStates();
    }

    handleSuccess(event) {
        this.isEditMode = false;
        this.isLoading = false;
        console.log('handleSuccess',event.detail.id);
        console.log('preventedNavigationHandlers',window.preventNavigationHandlers);

        window.preventNavigationHandlers.setUnsavedChanges(false);
        console.log('preventedNavigationHandlers',window.preventNavigationHandlers);

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Record updated successfully',
                variant: 'success'
            })
        );

        this.draftValues = {};
        this.loadFieldStates();
    }

    handleSubmit() {
        this.isLoading = true   
    }

    handleError(event) {
        const fieldErrors = event.detail?.output?.fieldErrors || {};
        let foundField = false;
        
        for (const [fieldApiName, errors] of Object.entries(fieldErrors)) {
            const inputCmp = this.template.querySelector(
                `lightning-input-field[field-name="${fieldApiName}"]`
            );
            if (inputCmp) {
                inputCmp.setCustomValidity(errors[0].message);
                inputCmp.reportValidity();
                foundField = true;
            }
        }
        
        if (!foundField) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Erreur',
                    message: event.detail?.detail || 'Une erreur est survenue',
                    variant: 'error'
                })
            );
        }
        
        this.isLoading = false;

    }
}