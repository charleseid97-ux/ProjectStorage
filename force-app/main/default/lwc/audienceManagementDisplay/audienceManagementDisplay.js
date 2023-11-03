import { LightningElement, wire, track } from 'lwc';
import getContacts from '@salesforce/apex/CTL_AudienceManagement.getContacts';
import getCampaigns from '@salesforce/apex/CTL_AudienceManagement.getCampaigns';
import addToCampaign from '@salesforce/apex/CTL_AudienceManagement.addToCampaign';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import amQuery from "@salesforce/messageChannel/audienceManagementQuery__c";

//Columns to display
const columns = [
    { label: 'First Name', fieldName: 'FirstName', sortable: "true"},
    { label: 'Last Name', fieldName: 'LastName', sortable: "true" },
    { label: 'Company Name', fieldName: 'AccountName', sortable: "true"},
    { label: 'Professional Email', fieldName: 'Email', sortable: "true"}
];

//Columns for the export
const columnsExport = [
    { label: 'First Name', fieldName: 'FirstName', sortable: "true"},
    { label: 'Last Name', fieldName: 'LastName', sortable: "true" },
    { label: 'Company Name', fieldName: 'AccountName', sortable: "true"},
    { label: 'Professional Email', fieldName: 'Email', sortable: "true"},
    { label: 'Phone', fieldName: 'Phone', sortable: "true"}
]

export default class AudienceManagementDisplay extends LightningElement {
    subscriptionQuery = null;

    showSpinner = false;
    showSpinnerCampaign = false;
    showAddToCampaignModal = false;
    addButtonDisabled = true;

    //List of parameters for the campaign lookup
    @track allCampaigns;
    @track mapCampaigns = {};
    @track selectedCampaign;

    page = 1; //initialize 1st page
    items = []; //contains all the records.
    data = []; //data  displayed in the table
    columns = columns; //holds column info.
    startingRecord = 1; //start record position per page
    endingRecord = 0; //end record position per page
    pageSize = 200; //default value we are assigning
    totalRecountCount = 0; //total record count received from all retrieved records
    totalPage = 1; //total number of page is needed to display all records
    selectedRows = [];
    @track sortBy;
    @track sortDirection;

    //Parameter for the Select all contacts button
    allSelected = false;

    @wire(MessageContext)
    MessageContext;

    //Retrieves all campaign on load
    @wire(getCampaigns, {})
    campaigns({data,error}) {
        if(data && data.length){ 
            let campaigns =[];
            let mapCampaigns = {};
            data.forEach(campaign =>{
                campaigns.push({label:campaign.Name,value:campaign.Id});
                mapCampaigns[campaign.Id] = campaign;
            });
            this.allCampaigns = [...campaigns];
            this.mapCampaigns = mapCampaigns;
        }
        else if(error)
        {
            console.log('@err getCampaigns:',error);
        }
    }

    //Subscribes to the message channel audience Management Query
    subscribeToMessageChannel() {
        if(!this.subscriptionQuery) {
            this.subscriptionQuery = subscribe(this.MessageContext, amQuery, (message) => this.handleQueryMessage(message));
        }
    }

    //Unsubscribe to the message channel Audience Management Query
    unsubscribeToMessageChannel() {
        unsubscribe(this.subscriptionQuery);
        this.subscriptionQuery = null;
    }

    //Retrieves the list of contact when receiving a new Audience Management Query via the message channel
    handleQueryMessage(message) {
        console.log('new query : ' + message.query);
        this.getContactsList(message.query);
    }

