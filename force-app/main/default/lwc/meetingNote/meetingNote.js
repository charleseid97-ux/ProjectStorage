/* eslint-disable @lwc/lwc/no-inner-html */
/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 28-09-2023
 * @last modified by  : Thanina YAYA
**/
import { LightningElement, track, api, wire } from 'lwc';
//standard LWC services
import { getRecord } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

//apex methods
import createRelatedObjects from '@salesforce/apex/CTL_MeetingNotes.createRelatedObjects';
import getContacts from '@salesforce/apex/CTL_MeetingNotes.getNeededContacts';
import getProducts from '@salesforce/apex/CTL_MeetingNotes.getProducts';
import getOpportunities from '@salesforce/apex/CTL_MeetingNotes.getOpportunities';
import getUsers from '@salesforce/apex/CTL_MeetingNotes.getUsers';
import getEmailTemplate from '@salesforce/apex/CTL_MeetingNotes.getEmailTemplate';
import sendEmailMeeting from '@salesforce/apex/CTL_MeetingNotes.sendEmailMeeting';
import getOrgId from '@salesforce/apex/CTL_MeetingNotes.getOrgId';
import getClientContacts from '@salesforce/apex/CTL_MeetingNotes.getClientContacts';

//custom labels
import MissingClientProduct from '@salesforce/label/c.MissingClientProduct';
import MissingProductRating from '@salesforce/label/c.MissingProductRating';
import MissingTaskInfos from '@salesforce/label/c.MissingTaskInfos';
import MissingDataTitle from '@salesforce/label/c.MissingDataTitle';


export default class MeetingNote extends LightningElement {

    @api recordId;
    @api objectApiName;
    @api dispLwc = false; // used in order to display this LWC in new tab app page

    @track currentContact={};
    @track internalContacts; //list of options to choose.
    @track externalContacts;
    @track allProducts;
    @track relatedOpportunity;
    @track allOpportunities;
    @track allUsers;
    @track allTasks = [{Description__c : '', ActivityDate:'', OwnerId:'',OwnerLabel:'',Index:0, IsDelete: false}];
    @track allContactShare;
    @track mapContacts = {};
    @track mapProducts = {};
    @track mapOpportunities = {};
    @track mapUsers = {};
    @track selectedClients = [];
    @track selectedInternals = [];
    @track selectedProducts = [];
    @track selectedOpportunities;
    @track selectedContactShare =[];
    @track clientPills=[];
    @track internalPills=[];
    @track clientInterest = [];
    @track oppMeetingNote = []; //to delete
    @track contactPills =[];
    @track meetingNote = {id :'' , Name:'', Date__c: new Date()};
    @track emailTemplate;
    @track prevSelectedCont = [];
    @track allSelectedClients = [];

    @track taskObjects = [];
    openSections = ["Attende","MeetingType","Note","FollowUP","Share"];
    meetingDate = new Date();
    meetingName = '';
    oppportunityId = '';
    isSalesPres = true;
    isRelatMgt = false;
    meetingTopic = '';
    meetingNotes = '';
    companyName='';
    companyOwner={};
    quickActionName='';
    isLoading = true;
    isrendered = false;
    shareToCarmi = true;
    orgId = ''; //Used for rating image in assets
    emailTempName = 'MeetingNoteEmail'; //Email template Name
    productSearchFields = ['code'];
    oppSearchFields = ['Name'];
    clientSearchKey = '';
    currentIter = 1;
    nextIter = 1;
    errorMessage = '';

    get title(){
        return ((this.quickActionName.indexOf('NewMeetingNote') > -1)?'Meeting Note':(this.quickActionName.indexOf('NewCallNote') > -1)?'Call Note':'Event Note');
    }
    get meetingType(){
        return ((this.quickActionName.indexOf('NewMeetingNote') > -1)?'Meeting':(this.quickActionName.indexOf('NewCallNote') > -1)?'Call':'Event');
    }
    get initialMeetingName(){
        return this.meetingType;
    }
    get fieldsList(){
        if(this.objectApiName==='Contact') 
        return ['Contact.Email','Contact.AccountId','Contact.Name','Contact.Id','Contact.Account.Name','Contact.Account.OwnerId','Contact.Account.Owner.Name'];
        return ['Account.Id','Account.Name','Account.OwnerId','Account.Owner.Name'];
    }
    get companieId(){
        if(this.objectApiName === 'Contact') 
        return this.currentContact.AccountId;
        return this.recordId;
    }
    get taskRequiered(){
        return this.isSalesPres;
    }
    
