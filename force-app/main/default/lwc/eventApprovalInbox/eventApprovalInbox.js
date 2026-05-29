import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import loadApprovals from '@salesforce/apex/EventApprovalInboxController.loadApprovals';
import bulkApprove from '@salesforce/apex/EventApprovalInboxController.bulkApprove';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

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

export default class EventApprovalInbox extends NavigationMixin(LightningElement) {
    sortedBy;
    sortedDirection = 'asc';
    @track eventRows = [];
    @track speakerRows = [];

    @track filteredEventRows = [];
    @track filteredSpeakerRows = [];

    @track selectedRows = [];

    isLoading = false;

    showAssignedToMe = true;
    showAssignedToQueue = true;
    showAssignedToOther = true;

    eventColumns = EVENT_COLUMNS;
    speakerColumns = SPEAKER_COLUMNS;

    connectedCallback() {
        this.load();
    }

    // Load approvals
    async load() {

        this.isLoading = true;

        try {

            const result = await loadApprovals();

            this.eventRows = (result?.eventRows || []).map(row => ({
                ...row,
                eventUrl: '/' + row.eventId
            }));

            this.speakerRows = (result?.speakerRows || []).map(row => ({
                ...row,
                eventUrl: '/' + row.eventId
            }));

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

    // Apply assignment filters
    applyFilters() {

        const allowed = [];

        if (this.showAssignedToMe) {
            allowed.push('ME');
        }

        if (this.showAssignedToQueue) {
            allowed.push('QUEUE');
        }

        if (this.showAssignedToOther) {
            allowed.push('OTHER');
        }

        this.filteredEventRows = this.eventRows.filter(
            row => allowed.includes(row.assignmentType)
        );

        this.filteredSpeakerRows = this.speakerRows.filter(
            row => allowed.includes(row.assignmentType)
        );
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

        if (event.target.keyField === 'workItemId') {

            if (cloneData.length && cloneData[0].speakerName) {
                this.filteredSpeakerRows = cloneData;
            } else {
                this.filteredEventRows = cloneData;
            }
        }
    }

}