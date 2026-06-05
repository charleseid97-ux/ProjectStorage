import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { getRecord, getFieldValue }      from 'lightning/uiRecordApi';
import getApprovalHistory from '@salesforce/apex/CustomApprovalHistoryController.getApprovalHistory';
import processApproval    from '@salesforce/apex/CustomApprovalHistoryController.processApproval';
import LABEL_NOT_ELIGIBLE from '@salesforce/label/c.Grid_EmailApprovalNotEligible';
import NAME_FIELD         from '@salesforce/schema/Grid__c.Name';

export default class GridEmailApprovalAction extends NavigationMixin(LightningElement) {

    label = { notEligible: LABEL_NOT_ELIGIBLE };

    // Set from URL state
    recordId;
    action = 'Approve';

    @track isLoading    = true;
    @track isEligible   = false;
    @track isProcessing = false;
    @track isDone       = false;
    @track comments     = '';
    workItemId;

    // ── Read URL params ────────────────────────────────────────────────────────
    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        if (pageRef?.state) {
            this.recordId = pageRef.state.c__recordId || null;
            this.action   = pageRef.state.c__action   || 'Approve';
            if (!this.recordId) {
                this.isLoading  = false;
                this.isEligible = false;
            }
        }
    }

    // ── Grid record name ───────────────────────────────────────────────────────
    @wire(getRecord, { recordId: '$recordId', fields: [NAME_FIELD] })
    gridRecord;

    get gridName() {
        return getFieldValue(this.gridRecord?.data, NAME_FIELD) || '';
    }

    // ── Eligibility check ──────────────────────────────────────────────────────
    @wire(getApprovalHistory, { recordId: '$recordId' })
    wiredHistory({ data, error }) {
        if (data) {
            this.isLoading = false;
            if (!data.canApproveOrReject || data.processStatus !== 'Pending') {
                this.isEligible = false;
                return;
            }
            const eligible = data.rows.find(r => r.canApproveOrReject && r.workItemId);
            if (!eligible) {
                this.isEligible = false;
                return;
            }
            this.workItemId = eligible.workItemId;
            this.isEligible = true;
        } else if (error) {
            this.isLoading  = false;
            this.isEligible = false;
        }
    }

    // ── Derived getters ────────────────────────────────────────────────────────
    get showNotEligible() {
        return !this.isLoading && !this.isEligible && !this.isDone;
    }

    get showConfirm() {
        return !this.isLoading && this.isEligible && !this.isDone;
    }

    get isApprove() {
        return this.action === 'Approve';
    }

    get actionLabel() {
        return this.isApprove ? 'Approve' : 'Reject';
    }

    get confirmLabel() {
        return this.isApprove ? 'Confirm Approval' : 'Confirm Rejection';
    }

    get confirmVariant() {
        return this.isApprove ? 'success' : 'destructive';
    }

    get cardTitle() {
        return 'Grid Amendment — ' + this.actionLabel;
    }

    get cardIcon() {
        return this.isApprove ? 'utility:check' : 'utility:close';
    }

    get actionBadgeClass() {
        return this.isApprove ? 'action-badge action-badge_approve' : 'action-badge action-badge_reject';
    }

    get successMessage() {
        return this.isApprove ? 'The Grid Amendment has been approved successfully.' : 'The Grid Amendment has been rejected.';
    }

    // ── Handlers ───────────────────────────────────────────────────────────────
    handleCommentChange(event) {
        this.comments = event.target.value;
    }

    handleConfirm() {
        this.isProcessing = true;
        processApproval({
            workItemId:      this.workItemId,
            action:          this.action,
            comments:        this.comments,
            nextApproverIds: []
        })
        .then(result => {
            this.isProcessing = false;
            if (result.success) {
                this.isEligible = false;
                this.isDone     = true;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: this.recordId,
                            actionName: 'view'
                        }
                    });
                }, 2500);
            } else {
                this.isEligible = false;
            }
        })
        .catch(() => {
            this.isProcessing = false;
            this.isEligible   = false;
        });
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, actionName: 'view' }
        });
    }
}