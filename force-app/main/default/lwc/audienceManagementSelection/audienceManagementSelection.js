/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 25-04-2024
 * @last modified by  : Thanina YAYA
**/
import { LightningElement, wire, track } from 'lwc';

import Id from '@salesforce/user/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import { publish, MessageContext } from 'lightning/messageService';
import amQuery from "@salesforce/messageChannel/audienceManagementQuery__c";

import getAllFilters from '@salesforce/apex/CTL_AudienceManagement.getAllFilters';
import getCurrentProfile from '@salesforce/apex/CTL_AudienceManagement.getCurrentProfile';
import getProducts from '@salesforce/apex/CTL_AudienceManagement.getProducts';
import getUsers from '@salesforce/apex/CTL_AudienceManagement.getUsers';
import getContactFromProductInterest from '@salesforce/apex/CTL_AudienceManagement.getContactFromProductInterest';
import getCompanyFromProductInterest from '@salesforce/apex/CTL_AudienceManagement.getCompanyFromProductInterest';
import getPickValues from '@salesforce/apex/CTL_AudienceManagement.getPicklistValues';
import getPicklistStateCode from '@salesforce/apex/CTL_AudienceManagement.getPicklistStateCode';

export default class AudienceManagementSelection extends LightningElement {
    activeSections = ['ContactCompany', 'SubManagement', 'ProdInterest', 'EventPreferences', 'CustInterest', 'Interactions'];

    showSpinner = true;

    //List of filters retrieved from the custom metadata Audience Management Field
    allFilters = [];
    contactCompanyFilters = [];
    subManagementFilters = [];
    eventPrefFilters = [];
    custInterestFilters = [];
    interactionsFilters = [];
    
    //List of filters retrieved from the custom metadata Preference Center Category
    regionsFilters = [];
    preferencesFilters = [];
    otherInterestsFilters = [];

    //Parameters for the child filters modal for the Preference Center filters
    childModalTitle;
    childModalFilters = [];
    childModalOpened = false;

    //List of parameters used for the product lookup
    @track allProducts;
    @track mapProducts = {};
    @track selectedProduct;
    @track selectedRating = 0;
    @track selectedDateFrom;
    @track selectedProductInvested = false;
    productSearchFields = ['code'];

    //List of parameters used for the user lookup
    @track allUsers = [];
    @track allContOwner = [];
    @track mapUsers = {};
    @track selectedUser = [];
    @track compOwnesPills;
    @track selectedUserContact=[];
    @track contOwnersPills;
    @track teamVals = [];
    @track selectedTeams = [];
    @track teamsPills;
    @track mailingArea = [];
    @track selectedMailingArea = [];
    @track mailingPills;

    domainName = '@';
    myCompanyFilter = false;
    myTeamCompanyFilter = false;
    @track userId = Id;
    //List of filters to add to the query
    contactFiltersValue = [];
    interactionsFiltersValue = [];
    @track mapPrentChilds = {};
    baseQuery = 'SELECT id, FirstName, LastName, Account.Name, Email, Phone, Invitation_Opt_Out__c, Newsletter_Opt_Out__c FROM Contact WHERE HasOptedOutOfEmail = false AND Global_Hardbounced__c = false  AND ContactStatus__c = \'true\' AND Account.Name != \'Carmignac\' AND AccountId != null';
    
    get dispSelectionPills(){
            let dispPills = {CompanyTeam: this.teamsPills && this.teamsPills.length,
                            CompanyOwner: this.compOwnesPills && this.compOwnesPills.length,
                            ContactOwner: this.contOwnersPills && this.contOwnersPills.length,
                            ContactMailing: this.mailingPills && this.mailingPills.length };

        return dispPills;
    }

    @wire(MessageContext)
    MessageContext;

    //MailingStateCode
    @wire (getPicklistStateCode, {})
    getMailingAreaValues({ error, data }) {
        if (data && data.length) {
            this.mailingArea = [...data];
        } else if (error) {
            console.error('@err getMailingAreaPickVals:', error);
        }
    }

