import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getKYC from '@salesforce/apex/UTIL_LegalEntity.getKYC';
import createRelatedPartyContactAndRole from '@salesforce/apex/LegalEntityAP01.createRelatedPartyContactAndRole';

import KYC_First_Name from '@salesforce/label/c.KYC_First_Name';
import KYC_Last_Name from '@salesforce/label/c.KYC_Last_Name';
import KYC_Date_of_Birth from '@salesforce/label/c.KYC_Date_of_Birth';
import KYC_Role from '@salesforce/label/c.KYC_Role';
import KYC_Action from '@salesforce/label/c.KYC_Action';

export default class KYCume extends LightningElement {

    @api recordId;
    @api firstName;
    @api lastname;
    @api dateofbirth;
    @api role;
    @track error;
    @track KYCCreatedId;
    @track alldata = [];

    label = {KYC_First_Name,KYC_Last_Name,KYC_Date_of_Birth,KYC_Role,KYC_Action,};

    @wire(getKYC, {recordId: '$recordId'})
    getKYC({error, data }) {
        if (data) {
            let obj = JSON.parse(data);
            obj.forEach(data => {
                this.alldata.push(data);
            })
            this.error = undefined;
        } else if (error) {
            this.error = error;
        }
    }

    handleCreateKYC(event) {
        this.firstName = event.target.value.firstName;
        console.log('firstName:', this.firstName);

        this.lastname = event.target.value.lastName;
        console.log('Lastname:', this.lastname);

        this.dateofbirth = event.target.value.dateOfBirth;
        console.log('Dateofbirth:', this.dateofbirth);
        var multiRole = '';
        for (var key in event.target.value.kycCategories) {
            multiRole += event.target.value.kycCategories[key].name + ';';
        }
        console.log('multiRole:', multiRole);
        this.role = multiRole;

        console.log('selectedRecordId:', this.recordId);

        createRelatedPartyContactAndRole({
                KYCFirstname: this.firstName,
                KYCLastname: this.lastname,
                KYCDateofbirth: this.dateofbirth,
                KYCRole: this.role,
                recordId: this.recordId
        })
        .then(result => {
            console.log('result : ' + result);
            if (result) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: result,
                        variant: 'error'
                    })
                );

            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Record created successfully',
                        variant: 'success'
                    })
                );
                window.location.reload();
            }
        })
        .catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: error,
                    variant: 'error'
                })
            );
        });
    }
}