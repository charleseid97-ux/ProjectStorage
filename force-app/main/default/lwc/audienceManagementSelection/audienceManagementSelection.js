import { LightningElement, wire, track } from 'lwc';

import Id from '@salesforce/user/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import { publish, MessageContext } from 'lightning/messageService';
import amQuery from "@salesforce/messageChannel/audienceManagementQuery__c";

import getAllFilters from '@salesforce/apex/CTL_AudienceManagement.getAllFilters';
import getProducts from '@salesforce/apex/CTL_AudienceManagement.getProducts';
import getUsers from '@salesforce/apex/CTL_AudienceManagement.getUsers';
import getContactFromProductInterest from '@salesforce/apex/CTL_AudienceManagement.getContactFromProductInterest';
import getCompanyFromProductInterest from '@salesforce/apex/CTL_AudienceManagement.getCompanyFromProductInterest';


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
    @track allUsers;
    @track mapUsers = {};
    @track selectedUser;

    myCompanyFilter = true;
    myTeamCompanyFilter = false;
    @track userId = Id;

    //List of filters to add to the query
    contactFiltersValue = [];
    interactionsFiltersValue = [];

    baseQuery = 'SELECT id, FirstName, LastName, Account.Name, Email, Phone FROM Contact WHERE HasOptedOutOfEmail = false AND ContactStatus__c = \'true\'';

    @wire(MessageContext)
    MessageContext;

    //Retrieve products on load
    @wire(getProducts, {})
    products({data,error}) {
        if(data && data.length){ 
            let products =[];
            let mapProducts = {};
            data.forEach(product =>{
                products.push({label:product.Product_Name__c,value:product.Id,code:product.Name});
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
            var contactCompanyFiltersTemp = [];
            var subManagementFiltersTemp = [];
            var custInterestFiltersTemp = [];
            var eventPrefFiltersTemp = [];
            var interactionsFiltersTemp = [];
            var preferencesFiltersTemp = [];
            var otherInterestsFiltersTemp = [];
            var regionsFiltersTemp = [];
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
            }
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
    }

    handleChangeMyTeamCompany(event) {
        this.myTeamCompanyFilter = event.detail.checked;
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
            var index = this.contactFiltersValue.findIndex(e => e.name == event.currentTarget.dataset.id)
            if(index >= 0) {
                this.contactFiltersValue.splice(index, 1);
            }
        } else {
            var newValue = {};
            newValue.name = event.currentTarget.dataset.id;
            newValue.value = event.detail.value;
            this.changeFilterValue(newValue);
        }        
    }

    handleChangeToggle(event) {
        if(event.detail.checked) {
            var newValue = {};
            newValue.name = event.currentTarget.dataset.id;
            newValue.value = event.detail.checked;
            this.changeFilterValue(newValue);  
        } else {
            var index = this.contactFiltersValue.findIndex(e => e.name == event.currentTarget.dataset.id)
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
        var filter = this.allFilters.find(e => e.name == newValue.name);
        if(filter.section == 'Digital Interactions') {
            this.addToInteractionsFilters(newValue);
        } else {
            this.addToContactFilters(newValue);
        }
    }

    addToContactFilters(newValue) {
        var index = this.contactFiltersValue.findIndex(e => e.name == newValue.name)
        if(index >= 0) {
            this.contactFiltersValue.splice(index, 1);
        }
        this.contactFiltersValue.push(newValue);
    }

    addToInteractionsFilters(newValue) {
        var index = this.interactionsFiltersValue.findIndex(e => e.name == newValue.name)
        if(index >= 0) {
            this.interactionsFiltersValue.splice(index, 1);
        }
        this.interactionsFiltersValue.push(newValue);
    }

    handleProducts(event){
        var product = this.mapProducts[event.detail.selectedValues];
        if(product) {
            this.selectedProduct = {id:event.detail.selectedValues, name:product.Product_Name__c};
        }
    }

    handleUsers(event){
        var user = this.mapUsers[event.detail.selectedValues];
        if(user) {
            this.selectedUser = {id:event.detail.selectedValues, name:user.Name};
        }
    }

    handleRemoveSelectedProduct() {
        this.selectedProduct = null;
    }

    handleRemoveSelectedUser() {
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
        var childFilters = this.findChildrenFilters(this.childModalTitle);
        var filtersTemp = [];
        for (var childFilter of childFilters) {
            var filter = {...childFilter};
            if (this.contactFiltersValue.find(e => e.name == childFilter.name)) {
                filter.checked = true;                
            } else {
                filter.checked = false;
            }
            filtersTemp.push(filter);
        }
        this.childModalFilters = filtersTemp;
        this.childModalOpened = true;
    }

    closeModalChild() {
        this.childModalOpened = false;
    }

    //Resets every filter to their initial state
    handleClickReset(event) {
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
        // Clear the variables
        this.contactFiltersValue = [];
        this.interactionsFiltersValue = [];
        this.selectedDateFrom = null;
        this.selectedProduct = null;
        this.selectedRating = 0;
        this.selectedProductInvested = false;
        this.myCompanyFilter = false;
        this.myTeamCompanyFilter = false;
    }

    //Builds the query and sends it to the audienceManagementDisplay component
    handleClickRun(event) {
        //If a product has been selected, build a query to retrieve the contact linked to these product interest
        if(this.selectedProduct || this.selectedDateFrom) {
            this.showSpinner = true;
            getContactFromProductInterest({request: this.buildQueryInterest()})
            .then(data => {                
                var query = this.baseQuery
                query += ' AND Id IN (';
                var firstId = true;
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
                    .then(data => {
                        query += ' AND AccountId IN (';
                        var firstCompany = true;
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
            query += ' Product__c=\'' + this.selectedProduct.id + '\'';
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

        if(this.selectedUser) {
            query += ' AND Account.OwnerId=\'' + this.selectedUser.id + '\'';
        }
        
        for (const contFilter of this.contactFiltersValue) {
            var filter = this.findFilter(contFilter.name);            
            query += ' AND ';
            if(filter.objectName != 'Contact') {
                query += filter.objectName + '.';
            }
            query += filter.fieldName;
            if(filter.isPicklist) {
                query += '=\'';
            } else if(filter.isText) {
                query += ' LIKE \'%'
            } else if(filter.isMultipicklist) {
                query += ' INCLUDES (\'';
            } else if(filter.isCheckbox) {
                query += '='
            } else {
                query += '>=';
            }

            if(filter.isMultipicklist) {
                query += contFilter.value.toString().replaceAll(',', '\',\'');
            } else {
                query += contFilter.value;
            }

            if(filter.isPicklist) {
                query += '\'';
            } else if(filter.isText) {
                query += '%\'';
            } else if(filter.isMultipicklist) {
                query += '\')';
            }         
        }
        if(this.interactionsFiltersValue.length > 0) {
            query += ' AND Id IN (SELECT Contact_lu__c FROM Digital_Interaction__c WHERE ';
            var first = true;
            for (const intFilter of this.interactionsFiltersValue) {
                if(first) {
                    first = false;
                } else {
                    query += ' AND ';
                }
                var filter = this.findFilter(intFilter.name);                
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
        return this.allFilters.find(e => e.name == name);
    }

    findChildrenFilters(parentName) {
        return this.allFilters.filter(e => e.parentName == parentName);
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