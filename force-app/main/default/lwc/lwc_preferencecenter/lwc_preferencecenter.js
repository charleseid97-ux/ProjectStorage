/*
    Author : Noor Goolamnabee 
    Date : 07/07/2022
    Description :  Preference Center /  Communication Preference
    Referenced In : Contact's Record Page under Preference Center Tab
    APEX Controller : PreferenceCenterController
*/
import { LightningElement, wire, track, api } from 'lwc';
//Lightning Imports
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

//Salesforce APEX Imports
import { refreshApex } from '@salesforce/apex';
import getAlertTypesWithProspaceAlert from '@salesforce/apex/PreferenceCenterController.getAlertTypesWithProspaceAlert';
//DML Methods Imports
import createProspaceAlerts from '@salesforce/apex/PreferenceCenterController.createProspaceAlerts';
import deleteProspaceAlerts from '@salesforce/apex/PreferenceCenterController.deleteProspaceAlerts';
//BULK DML Methods
import createAllProspaceAlerts from '@salesforce/apex/PreferenceCenterController.createAllProspaceAlerts';
import deleteAllProspaceAlerts from '@salesforce/apex/PreferenceCenterController.deleteAllProspaceAlerts';
//Marketing Emails Methods Imports
import getContactInfo from '@salesforce/apex/PreferenceCenterController.getContactInfo';
import generateCommunicationTypesJSON from '@salesforce/apex/PreferenceCenterController.generateCommunicationTypesJSON';
import generateInterestsMAP from '@salesforce/apex/PreferenceCenterController.generateInterestsMAP';
//DML Methods
import optOutOfEmailsContact from '@salesforce/apex/PreferenceCenterController.optOutOfEmailsContact';
import updateContactCommunicationTypes from '@salesforce/apex/PreferenceCenterController.updateContactCommunicationTypes';
import updateInterests from '@salesforce/apex/PreferenceCenterController.updateInterests';
import updateMainInterestOnly from '@salesforce/apex/PreferenceCenterController.updateMainInterestOnly';
// Import custom labels
import duplicateSubscriptionMsg from '@salesforce/label/c.PreferenceCenter_Duplicate_Subscription_Msg';
import generalErrorMsg from '@salesforce/label/c.PreferenceCenter_General_Error_Msg';
import subcriptionCreationMsg from '@salesforce/label/c.PreferenceCenter_Subscription_Creation_Msg';
import subscriptionsCreationConfirmMsg from '@salesforce/label/c.PreferenceCenter_Subscriptions_Creation_Confirmation_Msg';
import allSubscriptionsCreationMsg from '@salesforce/label/c.PreferenceCenter_Subscriptions_Creation_Msg';
import subscriptionDeletionMsg from '@salesforce/label/c.PreferenceCenter_Subscription_Deletion_Msg';
import subscriptionsDeletionConfirmMsg from '@salesforce/label/c.PreferenceCenter_Subscriptions_Deletion_Confirmation_Msg';
import allSubscriptionsDeletionMsg from '@salesforce/label/c.PreferenceCenter_Subscriptions_Deletion_Msg';
import subscriptionUpdateMessage from '@salesforce/label/c.PreferenceCenter_Subscription_Update_Msg';
import contactNotSynchronizedMSG from '@salesforce/label/c.PreferenceCenter_Contact_Not_Sync';

