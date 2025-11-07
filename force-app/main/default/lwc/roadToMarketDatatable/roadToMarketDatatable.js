import { LightningElement, api, track } from 'lwc';
import getTasks from '@salesforce/apex/RoadToMarketDatatableController.getTasks';
import getTeamPicklistValues from '@salesforce/apex/RoadToMarketDatatableController.getTeamPicklistValues';
import getStatusPicklistValues from '@salesforce/apex/RoadToMarketDatatableController.getStatusPicklistValues';
import updateTasks from '@salesforce/apex/RoadToMarketDatatableController.updateTasks';
import deleteTask from '@salesforce/apex/RoadToMarketDatatableController.deleteTask';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { createRecord } from 'lightning/uiRecordApi';
import RTM_OBJECT from '@salesforce/schema/RoadToMarket__c';
import NAME_FIELD from '@salesforce/schema/RoadToMarket__c.Name';
import TEAM_FIELD from '@salesforce/schema/RoadToMarket__c.Team__c';
import STATUS_FIELD from '@salesforce/schema/RoadToMarket__c.Status__c';
import DEADLINE_FIELD from '@salesforce/schema/RoadToMarket__c.Deadline__c';
import PARENT_FIELD from '@salesforce/schema/RoadToMarket__c.RoadToMarket__c';
import CriticityColumn from './customCriticity.html';
 
const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text', editable: true },
    {
        label: 'Team', fieldName: 'Team__c', type: 'customPicklist', editable: true,
        typeAttributes: { options: { fieldName: 'teamOptions' }, value: { fieldName: 'Team__c' } }
    },
    { label: 'Description', fieldName: 'Description__c', type: 'text', editable: true },
    { label: 'Contributors', fieldName: 'Contributors__c', type: 'text', editable: true },
    { label: 'Deadline', fieldName: 'Deadline__c', type: 'date-local', editable: true },
    {
        label: 'Status', fieldName: 'Status__c', type: 'customPicklist', editable: true,
        typeAttributes: { options: { fieldName: 'statusOptions' }, value: { fieldName: 'Status__c' } }
    },
    { label: 'Criticity', fieldName: 'Criticity__c', type: 'customCriticity' },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Delete', name: 'delete', iconName: 'utility:delete' }] }
    }
];
 
export default class RoadToMarketDatatable extends LightningElement {
    @api recordId;
    @track columns = COLUMNS;
    @track data = [];
    @track draftValues = [];
    @track teamFilter = '';
    teamOptions = [];
    statusOptions = [];
    _wiredResult;
 
    showModal = false;
    newName = '';
    newTeam = '';
    newDeadline = '';
    newStatus = '';

       static customTypes = {
        customCriticity: {
            template: CriticityColumn,
            typeAttributes: ['value']
        }
    };
 
       get teamOptionsWithAll() {
        return [{ label: 'All', value: '' }, ...this.teamOptions];
    }
 
    connectedCallback() {
        getTeamPicklistValues().then(result => {
this.teamOptions = result.map(val => ({ label: val, value: val }));
        });
        getStatusPicklistValues().then(result => {
this.statusOptions = result.map(val => ({ label: val, value: val }));
        });
        this.loadData();
    }
 
    loadData() {
        getTasks({ parentId: this.recordId, teamFilter: this.teamFilter })
            .then(result => {
this.data = result.map(row => ({
                    ...row,
                    teamOptions: this.teamOptions,
                    statusOptions: this.statusOptions
                }));
            })
            .catch(error => console.error(error));
    }
 
    handleFilterChange(event) {
        this.teamFilter = event.detail.value;
        this.loadData();
    }
 
    handleSave(event) {
        updateTasks({ updatedRecords: event.detail.draftValues })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Tasks updated', variant: 'success' }));
                this.draftValues = [];
                this.loadData();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body.message, variant: 'error' }));
            });
    }
 
    handleRowAction(event) {
        const { action, row } = event.detail;
if (action.name === 'delete') {
deleteTask({ recordId: row.Id })
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({ title: 'Deleted', message: 'Task deleted', variant: 'success' }));
                    this.loadData();
                })
                .catch(error => {
                    this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body.message, variant: 'error' }));
                });
        }
    }
 
    handleNewClick() {
        this.showModal = true;
    }
 
    handleModalClose() {
        this.showModal = false;
        this.newName = '';
        this.newTeam = '';
        this.newDeadline = '';
        this.newStatus = '';
    }
 
    handleCreate() {
        const fields = {};
        fields[NAME_FIELD.fieldApiName] = this.newName;
        fields[TEAM_FIELD.fieldApiName] = this.newTeam;
        fields[DEADLINE_FIELD.fieldApiName] = this.newDeadline;
        fields[STATUS_FIELD.fieldApiName] = this.newStatus;
        fields[PARENT_FIELD.fieldApiName] = this.recordId;
 
        const recordInput = { apiName: RTM_OBJECT.objectApiName, fields };
        createRecord(recordInput)
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Created', message: 'New task created', variant: 'success' }));
                this.handleModalClose();
                this.loadData();
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: error.body.message, variant: 'error' }));
            });
    }
 
    handleInputChange(event) {
        const { name, value } = event.target;
        if (name === 'newName') this.newName = value;
        if (name === 'newTeam') this.newTeam = value;
        if (name === 'newDeadline') this.newDeadline = value;
        if (name === 'newStatus') this.newStatus = value;
    }
}