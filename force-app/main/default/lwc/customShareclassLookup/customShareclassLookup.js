import { LightningElement, api, track } from 'lwc';
import getFilteredProjectShareclasses from '@salesforce/apex/ShareclassNavigatorController.getFilteredProjectShareclasses';
import getFilteredReferentialShareclasses from '@salesforce/apex/ShareclassNavigatorController.getFilteredReferentialShareclasses';

export default class CustomShareclassLookup extends LightningElement {
    @api objectApiName;
    @api recordId;

    @track searchTerm = '';
    @track results = [];
    @track noResults = false;
    @track selectedDisplayName = '';
    @track selectedRecordId = null;
    @track showResults = false;

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.selectedDisplayName = this.searchTerm;
        this.selectedRecordId = null;
        this.loadResults();
    }

    loadResults() {
        if (this.objectApiName === 'ProjectShareclass__c') {
            getFilteredProjectShareclasses({ projectChildId: this.recordId, searchTerm: this.searchTerm })
                .then(data => {
                    this.results = data.map(item => ({
                        Id: item.Id,
                        displayName: item.Share_Class_Name__c
                    }));
                    this.showResults = true;
                    this.noResults = (data.length === 0);
                })
                .catch(error => console.error('🚨 Apex Error:', error));
        } else if (this.objectApiName === 'Share_Class__c') {
            getFilteredReferentialShareclasses({ searchTerm: this.searchTerm })
                .then(data => {
                    this.results = data.map(item => ({
                        Id: item.Id,
                        displayName: item.Name
                    }));
                    this.showResults = true;
                    this.noResults = (data.length === 0);
                })
                .catch(error => console.error('🚨 Apex Error:', error));
        }
    }

    selectResult(event) {
        this.selectedRecordId = event.currentTarget.dataset.id;
        this.selectedDisplayName = event.currentTarget.dataset.name;

        this.showResults = false; // Cache les autres résultats après sélection.

        this.dispatchEvent(new CustomEvent('recordselected', { 
            detail: { 
                recordId: this.selectedRecordId, 
                recordName: this.selectedDisplayName 
            } 
        }));
    }
}