import { LightningElement, api, track, wire } from 'lwc';

import insertStrategicNews from '@salesforce/apex/StrategicNewsController.insertStrategicNews';
import getStrategicNewsList from '@salesforce/apex/StrategicNewsController.getStrategicNewsList';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { NavigationMixin } from 'lightning/navigation';

import STRATEGICNEWS_OBJECT from '@salesforce/schema/StrategicNews__c';
import SUBTYPE_FIELD from '@salesforce/schema/StrategicNews__c.Subtype__c';
import TYPE_FIELD from '@salesforce/schema/StrategicNews__c.Type__c';

export default class StrategicNews extends NavigationMixin(LightningElement) {

    @api recordId;
    @api objectname;
    @api keyfieldapiname;
    @api autoselectsinglematchingrecord;
    @api lookupLabel;
    @api invalidOptionChosenMessage;

    @track snRecord = STRATEGICNEWS_OBJECT;

    @track object;
    @track searchKey;

    @track snId;
    @track subtype;
    @track error;
    @track values;

    @track subTypeOptions;
    @track typeOptions;

    @track showProductSelector = false;
    @track switchTo = true;
    @track snList;

    @track columns = [{
        label: 'Strategic News',
        fieldName: 'nameUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'name' } },
        sortable: true, hideDefaultActions: "true"
    }, {
        label: 'Title',
        fieldName: 'title',
        type: 'text',
        sortable: true, hideDefaultActions: "true"
    }, {
        label: 'Type',
        fieldName: 'type',
        type: 'text',
        sortable: true, hideDefaultActions: "true"
    }, {
        label: 'Sub Type',
        fieldName: 'subType',
        type: 'text',
        sortable: true, hideDefaultActions: "true"
    }, {
        label: 'Created Date',
        fieldName: 'createdDate',
        type: 'text',
        sortable: true, hideDefaultActions: "true"
    }];

    // LookUp Products
    @track selectedItemsToDisplay = ''; //to display items in comma-delimited way
    @track values = []; //stores the labels in this array
    @track pIds = []; //stores the ids in this array
    @track isItemExists = false; //flag to check if message can be displayed

    allowedFormats = ['font', 'size', 'bold', 'italic', 'underline', 'strike',
        'list', 'indent', 'align', 'background', 'code', 'code-block'];

    handleSortdata(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(event.detail.fieldName, event.detail.sortDirection);
    }

    sortData(fieldname, direction) {
        let parseData = JSON.parse(JSON.stringify(this.snList));
        let keyValue = (a) => {
            return a[fieldname];
        };
        let isReverse = direction === 'asc' ? 1 : -1;
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            
            return isReverse * ((x > y) - (y > x));
        });
        
        this.snList = parseData;
    }

    @wire(getStrategicNewsList, { accId: '$recordId' })
    wiredStrategicNews({ error, data }) {
        if (data) {
            this.snList = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
        }
    }

    @wire(getObjectInfo, { objectApiName: STRATEGICNEWS_OBJECT })
    strategicNewsInfo;

    @wire(getObjectInfo, { objectApiName: STRATEGICNEWS_OBJECT })
    strategicNewsInfo;

    @wire(getPicklistValues, { recordTypeId: '$strategicNewsInfo.data.defaultRecordTypeId', fieldApiName: SUBTYPE_FIELD })
    subtypeFieldInfo({ data, error }) {
        if (data) this.subTypeFieldData = data;
        if (error) this.error = error;
    }
    @wire(getPicklistValues, { recordTypeId: '$strategicNewsInfo.data.defaultRecordTypeId', fieldApiName: TYPE_FIELD })
    typeFieldInfo({ data, error }) {
        if (data) this.typeOptions = data.values;
        if (error) this.error = error;
    }
    handleTypeChange(event) {
        let key = this.subTypeFieldData.controllerValues[event.target.value];
        this.subTypeOptions = this.subTypeFieldData.values.filter(opt => opt.validFor.includes(key));
        this.snRecord.Type__c = event.detail.value;
        console.log('==> ',event.detail.value);
        this.showProductSelector = event.detail.value === 'PRODUCT/ BUY LIST' ? true : false;
    }

    handleSubTypeChange(event) {
        this.snRecord.Subtype__c = event.detail.value;
    }

    handleShortSubjectDescriptionChange(event) {
        this.snRecord.ShortSubjectDescription__c = event.detail.value;
    }
    handleLongTitleChange(event) {
        this.snRecord.LongTitle__c = event.target.value;
    }
    handleStrategicNewsChange(event) {
        this.snRecord.StrategicNews__c = event.target.value;
    }

    clickSwitch() {
        this.switchTo = !this.switchTo;
    }

    //captures the retrieve event propagated from lookup component
    selectItemEventHandler(event) {
        let args = JSON.parse(JSON.stringify(event.detail.arrItems));
        this.displayItem(args);
    }

    //captures the remove event propagated from lookup component
    deleteItemEventHandler(event) {
        let args = JSON.parse(JSON.stringify(event.detail.arrItems));
        this.displayItem(args);
    }

    //displays the items in comma-delimited way
    displayItem(args) {
        this.values = []; //initialize first
        args.map(element => {
            this.values.push(element.label);
            this.pIds.push(element.value);
        });
        
        this.snRecord.Product_Ids__c = this.pIds.join(';');
        this.isItemExists = (args.length > 0);
        this.selectedItemsToDisplay = this.values.join(', ');
    }

    objSelected(event) {
        let detail = event.detail;
        this.object = detail.object;
        this.searchKey = detail.searchKey;
        this.snRecord.MeetingNote = this.object.Id;
    }

    // This method will display initial text
    get myVal() {
        return  "Source of News:<br/>" +
                "Attendees:<br/>" +
                "Comment:<br/>" +
                "Next Steps:<br/>";
    }

    createRec() {
        this.snRecord.Company__c = this.recordId;
        
        const isInputsCorrect = [...this.template.querySelectorAll('lightning-input')]
            .reduce((validSoFar, inputField) => {
                inputField.reportValidity();
                return validSoFar && inputField.checkValidity();
            }, true);
        const isComboboxCorrect = [...this.template.querySelectorAll('lightning-combobox')]
            .reduce((validSoFar, inputField) => {
                inputField.reportValidity();
                return validSoFar && inputField.checkValidity();
            }, true);
        if (isInputsCorrect || isComboboxCorrect) {
            
            insertStrategicNews({
                sn: this.snRecord
            }).then(result => {
                this.snRecord = {};
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Strategic News created successfully',
                        variant: 'success',
                    }),
                );
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result.Id,
                        objectApiName: 'StrategicNews__c',
                        actionName: 'view'
                    },
                });
            }).catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error creating record',
                        message: error.body.message,
                        variant: 'error',
                    }),
                );
            });
        }
    }
}