    @wire(CurrentPageReference)
    getQuickActionName(currentPageReference) {        
     //if the page is a quick action, get quick action API name
     if(currentPageReference && (currentPageReference?.type === 'standard__quickAction')) {
         this.quickActionName = currentPageReference.attributes?.apiName;
     }
    }

    @wire (getRecord,{recordId:'$recordId',fields: '$fieldsList'}) 
    contactInfo({data,error}){
        if (data && data.fields){
            if(this.objectApiName === 'Contact'){
                this.currentContact = {Id:data.fields.Id?.value,Email:data.fields.Email?.value,Name:data.fields.Name?.value,AccountId:data.fields.AccountId?.value};
                this.companyName = data.fields?.Account?.displayValue;
                this.companyOwner = {id:data.fields.Account?.value?.fields?.OwnerId?.value,name:data.fields.Account?.value?.fields?.Owner?.displayValue};
                //select this first contact
                let mapCont=Object.assign({},this.mapContacts);
                mapCont[this.currentContact.Id] = Object.assign({},this.currentContact);
                this.mapContacts = mapCont;
                this.selectedClients.push(this.currentContact.Id);
                this.prevSelectedCont.push(this.currentContact.Id);
                this.allSelectedClients.push(this.currentContact.Id);
                this.clientPills = [...this.contactsPills(this.selectedClients,'standard:contact')];
            } 
            else {
                this.companyName = data.fields.Name?.value;
                this.companyOwner = {id:data.fields.OwnerId?.value,name:data.fields.Owner?.displayValue};
            }
            this.allTasks[0] = {Description__c : '', ActivityDate:this.formateDate(new Date()), 
                            OwnerId:this.companyOwner.id,OwnerLabel:this.companyOwner.name,Index:0, IsDelete: false};
        }else if(error){
            console.log('@Error: Get Contact&Company',error); 
        }
    }
    //get only Carmignac Contacts.
    @wire (getContacts) 
    allContacts({data,error}){
        if(data && data.length){
            let internal=[];
            let mapCont=Object.assign({},this.mapContacts);
            data.forEach(cont =>{
                if(cont.Account.Name === 'CARMIGNAC') internal.push({label:cont.Name,value:cont.Id});
                mapCont[cont.Id] = Object.assign({},cont);
            });
            this.internalContacts = [...internal];
            this.allContactShare = [...internal];
            this.mapContacts = mapCont;

        }else if(error){ 
            console.log('@Error: Get Carmignac Contacts',error);
        }
    }
    //get client Contacts using searchKey
    @wire (getClientContacts,{searchKey:'$clientSearchKey',selectedIds: '$allSelectedClients'}) 
    allClientContacts({data,error}){
        if(data && data.length){
            this.prevSelectedCont = [...new Set([...this.prevSelectedCont,...this.selectedClients])];
            this.selectedClients = [];
            console.log('@@prev selected:'+JSON.stringify(this.prevSelectedCont));
            let external=[];
            let mapCont=Object.assign({},this.mapContacts);
            data.forEach(cont =>{
                external.push({label:cont.Name,value:cont.Id});
                mapCont[cont.Id] = Object.assign({},cont);
            });
            this.externalContacts = [...external];
            this.mapContacts = mapCont;

        }else if(error){
            console.log('@Error: Get Carmignac Contacts',error);
        }
    }

    @wire (getOpportunities,{statFilter:''})
    opportunities({data,error}){
        if(data && data.length){ 
            let opportunities =[];
            let mapOpportunities = {};
            data.forEach(opp =>{
                opportunities.push({label:opp.Name,value:opp.Id});
                mapOpportunities[opp.Id] = opp;
            });
            this.allOpportunities = [...opportunities];
            this.mapOpportunities = mapOpportunities;
        }
        else if(error){
            console.log('@Error: Get Products',error);
        }
    }

    @wire (getProducts,{statFilter:''})
    products({data,error}){
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
        else if(error){
            console.log('@Error: Get Products',error);
        }
    }
    
    @wire (getUsers)
    users({data,error}){
        if(data && data.length){
            let users =[];
            let mapUsers= {};
            data.forEach(user =>{
                users.push({label:user.Name,value:user.Id});
                mapUsers[user.Id] = user;
            });
            this.allUsers = [...users];
            this.mapUsers = mapUsers;
        }
        else if(error){
            console.log('@Error: Get Users',error);
        }
    }

