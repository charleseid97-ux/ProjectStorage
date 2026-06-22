/**
 * @description Custom Approval Inbox LWC — home/app-page widget showing pending approval items
 *              for the current user across all target objects. Shows the first 5 items in a card;
 *              "View All" opens a full datatable modal with Approve/Reject row actions.
 * @author Charles EID
 */
import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { reduceError } from 'c/gridBuilderUtils';
import getItemsToApprove from '@salesforce/apex/CustomApprovalInboxController.getItemsToApprove';

const COLUMNS = [
    { label: 'Related To',         fieldName: 'targetRecordUrl', type: 'url', typeAttributes: { label: { fieldName: 'targetRecordName' }, target: '_self' } },
    { label: 'Type',               fieldName: 'objectLabel',             type: 'text' },
    { label: 'Most Recent Approver', fieldName: 'previousApproverName',  type: 'text' },
    { label: 'Date Submitted',     fieldName: 'submissionDateFormatted', type: 'text' },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Approve', name: 'Approve' }, { label: 'Reject', name: 'Reject' }] }
    }
];

export default class CustomApprovalInbox extends NavigationMixin(LightningElement) {

    // ── Admin-configurable ───────────────────────────────────────────────────
    @api cardTitle     = 'Items to Approve';
    @api objectApiName  = '';
    @api approvalSystem = ''; // 'Custom' | 'Standard' | '' (both)

    // ── State ───────────────────────────────────────────────────────────────
    @track items      = [];
    isLoading         = false;
    errorMessage      = null;
    isModalOpen       = false;
    isAllModalOpen    = false;
    selectedRow       = null;
    columns           = COLUMNS;

    // ── Getters ─────────────────────────────────────────────────────────────
    get hasItems()     { return this.items && this.items.length > 0; }
    get isEmpty()      { return !this.isLoading && !this.errorMessage && !(this.items && this.items.length > 0); }
    get hasError()     { return !!this.errorMessage; }
    get noRecall()     { return false; }
    get visibleItems() { return (this.items || []).slice(0, 5); }

    // ── Lifecycle ────────────────────────────────────────────────────────────
    connectedCallback() {
        this.loadData();
    }

    // ── Data ─────────────────────────────────────────────────────────────────
    loadData() {
        this.isLoading    = true;
        this.errorMessage = null;
        getItemsToApprove({ objectApiName: this.objectApiName || '', approvalSystem: this.approvalSystem || '' })
            .then(result  => {
                this.items = (result || []).map(item => ({
                    ...item,
                    targetRecordUrl: item.targetRecordId ? `/lightning/r/${item.targetRecordId}/view` : null
                }));
            })
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

    // ── View All modal ────────────────────────────────────────────────────────
    handleViewAll() {
        this.isAllModalOpen = true;
    }

    handleAllModalClose() {
        this.isAllModalOpen = false;
    }

    // ── Datatable row action ──────────────────────────────────────────────────
    handleRowAction(event) {
        const row = event.detail.row;
        this.openApprovalModal(row);
    }

    // ── Action dropdown (card list) ───────────────────────────────────────────
    handleActionSelect(event) {
        const stepId = event.target.dataset.stepId;
        const item   = this.items.find(i => i.stepId === stepId);
        if (!item) return;
        this.openApprovalModal(item);
    }

    openApprovalModal(item) {
        // Standard Salesforce workitems: navigate to the record page so the user can act natively
        if (item.isStandardApproval) {
            this[NavigationMixin.Navigate]({
                type       : 'standard__recordPage',
                attributes : { recordId: item.stepId, actionName: 'view' }
            });
            return;
        }
        this.selectedRow = {
            stepId             : item.stepId,
            displayTitle       : item.targetRecordName + (item.stepLabel ? ' — ' + item.stepLabel : ''),
            isPending          : true,
            canApproveOrReject : true,
            nextApproverSource : item.nextApproverSource || null,
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