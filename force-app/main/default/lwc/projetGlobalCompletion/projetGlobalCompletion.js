import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import COMPLETION_RATE_GLOBAL from '@salesforce/schema/ProjectProduct__c.Global_Completion_Rate__c';
import PARENT_END_DATE from '@salesforce/schema/ProjectProduct__c.EndDate__c';
import PARENT_START_DATE from '@salesforce/schema/ProjectProduct__c.ProjectStartDate__c';

import COMPLETION_RATE_STEP from '@salesforce/schema/ProjectProductChild__c.Completion_Rate_Test__c';
import RECORD_TYPE_NAME from '@salesforce/schema/ProjectProductChild__c.RecordType.Name';

import getRecordId from '@salesforce/apex/ProjectChildTeamValidationController.getRecordId';
import getParentDatesFromProductChild from '@salesforce/apex/ProjectGlobalCompletionController.getParentDatesFromProductChild';
import getParentDatesFromShareclassChild from '@salesforce/apex/ProjectGlobalCompletionController.getParentDatesFromShareclassChild';

export default class projetGlobalCompletion extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track currentRecordId;

    @api RemainingProjectDays;
    @api EndDate;
    @api GlobalProjectCompletion;
    percentage = 0;
    title = '';
    showRemainingDays = false;
    progressTitle = '';

    get fields() {
        return this.objectApiName === 'ProjectProduct__c'
            ? [COMPLETION_RATE_GLOBAL, PARENT_START_DATE, PARENT_END_DATE]
            : [COMPLETION_RATE_STEP, RECORD_TYPE_NAME];
    }

    connectedCallback() {
        // Initialiser correctement currentRecordId
        if (this.objectApiName === 'ProjectProduct__c') {
            this.currentRecordId = this.recordId;
        }
    }

    @wire(getRecordId, { currentRecordId: '$recordId' })
    wiredRecordId({ data, error }) {
        if (data) {
            this.currentRecordId = data;
        } else if (error) {
            this.currentRecordId = this.recordId;
            console.error('Error getRecordId:', error);
        }
    }

    @wire(getRecord, { recordId: '$currentRecordId', fields: '$fields' })
    wiredRecord({ data, error }) {
        if (data) {
            this.percentage = this.objectApiName === 'ProjectProduct__c'
                ? Math.round(getFieldValue(data, COMPLETION_RATE_GLOBAL))
                : Math.round(getFieldValue(data, COMPLETION_RATE_STEP));

            if (this.objectApiName === 'ProjectProduct__c') {
                this.title = 'Project Launch Date';
                const start = getFieldValue(data, PARENT_START_DATE);
                const end = getFieldValue(data, PARENT_END_DATE);
                this.calculateRemainingDays(start, end);
                this.EndDate = end;
            } else {
                this.title = getFieldValue(data, RECORD_TYPE_NAME);
                this.progressTitle = 'Phase progress : ';
            }
        } else if (error) {
            console.error('Error wiredRecord:', error);
        }
    }

    @wire(getParentDatesFromProductChild, { childId: '$recordId' })
    wiredParentDatesFromChild({ data, error }) {
        if (data && this.objectApiName === 'ProjectProductChild__c') {
            this.calculateRemainingDays(data.ProjectStartDate__c, data.EndDate__c);
            this.EndDate = data.EndDate__c;
        } else if (error) {
            console.error('Error parent dates ProductChild:', error);
        }
    }

    @wire(getParentDatesFromShareclassChild, { shareclassChildId: '$recordId' })
    wiredParentDatesFromShareclassChild({ data, error }) {
        if (data && this.objectApiName === 'ProjectShareclassChild__c') {
            this.calculateRemainingDays(data.ProjectStartDate__c, data.EndDate__c);
            this.EndDate = data.EndDate__c;
        } else if (error) {
            console.error('Error parent dates ShareclassChild:', error);
        }
    }

    calculateRemainingDays(start, end) {
        const today = new Date();
        const startDate = new Date(start) > today ? new Date(start) : today;
        const endDate = new Date(end);

        if (startDate < endDate) {
            const diff = Math.round((endDate - startDate) / (1000 * 3600 * 24));
            this.RemainingProjectDays = diff;
            this.showRemainingDays = true;
        } else {
            this.RemainingProjectDays = 0;
            this.showRemainingDays = false;
        }
    }

    get progressValue() {
        return `${this.percentage} 100`;
    }

    get displayCurrentPhaseTitle() {
        return this.objectApiName !== 'ProjectProduct__c';
    }
}