    @wire (getPickValues, {sObjectName: 'Account', fieldName: 'Team__c'})
    getTeamValues({ error, data }) {
        if (data && data.length) {
            this.teamVals = [...data];
        } else if (error) {
            console.error('@err getTeamPickVals:', error);
        }
    }

    @wire(getCurrentProfile, { userId: '$userId' })
    getprofile({ error, data }) {
        if (data) {
            console.log('Profile', data);
            if (data === 'Carmignac - CRM') {
                this.myTeamCompanyFilter = true;
            } else if (data === 'Carmignac - Business Developer') {
                this.myCompanyFilter = true;
            }
        } else if (error) {
            console.error('@err getprofile:', error);
        }
    }
    //Retrieve products on load
    @wire(getProducts, {})
    products({data,error}) {
        if(data && data.length){ 
            let products =[];
            let mapProducts = {};
            data.forEach(product =>{
                products.push({label:product.Code__c+" | "+product.Name,value:product.Id,code:product.Code__c});
                mapProducts[product.Id] = product;
            });
            this.allProducts = [...products];
            this.mapProducts = mapProducts;
        }
        else if(error)
        {
            console.log('@err getProduct:',error);
        }
    }

    //Retrieve users on load
    @wire(getUsers, {})
    users({data,error}) {
        if(data && data.length){ 
            let users =[];
            let mapUsers = {};
            data.forEach(user =>{
                users.push({label:user.Name,value:user.Id});
                mapUsers[user.Id] = user;
            });
            this.allUsers = [...users];
            this.allContOwner= [...users];
            this.mapUsers = mapUsers;
        }
        else if(error)
        {
            console.log('@err getUsers:',error);
        }
    }

    //Retrieve filters on load
    @wire(getAllFilters, {})
    getFiltersBySection({data, error}){
        if(data) {
            let contactCompanyFiltersTemp = [];
            let subManagementFiltersTemp = [];
            let custInterestFiltersTemp = [];
            let eventPrefFiltersTemp = [];
            let interactionsFiltersTemp = [];
            let preferencesFiltersTemp = [];
            let otherInterestsFiltersTemp = [];
            let regionsFiltersTemp = [];
            //manage PrefCenter Parent and childs
            let mapPrefParentChilds = {};
            for (const value of data) {
                
                if(!value.hasParent) {
                    //Every filter is stocked in the list corresponding to its section
                    switch (value.section) {
                        case 'Contact and Company filters':
                            contactCompanyFiltersTemp.push(value);
                            break;
                        case 'Subscription Management':
                            subManagementFiltersTemp.push(value);
                            break;
                        case 'Event Preferences':
                            eventPrefFiltersTemp.push(value);
                            break;                 
                        case 'Customer Interests':
                            custInterestFiltersTemp.push(value);
                            break;
                        case 'Digital Interactions':
                            interactionsFiltersTemp.push(value);
                            break;
                        case 'Preference':
                            preferencesFiltersTemp.push(value);
                            break;
                        case 'Interest':
                            otherInterestsFiltersTemp.push(value);
                            break;
                        case 'Region':
                            regionsFiltersTemp.push(value);
                            break;
                        default:
                            break;
                    }
                }   
                //to check after
                else{
                    let childs = [];
                    if(mapPrefParentChilds[value.parentName] && (mapPrefParentChilds[value.parentName]).length)
                    childs = mapPrefParentChilds[value.parentName];
                    childs.push(value.name);
                    mapPrefParentChilds[value.parentName] = [...childs]; 
                }             
            }
            
            this.mapPrentChilds = mapPrefParentChilds;
            this.contactCompanyFilters = contactCompanyFiltersTemp;
            this.subManagementFilters = subManagementFiltersTemp;
            this.custInterestFilters = custInterestFiltersTemp;
            this.eventPrefFilters = eventPrefFiltersTemp;
            this.interactionsFilters = interactionsFiltersTemp;
            this.preferencesFilters = preferencesFiltersTemp;
            this.otherInterestsFilters = otherInterestsFiltersTemp;
            this.regionsFilters = regionsFiltersTemp;
            this.allFilters = data;
            this.showSpinner = false;
        } else {
            console.log(error);
        }
    }

