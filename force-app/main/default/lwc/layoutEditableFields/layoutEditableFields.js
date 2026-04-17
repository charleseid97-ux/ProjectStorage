import { LightningElement, api, wire, track } from 'lwc';
import { getRecordUi } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getEditableFields from '@salesforce/apex/PageLayoutController.getEditableFields';
import getEditableFieldsFromSourceField from '@salesforce/apex/PageLayoutController.getEditableFieldsFromSourceField';
import getFields from '@salesforce/apex/PageLayoutController.getFields';
import getUserPermissionSet from '@salesforce/apex/PageLayoutController.getUserPermissionSet';
import getRecordTypeId from '@salesforce/apex/PageLayoutController.getRecordTypeId';
// import checkEditableConidtions from '@salesforce/apex/PageLayoutController.checkEditableConidtions';
import checkModificationConidtions from '@salesforce/apex/PageLayoutController.checkModificationConidtions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import BEFORE_UNLOAD_HANDLER from '@salesforce/resourceUrl/handleBeforeUnload';
import { loadScript } from 'lightning/platformResourceLoader';
import { NavigationMixin } from 'lightning/navigation';
import getFieldRules from '@salesforce/apex/FieldDisplayRuleService.getRulesForObject';
import ProjectProductChildOBJ from '@salesforce/schema/ProjectProductChild__c';
import ProjectShareclassChildOBJ from '@salesforce/schema/ProjectShareclassChild__c';
import getAllFieldsByRecordId from '@salesforce/apex/PageLayoutController.getAllFieldsByRecordId';

export default class LayoutEditableFields extends NavigationMixin(LightningElement) {

    @api recordId;
    @api objectApiName;
    @track sections = [];
    @track isEditMode = false;
    @api viewAll = false;
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
    requiredFields = new Set();
    allData;
    editableFieldList = [];
    checkModificationConidtions ;
    fieldPermissions = null;
    recordUiData = null;
    recordTypeId = null;
    userHasEditPermission = false;
    // checkEditableConidtions = false;
    dynamicRules = [];
    

    get tabClass() { 
        return this.isEditMode ? 'edit-content' : '';
    }    
    get filteredSections() {
        if (!this.sections) return [];

        return this.sections.filter(section =>
            section.fields.some(field => field.isEditable)
        );
    }

   

    connectedCallback() {
        this.currentObject = this.objectApiName == 'ProjectProductChild__c'? ProjectProductChildOBJ : this.objectApiName == 'ProjectShareclassChild__c'? ProjectShareclassChildOBJ : null;

        getFieldRules({ objectApiName: this.objectApiName })
        .then((rules) => {
            this.dynamicRules = rules;
            console.log('✅ Règles dynamiques chargées :', this.dynamicRules);
            this.updateSections();

        })
        .catch(error => {
            console.error('❌ Erreur chargement règles dynamiques :', error);
        });
    }
    
    @wire(getFieldRules, { objectApiName: '$objectApiName' })
    wiredFieldRules({ error, data }) {
        console.log('getFieldRules',this.objectApiName, data, error);
        if (data) {
            this.dynamicRules = data;
            console.log('✅ Règles dynamiques chargées wire :', this.dynamicRules);
            this.updateSections();
        } else if (error) {
            console.error('❌ Erreur chargement règles dynamiques :', error);
        }
    }
    