export default class Lwc_preferencecenter extends LightningElement {
    @api recordId; // :- Obtaining the Contact Id from the Contact Record Page
    //START  : Event Related Variables
    inputValFromCriteriaCom; // :- Stores the value obtained from the Share Class Lookup Input Field value change
    //END  : Event Related Variables
    //START :  Server Initialized Variables -----------
    alertTypesArr = []; // :- Stores the Alert Types for the Toggle Buttons
    existingProspaceAlertsArr = []; // :- Stores Prospace ALerts related to the Contact
    @track newProspaceAlertsArr = []; // :- Stores the existing Prospace Alerts to display when the appropriate Alert Type Toggle Button is selected. 
    communicationTypesArr = []; // :- MARKETING EMAIL SECTION : Contains list of Communication Types
    @track interestsMainsArr = []; // :- MARKETING EMAIL SECTION : Contains list of Interests Main Titles
    interestsSubsidiariesArr = []; // :- MARKETING EMAIL SECTION : Contains list of Interests' Subsidiaries
    //END : Server Initialized Variables -------------
    //START : Variable related to the Modal/PopUp --------
    isModalDisplayed = false; // :- Displays the Modal/PopUp
    modalTitle; // :- Displays the Alert Type Name in the Modal/PopUp Header Section
    isEmptyState = true; // :- Responsible for the Empty State of Share Classes and Funds
    isSpinnerLoading = false; // :- Displays the Lightning Spinner Animation
    @track clearShareClassLookup = false; // :- Indicates whether to empty the Lookup field value for the Filter Criteria Component
    @track fundIdToCascadeDown; // :- Fund Id to pass down to the Filter Criteria Child Component 
    //Marketing Email Section
    isInterestDisplayed = false; // :- MARKETING EMAIL SECTION : Handles the Interests Modal/PopU display 
    isInterestLoading = false; // :- MARKETING EMAIL SECTION : Handles the loading of Interests when saving
    @track interestsCheckboxList = []; // :- MARKETING EMAIL SECTION : Contains list of Interests' Subsidiaries to filter in the Modal
    @track mainInterestsObjArr = []; // :- MARKETING EMAIL SECTION : Contains list of Main Interests and their values to send to APEX
    //END : Variable related to the Modal/PopUp --------
    //START : Component Attributes
    selectedAlertTypeId; // :- Stores the ALert Type Id from the Toggle Buttons for Prospace Alert Assignment
    allAlertTypesIDsArr = []; // :- Stores the IDs for all the Alert Types displayed in the Prospace Alert Section
    isAlertTypesArrayInitialized = false; // :- Handles the Prospace Alerts Section's visibilty
    isChooseAllToggleSelected = false; // :- Handles the Choose All Toggle Button's selection status
    isChooseAllLoading = false; // :- Handles the display of the spinner when Choose All Toggle Button is changed
    isOptOutLoading = false; // :- MARKETING EMAIL SECTION : Handles Loading when Opt Out Toggle is changed
    isCommunicationTypeLoading = false; // :- MARKETING EMAIL SECTION : Handles Communication Types Loading
    isMainInterestLoading = false; // :- MARKETING EMAIL SECTION : Handles Main Interests Loading
    //END : Component Attributes
    //START :Custom Labels Reference
    customLabelsReference = {
        contactNotSynchronizedMSG
    }
    //END : Custom Labels Reference
    //START : Component Lifecycle Methods
    //The Component's Constructor is executed when the Component is loaded.
    constructor() {
        super();
        //Adding Event Listener for the Filter Criteria Component's Events
        this.template.addEventListener('Lookup_InputField_Value_Change_Event', event => {
            this.inputValFromCriteriaCom = event.detail; // :- Input value from the Share Class Lookup Field
        });
    }
    //END : Component Lifecycle Methods
    //START : APEX Methods ---------------------------------------------
    //Start : Wire Methods -----------------
    //Description : Returns a JSON String of Alert Types and Prospace Alert
    @wire(getAlertTypesWithProspaceAlert, { contactId: '$recordId' })
    wiredgetAlertTypesWithProspaceAlert({ error, data }) {
        if (data) {
            //Separating the Alert Types List and Prospace Alert List after Converting the serialized JSON String from APEX to a JSON Object
            this.alertTypesArr = JSON.parse(data).alertTypeStructureList;
            this.existingProspaceAlertsArr = JSON.parse(data).prospaceAlertList;
            this.isAlertTypesArrayInitialized = JSON.parse(data).alertTypeStructureList.length > 0 ? true : false;
            //Checking if Prospace Alerts have been created for all Alert Types
            const isProspaceAlertCreated = this.alertTypesArr.every(alertTypeObj => {
                if (alertTypeObj.prospaceAlertCreated === true) {
                    return true;
                } else {
                    return false;
                }
            });
            this.isChooseAllToggleSelected = isProspaceAlertCreated;
        } else if (error) {
            this.showErrorNotification(error, 'wiredgetAlertTypesWithProspaceAlert');
        }
    }
    //Description : Returns the list of Alert Types and Prospace Alerts without any front-end data modification for APEX Refresh when creating/deleting Prospace Alerts
    @wire(getAlertTypesWithProspaceAlert, { contactId: '$recordId' })
    getAlertTypesWithProspaceAlertCacheUpdate;
    //End : Wire Methods -----------------
    //Start : Imperative Methods ----------
    //Description : Creates a new Prospace Alert when the Add button is clicked in the Modal/PopUp
    addProspaceAlert() {
        //Getting the Fund Lookup Field value from the DOM directly
        let fundSearchVal = this.template.querySelector('div[data-id="fund_input_container"]').firstChild.value;
        this.isSpinnerLoading = true;
        createProspaceAlerts({ contactId: this.recordId, alertTypeId: this.selectedAlertTypeId, fundId: fundSearchVal, shareClassId: this.inputValFromCriteriaCom, isPublication: false })
            .then(result => {
                this.isSpinnerLoading = false;
                //Setting the Empty State to False
                this.isEmptyState = false;
                //Checking if record has been created in the database
                if (result) {
                    this.showNotification(subcriptionCreationMsg, '', 'success');
                    //Clearing the LookUp Fields' values after the creation of a Prospace Alert 
                    this.clearShareClassLookup = true;
                    this.template.querySelector('div[data-id="fund_input_container"]').firstChild.value = "";
                    //START : Cache Refresh
                    //Refreshes the Wired Cache to obtain the newly created Prospace Alerts and display them on the modal/PopUp as they are added
                    refreshApex(this.getAlertTypesWithProspaceAlertCacheUpdate).then(() => {
                        this.refreshProspaceAlerts("", true);
                        //Enabling the Delete All Button when the new Prospace Alerts List starts getting populated
                        if (this.newProspaceAlertsArr.length > 0) {
                            this.template.querySelector('div[data-id="modal_buttons_container"]').children[1].disabled = false;
                        }
                    });
                    //END : Cache Refresh
                } else {
                    this.showNotification(duplicateSubscriptionMsg, '', 'warning');
                }
            })
            .catch(error => {
                if (this.isSpinnerLoading) { this.isSpinnerLoading = false; }
                this.showErrorNotification(error, 'addProspaceAlert');
            });
    }
    //Description : Deletes existing Prospace Alerts when the delete button is selected in the Modal/PopUp
    removeProspaceAlert(event) {
        this.isSpinnerLoading = true;
        deleteProspaceAlerts({ prospaceAlertId: event.target.value, alertTypeId: "", isPublication: false })
            .then(result => {
                if (result) {
                    this.isSpinnerLoading = false;
                    this.showNotification(subscriptionDeletionMsg, '', 'success');
                    //START : Cache Refresh
                    //Refreshing the Wired Cache to obtain the updated Prospace alerts and display them on the modal as they are deleted
                    refreshApex(this.getAlertTypesWithProspaceAlertCacheUpdate).then(() => {
                        this.refreshProspaceAlerts("", true);
                        //Disabling the Delete All Button when the new Prospace Alerts is Empty. 
                        if (this.newProspaceAlertsArr.length < 1) {
                            this.template.querySelector('div[data-id="modal_buttons_container"]').children[1].disabled = true;
                            this.isEmptyState = true;
                        } else {
                            this.isEmptyState = false;
                        }
                    });
                    //END : Cache Refresh
                }
            }).catch(error => {
                if (this.isSpinnerLoading) { this.isSpinnerLoading = false; }
                this.showErrorNotification(error, 'removeProspaceAlert');
            });
    }
    //Description : Adds all Prospace Alerts for all Alerts Types
    addAllProspaceAlerts(alertTypesIDsArray, isOperationInModalPopUp) {
        this.isChooseAllLoading = isOperationInModalPopUp ? false : true;
        this.isSpinnerLoading = isOperationInModalPopUp ? true : false;
        createAllProspaceAlerts({ recordId: this.recordId, selectedAlertTypesList: isOperationInModalPopUp ? [this.selectedAlertTypeId] : alertTypesIDsArray })
            .then(result => {
                this.showNotification(allSubscriptionsCreationMsg, '', 'success');
                if (isOperationInModalPopUp) {
                    this.isSpinnerLoading = false;
                    this.isEmptyState = this.isEmptyState ? false : true;
                } else {
                    this.isChooseAllLoading = false;
                }
                refreshApex(this.getAlertTypesWithProspaceAlertCacheUpdate).then(() => {
                    if (isOperationInModalPopUp) {
                        this.refreshProspaceAlerts("", true);
                        if (this.newProspaceAlertsArr.length > 0) {
                            //Disabling the Add All button in the modal
                            this.template.querySelector('div[data-id="modal_buttons_container"]').children[0].disabled = true;
                            //Enabling the Delete All button in the modal
                            this.template.querySelector('div[data-id="modal_buttons_container"]').children[1].disabled = false;
                        }
                    }
                });
            })
            .catch(error => {
                this.showErrorNotification(error, 'addAllProspaceAlerts');
            });
    }
    //Description : Deletes all Prospace Alerts for all Alerts Types
    removeAllProspaceAlerts(alertTypesIDsArray, isOperationInModalPopUp) {
        this.isChooseAllLoading = isOperationInModalPopUp ? false : true;
        this.isSpinnerLoading = isOperationInModalPopUp ? true : false;
        deleteAllProspaceAlerts({ recordId: this.recordId, selectedAlertTypesList: isOperationInModalPopUp ? [this.selectedAlertTypeId] : alertTypesIDsArray })
            .then(result => {
                this.showNotification(allSubscriptionsDeletionMsg, '', 'success');
                if (isOperationInModalPopUp) {
                    this.isSpinnerLoading = false;
                    this.isEmptyState = true;
                } else {
                    this.isChooseAllLoading = false;
                }
                refreshApex(this.getAlertTypesWithProspaceAlertCacheUpdate).then(() => {
                    if (isOperationInModalPopUp) {
                        this.refreshProspaceAlerts("", true);
                        if (this.newProspaceAlertsArr.length > 0) {
                            //Enabling the Add All button in the modal
                            this.template.querySelector('div[data-id="modal_buttons_container"]').children[0].disabled = false;
                            //Disabling the Delete All button in the modal
                            this.template.querySelector('div[data-id="modal_buttons_container"]').children[1].disabled = true;
                        }
                    }
                });
            })
            .catch(error => {
                this.showErrorNotification(error, 'removeAllProspaceAlerts');
            });
    }
    //End : Imperative Methods ----------
    //END : APEX Methods -----------------------------------------------

