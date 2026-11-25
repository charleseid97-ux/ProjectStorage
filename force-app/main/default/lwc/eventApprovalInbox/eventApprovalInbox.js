import { LightningElement } from 'lwc';

import loadApprovals from '@salesforce/apex/EventApprovalInboxController.loadApprovals';
import bulkApprove from '@salesforce/apex/EventApprovalInboxController.bulkApprove';
import unblockStuckEvent from '@salesforce/apex/EventApprovalInboxController.unblockStuckEvent';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const ORGANIZER_PROCESS_DEVELOPER_NAME = 'OrganizerApprovalProcess';
const SPEAKER_PROCESS_DEVELOPER_NAME = 'SpeakerApproval';
const HOP_PROCESS_DEVELOPER_NAME = 'SpeakerApprovalHOP';

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

const STUCK_EVENT_COLUMNS = [
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
    { label: 'Status', fieldName: 'status', sortable: true },
    {
        type: 'button',
        typeAttributes: {
            label: 'Unblock',
            name: 'unblock',
            title: 'Unblock Event',
            variant: 'brand'
        }
    }
];

export default class EventApprovalInbox extends LightningElement {

    sortedBy;
    sortedDirection = 'asc';

    eventRows = [];
    speakerRows = [];
    organizerRows = [];
    hopRows = [];
    stuckEventRows = [];

    filteredEventRows = [];
    filteredSpeakerRows = [];
    filteredOrganizerRows = [];
    filteredHopRows = [];

    selectedRows = [];

    isLoading = false;

    showAssignedToMe = true;
    showAssignedToQueue = true;
    showAssignedToOther = false;
    showOrganizerApprovals = false;
    showHopApprovals = false;
    showStuckEvents = false;

    hasSpeakerApproverPermission = false;
    hasOrganizerApproverPermission = false;
    hasHopApproverPermission = false;
    hasBooklyAdminPermission = false;

    eventColumns = EVENT_COLUMNS;
    speakerColumns = SPEAKER_COLUMNS;
    organizerColumns = EVENT_COLUMNS;
    hopColumns = EVENT_COLUMNS;
    stuckEventColumns = STUCK_EVENT_COLUMNS;

    // Charge les approbations au chargement du composant.
    connectedCallback() {
        this.load();
    }

