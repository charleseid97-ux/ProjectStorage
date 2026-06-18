/**
 * @description Custom Approval Inbox LWC — home/app-page widget showing pending approval items
 *              for the current user across all target objects. Shows up to 10 items ordered by
 *              submission date, with inline Approve/Reject via the shared customApprovalActionModal.
 * @author Charles EID
 */
import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { reduceError } from 'c/gridBuilderUtils';
import getItemsToApprove from '@salesforce/apex/CustomApprovalInboxController.getItemsToApprove';

export default class CustomApprovalInbox extends NavigationMixin(LightningElement) {

    // ── State ───────────────────────────────────────────────────────────────
    @track items     = [];
    isLoading        = false;
    errorMessage     = null;
    isModalOpen      = false;
    selectedRow      = null;

    // ── Getters ─────────────────────────────────────────────────────────────
    get hasItems()  { return this.items && this.items.length > 0; }
    get isEmpty()   { return !this.isLoading && !this.errorMessage && !(this.items && this.items.length > 0); }
    get hasError()  { return !!this.errorMessage; }
    get noRecall()  { return false; } // recall is a submitter action — out of scope for this widget

    // ── Lifecycle ────────────────────────────────────────────────────────────
    connectedCallback() {
        this.loadData();
    }

    // ── Data ─────────────────────────────────────────────────────────────────
    loadData() {
        this.isLoading    = true;
        this.errorMessage = null;
        getItemsToApprove()
            .then(result  => { this.items = result || []; })
            .catch(error  => { this.errorMessage = reduceError(error); })
            .finally(()   => { this.isLoading = false; });
    }

    handleRefresh() {
        this.loadData();
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    handleRecordNavigate(event) {
        const recordId = event.currentTarget.dataset.recordId;
        if (!recordId) return;
        this[NavigationMixin.Navigate]({
            type       : 'standard__recordPage',
            attributes : { recordId, actionName: 'view' }
        });
    }

    handleViewAll() {
        // TODO: replace filterName 'All' with the actual list view developer name once configured
        this[NavigationMixin.Navigate]({
            type       : 'standard__objectPage',
            attributes : { objectApiName: 'CustomApprovalStep__c', actionName: 'list' },
            state      : { filterName: 'All' }
        });
    }

    // ── Action dropdown ───────────────────────────────────────────────────────
    handleActionSelect(event) {
        const stepId = event.target.dataset.stepId;
        const item   = this.items.find(i => i.stepId === stepId);
        if (!item) return;
        this.selectedRow = {
            stepId             : item.stepId,
            displayTitle       : item.targetRecordName + (item.stepLabel ? ' — ' + item.stepLabel : ''),
            isPending          : true,
            canApproveOrReject : true,
            nextApproverSource : item.nextApproverSource || null,
            // detail fields shown in modal body
            stepName           : item.stepLabel,
            stepDateFormatted  : item.stepDateFormatted,
            status             : 'Pending',
            statusClass        : 'status-pending',
            assignedTo         : item.assignedToName,
            actualApprover     : null,
            comments           : null
        };
        this.isModalOpen = true;
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
}