    //START : Async Methods -----------------------------------------
    async selectAllAlertTypes(event) {
        //Storing the selected Toggle Button's checked value.
        let isToggleChecked = event.target.checked;
        //The confirmation prompt paramters with await 
        let isSelectionConfirmed = await LightningConfirm.open({
            message: event.target.checked ? subscriptionsCreationConfirmMsg : subscriptionsDeletionConfirmMsg,
            theme: "info", // other options are success, info, warning
            variant: 'headerless',
        });
        //Checking for User Confirmation
        if (isSelectionConfirmed) {
            //Retrieving all the Alert Types Ids from the Alert Types List
            this.alertTypesArr.forEach(alertTypeObject => {
                this.allAlertTypesIDsArr.push(alertTypeObject.alertTypeId);
            });
            if (isToggleChecked) {
                this.addAllProspaceAlerts(this.allAlertTypesIDsArr, false);
            } else {
                this.removeAllProspaceAlerts(this.allAlertTypesIDsArr, false);
            }
        }
    }

    async deleteAllProspaceAlertsAsync(event) {
        let selectedAlertTypesArr = [event.target.value];
        let isSelectionConfirmed = await LightningConfirm.open({
            message: subscriptionsDeletionConfirmMsg,
            theme: "warning", // other options are success, info, warning
            variant: 'headerless',
        });
        if (isSelectionConfirmed) {
            deleteAllProspaceAlerts({ recordId: this.recordId, selectedAlertTypesList: selectedAlertTypesArr })
                .then(result => {
                    if (result) {
                        this.showNotification('All Prospace Alerts have been successfully deleted.', '', 'success');
                        refreshApex(this.getAlertTypesWithProspaceAlertCacheUpdate);
                    }
                }).catch(error => {
                    this.showErrorNotification(error, 'deleteAllProspaceAlertsAsync');
                });
        }
    }
    //END : Async Methods -------------------------------------------