    @wire (getEmailTemplate,{name : '$emailTempName'})
    templateMail({data,error}){
        if(data){
            this.emailTemplate = data;
        }
        else if(error){
            console.log('@Error: Get Template Email',error);
        }
    }

    @wire (getOrgId)
    wireOrgId({data,error}){
        if(data) this.orgId = data;
        else if(error){
            console.log('@Error: Get Org ID',error);
        }
    }

    connectedCallback() {
       let todayDate = new Date();
        this.meetingDate=this.formateDate(todayDate);
        this.meetingName = this.initialMeetingName;
        this.isLoading = false;
    }

    handleFieldChange(evt){
        switch (evt.target.fieldName)
        {
            case 'Date__c': 
                this.meetingDate = evt.target.value;
                break;
            case 'Name':
                this.meetingName = evt.target.value;
                break;
            case 'Note__c':
                this.meetingNotes = evt.target.value;
                break;
            case 'Topic__c':
                this.meetingTopic = evt.target.value;
                break;
            default:
                //do nothing
        }
    }
    handleMeetingType(evt){
        if(evt.target.dataset.item === "SalesPresentation__c") {
            this.isSalesPres = evt.target.value;
            this.isRelatMgt = !this.isSalesPres;
        }
        else {
            this.isRelatMgt = evt.target.value;
            this.isSalesPres = !this.isRelatMgt;
        }
    }
    handleSectionToggle(event){
        console.log(JSON.stringify(event.detail.openSections));
    }
    
