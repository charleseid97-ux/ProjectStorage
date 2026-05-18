import { LightningElement, api, track } from 'lwc';
import getApprovalsForEvent from '@salesforce/apex/EventApprovalsPanelController.getApprovalsForEvent';
import actOnWorkitem from '@salesforce/apex/EventApprovalsPanelController.actOnWorkitem';
import recallApproval from '@salesforce/apex/EventApprovalsPanelController.recallApproval';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class EventApprovalsPanel extends LightningElement {
    @api recordId;
    @track pending = [];
    @track processed = [];
    @track isLoading = false;

    connectedCallback() {
        this.load();
    }

    load() {
        if (!this.recordId) {
            return Promise.resolve();
        }

        this.isLoading = true;

        return getApprovalsForEvent({ eventId: this.recordId })
            .then((res) => {
                this.pending = (res?.pending || [])
                    .filter((r) => r != null)
                    .map((r) => ({
                        ...r,
                        showRejectBox: false,
                        rejectComment: ''
                    }));

                this.processed = (res?.processed || [])
                    .filter((r) => r != null)
                    .map((r) => ({
                        ...r,
                        showRecallBox: false,
                        recallComment: ''
                    }));
            })
            .catch((err) => {
                this.showToast('Error', err?.body?.message || err.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleApprove(event) {
        const workItemId = event.currentTarget.dataset.workitemId;
        this.act(workItemId, 'Approve', '');
    }

    handleOpenReject(event) {
        const workItemId = event.currentTarget.dataset.workitemId;

        this.pending = this.pending.map((row) => ({
            ...row,
            showRejectBox: row.workItemId === workItemId
        }));
    }

    handleCancelReject(event) {
        const workItemId = event.currentTarget.dataset.workitemId;

        this.pending = this.pending.map((row) => {
            if (row.workItemId === workItemId) {
                return {
                    ...row,
                    showRejectBox: false,
                    rejectComment: ''
                };
            }
            return row;
        });
    }

   handleRejectCommentChange(event) {
        const workItemId = event.currentTarget.dataset.workitemId;
        const value = event.target.value;

        this.pending = this.pending.map((row) => {
            if (row.workItemId === workItemId) {
                return {
                    ...row,
                    rejectComment: value
                };
            }
            return row;
        });

        event.target.setCustomValidity('');
        event.target.reportValidity();
    }

    handleSubmitReject(event) {
        const workItemId = event.currentTarget.dataset.workitemId;
        const row = (this.pending || []).find((r) => r.workItemId === workItemId);

        if (!row) {
            this.showToast('Error', 'Unable to find the selected approval row.', 'error');
            return;
        }

        const textarea = this.template.querySelector(
            `lightning-textarea[data-workitem-id="${workItemId}"]`
        );

        const finalComment = (row.rejectComment || '').trim();

        if (!finalComment) {
            if (textarea) {
                textarea.setCustomValidity('Rejection comment is required.');
                textarea.reportValidity();
            }
            return;
        }

        if (textarea) {
            textarea.setCustomValidity('');
            textarea.reportValidity();
        }

        this.act(workItemId, 'Reject', finalComment);
    }

    async act(workItemId, action, comments) {
        if (!workItemId || !action) return;

        this.isLoading = true;
        try {
            await actOnWorkitem({
                workItemId,
                action,
                comments: comments || ''
            });

            this.showToast('Success', `${action} performed`, 'success');
            await this.load();
        } catch (err) {
            this.showToast('Error', err?.body?.message || err.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleOpenRecall(event) {
        const processInstanceId = event.currentTarget.dataset.processInstanceId;
        this.processed = this.processed.map((row) => ({
            ...row,
            showRecallBox: row.processInstanceId === processInstanceId
        }));
    }

    handleCancelRecall(event) {
        const processInstanceId = event.currentTarget.dataset.processInstanceId;
        this.processed = this.processed.map((row) => {
            if (row.processInstanceId === processInstanceId) {
                return {
                    ...row,
                    showRecallBox: false,
                    recallComment: ''
                };
            }
            return row;
        });
    }

    handleRecallCommentChange(event) {
        const processInstanceId = event.currentTarget.dataset.processInstanceId;
        const value = event.target.value;

        this.processed = this.processed.map((row) => {
            if (row.processInstanceId === processInstanceId) {
                return {
                    ...row,
                    recallComment: value
                };
            }
            return row;
        });
    }

    async handleSubmitRecall(event) {
        const processInstanceId = event.currentTarget.dataset.processInstanceId;
        const row = (this.processed || []).find((r) => r.processInstanceId === processInstanceId);

        if (!row) {
            this.showToast('Error', 'Unable to find the selected approval row.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            await recallApproval({
                recallTargetId: row.recallTargetId,
                eventSpeakerApprovalId: row.eventSpeakerApprovalId,
                processDeveloperName: row.processDeveloperName,
                comments: row.recallComment
            });

            this.showToast('Success', 'Approval resubmitted successfully.', 'success');
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
        if (Number.isNaN(date.getTime())) return dateString;

        return new Intl.DateTimeFormat(undefined, {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }).format(date);
    }

    // Ajoute le processName dans la logique du titre
    get pendingWithTitle() {
        return (this.pending || []).map((row) => {
            const isOrganizerApproval =
                (row?.processName || '').toLowerCase() === 'organizer approval';

            return {
                ...row,
                displayTitle: row?.speakerName
                    ? row.speakerName
                    : isOrganizerApproval
                        ? 'Organizer Approval'
                        : 'Event team approval'
            };
        });
    }

    get processedWithTitle() {
        return (this.processed || []).map((row) => {
            const resultText = (row?.result || '').toLowerCase();
            const isApproved = resultText === 'approved';
            const isRejected = resultText === 'rejected';

            const resultTextClass =
                'slds-m-left_x-small result-text ' +
                (isApproved ? 'result-approved' : isRejected ? 'result-rejected' : '');

            const resultIcon = isApproved
                ? 'utility:success'
                : isRejected
                    ? 'utility:close'
                    : 'utility:info';

            const resultVariant = isApproved ? 'success' : isRejected ? 'error' : undefined;
            const resultClass = !isApproved && !isRejected ? 'slds-icon-text-brand' : '';

            const isOrganizerApproval =
                (row?.processName || '').toLowerCase() === 'organizer approval';

            return {
                ...row,
                displayTitle: row?.speakerName
                    ? row.speakerName
                    : isOrganizerApproval
                        ? 'Organizer Approval'
                        : 'Event team approval',
                actionDateFormatted: this.formatDateTime(row?.actionDate),
                actorNameTrimmed: (row?.actorName || '').trim(),
                resultTextClass,
                resultIcon,
                resultVariant,
                resultClass,
                isRecalled: (row?.eventSpeakerApprovalStatus || '').toLowerCase() === 'recalled',
                showRecalledDisabled: !!row?.showRecalledDisabled,
                showProcessedComment: isRejected && !!row?.comments
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