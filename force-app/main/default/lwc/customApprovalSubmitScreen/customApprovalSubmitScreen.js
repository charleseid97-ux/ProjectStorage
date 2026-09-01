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
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
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
        this.requestClose();
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
                this.dispatchEvent(new RefreshEvent());
                this.requestClose();
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

    // The Quick Action wrapper (this component's parent) is the one actually registered as the lightning__RecordAction target, so it's the one that must dispatch CloseActionScreenEvent
    // That only works from the literal action component, not from a nested child. 
    // This component instead fires a plain "close" event that the parent listens for (onclose) and turns into the real CloseActionScreenEvent.
    requestClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}