    checkMandatory(){
        let allOK= true;
        this.errorMessage = '';
        if(!(this.clientPills.length > 0) || (!(this.clientInterest.length > 0) && this.isSalesPres)) {
            this.errorMessage = MissingClientProduct;
            allOK = false;
        }
        if(this.isSalesPres){
            //check clientInterest part
            console.log('@@@MeetingNote: '+JSON.stringify(this.clientInterest));
            if(this.clientInterest.length > 0){
                this.clientInterest.forEach(interest => {
                    if(!(interest.rating > 0)) {
                        this.errorMessage = MissingProductRating;
                        allOK = false;
                    }
                });
            }
            //check follow up task
            if(!(this.allTasks[0].Description__c) || !(this.allTasks[0].ActivityDate) || !(this.allTasks[0].OwnerId)){
                this.errorMessage = MissingTaskInfos;
                allOK = false; 
            }
        }
        return allOK;
    }
    handleSubmit(event){
        event.preventDefault();
        let fields = event.detail.fields;
        fields.Meeting_Type__c = this.meetingType ;
        fields.Company__c = this.companieId;
        //check the requiered fields and section here before submit 
            if(this.checkMandatory()){
                    this.isLoading = true;
                    this.template.querySelector('lightning-record-edit-form').submit(fields);
            } else{
                const evt = new ShowToastEvent({
                    title: MissingDataTitle,
                    message: this.errorMessage,
                    variant: 'error',
                    mode: 'sticky'
                });
                this.dispatchEvent(evt); 
            }    
    }
     handleCancel()
     {
        this.dispatchEvent(new CloseActionScreenEvent());
     }
     handleError(evt){
        this.isLoading = false;
        console.log('@Error: Save Meeting Note: '+JSON.stringify(evt.detail));
        this.showToast(JSON.stringify(evt.detail), 'Error', 'Error: Save Meeting Note');  
     }
     handleSuccess(event){
        //create related Object;
        event.preventDefault();
        let allAttende = [...this.allSelectedClients];
        allAttende.splice(0, 1); //omit first client contact represtent the who of the event , so by default this will create an event relation for this one
        //All client and carmi attendees
        if(this.selectedInternals.length > 0) allAttende = allAttende.concat(this.selectedInternals);
        this.meetingNote = {id: event.detail.id,Name: event.detail?.fields?.Name.value, Date__c: new Date(event.detail?.fields?.Date__c.value)};
        //Event Miror Information 
        const today = new Date();
        let eventDate = new Date((this.meetingNote.Date__c).getFullYear(), (this.meetingNote.Date__c).getMonth(), 
        (this.meetingNote.Date__c).getDate(), today.getHours(), today.getMinutes(), today.getSeconds(), today.getMilliseconds());
        let eventEnd = new Date((this.meetingNote.Date__c).getFullYear(), (this.meetingNote.Date__c).getMonth(), 
        (this.meetingNote.Date__c).getDate(), today.getHours(), (today.getMinutes()) + 30, today.getSeconds(), today.getMilliseconds());
        let evtSalesforce = {   StartDateTime: eventDate.toISOString(),
                                EndDateTime: eventEnd.toISOString(),
                                Subject: this.meetingNote.Name,
                                Meeting_Note__c: this.meetingNote.id,
                                WhoId: this.allSelectedClients[0],
                                WhatId: this.companieId
                            };
        //Create client interest only in case of salesPresentation Meeting...
        let interestObject = [];
        if(this.isSalesPres){
            this.clientInterest.forEach(interest => {
                if(interest.rating && interest.rating > 0 )
                 interestObject.push({Interest__c:interest.rating,MeetingNote__c:this.meetingNote.id,Product__c:interest.id});
            });
        }
        //Task part need to check that all fields are filled up ...
        this.allTasks.forEach(task => {
            if(task.Description__c.length && task.ActivityDate && task.OwnerId.length)
                this.taskObjects.push({Subject: `follow up - ${this.meetingType} - ${this.companyName}`, Description__c: task.Description__c, 
                              ActivityDate: task.ActivityDate, WhatId:this.meetingNote.id, 
                              OwnerId: task.OwnerId, OwnerLabel: task.OwnerLabel,
                              Priority: 'Normal',Type: `Follow Up ${this.meetingType}`});
        });
        //Call apex to create related records....
        createRelatedObjects({ evt: evtSalesforce,participants:allAttende, prodInterest: interestObject, tasks: this.taskObjects})
            .then((result) => {
                if(result.success){
                    result.objectList.forEach(task => {
                        this.taskObjects.forEach(taskObj => {
                            if ( taskObj.Description__c == task.Description__c
                                && taskObj.Subject == task.Subject
                                && taskObj.WhatId == task.WhatId
                                && taskObj.OwnerId == task.OwnerId ) {
                                    taskObj.Id = task.Id;
                            }
                        });
                    });
                    this.isLoading = false;
                    const evt = new ShowToastEvent({
                        title: this.title+' Created',
                        "message": "Record {0} created! with related records See it {1}!",
                        "messageData": [
                        'Salesforce',
                            {
                                url: '/'+this.meetingNote.id,
                                label: 'here'
                            }
                        ],
                        variant: 'success',
            
                    });
                    this.dispatchEvent(evt);
                    //***send Summary email here , Once all related records to meeting note are successfully created***
                    
                    //Send Email To shared part
                    let shareWith = [];
                    if(this.shareToCarmi) shareWith = [...this.selectedInternals];
                    shareWith = [...new Set([...shareWith, ...this.selectedContactShare])];
                    let contShareList = [];
                    shareWith.forEach(shareCont => {
                        contShareList.push(this.mapContacts[shareCont]);
                    });
                    let tmpEmail = {};
                    if(shareWith.length > 0 ) tmpEmail = {HtmlValue : this.buildEmail(this.emailTemplate.HtmlValue), Subject : this.emailTemplate.Subject, EnhancedLetterheadId : this.emailTemplate.EnhancedLetterheadId};

                    if(shareWith.length > 0 ){
                        
                        sendEmailMeeting({et:tmpEmail,participants:contShareList ,meetingNoteId: this.meetingNote.id})
                        .then((res) => {
                            if(res) console.log('@Email send with success OK:',res);
                            else{
                                console.log('@Error: Send Email Apex: check debug logs');
                            }
                        })
                        .catch((error) => {
                            this.showToast(error?.body?.message, 'Error', 'Error: Send Email Apex'); 
                        });
                    }
                    //***End send Email***/
                    this.dispatchEvent(new CloseActionScreenEvent());
                    // eslint-disable-next-line no-eval
                    eval("$A.get('e.force:refreshView').fire();"); //to refresh view, instead of reloading page. 
                }else {
                    this.isLoading = false;
                    this.showToast('Technical Issue During MeetingNote related Record Creation, Please Contact an Admin', 'Error', 'Error: Related MeetingNote Objects Creation');
                }
            })
            .catch((error) => {
                this.isLoading = false;
                console.log('@Error: Related MeetingNote Objects',error);
                this.showToast(error?.body?.message, 'Error', 'Error: Related MeetingNote Objects');
            });
     }
    
