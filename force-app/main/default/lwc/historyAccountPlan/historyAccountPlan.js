import { LightningElement, wire, track, api } from 'lwc';

import getHistoryAccountPlan from '@salesforce/apex/HistoryAccountPlan.getHistoryAccountPlan';

// Datatable Columns
const columns = [
    {
        label: 'Field',
        fieldName: 'field',
        type: 'text', sortable: "true", hideDefaultActions: "true"
    }, {
        label: 'Name',
        fieldName: 'objName',
        type: 'text', sortable: "true", hideDefaultActions: "true"
    }, {
        label: 'Old Value',
        fieldName: 'oldValue',
        type: 'text', sortable: "true", hideDefaultActions: "true"
    }, {
        label: 'New Value',
        fieldName: 'newValue',
        type: 'text', sortable: "true", hideDefaultActions: "true"
    }, {
        label: 'Modify By',
        fieldName: 'modifyBy',
        type: 'text', sortable: "true", hideDefaultActions: "true"
    }, {
        label: 'Updated Date',
        fieldName: 'createdDate',
        type: 'text', sortable: "true", hideDefaultActions: "true"
    }
];


export default class HistoryAccountPlan extends LightningElement {
    @api recordId

    @track error;
    @track apList;

    @track columns = columns;

    @wire(getHistoryAccountPlan, { apId: '$recordId' })
    opp({ error, data }) {

        if (data) {
            this.apList = data;
        }
        else if (error) {
            window.console.log(error);
        }
    }

    handleSortdata(event) {
        // field name
        this.sortBy = event.detail.fieldName;

        // sort direction
        this.sortDirection = event.detail.sortDirection;

        // calling sortdata function to sort the data based on direction and selected field
        this.sortData(event.detail.fieldName, event.detail.sortDirection);
    }

    sortData(fieldname, direction) {
        // serialize the data before calling sort function
        let parseData = JSON.parse(JSON.stringify(this.apList));

        // Return the value stored in the field
        let keyValue = (a) => {
            return a[fieldname];
        };

        // cheking reverse direction 
        let isReverse = direction === 'asc' ? 1 : -1;

        // sorting data 
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : ''; // handling null values
            y = keyValue(y) ? keyValue(y) : '';

            // sorting values based on direction
            return isReverse * ((x > y) - (y > x));
        });

        // set the sorted data to data table data
        this.apList = parseData;

    }
}