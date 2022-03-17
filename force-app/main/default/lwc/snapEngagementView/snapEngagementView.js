import { LightningElement, wire, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { getData } from 'c/utilsEngagmentView'

import disByMonths from '@salesforce/apex/ContactDigitalInteractionUtil.disByMonths';

export default class snapEngagementView extends LightningElement {

    @api recordId
    @api clickedButton

    @track months = [];
    @track mapData = [];
    @track showFilter = false;

    @wire(disByMonths, { contactId: '$recordId', clickedButton: '$clickedButton' })
    disByMonths({ error, data }) {
        if (error) {
            let message = 'Unknown error';
            if (Array.isArray(error.body)) {
                message = error.body.map(e => e.message).join(', ')
            } else if (typeof error.body.message === 'string') {
                message = error.body.message;
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading contact',
                    message,
                    variant: 'error',
                }),
            );
        } else if (data) {
            getData(data, this.months, this.mapData)
            this.error = undefined
        }
    }

    clickFilter() {
        this.showFilter = !this.showFilter
    }
}