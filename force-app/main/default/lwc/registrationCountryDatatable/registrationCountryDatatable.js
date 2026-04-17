import { LightningElement, api, track, wire } from 'lwc';
import getUniqueCountries from '@salesforce/apex/RegistrationCountryDatatableController.getUniqueCountries';

const COLUMNS = [
    { label: 'Country', fieldName: 'countryLabel', type: 'text' },
    { label: 'Registration Status', fieldName: 'registrationStatus', type: 'text' }
];

export default class RegistrationCountryDatatable extends LightningElement {
    @api recordId;
    @track data = [];
    columns = COLUMNS;

    @wire(getUniqueCountries, { productId: '$recordId' })
    wiredCountries({ error, data }) {
        if (data) {
            this.data = data;
        } else if (error) {
            console.error(error);
        }
    }

    get hasData() {
        return this.data && this.data.length > 0;
    }
}