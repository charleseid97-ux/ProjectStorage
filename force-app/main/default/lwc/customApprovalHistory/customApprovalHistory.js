/**
 * @description Custom Approval History LWC — generic approval history table for any SObject record page.
 *              Displays full history across all ProcessInstance attempts with Approve / Reject / Recall actions.
 *              Uses imperative Apex calls (no @wire). Step config driven by ApprovalStepConfig__mdt.
 * @author Charles EID
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { reduceError } from 'c/gridBuilderUtils';
import getApprovalHistory from '@salesforce/apex/CustomApprovalHistoryController.getApprovalHistory';
import processApproval from '@salesforce/apex/CustomApprovalHistoryController.processApproval';

const STATUS_CLASS_MAP = {
    Approved  : 'status-approved',
    Rejected  : 'status-rejected',
    Pending   : 'status-pending',
    Started   : 'status-started',
    Submitted : 'status-started'
};

export default class CustomApprovalHistory extends LightningElement {

    // ── Public API ──────────────────────────────────────────────────────────
    _recordId;
    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        if (value) { this.loadData(); }
    }

    // ── State ───────────────────────────────────────────────────────────────
    @track rows          = [];
    isLoading            = false;
    errorMessage         = null;
    canApproveOrReject   = false;
    canRecall            = false;
    processStatus        = null;

    isModalOpen          = false;
    selectedRow          = null;
    isActionLoading      = false;
    actionError          = null;
    nextApproverIds      = [];
    modalComments        = '';

    // ── Getters ──────────────────────────────────────────────────────────────
    get hasRows()           { return this.rows && this.rows.length > 0; }
    get hasError()          { return !!this.errorMessage; }
    get hasProcessStatus()  { return !!this.processStatus; }
    get headerTitle()       { return `Approval History (${(this.rows || []).length})`; }

    get showModalApproveReject() {
        return this.selectedRow && this.selectedRow.isPending && this.canApproveOrReject;
    }
    get showModalRecall() {
        return this.canRecall;
    }
    get showNextApproverInput() {
        return this.selectedRow && this.selectedRow.nextApproverSource === 'UserInput';
    }
    get showModalInputs() {
        return this.selectedRow && this.selectedRow.isPending;
    }

    // ── Data Loading ─────────────────────────────────────────────────────────
    loadData() {
        if (!this._recordId) return;
        this.isLoading    = true;
        this.errorMessage = null;

        getApprovalHistory({ recordId: this._recordId })
            .then(result => {
                this.rows = (result.rows || [])
                    .map(row => ({ ...row, statusClass: STATUS_CLASS_MAP[row.status] || '' }))
                    .sort((a, b) => {
                        const diff = new Date(b.stepDate) - new Date(a.stepDate);
                        if (diff !== 0) return diff;
                        // Tiebreaker: pending work items float to the top
                        return (b.isPending ? 1 : 0) - (a.isPending ? 1 : 0);
                    });
                this.canApproveOrReject = result.canApproveOrReject;
                this.canRecall          = result.canRecall;
                this.processStatus      = result.processStatus;
            })
            .catch(error => {
                this.errorMessage = reduceError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRefresh() {
        this.loadData();
    }

    // ── Header Buttons ────────────────────────────────────────────────────────
    handleHeaderApprove() {
        const firstPending = this._firstPendingRow();
        if (firstPending) this._openModal(firstPending);
    }

    handleHeaderReject() {
        const firstPending = this._firstPendingRow();
        if (firstPending) this._openModal(firstPending);
    }

    handleHeaderRecall() {
        const firstPending = this._firstPendingRow();
        if (firstPending) this._openModal(firstPending);
    }

    // ── Table Row Click ───────────────────────────────────────────────────────
    handleRowClick(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const row = this.rows.find(r => r.id === rowId);
        if (row) this._openModal(row);
    }

    // ── Modal Actions ─────────────────────────────────────────────────────────
    handleModalApprove() {
        this._submitAction('Approve', this.modalComments, this.nextApproverIds);
    }

    handleModalReject() {
        this._submitAction('Reject', this.modalComments, []);
    }

    handleModalRecall() {
        this._submitAction('Removed', this.modalComments, []);
    }

    handleModalClose() {
        this.isModalOpen     = false;
        this.selectedRow     = null;
        this.nextApproverIds = [];
        this.modalComments   = '';
        this.actionError     = null;
    }

    handleNextApproverChange(event) {
        const id = event.detail && event.detail.recordId;
        this.nextApproverIds = id ? [id] : [];
    }

    handleModalCommentChange(event) {
        this.modalComments = event.target.value;
    }

    // ── Private Helpers ───────────────────────────────────────────────────────
    _firstPendingRow() {
        return (this.rows || []).find(r => r.isPending) || null;
    }

    _openModal(row) {
        this.selectedRow     = row;
        this.nextApproverIds = [];
        this.modalComments   = '';
        this.actionError     = null;
        this.isModalOpen     = true;
    }

    _submitAction(action, comments, nextApproverIds) {
        if (!this.selectedRow || !this.selectedRow.workItemId) return;

        this.isActionLoading = true;
        this.actionError     = null;

        processApproval({
            workItemId      : this.selectedRow.workItemId,
            action          : action,
            comments        : comments || null,
            nextApproverIds : nextApproverIds || []
        })
        .then(result => {
            if (result.success) {
                this.handleModalClose();
                this.dispatchEvent(new ShowToastEvent({
                    title   : 'Success',
                    message : `Action "${action}" completed successfully.`,
                    variant : 'success'
                }));
                this.loadData();
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
}