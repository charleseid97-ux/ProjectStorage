import { LightningElement, api, wire, track } from 'lwc';
import{ refreshApex } from '@salesforce/apex';
import getChildren from '@salesforce/apex/ProjectManagementPhaseController.getProjectChildren';
import updateChildren from '@salesforce/apex/ProjectManagementPhaseController.updateProjectChildren';
 
const COLUMNS = [
    { label: 'Project Product Child Name', fieldName: 'Name', type: 'text'},
    { label: 'Start Date', fieldName: 'StartDate__c', type: 'date-local', editable: true },
    { label: 'End Date', fieldName: 'EndDate__c', type: 'date-local', editable: true },
    { label: 'Completion Rate by Step', fieldName: 'CompletionRateStep__c', type: 'number' },
    { label: 'Status', fieldName: 'Status__c', type: 'text', editable: true },
    {
        label: 'Phase Status Indicator',
        fieldName: 'RAG__c',
        type: 'text'
    }
];

export default class ProjectManagementPhase extends LightningElement {
    @api recordId;
    @track records = [];
    @track draftValues = [];
    columns = COLUMNS;
    @api isLoading = false;
 
    @wire(getChildren, { parentId: '$recordId' })
    wiredChildren({ error, data }) {
        if (data) {
            this.records = data.map(rec => ({
                ...rec,
                PhaseStatusIcon: this.getIconFromFormula(rec.RAG__c)
            }));
        } else if (error) {
            console.error(error);
        }
    }

    refreshData(){
        return refreshApex(this.freshData);
    }

    getIconFromFormula(indicator) {
        if (indicator === '✅') return 'utility:check';
        if (indicator === '⚠️') return 'utility:warning';
        if (indicator === '🚨') return 'utility:error';
        return 'utility:dot';
    }
 handleSave(event) {
    this.isLoading = true;
    const updates = event.detail.draftValues;
 
    updateChildren({ updatedRecords: updates, parentId: this.recordId })
        .then((data) => {
            this.records = data.map(rec => ({
                ...rec,
                PhaseStatusIcon: this.getIconFromFormula(rec.RAG__c)
            }));
            this.draftValues = [];
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error updating validation:', error);
            this.isLoading = false;
        });
}
}