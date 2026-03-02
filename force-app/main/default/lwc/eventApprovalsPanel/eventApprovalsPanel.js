import { LightningElement, api, track } from 'lwc';
import getApprovalsForEvent from '@salesforce/apex/EventApprovalsController.getApprovalsForEvent';
import actOnWorkitem from '@salesforce/apex/EventApprovalsController.actOnWorkitem';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// If you add a static resource named "myIcons", uncomment to use it for custom images
// import myIcons from '@salesforce/resourceUrl/myIcons';

export default class EventApprovalsPanel extends LightningElement {
    @api recordId;
    @track pending = [];
    @track processed = [];
    @track isLoading = false;

    connectedCallback() {
        this.load();
    }

    load() {
        if (!this.recordId) return Promise.resolve();

        this.isLoading = true;

        return getApprovalsForEvent({ eventId: this.recordId })
            .then(res => {
                this.pending = (res?.pending || []).filter(r => r != null);
                this.processed = (res?.processed || []).filter(r => r != null);
            })
            .catch(err => {
                this.showToast('Error', err?.body?.message || err.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleApprove(event) {
        const workItemId = event.currentTarget.dataset.workitemId;
        this.act(workItemId, 'Approve');
    }

    handleReject(event) {
        const workItemId = event.currentTarget.dataset.workitemId;
        this.act(workItemId, 'Reject');
    }

    async act(workItemId, action) {
        if (!workItemId || !action) return;

        this.isLoading = true;
        try {
            await actOnWorkitem({
                workItemId: workItemId,
                action: action,
                comments: 'Actioned from LWC'
            });

            this.showToast('Success', `${action} performed`, 'success');

            await this.load();
        } catch (err) {
            this.showToast('Error', err?.body?.message || err.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    formatDateTime(dateString) {
        if (!dateString) return '';

        const date = new Date(dateString);
        if (isNaN(date.getTime())) return dateString;

        return new Intl.DateTimeFormat(undefined, {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }).format(date);
    }

    get pendingWithTitle() {
        return (this.pending || []).map(row => ({
            ...row,
            displayTitle: row?.speakerName ? row.speakerName : 'Event Approval'
        }));
    }

    get processedWithTitle() {
        return (this.processed || []).map(row => {
            const resultText = (row?.result || '').toLowerCase();
            const isApproved = resultText === 'approved';
            const isRejected = resultText === 'rejected';
            const resultTextClass =
                'slds-m-left_x-small result-text ' +
                (isApproved ? 'result-approved' : isRejected ? 'result-rejected' : '');
            const resultIcon = isApproved ? 'utility:success' : isRejected ? 'utility:close' : 'utility:info';
            const resultVariant = isApproved ? 'success' : isRejected ? 'error' : undefined;
            const resultClass = !isApproved && !isRejected ? 'slds-icon-text-brand' : '';

          
            return {
                ...row,
                displayTitle: row?.speakerName ? row.speakerName : 'Event Approval',
                actionDateFormatted: this.formatDateTime(row?.actionDate),
                actorNameTrimmed: (row?.actorName || '').trim(),
                resultTextClass,
                resultIcon,
                resultVariant,
                resultClass
                // resultSrc
            };
        });
    }

    get hasPending() {
        return this.pendingWithTitle.length > 0;
    }

    get hasProcessed() {
        return this.processedWithTitle.length > 0;
    }
}