    handleClients(e){
        this.clientSearchKey = e.detail.searchKey;
        this.selectedClients = [...e.detail.selectedValues];
        this.allSelectedClients = [...new Set([ ...this.prevSelectedCont,...this.selectedClients])];
        this.clientPills = [...this.contactsPills(this.allSelectedClients,'standard:contact')];
    }
    handleInternal(e){
        this.selectedInternals = [...e.detail.selectedValues];
        this.internalPills = [...this.contactsPills(this.selectedInternals,'standard:user')];
    }
    handleProducts(e){
        //construct Pills part
        this.selectedProducts = [...e.detail.selectedValues];
        let items= [];
        console.log('@ClientInterestBefor: '+JSON.stringify(this.clientInterest));
        e.detail.selectedValues.forEach((prod,index) =>{
            const indCurrent = this.clientInterest.findIndex(elm => elm.id === prod);
            const ratProd = (indCurrent > -1)? this.clientInterest[indCurrent].rating:0;
            const picProd = (indCurrent > -1)? this.clientInterest[indCurrent].pic:'stars_000';
            items.push({id: prod,
                        index: index,
                        label: this.mapProducts[prod].Product_Name__c,
                        name: prod,
                        icon: 'custom:custom5',
                        alternativeText: this.mapProducts[prod].Name,
                        href: '/'+prod,
                        pic: picProd,
                        rating:ratProd
                    });
        });
        console.log('@ClientInterestafter items: '+JSON.stringify(items));
        this.clientInterest= [...items];
    }
    handleRating(e){
        //e.preventDefault();
        this.clientInterest[e.target.dataset.item].rating = e.detail;
        switch (e.detail)
        {
            case 1:
                this.clientInterest[e.target.dataset.item].pic = "stars_100";
                break;
            case 2:
                this.clientInterest[e.target.dataset.item].pic = "stars_200";
                break;
            case 3:
                this.clientInterest[e.target.dataset.item].pic = "stars_300";
                break;
            case 4:
                this.clientInterest[e.target.dataset.item].pic = "stars_400";
                break;
            case 5:
                this.clientInterest[e.target.dataset.item].pic = "stars_500";
                break;
            default: 
                this.clientInterest[e.target.dataset.item].pic = "stars_000";
        }
    }
   
    handleItemRemove(e){
        let origin = e.target.dataset.item;
        const index = e.detail.index;
        if(origin === 'Client'){
            this.clientPills.splice(index, 1);
            let deletedElm = this.allSelectedClients.splice(index,1); //it will hold one value, on elem will be deleted
            const indCurrent = this.selectedClients.findIndex(elm => elm === deletedElm[0]);
            if(indCurrent > -1) this.selectedClients.splice(indCurrent,1);
            const indPrev = this.prevSelectedCont.findIndex(elm => elm === deletedElm[0]);
            if(indPrev > -1) this.prevSelectedCont.splice(indPrev,1);
        }else if(origin === 'Internal'){
                this.internalPills.splice(index, 1);
                this.selectedInternals.splice(index,1);
        }else if(origin == 'Opportunity') {    // to delete    
            this.oppMeetingNote.splice(index,1);
            this.selectedOpportunities.splice(index,1);
        }
        else{
                this.contactPills.splice(index,1);
                this.selectedContactShare.splice(index,1);
            }
        
    }
    handleAddTask(){
        let allTasks = [...this.allTasks];
        let nbTasks = this.allTasks.length;
        allTasks[(nbTasks - 1)].IsDelete = false; 
        allTasks.push({Description__c : '', ActivityDate:this.formateDate(new Date()), OwnerId:this.companyOwner.id,OwnerLabel:this.companyOwner.name,Index:nbTasks,IsDelete : true});
        this.allTasks = [...allTasks];
    }
    handleTaskFields(e){
        let indexTask = e.target.dataset.id;
        if(e.target.name === "taskDes") this.allTasks[indexTask].Description__c = e.target.value;
        else  this.allTasks[indexTask].ActivityDate = e.target.value;

    }
    handleUsers(e){
        let index = e.target.dataset.id;
        this.allTasks[index].OwnerId = e.detail.selectedValues;
        this.allTasks[index].OwnerLabel = e.detail.selectedLabel;
    }
    handleRemoveSelectedUser(e){
        let index = e.target.dataset.id;
        this.allTasks[index].OwnerId = '';
        this.allTasks[index].OwnerLabel = '';
    }
    handleOpportunity(e){
        this.oppportunityId = e.detail.selectedValues;
        // this.allTasks[index].OwnerLabel = e.detail.selectedLabel;
    }
    handleRemoveSelectedOpp(e){
        this.oppportunityId = '';
    }
    handleDeleteTask(e){
        let index = e.target.dataset.id;
        this.allTasks.splice(index,1);
        if(index - 1 !== 0 ) this.allTasks[(index - 1)].IsDelete = true;
    }
    handleShareCarmi(e){
        this.shareToCarmi = e.target.checked;
    }
    handleShareOther(e){
        this.selectedContactShare = [...e.detail.selectedValues];
        this.contactPills = [...this.contactsPills(this.selectedContactShare,'standard:user')];
    }
    // Utility methods
    formateDate(dd){
        const dateStr = new Intl.DateTimeFormat('en', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        })
        const [{value: mo}, , {value: da}, , {value: ye}] = dateStr.formatToParts(dd);

