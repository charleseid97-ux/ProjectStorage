/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 29-09-2023
 * @last modified by  : Thanina YAYA
**/
import { LightningElement, api, track, wire} from 'lwc';
import { refreshApex } from '@salesforce/apex';
import saveProspaceAlerts from '@salesforce/apex/CTL_SearchSubscriptionProduct.saveProspaceAlerts';
import getAlertTypes from '@salesforce/apex/CTL_SearchSubscriptionProduct.getAlertTypes';
import getShareClassesByCountryWithSub from '@salesforce/apex/CTL_SearchSubscriptionProduct.getShareClassesByCountryWithSub';
import { getRecord } from 'lightning/uiRecordApi';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

const CONTACT_FIELDS = ['Contact.WebsiteCountry__c','Contact.TECH_WebSiteID__c']; 

export default class SearchSubscriptionProduct extends LightningElement {

    @api alertType = '';
    @api recordId;
    @api counter;
 
    defaultOpenStrat = [];
    defaultOpenFund = [];
    isLoading = true;
    searchKey;
    countryCode='';
    techContactId='';
    refreshRequired = null;
    @track mapFundCodeName;
    @track initGroupedData = [];
    @track selectedProducts={}; //to save only new selected products
    @track selectedAlerts={};
    @track existingSubscriptions={};
    @track newSubscriptions=[];
    @track results; //product tree Strat/Fund/shareClass
    @track mapAlertTypes={};
    @track errors;
    @track wiredResult = [];

    @api get showSpinner(){
        return this.isLoading;
    }
    get isNav(){
        let reg = new RegExp('Nav','gi');
        return (reg.test(this.alertType));
    }
    get isReport(){
        let reg = new RegExp('Report','gi');
        return (reg.test(this.alertType));
    }
    
    
    @wire (getAlertTypes,{cat:'$alertType'})
    alertsMeta({data,error}){
        if(data){
            let mapal = {};
            data.forEach(alert =>{
                mapal[alert.LWCLabel__c.toLowerCase()]={'label':alert.MasterLabel,'id':alert.DeveloperName,'webId':alert.WebsiteId__c};
            });
            this.mapAlertTypes = mapal;
        }else if(error){
            console.log(error);
        }
    }

    @wire (getRecord,{recordId:'$recordId',fields: CONTACT_FIELDS}) 
    contactInfo({data,error}){
        if (data && data.fields){
            this.countryCode = data.fields.WebsiteCountry__c?.value;
            this.techContactId = data.fields.TECH_WebSiteID__c?.value;
            console.log('@Cont Info:'+this.countryCode);
        }else if(error){
            console.log(error);
        }
    }
    @wire  (getShareClassesByCountryWithSub, {countryCode:'$countryCode' ,cat: '$alertType',contId:'$recordId', counter: '$counter'})
    wiredClasses(result){
        console.log('@counter: ' + this.counter);
        this.wiredResult = result;
        if(result.data){
            let helper = {};
            let groupFund = [];
            let alerts={};
            groupFund = result.data.reduce(function(r, o) {
            var key = o.Fund__c;
            alerts[o.Id] = {"daily":{"label":'Daily',"prospId":'','active':false,'checked':false},
                            "weekly":{"label":'Weekly',"prospId":'','active':false,'checked':false},
                            "monthly":{"label":'Monthly',"prospId":'','active':false,'checked':false}};
            
            let regD = new RegExp('daily','gi');
            let regW = new RegExp('weekly','gi');
            let regM = new RegExp('monthly','gi');
            let isDaily = false,  isWeekly = false, isMonthly = false;
            if(o.WebCommunications__r){
                o.WebCommunications__r.forEach(alert =>{
                    //check existing daily nav sub 
                    if((regD.test(alert.AlertType__c) || regD.test(alert.AlertTypeRecord__r?.Name)) && !isDaily){
                        alerts[o.Id].daily={"label":'Daily',"prospId":alert.Id,'active':alert.IsActive__c,'checked':alert.IsActive__c};
                        isDaily = true;
                    }
                    if((regW.test(alert.AlertType__c) || regW.test(alert.AlertTypeRecord__r?.Name)) && !isWeekly){
                        alerts[o.Id].weekly={"label":'Weekly',"prospId":alert.Id,'active':alert.IsActive__c,'checked':alert.IsActive__c};
                        isWeekly = true;
                    }
                    if((regM.test(alert.AlertType__c) || regM.test(alert.AlertTypeRecord__r?.Name)) && !isMonthly){
                        alerts[o.Id].monthly={"label":'Monthly',"prospId":alert.Id,'active':alert.IsActive__c,'checked':alert.IsActive__c};
                        isMonthly = true;
                    }
                    
                });
            }
            let newO = {"Id":o.Id,"Name":o.Name,"ISIN_Code__c":o.ISIN_Code__c,"alertTypes":alerts[o.Id]};
            if(!helper[key]) {
                helper[key] = Object.assign({"Id":o.Fund__c , "Code":o.Fund__r.Name , "Name":o.Fund__r.Product_Name__c,
                                            "Strategy":{"Id":o.Fund__r.Strategy__c,"Code":o.Fund__r.Strategy__r.Name,"Name":o.Fund__r.Strategy__r.Product_Name__c}
                                            }, {"products":[newO]}); // create a copy of o
                r.push(helper[key]);
            } else 
                (helper[key].products).push(newO);
            return r;
            }, []);
            this.selectedAlerts = alerts;
            //groupeByStrat
            this.results = groupFund.reduce(function(r, o) {
                var key = o.Strategy.Id;
                if(!helper[key]) {
                    helper[key] = Object.assign({"Id":o.Strategy.Id,"Code":o.Strategy.Code,"Name":o.Strategy.Name}, {"funds":[o]}); // create a copy of o
                    r.push(helper[key]);
                } else 
                    (helper[key].funds).push(o);
                return r;
                }, []);
            if(this.defaultOpenStrat.length === 0) {
                this.defaultOpenStrat.push(this.results[0]?.Id);
            }
            if(this.defaultOpenFund.length === 0) {
                this.defaultOpenFund.push(this.results[0]?.funds[0].Id);
            }
            this.initGroupedData= [...this.results];
            this.isLoading = false;
        } else if(result.error){
            this.isLoading = true;
            console.log(result.error);
        }
    }

