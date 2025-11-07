import { LightningElement, api, track, wire } from 'lwc';
import getChildren from '@salesforce/apex/ProjectProductChildDatatableController.getChildren';
import getStatusPicklistValues from '@salesforce/apex/ProjectProductChildDatatableController.getStatusPicklistValues';
import updateChildren from '@salesforce/apex/ProjectProductChildDatatableController.updateChildren';
import deleteChild from '@salesforce/apex/ProjectProductChildDatatableController.deleteChild';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { createRecord } from 'lightning/uiRecordApi';
import CHILD_OBJECT from '@salesforce/schema/ProjectProductChild__c';
import NAME_FIELD from '@salesforce/schema/ProjectProductChild__c.Name';
import STARTDATE_FIELD from '@salesforce/schema/ProjectProductChild__c.StartDate__c';
import STATUS_FIELD from '@salesforce/schema/ProjectProductChild__c.Status__c';
import PARENT_FIELD from '@salesforce/schema/ProjectProductChild__c.ProjectProductParent__c';
 
const COLUMNS_BASE = [
    { label: 'Name', fieldName: 'Name', type: 'text', editable: false },
    { label: 'Start Date', fieldName: 'StartDate__c', type: 'date-local', editable: true },
    { label: 'End Date', fieldName: 'EndDate__c', type: 'date-local', editable: true },
    { label: 'Completion %', fieldName: 'CompletionRateStep__c', type: 'number', cellAttributes: { alignment: 'left' }, editable: false },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'customPicklist',
        typeAttributes: {
            options: { fieldName: 'statusOptions' },
            value: { fieldName: 'Status__c' },
            label: 'Status',
            placeholder: 'Select status',
            context: { fieldName: 'Id' }
        },
        editable: true
    },
    { label: 'RAG', fieldName: 'RAG__c', type: 'text', editable: false },
];
 
export default class ProjectProductChildDatatable extends LightningElement {
    @api recordId;
    @track data = [];
    @track columns = COLUMNS_BASE;
    @track draftValues = [];
    statusOptions = [];
    _wiredResult;
 
    showModal = false;
    newName = '';
    newStartDate = '';
    newStatus = '';
 
    connectedCallback() {
        getStatusPicklistValues()
            .then(result => {
                this.statusOptions = result.map(val => ({ label: val, value: val }));
            });
    }
 
@wire(getChildren, { parentId: '$recordId' })
    wiredChildren(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.data = data
            .filter(row => row.Name !== 'Design')
                .map(row => ({
                    ...row,
                    Name: row.Name === 'Proposal' ? 'Design and Proposal' : row.Name,
                    statusOptions: this.statusOptions
                }));
        } else if (error) {
            console.error(error);
        }
    }
 
    handleSave(event) {
        const fields = event.detail.draftValues;
        updateChildren({ updatedRecords: fields })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Records updated',
                    variant: 'success'
                }));
                this.draftValues = [];
                return refreshApex(this._wiredResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }
 
    handleRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'delete') {
        deleteChild({ recordId: row.Id })
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Deleted',
                        message: 'Record deleted',
                        variant: 'success'
                    }));
                    return refreshApex(this._wiredResult);
                })
                .catch(error => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error deleting',
                        message: error.body.message,
                        variant: 'error'
                    }));
                });
        }
    }
 
    handleNewClick() {
        this.showModal = true;
    }
 
    handleModalClose() {
        this.showModal = false;
        this.newName = '';
        this.newStartDate = '';
        this.newStatus = '';
    }
 
    handleCreate() {
        const fields = {};
        fields[NAME_FIELD.fieldApiName] = this.newName;
        fields[STARTDATE_FIELD.fieldApiName] = this.newStartDate;
        fields[STATUS_FIELD.fieldApiName] = this.newStatus;
        fields[PARENT_FIELD.fieldApiName] = this.recordId;
 
        const recordInput = { apiName: CHILD_OBJECT.objectApiName, fields };
        createRecord(recordInput)
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Created',
                    message: 'New record created',
                    variant: 'success'
                }));
                this.handleModalClose();
                return refreshApex(this._wiredResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error creating',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }
 
    handleInputChange(event) {
        const { name, value } = event.target;
        if (name === 'newName') this.newName = value;
        if (name === 'newStartDate') this.newStartDate = value;
        if (name === 'newStatus') this.newStatus = value;
    }
}