    handleChangeMyCompany(event) {
        this.myCompanyFilter = event.detail.checked;
        if (this.myCompanyFilter) {
            this.myTeamCompanyFilter = false;
        } 
    }

    handleChangeMyTeamCompany(event) {
        this.myTeamCompanyFilter = event.detail.checked;
        if (this.myTeamCompanyFilter) {
            this.myCompanyFilter = false;
            // this.showToast('Please note that you cannot simultaneously check both "My Companies" and "My Team\'s Companies" Please select one option at a time.', 'Warning', 'Warning'); 
        }
    }

    handleDomainName(event) {
        this.domainName = event.detail.value;
        
    }

    handleChangePicklist(event) {
        var newValue = {};
        newValue.name = event.currentTarget.dataset.id;
        newValue.value = event.detail.value;
        this.changeFilterValue(newValue);
    }

    handleChangeMultipicklist(event) {
        var newValue = {};
        newValue.name = event.currentTarget.dataset.id;
        newValue.value = event.detail.value;
        this.changeFilterValue(newValue);
    }

    handleChangeText(event) {
        if(event.detail.value === '') {
            let index = this.contactFiltersValue.findIndex(e => e.name === event.currentTarget.dataset.id)
            if(index >= 0) {
                this.contactFiltersValue.splice(index, 1);
            }
        } else {
            let newValue = {};
            newValue.name = event.currentTarget.dataset.id;
            newValue.value = event.detail.value;
            this.changeFilterValue(newValue);
        }        
    }

    handleChangeToggleWithChilds(event) {
        let filterId = event.currentTarget.dataset.id;
        this.childModalTitle = event.target.ariaLabel;
        let childFilters = this.mapPrentChilds[this.childModalTitle];
        if(event.detail.checked) {
            let newValue = {};
            newValue.name = filterId;
            newValue.value = event.detail.checked;
            this.changeFilterValue(newValue); 
            let shouldOpenModel = true;
            childFilters.forEach(elem=> { 
                if (this.contactFiltersValue.find(e => e.name === elem)) {
                    shouldOpenModel = false;
                }
            });
            if(shouldOpenModel) this.handleOpenChildrenModal(event);
        } else {
            let indexParent = this.contactFiltersValue.findIndex(e => e.name === filterId)
            if(indexParent >= 0) {
                this.contactFiltersValue.splice(indexParent, 1);
            }
            childFilters.forEach(elem=> { 
                let index = this.contactFiltersValue.findIndex(e => e.name === elem)
                if(index >= 0) {
                    this.contactFiltersValue.splice(index, 1);
                } 
            });
        }
    }

    handleChangeToggle(event) {
        if(event.detail.checked) {
            let newValue = {};
            newValue.name = event.currentTarget.dataset.id;
            newValue.value = event.detail.checked;
            this.changeFilterValue(newValue);
        } else {
            let index = this.contactFiltersValue.findIndex(e => e.name === event.currentTarget.dataset.id)
            if(index >= 0) {
                this.contactFiltersValue.splice(index, 1);
            }
        }
    }

    handleChangeDate(event) {
        var newValue = {};
        newValue.name = event.currentTarget.dataset.id;
        newValue.value = event.detail.value;
        this.changeFilterValue(newValue);
    }

    handleChangeNumber(event) {
        var newValue = {};
        newValue.name = event.currentTarget.dataset.id;
        newValue.value = event.detail.value;
        this.changeFilterValue(newValue);
    }

    //Add the new filter value to the correct list of filter value, depending on the section of the filter
    changeFilterValue(newValue) {        
        var filter = this.allFilters.find(e => e.name === newValue.name);
        if(filter.section === 'Digital Interactions') {
            this.addToInteractionsFilters(newValue);
        } else {
            this.addToContactFilters(newValue);
        }
    }

    addToContactFilters(newValue) {
        var index = this.contactFiltersValue.findIndex(e => e.name === newValue.name)
        if(index >= 0) {
            this.contactFiltersValue.splice(index, 1);
        }
        if( typeof newValue?.value !== "object" ) this.contactFiltersValue.push(newValue);
        else if(newValue?.value?.length) this.contactFiltersValue.push(newValue);
    }

