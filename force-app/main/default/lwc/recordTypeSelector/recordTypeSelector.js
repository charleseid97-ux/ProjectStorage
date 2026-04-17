/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 07-15-2024
 * @last modified by  : SILA Nicolas
**/
// recordTypeSelector.js
import { LightningElement, wire, track } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import CASE_OBJECT from '@salesforce/schema/Case';
import getRecordTypes from '@salesforce/apex/RecordTypeController.getRecordTypes';
import { NavigationMixin } from 'lightning/navigation';

export default class RecordTypeSelector extends NavigationMixin(LightningElement) {

    @track showModal = true;
    @track recordTypeOptions = [];
    @track urlRT;
    @track selectedDescription = '';
    @track recordTypeDescriptions = {};

    @wire(getRecordTypes)
    wiredRecordTypes({ error, data }) {
        if (data) {
            this.recordTypeOptions = data;
            console.log('recordTypeOptions', data);

        } else if (error) {
            console.error('Error fetching record types', error);
        }
    }

    closeModal() {
        window.location = '/lightning/o/Case/list?filterName=__Recent';
    }

    handleRecordTypeChange(event) {
        this.urlRT = event.target.value;
        console.log('urlRT', this.urlRT);

    }

    handleContinue() {
        console.log('urlRT', this.urlRT);

        if (this.urlRT) {

            window.location = this.urlRT;
            
        } else {
            // Handle the case where no record type is selected
            console.error('No record type selected');
            // Optionally, show an error message to the user
        }
    }
}