    @wire(getAllFieldsByRecordId, { recordId: '$recordId' })
    wiredFieldRules({ error, data }) {
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
    
    @wire(getRecordTypeId, { objectApiName: '$objectApiName', recordId: '$recordId' })
    wiredRecordType({ error, data }) {
        if (data) {
            this.recordTypeId = data;
        } else if (error) {
            console.error('Error fetching Record Type Id:', error);
        }
    }

    @wire(getEditableFields, { objectApiName: '$objectApiName', teamView: '$teamParam', viewAll: '$viewAll' })
    wiredFieldPermissions({ error, data }) {
        if (data) {
            this.fieldPermissions = data;
            console.log('fieldPermissions',this.fieldPermissions);
            this.updateSections();
        } else {
            console.error('❌ Error fetching editable fields:', error);
        }
    }

    @wire(getUserPermissionSet, { teamView: '$teamParam' })
    wiredUserPermissions({ error, data }) {
        if (data) {
            this.userHasEditPermission = data;
            this.noEdit = !this.userHasEditPermission && !this.viewAll;
        } else {
            this.noEdit = !this.viewAll;
            console.error('❌ Error fetching user permission set:', error);
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

        if (this.recordTypeId && this.fieldPermissions && this.recordUiData && this.requiredFields && this.allData && this.dynamicRules) {
            this.sections = this.extractSections(this.recordUiData);
            if(this.sections.length <= 0) {
                this.displayEmptyMessage = true;
            } else {
                this.displayEmptyMessage = false;
            }
            this.isLoading = false;
        }
    }

    // Fetch required fields from Apex
    @wire(getFields, { objectVar: '$objectApiName', recordId: '$recordId' })
    wiredRequiredFields({ error, data }) {
        if (data) {
            this.requiredFields = new Set(data);
            this.updateSections();
        } else if (error) {
            console.error('❌ Error fetching required fields:', error);
        }
    }
    
    handleFieldChange(event) {
        const fieldName = event.target.fieldName;
        const fieldValue = event.target.value;
    
        console.log('🟡 Field changed:', fieldName, '➡️', fieldValue);
    
        // Skip if metadata is not loaded
        if (!this.fieldMetadata || !fieldName) {
            console.warn('⚠️ Missing metadata or field name');
            return;
        }
    
        let clonedAllData = { ...this.allData };
        clonedAllData[fieldName] = fieldValue;
        this.allData = clonedAllData;
        this.sections = this.extractSections(this.recordUiData);
    }

    extractSections(data) {
        let sections = [];
        let sectionIds = [];
        if (!data.layouts[this.objectApiName] || !data.layouts[this.objectApiName][this.recordTypeId]) {
            console.error('❌ Layout data not found for object:', this.objectApiName);
            return sections;
        }
        const recordLayout = data.layouts[this.objectApiName][this.recordTypeId]?.Full?.View

        // let tmprecordFields = this.newRecordUiData?.records[this.recordId].fields;
        // let record = {};
     
        // console.log(`tmprecordFields: ${JSON.stringify(tmprecordFields)}`);
        // Prépare les données de l’enregistrement pour l’évaluation JS
        // if(tmprecordFields) {
        //     for (let key in tmprecordFields) {
        //         record[key] = tmprecordFields[key].value;

        //     }
        // } else {
        let record = this.allData;
        // }
        console.log('record:', record );
        console.log('recordLayout:', recordLayout );
        
        const fieldsValues  = data.records[this.recordId]?.fields;
        if (recordLayout?.sections) {
            recordLayout.sections.forEach(section => {
                let fields = [];

                section.layoutRows.forEach(row => {
                    row.layoutItems.forEach(item => {
                        if (item.layoutComponents && item.layoutComponents.length > 0) {
                            let fieldApiName = item.layoutComponents[0].apiName;
                            if (fieldApiName) {
                                let fullApiName = this.objectApiName + '.' + fieldApiName;
                                
                                const rule = this.dynamicRules?.find(r => r.fieldApiName.toLowerCase() === fieldApiName.toLowerCase());
                                console.log('rule',rule);

                                const isVisibleByRule = this.evaluateRuleCondition(rule, record);
                                const isMandatoryByRule = this.evaluateMandatoryRuleCondition(rule, record);
                                console.log('fieldApiName',fieldApiName);
                                console.log('isMandatoryByRule',isMandatoryByRule);
                                console.log('isVisibleByRule',isVisibleByRule);
                                if ((this.fieldPermissions[fullApiName] || this.viewAll)) {

                                    const isMultiPicklist = this.fieldMetadata?.[fieldApiName]?.dataType === 'MultiPicklist';
                                    const isRichTextArea = this.fieldMetadata?.[fieldApiName]?.dataType === 'TextArea';
                                    fields.push({
                                        apiName: fieldApiName,
                                        label: item.label,
                                        isVisibleByRule: isVisibleByRule,
                                        isEditable: this.userHasEditPermission? this.parentRecordType == 'FundCreation' || this.parentRecordType == 'ShareclassCreation' ? true : this.editableFieldList.includes(fieldApiName)? true : false : false,
                                        isMultiPicklist: isMultiPicklist,
                                        isRichTextArea: isRichTextArea,
                                        helptext : this.fieldMetadata?.[fieldApiName]?.helptext,
                                        isRequired: this.requiredFields.has(fieldApiName) || isMandatoryByRule ,
                                        value: isMultiPicklist? fieldsValues[fieldApiName]?.value?.split(';') : fieldsValues[fieldApiName]?.value,
                                        columnClass: isMultiPicklist
                                        ? 'slds-col slds-size_3-of-3 slds-p-right_medium slds-p-bottom_medium'
                                        : isRichTextArea? 'slds-col slds-size_3-of-3 slds-p-right_medium slds-p-bottom_medium' :'slds-col slds-size_1-of-3 slds-p-right_medium slds-p-bottom_medium'
                                    });
                                }
                            }
                        }
                    });
                });

                if (fields.length > 0) {
                    sections.push({
                        id: section.id,
                        label: section.heading,
                        fields: fields
                    });
                    sectionIds.push(section.id);
                }
            });
        }
        console.log('sections'  ,sections);
        this.allSectionIds = sectionIds;

        return sections;
    }

    evaluateRuleCondition(rule, record) {
        console.log('evaluateRuleCondition',rule, record);

        if (!rule || !rule.displayCondition) {
            console.log(`📌 Aucune règle trouvée pour le champ ${rule?.fieldApiName}, on affiche le champ.`);
            return true;
        }
     
        try {

            const condition = rule.displayCondition.trim().replaceAll("'",'"');
            console.log(`🔍 Évaluation de la condition pour ${rule.fieldApiName} :`, condition);
            const evaluator = new Function('record', `return (${condition});`);
            const result = evaluator(record);
            return result;
        } catch (error) {
            console.error(`❌ Erreur d’évaluation pour ${rule.fieldApiName} :`, error);
            return false; // on masque le champ si erreur
        }
    }

    evaluateMandatoryRuleCondition(rule, record) {
        console.log('evaluateMandatoryRuleCondition',rule, record);
        if (!rule || !rule.mandatoryCondition) {
            return false;
        }
     
        try {
            const condition = rule.mandatoryCondition.trim().replaceAll("'",'"');
            console.log(`🔍 Évaluation de la condition pour ${rule.fieldApiName} :`, condition);
            const evaluator = new Function('record', `return (${condition});`);
            const result = evaluator(record);
     
            return result;
        } catch (error) {
            console.error(`❌ Erreur d’évaluation pour ${rule.fieldApiName} :`, error);
            return false; // on masque le champ si erreur
        }
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

        getFieldRules({ objectApiName: this.objectApiName })
        .then((rules) => {
            this.dynamicRules = rules;
            console.log('✅ Règles dynamiques chargées :', this.dynamicRules);
            this.updateSections();

        })
        .catch(error => {
            console.error('❌ Erreur chargement règles dynamiques :', error);
        });
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