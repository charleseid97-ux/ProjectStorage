import { LightningElement, api, track, wire } from 'lwc';
import getMilestones from '@salesforce/apex/MilestoneDatatableController.getMilestones';
import getStatusPicklistValues from '@salesforce/apex/MilestoneDatatableController.getStatusPicklistValues';
import updateMilestones from '@salesforce/apex/MilestoneDatatableController.updateMilestones';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { createRecord, deleteRecord } from 'lightning/uiRecordApi';
import MILESTONE_OBJECT from '@salesforce/schema/Milestone__c';
import NAME_FIELD from '@salesforce/schema/Milestone__c.Name';
import STARTDATE_FIELD from '@salesforce/schema/Milestone__c.StartDate__c';
import STATUS_FIELD from '@salesforce/schema/Milestone__c.Status__c';
import PRODUCT_FIELD from '@salesforce/schema/Milestone__c.Project_product__c';
 
const COLUMNS_BASE = [
    { label: 'Name', fieldName: 'Name', type: 'text', editable: false },
    { label: 'Start Date', fieldName: 'StartDate__c', type: 'date-local', editable: true },
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
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Delete', name: 'delete', iconName: 'utility:delete' }] }
    }
];
 
export default class MilestoneDatatable extends LightningElement {
    @api recordId;
    @track data = [];
    @track columns = COLUMNS_BASE;
    @track draftValues = [];
    statusOptions = [];
    _wiredMilestonesResult;
 
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
 
    @wire(getMilestones, { parentId: '$recordId' })
    wiredMilestones(result) {
        this._wiredMilestonesResult = result;
        const { data, error } = result;
        if (data) {
this.data = data.map(row => {
                return {
                    ...row,
                    statusOptions: this.statusOptions
                };
            });
        } else if (error) {
            console.error(error);
        }
    }
 
    handleSave(event) {
        const fields = event.detail.draftValues;
        updateMilestones({ updatedRecords: fields })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Milestones updated',
                    variant: 'success'
                }));
                this.draftValues = [];
                return refreshApex(this._wiredMilestonesResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error updating milestones',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }
 
    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
if (action.name === 'delete') {
deleteRecord(row.Id)
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Milestone deleted',
                        variant: 'success'
                    }));
                    return refreshApex(this._wiredMilestonesResult);
                })
                .catch(error => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error deleting milestone',
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
        fields[PRODUCT_FIELD.fieldApiName] = this.recordId;
 
        const recordInput = { apiName: MILESTONE_OBJECT.objectApiName, fields };
        createRecord(recordInput)
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Milestone created',
                    variant: 'success'
                }));
                this.handleModalClose();
                return refreshApex(this._wiredMilestonesResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error creating milestone',
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