    connectedCallback() {
        this.subscribeToMessageChannel();
        // this.getContactsList('');
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    //Retrieves the contacts based on the query and initializes the datatable with these records
    getContactsList(query) {
        this.showSpinner = true;
        getContacts ({request: query})
        .then(data => {
            this.items = data.map(
                row => { return {...row, AccountName: row.Account.Name}}
            );
            this.totalRecountCount = data.length;
            this.totalPage = Math.ceil(this.totalRecountCount / this.pageSize);
            //here we slice the data according page size
            this.data = this.items.slice(0, this.pageSize);
            this.endingRecord = this.pageSize;
            this.columns = columns;
            this.error = undefined;

            //Scrolls the page to the datatable
            const datatable = this.template.querySelector('[data-id="datatable"');
            const y = datatable.getBoundingClientRect().top - 200;
            window.scrollTo({top: y, behavior:'smooth'});
        })
        .catch(error => {
            this.error = error;
            this.data = undefined;
            var errorStr = error.body.message;
            //User friendly error message if the result of the query is over 50000 records
            if(errorStr.includes('Too many rows')) {
                errorStr = 'Your query is too large, please add filters.';
            }
            this.showToast(errorStr, 'Error', 'Error'); //show toast for error
        })
        .finally(() => {
            this.showSpinner = false;
        })
    }
    
    //press on previous button this method will be called
    previousHandler() {
        if (this.page > 1) {
            this.page = this.page - 1;
            this.displayRecordPerPage(this.page);
        }
    }
    
    //press on next button this method will be called
    nextHandler() {
        if ((this.page < this.totalPage) && this.page !== this.totalPage) {
            this.page = this.page + 1;
            this.displayRecordPerPage(this.page);
        }
    }

    //return if current page is the first one
    get isFirstPage() {
        return this.page === 1;
    }

    //return if current page is the last one
    get isLastPage() {
        return this.page === this.totalPage;
    }
    
    //this method displays records page by page
    displayRecordPerPage(page) {
        this.startingRecord = ((page - 1) * this.pageSize);
        this.endingRecord = (this.pageSize * page);
        this.endingRecord = (this.endingRecord > this.totalRecountCount)
            ? this.totalRecountCount : this.endingRecord;
        this.data = this.items.slice(this.startingRecord, this.endingRecord);
        //increment by 1 to display the startingRecord count, 
        //so for 2nd page, it will show "Displaying 6 to 10 of 23 records. Page 2 of 5"
        this.startingRecord = this.startingRecord + 1;
        this.template.querySelector('[data-id="datatable"]').selectedRows = this.selectedRows;
    }

    handleRowSelection(event) {
        let updatedItemsSet = new Set();
        // List of selected items we maintain.
        let selectedItemsSet = new Set(this.selectedRows);
        // List of items currently loaded for the current view.
        let loadedItemsSet = new Set();
        this.data.map((ele) => {
            loadedItemsSet.add(ele.Id);
        });
        if (event.detail.selectedRows) {
            event.detail.selectedRows.map((ele) => {
                updatedItemsSet.add(ele.Id);
            });
            // Add any new items to the selectedRows list
            updatedItemsSet.forEach((id) => {
                if (!selectedItemsSet.has(id)) {
                    selectedItemsSet.add(id);
                }
            });
        }
        loadedItemsSet.forEach((id) => {
            if (selectedItemsSet.has(id) && !updatedItemsSet.has(id)) {
                // Remove any items that were unselected.
                selectedItemsSet.delete(id);
            }
        });
        this.selectedRows = [...selectedItemsSet];
    }

    handleSelectAll() {
        let updatedItemsSet = new Set();
        // List of selected items we maintain.
        let selectedItemsSet = new Set(this.selectedRows);
        this.items.map((ele) => {
            updatedItemsSet.add(ele.Id);
        });
        // Add any new items to the selectedRows list
        updatedItemsSet.forEach((id) => {
            if (!selectedItemsSet.has(id)) {
                selectedItemsSet.add(id);
            }
        });
        this.selectedRows = [...selectedItemsSet];
        this.allSelected = true;
    }

    handleUnselectAll() {
        this.selectedRows = [];
        this.allSelected = false;
    }

    get noContacts() {
        return this.items.length == 0;
    }

    //Retrieves the column and the direction to sort by and call the sorting method 
    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortBy, this.sortDirection);
    }

    //Orders the data depending on the sort direction 
    sortData(fieldname, sortDirection) {
        let sortResult = Object.assign([], this.items);
        this.items = sortResult.sort(function(a,b) {
            if(a[fieldname] < b[fieldname]) {
                return (sortDirection === 'asc' ? -1 : 1);
            }
            else if(a[fieldname] > b[fieldname]) {
                return (sortDirection === 'asc' ? 1 : -1);
            }
        })
        
        //Sets the datatable to the first page
        this.page = 1;
        this.displayRecordPerPage(1);
    }

    //Open the campaign selection modal
    openAddToCampaign() {
        if(this.selectedRows.length > 0) {
            this.showAddToCampaignModal = true;
        } else {
            this.showToast('Please select contacts to add to the campaign first.', 'No contact selected', 'WARNING');
        }
    }

    closeAddToCampaign() {
        this.showAddToCampaignModal = false;
    }

    //Adds the selected contacts to the selected campaign
    handleAddToCampaign() {
        this.showSpinnerCampaign = true;
        addToCampaign({campaignId: this.selectedCampaign.id, contactIds: this.selectedRows})
        .then(result => {
            //Different messages if the treatment is done synchronously or asynchronously
            if(result === 'ENQUEUED') {
                this.showToast('Due to the amount of contacts, the task will be treated in the background. You will be notified when the treatment is finished.', 'WARNING', 'WARNING');
            } else {
                this.showToast('The selected contacts have been added to the following campaign : {1}', 'SUCCESS', 'SUCCESS', ['Salesforce', {url: '/'+this.selectedCampaign.id, label:result}]);
            }
        })
        .catch(error => {
            var errorStr = error.body.message;
            //User friendly error message if a contact was already a campaign member of the selected campaign
            if(errorStr.includes('DUPLICATE_VALUE')) {
                errorStr = 'At least one of the selected contact is already in the campaign.'
            }
            this.showToast(errorStr, 'Error', 'Error');
        })
        .finally( () => {
            this.closeAddToCampaign();
            this.showSpinnerCampaign = false;
        })
    }

    handleSelectedCampaign(event) {
        var campaign = this.mapCampaigns[event.detail.selectedValues];
        if(campaign) {
            this.selectedCampaign = {id:event.detail.selectedValues, name:campaign.Name};
            this.addButtonDisabled = this.selectedCampaign ? false : true;
        }

        //construct Pills part 
        var campaign = this.mapCampaigns[event.detail.selectedValues];
        if(campaign) {
            this.selectedCampaign = {id:event.detail.selectedValues, name:campaign.Name};
            this.addButtonDisabled = this.selectedCampaign ? false : true;
        }
    }

    handleRemoveSelectedCampaign() {
        this.selectedCampaign = null;
        this.addButtonDisabled = this.selectedCampaign ? false : true;
    }

    // exports the table as csv
    handleExport() { 
        // Prepare a csv
        let doc = '';
       
        // Adds the header columns
        columnsExport.forEach(element => {
            if(doc == '') {
                doc += element.label;
            } else {
                doc+= ',' + element.label;
            }        
        });
        doc += '\n';
        // Add the data rows
        this.items.forEach(record => {
            doc += '\'' + record.FirstName + '\''; 
            doc += ',\'' + record.LastName + '\'';
            doc += ',\'' + record.Account.Name + '\''; 
            doc += ',\'' + record.Email + '\''; 
            doc += ',\'' + record.Phone + '\''; 
            doc += '\n';
        });
        // Creates the doc and starts the download
        var element = 'data:text/csv;charset=utf-8,' + encodeURIComponent(doc);
        let downloadElement = document.createElement('a');
        downloadElement.href = element;
        downloadElement.target = '_self';
        const currentDate = new Date();
        const dateStr = currentDate.toISOString().substring(0,currentDate.toISOString().lastIndexOf('.')).replaceAll('-', '').replaceAll(':', '').replace('T', '_');
        downloadElement.download = 'ContactExtract_' + dateStr + '.csv';
        document.body.appendChild(downloadElement);
        downloadElement.click();
    }

    showToast(message, variant, title) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }

    showToast(message, variant, title, messageData) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable',
            messageData: messageData
        });
        this.dispatchEvent(event);
    }
}