    addToInteractionsFilters(newValue) {
        var index = this.interactionsFiltersValue.findIndex(e => e.name === newValue.name)
        if(index >= 0) {
            this.interactionsFiltersValue.splice(index, 1);
        }
        this.interactionsFiltersValue.push(newValue);
    }

    handleProducts(event){
        var product = this.mapProducts[event.detail.selectedValues];
        if(product) {
            this.selectedProduct = {id:event.detail.selectedValues, name:product.Name};
        }
    }

    handleMultiSelection(e){
        const looukup = e.target?.dataset?.id;
        let newValue = {};

        switch(looukup){
            case 'CompanyTeam':
                this.selectedTeams = [...e.detail.selectedValues];
                this.teamsPills = [...this.selectionPills(this.teamVals,'standard:team_member',this.selectedTeams)];
                break;
            case 'CompanyOwner':
                this.selectedUser =  [...e.detail.selectedValues]; 
                this.compOwnesPills = [...this.selectionPills(this.allUsers,'standard:user',this.selectedUser)];
                break;
            case 'ContactOwner':
                this.selectedUserContact = [...e.detail.selectedValues];
                this.contOwnersPills = [...this.selectionPills(this.allContOwner,'standard:user',this.selectedUserContact)];
                break;
            case 'MailingState':
                this.selectedMailingArea = [...e.detail.selectedValues];
                this.mailingPills = [...this.selectionPills(this.mailingArea,'standard:service_territory',this.selectedMailingArea)];
                break;
            default:
                newValue.name = looukup;
                newValue.value = [...e.detail.selectedValues];
                this.changeFilterValue(newValue);             
        }
        
    }
    
    selectionPills(allData,icon,selectedOnes){
        let items= [];
        selectedOnes.forEach(cont =>{
            items.push({type: 'icon',
                        label: (allData.find(e => e.value === cont))?.label,
                        name: cont,
                        iconName: icon,
                        alternativeText: 'contact',
                        isLink: true
                        //href: '/'+cont
                    });
        });
        return items;
    }
    handleMultiItemRemove(e) {
        const looukup = e.target?.dataset?.id;
        const index = e.detail.index;
        switch(looukup){
            case 'CompanyTeam':
                this.teamsPills.splice(index, 1);
                this.selectedTeams.splice(index,1);
                break;
            case 'CompanyOwner':
                this.compOwnesPills.splice(index, 1);
                this.selectedUser.splice(index,1);
                break;
            case 'ContactOwner':
                this.contOwnersPills.splice(index, 1);
                this.selectedUserContact.splice(index,1);
                break;
            case 'MailingState':
                this.mailingPills.splice(index,1);
                this.selectedMailingArea.splice(index,1);
                break;
            default:
        }
        
    }
    handleRemoveSelectedProduct() {
        this.selectedProduct = null;
    }

    handleRemoveSelectedUsers() {
        this.selectedUser = null;
    }

    handleChangeInvested(event) {
        this.selectedProductInvested = event.detail.checked;
    }

    handleRating(event) {
        this.selectedRating = event.detail;
    }

    handleChangeDateProduct(event) {
        this.selectedDateFrom = event.detail.value;
    }

    //Retrieves the children filter of selected filter, build the modal with them and opens the modal
    handleOpenChildrenModal(event) {
        this.childModalTitle = event.target.ariaLabel;
        let childFilters = this.findChildrenFilters(this.childModalTitle);
        let filtersTemp = [];
        for (let childFilter of childFilters) {
            let filter = {...childFilter};
            if (this.contactFiltersValue.find(e => e.name === childFilter.name)) {
                filter.checked = true;                
            } else {
                filter.checked = false;
            }
            filtersTemp.push(filter);
        }
        this.childModalFilters = filtersTemp;
        this.childModalOpened = true;
    }