    //START : Modal Methods Section --------------------------
    //Description : Opens the Modal/PopUp
    openModalPopUp(event) {
        //Opening the Modal only for Nav and Reports
        if (event.currentTarget.parentElement.dataset.class === "nav_and_reports_container") {
            if (event.target.checked) {
                this.isModalDisplayed = true;
                this.modalTitle = event.target.name;
                //Setting the Alert Type Id from the selected Toggle Button's value
                this.selectedAlertTypeId = event.target.value;
                //Handling Empty States for Share Classes and Funds - when data is not available
                this.isEmptyState = this.newProspaceAlertsArr.length > 0 ? false : true;
                this.refreshProspaceAlerts(event, false);
                //START : Marketing Emails - European Equity Section
                if (this.isInterestDisplayed) {
                    this.isInterestDisplayed = false;
                }
                //END : Marketing Emails - European Equity Section
            } else {
                this.deleteAllProspaceAlertsAsync(event);
            }
        } else {
            //Creating a Prospace Alert when ALert Type Toggle is checked for Publication Section
            if (event.target.checked) {
                createProspaceAlerts({ contactId: this.recordId, alertTypeId: event.target.value, fundId: '', shareClassId: '', isPublication: true })
                    .then((result) => {
                        if (result) {
                            this.showNotification(subcriptionCreationMsg, '', 'success');
                            //Refreshes the Wired Cache for the newly updated Alert Types and re-render their Toggle Buttons
                            refreshApex(this.getAlertTypesWithProspaceAlertCacheUpdate).then(() => { });
                        } else {
                            this.showNotification(duplicateSubscriptionMsg, '', 'warning');
                        }
                    })
                    .catch((error) => {
                        this.showErrorNotification(error, 'openModalPopUp : createProspaceAlerts');
                    })
            } else { //Deleting the Prospace Alert when the Toggle Button is unchecked
                deleteProspaceAlerts({ prospaceAlertId: "", alertTypeId: event.target.value, isPublication: true })
                    .then(result => {
                        if (result) {
                            this.showNotification(subscriptionDeletionMsg, '', 'success');
                            refreshApex(this.getAlertTypesWithProspaceAlertCacheUpdate);
                        }
                    }).catch(error => {
                        this.showErrorNotification(error, 'openModalPopUp : deleteProspaceAlerts');
                    });
            }
        }
    }
    //Description : Opens up the Modal when the edit Button Icon is clicked for Alert Types with existing Prospace Alerts
    openModalPopUpExisting(event) {
        this.isModalDisplayed = true;
        //Differentiating between the interest and alert types edits
        if (event.target.name === "interestsEdit") {
            this.isInterestDisplayed = true;
            this.interestsCheckboxList = [];
            this.filterSubInterestsCheckbox(event.target.value);
        } else {
            this.modalTitle = event.target.name;
            this.selectedAlertTypeId = event.target.value;
            //Refreshing the new Prospace ALerts List to display the appropriate existing Prospace Alert for the appropriate Alert Type
            this.refreshProspaceAlerts(event, false);
            this.isEmptyState = this.newProspaceAlertsArr.length > 0 ? false : true;
        }
    }
    //Description : Opens up the Modal for European Equity only in the Marketing Emails section
    openInterestModal(event) {
        //Propulating the sub interests list for verification
        this.interestsCheckboxList = [];
        this.filterSubInterestsCheckbox(event.target.name);
        if (this.interestsCheckboxList.length > 0) {
            if (event.target.checked) {
                this.isModalDisplayed = true;
                this.modalTitle = event.target.ariaLabel;
                this.isInterestDisplayed = true;
                //Building the array of main interest to save
                this.mainInterestsObjArr.push({
                    checkboxAPI: event.target.name,
                    checkboxValue: event.target.checked
                });
            } else {
                this.mainInterestsObjArr.push({
                    checkboxAPI: event.target.name,
                    checkboxValue: false
                });
                let subInterestsArr = [];
                this.interestsCheckboxList.forEach(subInterest => {
                    subInterestsArr.push({
                        checkboxAPI: subInterest.checkboxAPI,
                        checkboxValue: false
                    });
                });
                this.isMainInterestLoading = true;
                updateInterests({ contactId: this.recordId, mainInterest: JSON.stringify(this.mainInterestsObjArr), subInterest: JSON.stringify(subInterestsArr) })
                    .then(result => {
                        this.showNotification(subscriptionUpdateMessage, '', 'success');
                        refreshApex(this.interestsMAPUpdated).then(() => {
                            this.interestsMainsArr = [];
                            this.interestsSubsidiariesArr = [];
                            this.isMainInterestLoading = false;
                            this.filterInterests(this.interestsMAPUpdated.data);
                        });
                    })
                    .catch(error => {
                        this.showErrorNotification(error, 'updateInterests');
                    });
            }
        } else {
            this.isMainInterestLoading = true;
            updateMainInterestOnly({ contactId: this.recordId, interestCheckboxAPI: event.target.name, isInterestSelected: event.target.checked })
                .then(result => {
                    this.showNotification(subscriptionUpdateMessage, '', 'success');
                    refreshApex(this.interestsMAPUpdated).then(() => {
                        this.interestsMainsArr = [];
                        this.interestsSubsidiariesArr = [];
                        this.isMainInterestLoading = false;
                        this.filterInterests(this.interestsMAPUpdated.data);
                    });
                })
                .catch(error => {
                    this.showErrorNotification(error, 'updateMainInterestOnly');
                });
        }
    }
    //Description : Closes the Modal
    closeModalPopUp() {
        this.isModalDisplayed = false;
        //Unchecking the selected Toggle Button when the process is cancelled or the Modal/PopUp is closed
        if (this.newProspaceAlertsArr.length === 0) {
            this.uncheckSelectedToggleOnCancel(this.template.querySelectorAll('div[data-class="nav_and_reports_container"]'));
            this.uncheckSelectedToggleOnCancel(this.template.querySelectorAll('div[data-class="publisher_container"]'));
        }
    }
    //START : Data Manipulation Methods-------------
    //Description : Sets Value from the Fund Lookup Field to cascade down to the Filter Criteria Component
    setFundValueForFilterCriteria() {
        //Setting the Fund Value with Fund Id
        this.fundIdToCascadeDown = this.template.querySelector('div[data-id="fund_input_container"]').firstChild.value;
    }
    //Description : Filters the Share Classes and Funds List to display the appropriate list based on the selected Alert Type Toggle Button
    refreshProspaceAlerts(event, serverCreateOrDeleteOps) {
        //Clearing the Prospace Alerts List before re-evaluation
        this.newProspaceAlertsArr = [];
        let buildNewProspaceAlertsArr = (eachObject, comparisionKey) => {
            //Checking if the selected Alert Type is found in the Prospace Alert Initial list
            if (eachObject.AlertTypeRecord__c === comparisionKey) {
                //Generating a new Array of Prospace Alerts containing Share Classes and Funds
                this.newProspaceAlertsArr.push({
                    Id: eachObject.Id,
                    FundName: eachObject.Fund__r.Name,
                    ShareClassName: eachObject.ShareClass__r.Name,
                    ShareClassISINCode: eachObject.ShareClass__r.ISIN_Code__c,
                    synchroStatusIconSuccess: eachObject.Synchro_Status__c === 'Success' ? true : eachObject.Synchro_Status__c === 'Failed' ? false : ''
                })
            }
        }
        if (serverCreateOrDeleteOps) {
            //For Create and Delete Server Operations : Looping in the Prospace Alert Updated Cache list from APEX to filter the ones associated with the selected Alert Type
            let updatedProspaceAlertsCache = JSON.parse(this.getAlertTypesWithProspaceAlertCacheUpdate.data).prospaceAlertList;
            updatedProspaceAlertsCache.forEach(eachProspaceAlert => {
                buildNewProspaceAlertsArr(eachProspaceAlert, this.selectedAlertTypeId);
            });
        } else {
            //For Display and Filtering of Prospace Alert Types :  Looping in the existing Prospace Alert list from APEX to filter the ones associated with the selected Alert Type
            this.existingProspaceAlertsArr.forEach(eachProspaceAlert => {
                buildNewProspaceAlertsArr(eachProspaceAlert, event.target.value);
            });
        }
    }
    //Description : Adds all Prospace Alerts for the selected Alert Type
    addAllProspaceAlertsModal() {
        this.addAllProspaceAlerts("", true);
    }
    //Description : Removes all Prospace Alerts for the selected Alert Type
    removeAllProspaceAlertsModal() {
        this.removeAllProspaceAlerts("", true);
    }
    //END : Data Manipulation Methods -------------
    //END : Modal Methods Section ----------------------------
    //START : Utility Methods ------------------------
    //Description : Handles server and client side errors' notification 
    showErrorNotification(errorObject, methodName) {
        if (errorObject.hasOwnProperty('body')) { //Ensuring only Server-Side Error is notified to the user.
            this.showNotification(generalErrorMsg, JSON.stringify(errorObject.body.message), 'error');
        }
        console.log('NGO : ' + methodName + ' : Error => ', errorObject);
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
    //Description : Unchecks the selected Toggle Button when the process is cancelled or the Modal is closed
    uncheckSelectedToggleOnCancel(elementsArray) {
        elementsArray.forEach(eachElement => {
            if (eachElement.firstChild.value === this.selectedAlertTypeId) {
                if (eachElement.firstChild.checked) {
                    eachElement.firstChild.checked = false;
                }
            }
        });
    }
    //END : Utility Methods --------------------------
    //START : Marketing Email Section --------------------------------------------------
    @wire(getContactInfo, { contactId: '$recordId' })
    wiredContacts;
    //Description : Selects the Email Opt Out Field on the Contact Detail's Page 
    optOutOfAllEmails(event) {
        this.isOptOutLoading = true;
        optOutOfEmailsContact({ contactId: this.recordId, isToggleChecked: event.target.checked })
            .then(result => {
                this.showNotification('Email Opt Out Field has been checked for the Contact', '', 'success');
                refreshApex(this.wiredContacts);
                this.isOptOutLoading = false;
            })
            .catch(error => {
                this.showErrorNotification(error, 'optOutOfAllEmails');
            });
    }
    //Description : Returns a JSON String of Contact Checkboxes Labels of Communication Types
    @wire(generateCommunicationTypesJSON, { contactId: '$recordId' })
    wiredCommunicationTypesJSON({ error, data }) {
        if (data) {
            JSON.parse(data).forEach(communicationType => {
                this.communicationTypesArr.push({
                    checkboxLabel: communicationType.checkboxAPI.substring(communicationType.checkboxAPI.lastIndexOf(';')+1),
                    checkboxAPI: communicationType.checkboxAPI.substring(0, communicationType.checkboxAPI.indexOf(';')),
                    checkboxValue: communicationType.checkboxValue
                })
            });
        } else if (error) {
            this.showErrorNotification(error, 'wiredCommunicationTypesJSON');
        }
    }
    //Description : Is called when cache is needed to update
    @wire(generateCommunicationTypesJSON, { contactId: '$recordId' })
    communicationTypesUpdatedJSON;
    //Description : Updates the Communication Types' Checkboxes when their appropriate Toggle Buttons are checked
    amendCommunicationType(event) {
        this.isCommunicationTypeLoading = true;
        updateContactCommunicationTypes({ contactId: this.recordId, commTypeCheckboxAPI: event.target.name, isCommTypeSelected: event.target.checked })
            .then(result => {
                this.showNotification(subscriptionUpdateMessage, '', 'success');
                refreshApex(this.communicationTypesUpdatedJSON).then(() => {
                    this.communicationTypesArr = [];
                    this.isCommunicationTypeLoading = false;
                    JSON.parse(this.communicationTypesUpdatedJSON.data).forEach(communicationType => {
                        this.communicationTypesArr.push({
                            checkboxLabel: communicationType.checkboxAPI.substring(communicationType.checkboxAPI.lastIndexOf(';')+1),
                            checkboxAPI: communicationType.checkboxAPI.substring(0, communicationType.checkboxAPI.indexOf(';')),
                            checkboxValue: communicationType.checkboxValue
                        })
                    });
                });
            })
            .catch(error => {
                this.showErrorNotification(error, 'amendCommunicationType');
            });
    }
    //Description : Returns a JSON String of Contact Checkboxes Labels of Interests
    @wire(generateInterestsMAP, { contactId: '$recordId' })
    wiredInterestsJSON({ error, data }) {
        if (data) {
            this.filterInterests(data);
        } else if (error) {
            this.showErrorNotification(error, 'wiredgetInterestFieldsLabels');
        }
    }
    //Description : Is called when cache is needed to update for interests
    @wire(generateInterestsMAP, { contactId: '$recordId' })
    interestsMAPUpdated;
    //Description : Save the Contact's Interests with the Main Interests
    saveContactInterest() {
        let interestCheckboxesElems = this.template.querySelector('div[data-id="interestsCheckboxContainer"]').children;
        if (interestCheckboxesElems.length > 0) {
            let SubInterestsArr = [];
            for (let i = 0; i < interestCheckboxesElems.length; i++) {
                SubInterestsArr.push({
                    checkboxAPI: interestCheckboxesElems[i].name,
                    checkboxValue: interestCheckboxesElems[i].checked
                });
            }
            this.isInterestLoading = true;
            updateInterests({ contactId: this.recordId, mainInterest: JSON.stringify(this.mainInterestsObjArr), subInterest: JSON.stringify(SubInterestsArr)})
                .then(result => {
                    this.showNotification(subscriptionUpdateMessage, '', 'success');
                    refreshApex(this.interestsMAPUpdated).then(() => {
                        this.interestsMainsArr = [];
                        this.interestsSubsidiariesArr = [];
                        this.isInterestLoading = false;
                        this.filterInterests(this.interestsMAPUpdated.data);
                    });
                })
                .catch(error => {
                    this.showErrorNotification(error, 'saveContactInterest');
                });
        }
    }
    //Description : Filter the Sub Interests' Checkboxes
    filterSubInterestsCheckbox(InterestToggle) {
        this.interestsSubsidiariesArr.forEach(interestObj => {
            if (interestObj.key === InterestToggle) {
                interestObj.values.forEach(subInterest => {
                    JSON.parse(subInterest).forEach(subInterestNested => {
                        this.interestsCheckboxList.push({
                            checkboxLabel: subInterestNested.SubCheckboxLabel,
                            checkboxAPI: subInterestNested.SubCheckboxAPI,
                            checkboxValue: subInterestNested.SubCheckboxValue
                        });
                    });
                });
            }
        });
    }
     //Description : Filter the Interests' Toggle Buttons and Checkboxes
    filterInterests(interestsArr){
        for (let key in interestsArr) {
            const keyInfo = key.split(";");
            let interestObj = {
                checkboxLabel: keyInfo[0],
                checkboxAPI: keyInfo[1],
                checkboxValue: keyInfo[2] === 'true' ? true : false,
                isSubInterests: ''
            }
            const isSubInterestCreated = JSON.parse(interestsArr[key][0]).some(subinterest => {
                if (keyInfo[2] === 'true' && JSON.parse(interestsArr[key][0]).length > 0) {
                    return true;
                }
                return false;
            });
            interestObj.isSubInterests = isSubInterestCreated;
            this.interestsMainsArr.push(interestObj);
            this.interestsSubsidiariesArr.push({ key: keyInfo[1], values: interestsArr[key] });
        }
    }
    //START : Marketing Email Section --------------------------------------------------
}