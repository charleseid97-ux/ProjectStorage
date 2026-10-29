import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import PROJECT_PRODUCT_CHILD_OBJECT from '@salesforce/schema/ProjectProductChild__c';
import STATUS_FIELD from '@salesforce/schema/ProjectProductChild__c.Status__c';
import getChildren from '@salesforce/apex/ProjectManagementPhaseController.getProjectChildren';
import updateChildren from '@salesforce/apex/ProjectManagementPhaseController.updateProjectChildren';

// FIX-20270: "Project Management Phase" table of the Admin interface tab. Status is edited with the generic datatablePicklist (customPicklist type).
export default class ProjectManagementPhase extends LightningElement {
    @api recordId;
    records = [];
    draftValues = [];
    columns = this.buildColumns([]);
    isLoading = false;

    @wire(getObjectInfo, { objectApiName: PROJECT_PRODUCT_CHILD_OBJECT })
    objectInfo;

    // Active Status values, read from the platform. Columns are built once here (not in a getter): a new columns array on each render would reset the table's draft values after a failed save
    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: STATUS_FIELD })
    wiredStatusValues({ data, error }) {
        if (data) {
            this.columns = this.buildColumns(data.values.map(({ label, value }) => ({ label, value })));
        }
        else if (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    @wire(getChildren, { parentId: '$recordId' })
    wiredChildren({ data, error }) {
        if (data) {
            this.records = this.toRows(data);
        }
        else if (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    buildColumns(statusOptions) {
        return [
            { label: 'Project Product Child Name', fieldName: 'Name', type: 'text' },
            { label: 'Start Date', fieldName: 'StartDate__c', type: 'date-local', editable: true },
            { label: 'End Date', fieldName: 'EndDate__c', type: 'date-local', editable: true },
            { label: 'Completion Rate by Step', fieldName: 'completionRate', type: 'percent', typeAttributes: { maximumFractionDigits: 2 } },
            { label: 'Status', fieldName: 'Status__c', type: 'customPicklist', editable: true, typeAttributes: { options: statusOptions, value: { fieldName: 'Status__c' }, label: 'Status', placeholder: 'Select status', context: { fieldName: 'Id' } } },
            { label: 'Phase Status Indicator', fieldName: 'RAG__c', type: 'text' }
        ];
    }

    handleSave(event) {
        this.isLoading = true;
        updateChildren({ updatedRecords: event.detail.draftValues, parentId: this.recordId })
            .then((data) => {
                this.records = this.toRows(data);
                this.draftValues = [];
            })
            .catch((error) => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // CompletionRateStep__c is stored from 0 to 100, the percent column expects 0 to 1
    toRows(data) {
        return data.map((record) => ({ ...record, completionRate: (record.CompletionRateStep__c ?? 0) / 100 }));
    }

    getErrorMessage(error) {
        return error?.body?.message ?? 'Unexpected error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}