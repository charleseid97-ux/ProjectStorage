/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 01-23-2024
 * @last modified by  : SILA Nicolas
**/
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

//Import Apex Methods
import updateRecord from '@salesforce/apex/PreferenceCenterController.updateRecord';
import updateFields from '@salesforce/apex/PreferenceCenterController.updateFields';
import generateTogglesJson from '@salesforce/apex/PreferenceCenterController.generateTogglesJson';
import getOptOut from '@salesforce/apex/PreferenceCenterController.getOptOut';
import getSubInterests from '@salesforce/apex/PreferenceCenterController.getSubInterests';

//Import Labels
import generalErrorMsg from '@salesforce/label/c.PreferenceCenter_General_Error_Msg';
import updateSucess from '@salesforce/label/c.PreferenceCenter_Subscription_Update_Msg';
import updateFail from '@salesforce/label/c.PreferenceCenter_Contact_Not_Sync';

export default class preferenceCenter extends LightningElement {
    // Flexipage provides recordId and objectApiName
    @api recordId;

    @track communicationTypes = [];
    @track interests = [];
    @track preferences = [];
    @track subinterests = [];
    @track currentInterest;
    @track regions = [];
    @track optOutField;
    @track lastModified;
    @track wiredTogglesRes = [];

    OptReasonLoading = false ;
    isOptOutLoading = false;
    isInterestLoading = false;
    isCommunicationTypeLoading = false;
    isPreferenceLoading = false;
    isRegionLoading = false;
    
    isModalDisplayed = false;
    optOutModal = false;
    modalTitle;

    toggleSection(event) {
        let buttonid = event.currentTarget.dataset.buttonid;
        let currentsection = this.template.querySelector('[data-id="' + buttonid + '"]');
        if (currentsection.className.search('slds-is-open') === -1) {
            currentsection.className = 'slds-section slds-is-open';
        } else {
            currentsection.className = 'slds-section slds-is-close';
        }
    }
    
    @wire(getOptOut, {recordId: '$recordId'})
    optOut;

    parseTogglesData(data, arr) {
        JSON.parse(data).forEach(elm => {
            arr.push({
                checkboxLabel : elm.checkboxLabel,
                checkboxAPI: elm.checkboxAPI,
                checkboxValue: elm.checkboxValue
            });
        });
    }

    parseAllTogglesData(data) {
        JSON.parse(data).forEach(elm => {
            let arr;
            switch (elm.checkboxCategory) {
                case 'Communication Type':
                    arr = this.communicationTypes;
                    break;
                case 'Preference':
                    arr = this.preferences;
                    break;
                case 'Interest':
                    arr = this.interests;
                    break;
                case 'Region':
                    arr = this.regions;
                    break;
            }
            arr.push({
                checkboxLabel : elm.checkboxLabel,
                checkboxAPI: elm.checkboxAPI,
                checkboxValue: elm.checkboxValue
            });
        });
    }

    @wire(generateTogglesJson, {recordId: '$recordId', category: ''})
    wiredToggles(result) {
        this.wiredTogglesRes = result;
        if (result.data) {
            this.parseAllTogglesData(result.data);
        }
        else if (result.error) {
            this.showNotification(generalErrorMsg, JSON.stringify(result.error.message), 'error');
        }
    }
    
    updateToggle(event, category,nameValue, checkedValue) {

        let checked = checkedValue != null ? checkedValue : event.target.checked ;
        let name = nameValue != null ? nameValue : event.target.name;
        updateRecord({recordId: this.recordId, apiName: name, apiValue: checked})
            .then(() => {
                if (category === 'Communication Type' || category ===  'OptOut') {
                    refreshApex(this.communicationTypeJSON)
                        .then(() => {
                            this.communicationTypes = [];
                            this.parseTogglesData(this.communicationTypeJSON.data, this.communicationTypes);
                        });
                    
                    // refreshApex(this.lastModifiedDateOptOut);
                    refreshApex(this.OptOut);
                    if (category === 'Communication Type' && checked === false) {
                        let allFalse = true;
                        this.communicationTypes.forEach(element => {
                            if (element.checkboxValue === true && element.checkboxAPI !== name) {
                                allFalse = false;
                            }
                        });
                        if (allFalse) {
                            let elm = this.template.querySelector("lightning-input[data-id='optOut']");
                            elm.checked = true;
                        }
                    }
                }
                else if (category === 'Preference') {
                    refreshApex(this.preferenceJSON)
                        .then(() => {
                            this.preferences = [];
                            this.parseTogglesData(this.preferenceJSON.data, this.preferences);
                        });
                }
                else if (category === 'Interest') {
                    refreshApex(this.interestJSON)
                        .then(() => {
                            this.interests = [];
                            this.parseTogglesData(this.interestJSON.data, this.interests);
                        });
                }
                else if (category === 'Region') {
                    refreshApex(this.regionJSON)
                        .then(() => {
                            this.regions = [];
                            this.parseTogglesData(this.regionJSON.data, this.regions);
                        })
                }
                this.showNotification(updateSucess, '', 'success');
            })
            .catch(error => {
                console.log(error);
                this.showNotification(updateFail, '', 'warning');
            })
            .finally(() => {
                this.isOptOutLoading = false;
                this.isCommunicationTypeLoading = false;
                this.isPreferenceLoading = false;
                this.isInterestLoading = false;
                this.isRegionLoading = false;
            });
    }

