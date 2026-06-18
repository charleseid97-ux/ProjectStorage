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

const STATUS_CLASS_MAP = {
    Approved  : 'status-approved',
    Rejected  : 'status-rejected',
    Pending   : 'status-pending',
    Started   : 'status-started',
    Submitted : 'status-started',
    Recalled  : 'status-recalled'
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

    // ── Getters ──────────────────────────────────────────────────────────────
    get hasRows()           { return this.rows && this.rows.length > 0; }
    get hasError()          { return !!this.errorMessage; }
    get hasProcessStatus()  { return !!this.processStatus; }
    get headerTitle()       { return `Approval History (${(this.rows || []).length})`; }

    get modalSelectedRow() {
        if (!this.selectedRow) return null;
        return {
            stepId             : this.selectedRow.stepId,
            displayTitle       : this.selectedRow.stepName,
            isPending          : this.selectedRow.isPending,
            canApproveOrReject : this.selectedRow.canApproveOrReject,
            nextApproverSource : this.selectedRow.nextApproverSource,
            stepName           : this.selectedRow.stepName,
            stepDateFormatted  : this.selectedRow.stepDateFormatted,
            status             : this.selectedRow.status,
            statusClass        : this.selectedRow.statusClass,
            assignedTo         : this.selectedRow.assignedTo,
            actualApprover     : this.selectedRow.actualApprover,
            comments           : this.selectedRow.comments
        };
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
        const firstPending = (this.rows || []).find(r => r.isPending && r.stepId) || null;
        if (firstPending) this._openModal(firstPending);
    }

    // ── Table Row Click ───────────────────────────────────────────────────────
    handleRowClick(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const row = this.rows.find(r => r.id === rowId);
        if (row) this._openModal(row);
    }

    // ── Modal events ──────────────────────────────────────────────────────────
    handleModalClose() {
        this.isModalOpen = false;
        this.selectedRow = null;
    }

    handleActionComplete(event) {
        const action = event.detail.action;
        this.handleModalClose();
        this.dispatchEvent(new ShowToastEvent({
            title   : 'Success',
            message : `Action "${action}" completed successfully.`,
            variant : 'success'
        }));
        this.loadData();
    }

    // ── Private Helpers ───────────────────────────────────────────────────────
    _firstPendingRow() {
        return (this.rows || []).find(r => r.isPending && r.canApproveOrReject) || null;
    }

    _openModal(row) {
        this.selectedRow = row;
        this.isModalOpen = true;
    }
}