     return `${ye}-${mo}-${da}`;
    }
    contactsPills(allCont,icon){
        let items= [];
        allCont.forEach(cont =>{
            items.push({type: 'icon',
                        label: this.mapContacts[cont].Name,
                        name: cont,
                        iconName: icon,
                        alternativeText: 'contact',
                        isLink: true,
                        href: '/'+cont
                    });
        });
        return items;
    }
    orderContactList(contacts){
      contacts.sort((a, b) =>  ((a.label < b.label)? -1 : ((a.label > b.label)? 1 : 0)));
    }

    //build email body
    buildEmail(emailTemplateBasic){
        // Create a new DOMParser
        const parser = new DOMParser();
        let orgUrl = window.location.origin;
        // Parse the element string
        const doc = parser.parseFromString(emailTemplateBasic, 'text/html');
        //client Attendees...
        const elmClient = doc.getElementById('companyAttList');
        elmClient.replaceChildren();
        this.clientPills.forEach(parti => {
            let newNode = doc.createElement("li");
            newNode.innerText = parti.label ;
            elmClient?.appendChild(newNode);
        });

        //Carmi Attendees...
        const elmCarmi = doc.getElementById('carmiAttList');
        elmCarmi.replaceChildren();
        this.internalPills.forEach(parti => {
            let newNode = doc.createElement("li");
            newNode.innerText = parti.label ;
            elmCarmi?.appendChild(newNode);
        });

        //Client Interest...
        if(this.isSalesPres){
            const elmInterest = doc.getElementById('interestLines');
            this.clientInterest.forEach(inter => {
                let imgUrl = orgUrl + "/file-asset-public/"+inter.pic+"?oid="+this.orgId;
                let newNode = doc.createElement("tr");
                newNode.innerHTML = `<td><span>${inter.label}</span></td>
                <td><span><img alt=${inter.pic} src=${imgUrl} title=${inter.pic}/> </span></td>` ;
                elmInterest?.appendChild(newNode);
            });
        }else{
            const interestHead = doc.getElementById('interestTableHeader');
            interestHead?.remove();
            const interestTable = doc.getElementById('interestTable');
            interestTable?.remove();
        }
        
        if(this.isSalesPres){
            const elmTask = doc.getElementById('taskTable');
            this.taskObjects.forEach(task => {
                let newNode = doc.createElement("tr");
                let taskURL = orgUrl+ '/'+task.Id;
                console.log('task',task);
                console.log('taskURL',taskURL,'task.Id', task.Id);
                newNode.innerHTML = `<td><span><a href="${taskURL}"> ${task.Subject}</a></span></td>
                <td><span>${task.Description__c} </span></td>
                <td><span>${task.ActivityDate} </span></td>
                <td><span>${task.OwnerLabel} </span></td>` ;
                elmTask?.appendChild(newNode);
            });
        }else{
            const taskHead = doc.getElementById('taskTableHeader');
            taskHead?.remove();
            const taskTable = doc.getElementById('taskTable');
            taskTable?.remove();
        }
        return (`<html style="overflow-y: hidden;">${doc.documentElement.innerHTML}</html>`);
    }

    showToast(message, variant, title) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        });
        this.dispatchEvent(evt);
    }


}