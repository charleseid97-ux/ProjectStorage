/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 18-02-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';

//Lightning Imports
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import CONTACT_SYNCHRO_FIELD from '@salesforce/schema/Contact.Synchrostatus__c';
import CONTACT_WEBSITEID_FIELD from '@salesforce/schema/Contact.TECH_WebSiteID__c';
import contactNotSynchronizedMSG from '@salesforce/label/c.PreferenceCenter_Contact_Not_Sync';

//import Apex Methods
import getTooglesValues from '@salesforce/apex/ProspaceAlertsController.getTooglesValues';
import subscriptionAlertPublication from '@salesforce/apex/ProspaceAlertsController.subscriptionAlertPublication';
import desactiveProspaceAlertType from '@salesforce/apex/ProspaceAlertsController.desactiveProspaceAlertType';

export default class prospaceAlerts extends LightningElement {
    @api recordId;
    counter = 0;
    
    
    @track navs = [];
    @track reports = [];
    @track performances = [];
    @track funds = [];
    @track holdings = [];
    @track publications = [];
    @track regularities = [];
    @track wiredProspaceAlerts = [];

    @api get showSpinner(){
        return this.isLoading;
    }

    fundOnly = false;
    isPerformance = false;
    isLoading = true;
    isModalDisplayed = false;
    modalTitle;
    alertType;
    hasRenderedOnce = false;

    customLabelsReference = {
        contactNotSynchronizedMSG
    }

    @wire(getRecord, {recordId: '$recordId', fields: [CONTACT_SYNCHRO_FIELD, CONTACT_WEBSITEID_FIELD]})
    contact;

    get contactNotSynchronised() {
        return getFieldValue(this.contact.data, CONTACT_SYNCHRO_FIELD) !== 'Success'
            && (getFieldValue(this.contact.data, CONTACT_WEBSITEID_FIELD) === null
            || getFieldValue(this.contact.data, CONTACT_WEBSITEID_FIELD) === undefined);
    }

    @wire(getTooglesValues, {recordId: '$recordId'})
    wiredToggles(result) {
        this.isLoading = true;
        this.navs = [];
        this.reports = [];
        this.performances = [];
        this.funds = [];
        this.holdings = [];
        this.publications = [];
        this.regularities = [];
        this.wiredProspaceAlerts = result;
        if (result.data) {
            let arr;
            JSON.parse(result.data).forEach(element => {
                console.log(element.checkboxValue);
                arr = element.checkboxCategory === 'Nav' ? this.navs : element.checkboxCategory === 'Report' ? this.reports : element.checkboxCategory === 'Performance' ? this.performances : element.checkboxCategory === 'Fund' ? this.funds : element.checkboxCategory === 'Holdings' ? this.holdings : element.checkboxCategory === 'Regularity' ? this.regularities : this.publications;
                arr.push({
                    checkboxLabel: element.checkboxLabel,
                    checkboxAPI: element.checkboxAPI,
                    checkboxValue: element.checkboxValue,
                    checkboxWebsiteId: element.checkboxWebsiteId
                });
            });
        }
        else if (result.error) {
            console.log(result.error);
            this.showNotification(result.error, 'error');
        }
        this.isLoading = false;
    }

    editSubscriptions(event) {
        if(event.target.title == 'Fund' || event.target.title == 'Holdings'){
            this.fundOnly = true;
            this.isPerformance = false;
            this.modalTitle = event.target.name ;
        }else if(event.target.title == 'Performance'){
            this.isPerformance = true;
            this.fundOnly = false;
            this.modalTitle = event.target.name;
        }else{
            this.isPerformance = false;
            this.fundOnly = false;
            this.modalTitle = event.target.title + ' Subscription';
        }
        this.isModalDisplayed = true;
        
        this.alertType = event.target.title;
        this.counter += 1;
    }

    openModal(event) {
        if (event.target.checked) {
            this.editSubscriptions(event);
        }
        else {
            console.log('id : '+event.target.value)
            this.deactivateAllProspaceAlert(event.target.value, event.target.name);            
        }
        refreshApex(this.wiredProspaceAlerts);
    }

    async deactivateAllProspaceAlert(alertTypeValue, toggleName) {
        let isSelectionConfirmed = await LightningConfirm.open({
            message: "Do you want to remove all subscriptions?",
            theme: "warning",
            variant: "headerless",
        });
        if (isSelectionConfirmed) {
            this.isLoading = true;
            console.log('Record: ' + this.recordId + ' alertType: ' + alertTypeValue);
            desactiveProspaceAlertType({recordId: this.recordId, alertType: alertTypeValue})
                .then(result => {
                    console.log(result);
                    this.showNotification('Subscription Deleted', 'The subscriptions has successfully been deleted', 'success');
                    eval("$A.get('e.force:refreshView').fire();");
                    
                })
                .catch(error => {
                    console.log(error);
                    this.showNotification('Subscription Not Deleted', 'An error occured while deleting your subscriptions. Please try again.', 'error');
                })
                .finally(() => {
                    refreshApex(this.wiredProspaceAlerts);
                    this.isLoading = false;
                });
        }
        else {
            let elm = this.template.querySelector("lightning-input[data-id='" + alertTypeValue + "']");
            elm.checked = true;
        }
    }

    closeModal() {
        refreshApex(this.wiredProspaceAlerts);
        this.checkToggleValues();
        this.isModalDisplayed = false;
        this.modalTitle = '';
        this.alertType = '';
        this.isLoading = false;
    }

    checkToggleValues() {
        this.navs.forEach(element => {
            let elm = this.template.querySelector("lightning-input[data-id='" + element.checkboxWebsiteId + "']");
            elm.checked = element.checkboxValue;
        });
        this.reports.forEach(element => {
            let elm = this.template.querySelector("lightning-input[data-id='" + element.checkboxWebsiteId + "']");
            elm.checked = element.checkboxValue;
        })
    }

    handleSaveSubscriptions() {
        this.isLoading = true;
        let getSearch = this.template.querySelector("c-search-subscription-product");
        if (getSearch) {
            getSearch.handleSaveSubscriptions();
        }
        this.isLoading = false;
    }

    subscriptionsSaved(event) {
        this.closeModal();
    }

    handleSavePublication(event) {
        console.log(event.target);
        this.isLoading = true;
        subscriptionAlertPublication({recordId: this.recordId, alertType: event.target.value, checked: event.target.checked})
            .then(() => {
                this.showNotification('Subscription Updated', 'The subscription was successfully updated', 'success');
            })
            .catch(() => {
                this.showNotification('Subscription Not Updated', 'An error occured while updating your subscriptions. Please try again.', 'error');
            })
            .finally(() => {
                refreshApex(this.wiredProspaceAlerts);
                this.isLoading = false;
            });
    }

    //Description : Displays a notification/toast
    showNotification(toastTitle, toastMessage, toastVariant) {
        const toastEvent = new ShowToastEvent({
            title: toastTitle,
            message: toastMessage,
            variant: toastVariant, //Possible Values : info(default), success, warning, and error.
        });
        this.dispatchEvent(toastEvent);
    }
}