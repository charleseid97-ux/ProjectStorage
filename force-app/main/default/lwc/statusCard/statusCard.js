import { LightningElement, api, wire , track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import PROJECT_STATUS from '@salesforce/schema/ProjectProduct__c.ProjectStatus__c'
import STATUS_COMMENT from '@salesforce/schema/ProjectProduct__c.StatusComment__c'
import STATUS_DATE from '@salesforce/schema/ProjectProduct__c.Tech_DateChangementStatus__c'
import LAUNCH_DATE from '@salesforce/schema/ProjectProduct__c.EndDate__c'
export default class StatusCards extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track projectStatus;
    @track commentStatus;
    @track dateStatus;
    @track launchdate;
    @api closedDate;
    @api closedComment;
    @api color;

     get fields(){
            return [PROJECT_STATUS , STATUS_COMMENT ,STATUS_DATE , LAUNCH_DATE];
        }

        @wire(getRecord , {
            recordId: '$recordId',
            fields: '$fields'
        })
        loadData({error, data}){
            if(data){
                  this.projectStatus = getFieldValue(data,PROJECT_STATUS);
                  this.commentStatus = getFieldValue(data,STATUS_COMMENT);
                  this.dateStatus = getFieldValue(data,STATUS_DATE);
                  this.launchdate = getFieldValue(data,LAUNCH_DATE);
            } else if(error){
                console.log('error'+error.message + error.body);
            }
        }

        get isClosed() {
            return this.projectStatus === 'Closed';
        }
    
        get isOnHold() {
            return this.projectStatus === 'On hold';
        }
    
        get isCancelled() {
            return this.projectStatus === 'Cancelled';
        }
   
}