    handleSeach(e){
        this.searchKey = e.target.value;
        if(this.searchKey.length > 0){
            let regex = new RegExp(e.target.value,'gi');
            let data = [];
            data = this.initGroupedData.filter(
                row => (regex.test(row.Name) || regex.test(row.Code))
            );
            this.results = [...data];
        }
        else{
            this.results = [...this.initGroupedData];
        }
    }

    handlePeriodSelection(e){
        console.log('@dataItem:'+JSON.stringify(this.selectedAlerts[e.target.name]));
        ((this.selectedAlerts[e.target.name])[e.target.value]).checked = e.target.checked;
        this.selectedProducts[e.target.name]={"shareClass":e.target.name,"fund":e.target.dataset.item,
            "alertType": this.selectedAlerts[e.target.name]};
        //add logique to create prospaceAlert here based on id period + compare between 
        console.log('@listProduct:'+JSON.stringify(this.selectedProducts));
    }
   
    dispachProspaceAlerts(event){
        event.preventDefault();
        // Creates the event with the contact ID data.
        const selectedEvent = new CustomEvent('createAlerts', { detail: this.selectedProducts});
        // Dispatches the event.
        this.dispatchEvent(selectedEvent);
    }
    @api handleSaveSubscriptions() {
        this.isLoading = true;
        let prospaceAlerts = [];
        for (let key in (this.selectedProducts)) {
            if (this.selectedProducts[key])
            {
                prospaceAlerts = prospaceAlerts.concat(this.createProspaceAlert(this.selectedProducts[key]));
            }
            
        }
        //call save apex
        if (prospaceAlerts.length > 0) {
            saveProspaceAlerts({alerts : prospaceAlerts})
            .then(() => {
                this.showToast('Subscriptions Updated', 'All subscriptions were successfully updated','success');
                this.isLoading = false;
                refreshApex(this.wiredResult);
                this.dispatchEvent(new CustomEvent('subscriptionssaved'));
                return true;
            }).catch(error => {
                console.log('@error: '+JSON.stringify(error));
                this.showToast('Subscriptions Not Updated', 'An error occured while updating your subscriptions. Please try again.', 'error');
                this.isLoading = false;
            });
        }
        else {
            this.isLoading = false;
        }
        return false;
    }
    cancelSubscriptions(){
        this.isLoading = true;
        this.results = [...this.initGroupedData];
        this.isLoading = false;
    }

    createProspaceAlert(prod){
        let prospaceAlerts = [];
        let alerts = prod.alertType;
        for(let key in alerts){
            if((alerts[key] && alerts[key].checked !== alerts[key].active)){
             
                if(alerts[key].prospId !== '') {
                    prospaceAlerts.push({
                                "ShareClass__c": prod.shareClass,
                                "Fund__c": prod.fund,
                                "Contact__c": this.recordId,
                                "AlertType__c":this.mapAlertTypes[key].webId,
                                "IsActive__c": alerts[key].checked,
                                "Id": alerts[key].prospId
                                });
                }
                else {
                    prospaceAlerts.push({
                    "ShareClass__c": prod.shareClass,
                    "Fund__c": prod.fund,
                    "Contact__c": this.recordId,
                    "AlertType__c":this.mapAlertTypes[key].webId,
                    "IsActive__c": alerts[key].checked
                    });
                }
            }
        }
        return prospaceAlerts;
    }

    expandAll() {
        let expandedFund = [];
        let expandedStrat = [];
        for (let strat in this.initGroupedData) {
            expandedStrat.push(this.initGroupedData[strat].Id);
            for (let fund in this.initGroupedData[strat].funds) {
                expandedFund.push(this.initGroupedData[strat].funds[fund].Id);
            }
        }
        this.defaultOpenFund = expandedFund;
        this.defaultOpenStrat = expandedStrat;
        console.log('The 2 following lines: expandAll');
        console.log(this.defaultOpenFund);
        console.log(this.defaultOpenStrat);
    }

    collapseAll() {
        this.defaultOpenStrat = [];
        this.defaultOpenFund = [];
    }

    showToast(title,message,variant) {
        const event = new ShowToastEvent({
            title: title,
            variant: variant,
            message: message
        });
        this.dispatchEvent(event);
    }
    
    handleSectionToggleStrat(event) {
        console.log('handle section toggle strat: ' + JSON.stringify(event.detail.openSections));
        console.log('handle strat: ' + JSON.stringify(this.defaultOpenStrat));
    }
    handleSectionToggleFund(event) {
        console.log('handle section toggle fund: ' + JSON.stringify(event.detail.openSections));
        console.log('handle fund: ' + JSON.stringify(this.defaultOpenFund));
    }

    @api forceRefresh() {
        refreshApex(this.wiredResult);
    }
}