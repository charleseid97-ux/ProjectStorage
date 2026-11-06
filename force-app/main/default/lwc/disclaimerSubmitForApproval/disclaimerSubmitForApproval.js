/**
 * @description Quick action LWC for submitting a Disclaimer__c record for approval.
 *              Renders the generic c-custom-approval-submit-screen with this process's settings. 
 *              Add new processes by copying this wrapper with a different processName rather than editing the generic screen.
 * @author Charles EID
 */
import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class DisclaimerSubmitForApproval extends LightningElement {

    @api recordId;

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}