import { LightningElement } from 'lwc';

import loadApprovals from '@salesforce/apex/EventApprovalInboxController.loadApprovals';
import bulkApprove from '@salesforce/apex/EventApprovalInboxController.bulkApprove';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const ORGANIZER_PROCESS_DEVELOPER_NAME = 'OrganizerApprovalProcess';
const SPEAKER_PROCESS_DEVELOPER_NAME = 'SpeakerApproval';

const EVENT_COLUMNS = [
    {
        label: 'Event',
        fieldName: 'eventUrl',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'eventName' },
            target: '_blank'
        }
    },
    { label: 'Type', fieldName: 'type', sortable: true },
    { label: 'Format', fieldName: 'format', sortable: true },
    { label: 'Date', fieldName: 'eventDate', type: 'date', sortable: true },
    { label: 'Speakers', fieldName: 'speakers', sortable: true },
    { label: 'Sales Team', fieldName: 'salesTeam', sortable: true },
    { label: 'Organizer', fieldName: 'organizer', sortable: true },
    { label: 'Process', fieldName: 'processName', sortable: true },
    { label: 'Assigned To', fieldName: 'assignedTo', sortable: true },
    { label: 'Status', fieldName: 'status', sortable: true }
];

const SPEAKER_COLUMNS = [
    { label: 'Speaker', fieldName: 'speakerName', sortable: true },
    {
        label: 'Event',
        fieldName: 'eventUrl',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'eventName' },
            target: '_blank'
        }
    },
    { label: 'Type', fieldName: 'type', sortable: true },
    { label: 'Format', fieldName: 'format', sortable: true },
    { label: 'Date', fieldName: 'eventDate', type: 'date', sortable: true },
    { label: 'Sales Team', fieldName: 'salesTeam', sortable: true },
    { label: 'Organizer', fieldName: 'organizer', sortable: true },
    { label: 'Process', fieldName: 'processName', sortable: true },
    { label: 'Assigned To', fieldName: 'assignedTo', sortable: true },
    { label: 'Status', fieldName: 'status', sortable: true }
];

export default class EventApprovalInbox extends LightningElement {
    sortedBy;
    sortedDirection = 'asc';

    eventRows = [];
    speakerRows = [];
    organizerRows = [];

    filteredEventRows = [];
    filteredSpeakerRows = [];
    filteredOrganizerRows = [];

    selectedRows = [];

    isLoading = false;

    showAssignedToMe = true;
    showAssignedToQueue = true;
    showAssignedToOther = false;
    showOrganizerApprovals = false;

    hasSpeakerApproverPermission = false;
    hasOrganizerApproverPermission = false;

    eventColumns = EVENT_COLUMNS;
    speakerColumns = SPEAKER_COLUMNS;
    organizerColumns = EVENT_COLUMNS;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.isLoading = true;

        try {
            const result = await loadApprovals();

            this.hasSpeakerApproverPermission =
                result?.hasSpeakerApproverPermission || false;

            this.hasOrganizerApproverPermission =
                result?.hasOrganizerApproverPermission || false;

            this.eventRows = (result?.eventRows || []).map(row => ({
                ...row,
                eventUrl: '/' + row.eventId
            }));

            this.speakerRows = (result?.speakerRows || []).map(row => ({
                ...row,
                eventUrl: '/' + row.eventId
            }));

            this.organizerRows = (result?.organizerRows || []).map(row => ({
                ...row,
                eventUrl: '/' + row.eventId
            }));

            this.selectedRows = [];
            this.applyFilters();

        } catch (e) {
            this.showToast(
                'Error',
                e?.body?.message || e.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    get showOtherFilter() {
        return this.hasSpeakerApproverPermission;
    }

    get showOrganizerApprovalFilter() {
        return this.hasOrganizerApproverPermission;
    }

    // Affiche toujours l'onglet Event
    get showEventApprovalTable() {
        return true;
    }

    // Affiche toujours l'onglet Speaker
    get showSpeakerApprovalTable() {
        return true;
    }

    // Affiche l'onglet Organizer uniquement si le filtre est coché
    get showOrganizerApprovalTable() {
        return this.showOrganizerApprovals &&
            this.hasOrganizerApproverPermission;
    }

    // Apply assignment filters
    applyFilters() {
        const allowed = [];

        if (this.showAssignedToMe) {
            allowed.push('ME');
        }

        if (this.showAssignedToQueue) {
            allowed.push('QUEUE');
        }

        this.filteredEventRows = this.eventRows.filter(row => {
            return row.assignmentType !== 'OTHER' &&
                allowed.includes(row.assignmentType);
        });

        this.filteredSpeakerRows = this.speakerRows.filter(row => {
            if (row.assignmentType !== 'OTHER') {
                return allowed.includes(row.assignmentType);
            }

            return this.showAssignedToOther &&
                this.hasSpeakerApproverPermission &&
                row.processDeveloperName === SPEAKER_PROCESS_DEVELOPER_NAME;
        });

        this.filteredOrganizerRows = this.organizerRows.filter(row => {
            return this.showOrganizerApprovals &&
                this.hasOrganizerApproverPermission &&
                row.processDeveloperName === ORGANIZER_PROCESS_DEVELOPER_NAME;
        });
    }

    // Handle checkbox filters
    handleFilterChange(event) {
        const field = event.target.name;

        this[field] = event.target.checked;

        this.applyFilters();
    }

    // Store selected rows
    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows.map(
            row => row.workItemId
        );
    }

    // Bulk approve selected rows
    async handleApproveSelected() {
        if (!this.selectedRows.length) {
            this.showToast(
                'Warning',
                'Select at least one approval',
                'warning'
            );

            return;
        }

        this.isLoading = true;

        try {
            await bulkApprove({
                workItemIds: this.selectedRows
            });

            this.showToast(
                'Success',
                'Approvals completed',
                'success'
            );

            await this.load();

        } catch (e) {
            this.showToast(
                'Error',
                e?.body?.message || e.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    // Display toast message
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    // Handle datatable sorting
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;

        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;

        const cloneData = [...event.target.data];

        cloneData.sort((a, b) => {
            let valueA = a[fieldName] || '';
            let valueB = b[fieldName] || '';

            valueA = typeof valueA === 'string'
                ? valueA.toLowerCase()
                : valueA;

            valueB = typeof valueB === 'string'
                ? valueB.toLowerCase()
                : valueB;

            if (valueA > valueB) {
                return sortDirection === 'asc' ? 1 : -1;
            }

            if (valueA < valueB) {
                return sortDirection === 'asc' ? -1 : 1;
            }

            return 0;
        });

        if (cloneData.length && cloneData[0].speakerName) {
            this.filteredSpeakerRows = cloneData;
        } else if (
            cloneData.length &&
            cloneData[0].processDeveloperName === ORGANIZER_PROCESS_DEVELOPER_NAME
        ) {
            this.filteredOrganizerRows = cloneData;
        } else {
            this.filteredEventRows = cloneData;
        }
    }

        // Label de l'onglet Event avec compteur
    get eventTabLabel() {
        return `Event approvals (${this.filteredEventRows.length})`;
    }

    // Label de l'onglet Speaker avec compteur
    get speakerTabLabel() {
        return `Speaker approvals (${this.filteredSpeakerRows.length})`;
    }

    // Label de l'onglet Organizer avec compteur
    get organizerTabLabel() {
        return `Organizer approvals (${this.filteredOrganizerRows.length})`;
    }
}