    // Recupere les approbations et prepare les lignes pour les tableaux.
    async load() {
        this.isLoading = true;

        try {
            const result = await loadApprovals();
            console.log('loadApprovals result:', result);
            console.log('Apex hasBooklyAdminPermission:', result?.hasBooklyAdminPermission);
            console.log('Apex stuckEventRows:', result?.stuckEventRows);
            
            this.hasSpeakerApproverPermission =
                result?.hasSpeakerApproverPermission || false;

            this.hasOrganizerApproverPermission =
                result?.hasOrganizerApproverPermission || false;

            this.hasHopApproverPermission =
                result?.hasHopApproverPermission || false;

            this.hasBooklyAdminPermission =
                result?.hasBooklyAdminPermission || false;

            // Ajoute l'URL Salesforce utilisee par les colonnes de type lien.
            this.eventRows = this.addEventUrls(result?.eventRows);
            this.speakerRows = this.addEventUrls(result?.speakerRows);
            this.organizerRows = this.addEventUrls(result?.organizerRows);
            this.hopRows = this.addEventUrls(result?.hopRows);
            this.stuckEventRows = this.addEventUrls(result?.stuckEventRows);

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

    // Ajoute l'URL de navigation Salesforce aux lignes recues.
    addEventUrls(rows) {
        return (rows || []).map(row => ({
            ...row,
            eventUrl: '/' + row.eventId
        }));
    }

    // Affiche la checkbox HOP uniquement si l'utilisateur a la permission.
    get showHopApprovalFilter() {
        return this.hasHopApproverPermission;
    }

    // Affiche l'onglet HOP uniquement si le filtre est coche.
    get showHopApprovalTable() {
        return this.showHopApprovals &&
            this.hasHopApproverPermission;
    }

    // Affiche la checkbox Other uniquement si l'utilisateur a la permission Speaker.
    get showOtherFilter() {
        return this.hasSpeakerApproverPermission;
    }

    // Affiche la checkbox Organizer uniquement si l'utilisateur a la permission Organizer.
    get showOrganizerApprovalFilter() {
        return this.hasOrganizerApproverPermission;
    }

    // Affiche toujours l'onglet Event.
    get showEventApprovalTable() {
        return true;
    }

    // Affiche toujours l'onglet Speaker.
    get showSpeakerApprovalTable() {
        return true;
    }

    // Affiche l'onglet Organizer uniquement si le filtre est coche.
    get showOrganizerApprovalTable() {
        return this.showOrganizerApprovals &&
            this.hasOrganizerApproverPermission;
    }

    // Affiche la checkbox Stuck Events uniquement pour les Bookly Admin.
    get showStuckEventFilter() {
        return this.hasBooklyAdminPermission;
    }

    // Affiche l'onglet Stuck Events uniquement lorsque le filtre est coche.
    get showStuckEventTable() {
        return this.showStuckEvents &&
            this.hasBooklyAdminPermission;
    }

    // Applique les filtres de checkbox sur chaque type d'approbation.
    applyFilters() {
        const allowed = [];

        if (this.showAssignedToMe) {
            allowed.push('ME');
        }

        if (this.showAssignedToQueue) {
            allowed.push('QUEUE');
        }

        // Event : affiche uniquement mes demandes ou celles de mes queues.
        this.filteredEventRows = this.eventRows.filter(row => {
            return row.assignmentType !== 'OTHER' &&
                allowed.includes(row.assignmentType);
        });

        this.filteredSpeakerRows = this.speakerRows.filter(row => {
            if (row.assignmentType !== 'OTHER') {
                return allowed.includes(row.assignmentType);
            }

            // Speaker OTHER : visible uniquement avec la permission dediee.
            return this.showAssignedToOther &&
                this.hasSpeakerApproverPermission &&
                row.processDeveloperName === SPEAKER_PROCESS_DEVELOPER_NAME;
        });

        this.filteredOrganizerRows = this.organizerRows.filter(row => {
            return this.showOrganizerApprovals &&
                this.hasOrganizerApproverPermission &&
                row.processDeveloperName === ORGANIZER_PROCESS_DEVELOPER_NAME;
        });

        this.filteredHopRows = this.hopRows.filter(row => {
            return this.showHopApprovals &&
                this.hasHopApproverPermission &&
                row.processDeveloperName === HOP_PROCESS_DEVELOPER_NAME;
        });
    }

    // Met a jour les filtres quand une checkbox change.
    handleFilterChange(event) {
        const field = event.target.name;

        this[field] = event.target.checked;

        console.log('Filter changed:', field, event.target.checked);
        console.log('showStuckEvents:', this.showStuckEvents);
        console.log('hasBooklyAdminPermission:', this.hasBooklyAdminPermission);
        console.log('showStuckEventTable:', this.showStuckEventTable);
        console.log('stuckEventRows:', this.stuckEventRows);

        this.applyFilters();
    }

    // Stocke les work items selectionnes dans les tableaux.
    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows.map(
            row => row.workItemId
        );
    }

    // Approuve en masse les lignes selectionnees.
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

    // Debloque l'Event selectionne en reutilisant la logique Bookly.
    async handleStuckEventAction(event) {
        if (event.detail.action.name !== 'unblock') {
            return;
        }

        this.isLoading = true;

        try {
            const status = await unblockStuckEvent({
                eventId: event.detail.row.eventId
            });

            this.showToast(
                'Success',
                `Event unblocked. New status: ${status}`,
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

    // Affiche un message toast.
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    // Trie le tableau actif selon la colonne selectionnee.
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

        // Reinjecte les donnees triees dans le bon tableau.
        if (cloneData.length && cloneData[0].speakerName) {
            this.filteredSpeakerRows = cloneData;
        } else if (
            cloneData.length &&
            cloneData[0].processDeveloperName === HOP_PROCESS_DEVELOPER_NAME
        ) {
            this.filteredHopRows = cloneData;
        } else if (
            cloneData.length &&
            cloneData[0].processDeveloperName === ORGANIZER_PROCESS_DEVELOPER_NAME
        ) {
            this.filteredOrganizerRows = cloneData;
        } else if (
            cloneData.length &&
            Object.prototype.hasOwnProperty.call(cloneData[0], 'workItemId')
        ) {
            this.filteredEventRows = cloneData;
        } else {
            this.stuckEventRows = cloneData;
        }
    }

    // Label de l'onglet HOP avec compteur.
    get hopTabLabel() {
        return `Head of Product approvals (${this.filteredHopRows.length})`;
    }

    // Label de l'onglet Event avec compteur.
    get eventTabLabel() {
        return `Event approvals (${this.filteredEventRows.length})`;
    }

    // Label de l'onglet Speaker avec compteur.
    get speakerTabLabel() {
        return `Speaker approvals (${this.filteredSpeakerRows.length})`;
    }

    // Label de l'onglet Organizer avec compteur.
    get organizerTabLabel() {
        return `Organizer approvals (${this.filteredOrganizerRows.length})`;
    }

    // Label de l'onglet Stuck Events avec compteur.
    get stuckEventTabLabel() {
        return `Stuck Events (${this.stuckEventRows.length})`;
    }
}