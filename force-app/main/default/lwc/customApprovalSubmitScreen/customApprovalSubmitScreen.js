/**
 * @description Generic reusable submission screen for custom approval processes.
 *              Displays an optional title, a comment textarea, and a Submit button.
 *              Calls CustomApprovalHistoryUtility.submitForApproval on the server.
 *              Fully driven by @api inputs; consumed by process-specific Quick
 *              Action wrapper components (e.g. gridSubmitAmendmentForApproval)
 *              rather than being a Quick Action target itself.
 * @author Charles EID
 */
import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitForApproval from '@salesforce/apex/CustomApprovalHistoryUtility.submitForApproval';

export default class CustomApprovalSubmitScreen extends LightningElement {

    @api recordId;
    @api processName;
    @api modalTitle = 'Submit for Approval';
    @api commentsLabel = 'Comments';
    @api commentsPlaceholder = 'Enter approval comments (optional)';
    @api submitLabel = 'Submit';
    @api cancelLabel = 'Cancel';
    @api successToastTitle = 'Success';
    @api successMessage = 'Record submitted for approval.';
    @api defaultErrorMessage = 'Submission failed.';

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

        submitForApproval({ recordId: this.recordId, processName: this.processName, comments: this.comments || null }).then(result => {
            if (result.success) {
                this.dispatchEvent(new ShowToastEvent({
                    title   : this.successToastTitle,
                    message : this.successMessage,
                    variant : 'success'
                }));
                this.dispatchEvent(new CloseActionScreenEvent());
            } else {
                this.errorMessage = result.errorMessage || this.defaultErrorMessage;
            }
        }).catch(error => {
            this.errorMessage = (error.body && error.body.message) ? error.body.message
                                : (error.message || 'An error occurred.');
        }).finally(() => {
            this.isLoading = false;
        });
    }
}