    closeModalChild(evt) {
        if(evt.target.dataset.parent) {
            let childFilters = this.mapPrentChilds[evt.target.dataset.parent];
            let ontoggle = false;
            childFilters.forEach(elem=> { 
                if (this.contactFiltersValue.find(e => e.name === elem)) {
                        ontoggle = true;    
                } 
            });
            if(ontoggle) {
                let parentToggle = this.template.querySelector(`lightning-input[data-id="${evt.target.dataset.parent}"]`);
                if(parentToggle) parentToggle.checked = true;
                let newValue = {};
                newValue.name = evt.target.dataset.parent;
                newValue.value = true;
                this.changeFilterValue(newValue); 

            }
        }
        this.childModalOpened = false;
    }

    //Resets every filter to their initial state
    handleClickReset() {
        // Clear the lightning-input 
        this.template.querySelectorAll('lightning-input').forEach(element => {
            if(element.type === 'toggle') {
                element.checked = false;
            } else {
                element.value = null;
            }
        });
        // Clear the combobox
        this.template.querySelectorAll('lightning-combobox').forEach(element => {            
            element.value = null;
        });
        //Clear All dual list 
        this.template.querySelectorAll('lightning-dual-listbox').forEach(element => {            
            element.value = null;
        });
        //Clear All multi Select Lookup filters 
        this.template.querySelectorAll('c-multi-select-search-list')?.forEach(element => {            
            element.value = [];
        });
        // Clear the variables
        this.contactFiltersValue = [];
        this.interactionsFiltersValue = [];
        this.selectedDateFrom = null;
        this.selectedProduct = null;
        this.selectedRating = 0;
        this.selectedProductInvested = false;
        this.myCompanyFilter = false;
        this.domainName = '@';
        this.myTeamCompanyFilter = false;
        this.selectedUserContact = [];
        this.selectedTeams = [];
        this.selectedMailingArea = [];
        this.teamsPills = [];
        this.mailingPills = [];
        this.contOwnersPills = [];
        this.compOwnesPills = [];
        this.selectedUser = [];
    }

    //Builds the query and sends it to the audienceManagementDisplay component
    handleClickRun() {
        //If a product has been selected, build a query to retrieve the contact linked to these product interest
        if(this.selectedProduct || this.selectedDateFrom) {
            this.showSpinner = true;
            getContactFromProductInterest({request: this.buildQueryInterest()})
            .then(data => {                
                let query = this.baseQuery
                query += ' AND Id IN (';
                let firstId = true;
                for (const iterator of data) {
                    if(firstId) {
                        firstId = false;
                    } else {
                        query += ',';
                    }
                    query += '\'' + iterator + '\'';
                }
                query += ')';
                if(this.selectedProductInvested) {
                    getCompanyFromProductInterest({productId: this.selectedProduct.id})
                    // eslint-disable-next-line no-shadow
                    .then(data => {
                        query += ' AND AccountId IN (';
                        let firstCompany = true;
                        for (const iterator of data) {
                            if(firstCompany) {
                                firstCompany = false;
                            } else {
                                query += ',';
                            }
                            query += '\'' + iterator + '\'';
                        }
                        query += ')';
                        const payload = {
                            query: this.buildQuery(query)
                        }
                        this.sendQuery(payload);
                    })
                    .catch(error => {
                        this.showToast(error.body.message, 'Error', 'Error'); //show toast for error
                    })
                } else {
                    const payload = {
                        query: this.buildQuery(query)
                    }
                    this.sendQuery(payload);
                }                
            })
            .catch(error => {
                this.showToast(error.body.message, 'Error', 'Error'); //show toast for error
            })
            .finally(() => {
                this.showSpinner = false;
            })
        } else {
            const payload = {
                query: this.buildQuery(this.baseQuery)
            }
            this.sendQuery(payload);
        }
    }

    //Build the query to retrieve the meeting notes linked to a product
    buildQueryInterest() {
        var query = 'SELECT MeetingNote__c FROM ClientInterest__c WHERE ';
        var first = true;
        if(this.selectedProduct) {
            if(first) {
                first = false;
            } else {
                query += ' AND ';
            }
            query += ' Strategy__c=\'' + this.selectedProduct.id + '\'';
        }
        if(this.selectedDateFrom) {
            if(first) {
                first = false;
            } else {
                query += ' AND ';
            }
            query += 'MeetingNote__r.Date__c>=' + this.selectedDateFrom;
        }
        if(this.selectedRating) {
            if(first) {
                first = false;
            } else {
                query += ' AND ';
            }
            query += 'Interest__c>=' + this.selectedRating;
        }
        console.log(query);
        return query;
    }

