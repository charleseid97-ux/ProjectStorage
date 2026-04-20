/**
 * @description Quick action LWC for submitting a Grid__c record for approval.
 *              Displays a comment textarea and a Submit button.
 *              Calls CustomApprovalHistoryUtility.submitForApproval on the server.
 * @author Charles EID
 */
import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitForApproval from '@salesforce/apex/CustomApprovalHistoryUtility.submitForApproval';

const PROCESS_NAME = 'GridAmendmentRequestApproval';

export default class GridSubmitForApproval extends LightningElement {

    @api recordId;

    comments     = '';
    isLoading    = false;
    errorMessage = null;

    handleCommentsChange(event) {
        this.comments = event.target.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSubmit() {
        this.isLoading    = true;
        this.errorMessage = null;

        submitForApproval({ recordId: this.recordId, processName: PROCESS_NAME, comments: this.comments || null }).then(result => {
            if (result.success) {
                this.dispatchEvent(new ShowToastEvent({
                    title   : 'Success',
                    message : 'Record submitted for approval.',
                    variant : 'success'
                }));
                this.dispatchEvent(new CloseActionScreenEvent());
            } else {
                this.errorMessage = result.errorMessage || 'Submission failed.';
            }
        }).catch(error => {
            this.errorMessage = (error.body && error.body.message) ? error.body.message
                                : (error.message || 'An error occurred.');
        }).finally(() => {
            this.isLoading = false;
        });
    }
}