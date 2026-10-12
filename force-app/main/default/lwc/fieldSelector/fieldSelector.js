import { LightningElement, wire, api, track } from 'lwc';
import getMetadataFields from '@salesforce/apex/FieldSelectorController.getMetadataFields';
import getDependentFields from '@salesforce/apex/FieldSelectorController.getDependentFields';
import getSelectedFields from '@salesforce/apex/FieldSelectorController.getSelectedFields';
import saveSelectedFields from '@salesforce/apex/FieldSelectorController.updateSelectedFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { MessageContext } from 'lightning/messageService';

export default class FieldSelector extends LightningElement {
    @api recordId; // The ID of the current record
    @api objectName = 'Product__c';
    showSpinner = false;
    @track availableFields = [];
    @track selectedFields = [];
    @track rawSelectedFields = [];
    @track dependentFields = [];
    changeMade = false;
    searchKey = '';

    @wire(MessageContext)
    messageContext;

    // Fetch available fields from metadata
    @wire(getMetadataFields, { objectApiName: '$objectName' })
    wiredMetadataFields({ error, data }) {
        if (data) {
            this.availableFields = data.map(field => ({ label: field.label, value: field.value }));
            this.refreshSelectedFields();
        }
        else if (error) {
            console.error('Error fetching metadata fields:', error);
        }
    }

    // Fetch dependent fields from metadata
    @wire(getDependentFields, { objectApiName: '$objectName' })
    wiredMetadataDependentFields({ error, data }) {
        if (data) {
            this.dependentFields = data.map(field => ({ controllingField: field.controllingField, dependentFields: field.dependentFields }));
        }
        else if (error) {
            console.error('Error fetching metadata fields:', error);
        }
    }

    // Fetch initially selected fields
    @wire(getSelectedFields, { recordId: '$recordId', objectApiName: '$objectName' })
    wiredSelectedFields({ error, data }) {
        if (data) {
            this.rawSelectedFields = data.map(field => field.value);
            this.refreshSelectedFields();
        }
        else if (error) {
            console.error('Error fetching selected fields:', error);
        }
    }

    // Function to refresh selected fields after available fields are ready
    refreshSelectedFields() {
        if (this.rawSelectedFields.length > 0 && this.availableFields.length > 0) {
            this.selectedFields = this.rawSelectedFields.map(fieldApiName => {
                const fieldMetadata = this.availableFields.find(f => f.value === fieldApiName);
                return { label: fieldMetadata ? fieldMetadata.label : fieldApiName, value: fieldApiName };
            });
        }
    }

    handleSearch(event) {
        this.searchKey = event.target.value.toLowerCase();
    }

    get filteredFields() {
        return this.availableFields.filter(field => field.label.toLowerCase().includes(this.searchKey) && !this.selectedFields.some(selected => selected.value === field.value));
    }

    arrayCompare(_arr1, _arr2) {
        if (!Array.isArray(_arr1) || !Array.isArray(_arr2) || _arr1.length !== _arr2.length) return false;

        // .concat() to not mutate arguments
        const arr1 = _arr1.concat().sort();
        const arr2 = _arr2.concat().sort();
        for (let i = 0; i < arr1.length; i++) {
            if (arr1[i] !== arr2[i]) return false;
        }
        return true;
    }

    handleFieldSelect(event) {
        const fieldValue = event.target.dataset.value;
        const selectedField = this.availableFields.find(field => field.value === fieldValue);
        if (selectedField) this.selectedFields = [...this.selectedFields, { ...selectedField }];
        this.changeMade = !this.arrayCompare(this.rawSelectedFields, this.selectedFields.map(field => field.value));
    }

    handleFieldRemove(event) {
        const fieldValue = event.target.dataset.value;
        this.selectedFields = this.selectedFields.filter(field => field.value !== fieldValue);
        this.changeMade = !this.arrayCompare(this.rawSelectedFields, this.selectedFields.map(field => field.value));
    }

    handleSave() {
        let fieldsArray = [];
        this.selectedFields.forEach(element => {
            let dependentRecord = this.dependentFields.find(field => field.controllingField === element.value);
            if (dependentRecord != null) {
                let dependentFieldsArray = dependentRecord.dependentFields.split(';');
                for (let i = 0; i < dependentFieldsArray.length; i++) {
                    if (this.selectedFields.find(field => field.value === dependentFieldsArray[i]) == null) {
                        const dependentField = this.availableFields.find(field => field.value === dependentFieldsArray[i]);
                        if (dependentField) fieldsArray.push(dependentField);
                    }
                }
            }
        });
        if (fieldsArray.length > 0) this.selectedFields = [...this.selectedFields, ...fieldsArray];

        const selectedValues = this.selectedFields.map(field => field.value);
        this.showSpinner = true;
        saveSelectedFields({ recordId: this.recordId, selectedFields: selectedValues, objectApiName: this.objectName }).then(() => {
            this.showSpinner = false;
            this.showToast('Success', 'Selected fields saved successfully!', 'success');
            window.location.reload();
        }).catch(error => {
            this.showSpinner = false;
            console.error('Error saving selected fields:', error);
            this.showToast('Error', error?.body?.message || 'An unexpected error occurred while saving the selected fields.', 'error'); // FIX-20269: show the Apex error (e.g. phase already validated) instead of failing silently
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}