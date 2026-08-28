/**
 * @description Shared approval action modal for customApprovalHistory and customApprovalInbox.
 *              Owns the processApproval Apex call and all action logic.
 *              Dispatches 'close' on dismissal and 'actioncomplete' on success.
 * @author Charles EID
 */
import { LightningElement, api } from 'lwc';
import { reduceError } from 'c/gridBuilderUtils';
import processApproval from '@salesforce/apex/CustomApprovalHistoryController.processApproval';

export default class CustomApprovalActionModal extends LightningElement {

    // ── Public API ──────────────────────────────────────────────────────────
    @api selectedRow = null; // { stepId, displayTitle, isPending, canApproveOrReject, nextApproverSource, ...optionalDetailFields }
    @api canRecall   = false;
    @api isOpen      = false;

    // ── Internal state ──────────────────────────────────────────────────────
    isActionLoading = false;
    actionError     = null;
    modalComments   = '';
    nextApproverIds = [];

    // ── Getters ─────────────────────────────────────────────────────────────
    get showDetailSection()     { return !!(this.selectedRow && this.selectedRow.stepName); }
    get showApproveReject()     { return !!(this.selectedRow && this.selectedRow.isPending && this.selectedRow.canApproveOrReject); }
    get showRecall()            { return this.canRecall; }
    get showNextApproverInput() { return !!(this.selectedRow && this.selectedRow.nextApproverSource === 'UserInput'); }
    get showInputs()            { return !!(this.selectedRow && this.selectedRow.isPending); }

    // ── Action handlers ─────────────────────────────────────────────────────
    handleApprove() {
        this._submitAction('Approve', this.modalComments, this.nextApproverIds);
    }

    handleReject() {
        this._submitAction('Reject', this.modalComments, []);
    }

    handleRecall() {
        this._submitAction('Removed', this.modalComments, []);
    }

    handleClose() {
        this._reset();
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleNextApproverChange(event) {
        const id = event.detail && event.detail.recordId;
        this.nextApproverIds = id ? [id] : [];
    }

    handleCommentChange(event) {
        this.modalComments = event.target.value;
    }

    // ── Private ─────────────────────────────────────────────────────────────
    _submitAction(action, comments, nextApproverIds) {
        if (!this.selectedRow || !this.selectedRow.stepId) return;

        this.isActionLoading = true;
        this.actionError     = null;

        processApproval({
            workItemId      : this.selectedRow.stepId,
            action          : action,
            comments        : comments || null,
            nextApproverIds : nextApproverIds || []
        })
        .then(result => {
            if (result.success) {
                this._reset();
                this.dispatchEvent(new CustomEvent('actioncomplete', { detail: { action } }));
            } else {
                this.actionError = result.errorMessage || 'An error occurred.';
            }
        })
        .catch(error => {
            this.actionError = reduceError(error);
        })
        .finally(() => {
            this.isActionLoading = false;
        });
    }

    _reset() {
        this.isActionLoading = false;
        this.actionError     = null;
        this.modalComments   = '';
        this.nextApproverIds = [];
    }
}