    //Builds the query from a base query by adding every selected filters
    buildQuery(query) {
        if(this.myCompanyFilter) {
            query += ' AND Account.OwnerId=\'' + this.userId + '\'';
        }

        if(this.myTeamCompanyFilter) {
            query += ' AND Account.Is_IN_my_Team__c=true';
        }

        if(this.selectedUser && this.selectedUser.length) {
            let quotedAndCommaSeparated = "'" + this.selectedUser.join("','") + "'";
            query += ' AND Account.OwnerId IN (' + quotedAndCommaSeparated + ')';
        }
        if(this.selectedUserContact && this.selectedUserContact.length){
            let quotedAndCommaSeparated = "'" + this.selectedUserContact.join("','") + "'";
            query += ' AND OwnerId IN (' + quotedAndCommaSeparated + ')';
        }
        
        if(this.domainName && this.domainName!='@') {
            query += ' AND Email LIKE \'%' + this.domainName + '%\'';
        }

        /*
        if(this.selectedTeams && this.selectedTeams.length){
            let quotedAndCommaSeparated = "'" + this.selectedTeams.join("','") + "'";
            query += ' AND Account.Team__c IN (' + quotedAndCommaSeparated + ')';
        }
        if(this.selectedMailingArea && this.selectedMailingArea.length){
            let quotedAndCommaSeparated = "'" + this.selectedMailingArea.join("','") + "'";
            query += ' AND MailingStateCode IN (' + quotedAndCommaSeparated + ')';
        }*/
        
        for (const contFilter of this.contactFiltersValue) {
            let filter = this.findFilter(contFilter.name); 
            query += ' AND ';
            if(filter.objectName !== 'Contact') {
                query += filter.objectName + '.';
            }
            query += filter.fieldName;
            if(filter.isPicklist) {
                if(filter.isMultiLookup){
                    query += ' IN (\'';
                } else query += '=\'';
            } else if(filter.isText) {
                query += ' LIKE \'%'
            } else if(filter.isMultipicklist) {
                query += ' INCLUDES (\'';
            } else if(filter.isCheckbox) {
                query += '='
            } else {
                query += '>=';
            }

            if(filter.isMultipicklist || filter.isMultiLookup) {
                query += contFilter.value.toString().replaceAll(',', '\',\'');
            } else {
                query += contFilter.value;
            }

            if(filter.isPicklist) {
                if(filter.isMultiLookup)  query += '\')';
                else query += '\'';
            } else if(filter.isText) {
                query += '%\'';
            } else if(filter.isMultipicklist) {
                query += '\')';
            }
        }
        if(this.interactionsFiltersValue.length > 0) {
            query += ' AND Id IN (SELECT Contact_lu__c FROM Digital_Interaction__c WHERE ';
            let first = true;
            for (const intFilter of this.interactionsFiltersValue) {
                if(first) {
                    first = false;
                } else {
                    query += ' AND ';
                }
                let filter = this.findFilter(intFilter.name);                
                query += filter.fieldName;
                if(filter.isPicklist) {
                    query += '=\'';
                } else if(filter.isText) {
                    query += ' LIKE \'%'
                } else if(filter.isCheckbox) {
                    query += '='
                } else {
                    query += '>=';
                }
                query += intFilter.value;
                if(filter.isPicklist) {
                    query += '\'';
                } else if(filter.isText) {
                    query += '%\'';
                }
            }
            query += ')';
        }
        
        return query;
    }

    findFilter(name) {
        return this.allFilters.find(e => e.name === name);
    }

    findChildrenFilters(parentName) {
        return this.allFilters.filter(e => e.parentName === parentName);
    }

    //Sends the query to the audienceManagementDisplay component via a messageChannel
    sendQuery(payload) {
        publish(this.MessageContext, amQuery, payload);
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
}