import { LightningElement, track, wire, api } from 'lwc';
import getRecordTypes from '@salesforce/apex/RollbackTeamValidationController.getProjectProductChildRecordTypes';
import getTeamPicklistValues from '@salesforce/apex/RollbackTeamValidationController.getTeamPicklistValues';
import rollbackTeamValidation from '@salesforce/apex/RollbackTeamValidationController.rollbackTeamValidation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
 
export default class RollbackTeamValidation extends LightningElement {
    @api recordId;
 
    @track phaseOptions = [];
    @track statusOptions = [
        { label: 'Draft', value: 'Draft' },
        { label: 'Validated', value: 'Validated' }
    ];
    @track teamOptions = [];
    @track selectedPhase = '';
    @track selectedStatus = '';
    @track selectedTeams = [];
 
    connectedCallback() {
        this.loadPhases();
        this.loadTeams();
    }
 
    loadPhases() {
        getRecordTypes()
            .then(data => {
                this.phaseOptions = data.map(rt => ({
                    label: rt.Name,
                    value: rt.DeveloperName
                }));
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load phases', 'error');
                console.error(error);
            });
    }
 
    loadTeams() {
        getTeamPicklistValues()
            .then(data => {
                this.teamOptions = data.map(team => ({
                    label: team,
                    value: team
                }));
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load teams', 'error');
                console.error(error);
            });
    }
 
    handlePhaseChange(event) {
        this.selectedPhase = event.detail.value;
    }
 
    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
    }
 
    handleTeamChange(event) {
        this.selectedTeams = event.detail.value;
    }
 
    handleSave() {
        if (!this.selectedPhase || !this.selectedStatus || this.selectedTeams.length === 0) {
            this.showToast('Error', 'All fields are required', 'error');
            return;
        }
 
        rollbackTeamValidation({
            phase: this.selectedPhase,
            status: this.selectedStatus,
            teams: this.selectedTeams,
            recordId: this.recordId
        })
            .then(() => {
                this.showToast('Success', 'Teams updated successfully', 'success');
                this.resetFields();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to update teams', 'error');
                console.error(error);
            });
    }
 
    resetFields() {
        this.selectedPhase = '';
        this.selectedStatus = '';
        this.selectedTeams = [];
    }
 
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}