    @wire(generateTogglesJson, {recordId: '$recordId', category: 'Communication Type'})
    communicationTypeJSON;

    updateToggleCommunicationType(event) {
        this.isCommunicationTypeLoading = true;
        this.updateToggle(event, 'Communication Type');
    }

    @wire(generateTogglesJson, {recordId: '$recordId', category: 'Preference'})
    preferenceJSON;
    
    updateTogglePreference(event) {
        if (event.target.checked) {
            this.openModal(event);
        }
        else {
            this.isPreferenceLoading = true;
            this.updateToggle(event, 'Preference');
        }
    }

    @wire(generateTogglesJson, {recordId: '$recordId', category: 'Interest'})
    interestJSON;

    updateToggleInterest(event) {
        this.isInterestLoading = true;
        this.updateToggle(event, 'Interest');
    }

    @wire(generateTogglesJson, {recordId: '$recordId', category: 'Region'})
    regionJSON;

    updateToggleRegion(event) {
        this.isRegionLoading = true;
        this.updateToggle(event, 'Region');
    }

    openModal(event) {
        this.currentInterest = event.target.value;
        this.modalTitle = event.target.ariaLabel;
        this.generateSubInterest(this.currentInterest);
    }

    generateSubInterest(interest) {
        var newSubInterests = [];
        getSubInterests({recordId: this.recordId, apiName: interest})
            .then(result => {
                JSON.parse(result).forEach(subIn => {
                    newSubInterests.push({
                        checkboxLabel : subIn.checkboxLabel,
                        checkboxAPI: subIn.checkboxAPI,
                        checkboxValue: subIn.checkboxValue
                    })
                });
                console.log(newSubInterests);
                this.subinterests = Array.from(newSubInterests);
                this.isModalDisplayed = true;
            })
            .catch(error => {
                console.log(error);
            });
    }

    saveModal() {
        let subInterestList = this.template.querySelector('[data-id="interestContainer"]').children;
        let listToUpdate = new Map();
        this.isPreferenceLoading = true;
        let oneTrue = false;

        for (let i = 0; i < subInterestList.length; i++) {
            listToUpdate[subInterestList[i].name] = subInterestList[i].checked;
            if (subInterestList[i].checked && !oneTrue) {
                oneTrue = true;
            }
        }
        listToUpdate[this.currentInterest] = oneTrue;

        updateFields({recordId: this.recordId, fields: listToUpdate})
            .then(result => {
                this.preferences = [];
                refreshApex(this.preferenceJSON)
                    .then(() => {
                        this.preferences = [];
                        this.parseTogglesData(this.preferenceJSON.data, this.preferences);
                    });
                this.showNotification(updateSucess, '', 'success');
            })
            .catch(error => {
                console.log(error);
                this.showNotification(updateFail, '', 'warning');
            })
            .finally(() => {
                this.isModalDisplayed = false;
                this.modalTitle = '';
                this.subinterests = [];
                this.currentInterest = '';
                this.isPreferenceLoading = false;
            });
    }

    closeModal() {
        this.wiredTogglesRes = [];
        refreshApex(this.wiredTogglesRes);
        this.checkTogglesValues();
        this.isModalDisplayed = false;
        this.modalTitle = '';
        this.subinterests = [];
        this.currentInterest = '';
    }
    checkTogglesValues() {
        let listToCheck = [this.interests, this.communicationTypes, this.preferences, this.regions, this.subinterests];
        listToCheck.forEach(array => {
            array.forEach(element => {
                let elm = this.template.querySelector("lightning-input[data-id='" + element.checkboxAPI + "']");
                if(elm) elm.checked = element.checkboxValue;
            });
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