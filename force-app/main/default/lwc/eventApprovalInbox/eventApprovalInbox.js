import { LightningElement } from 'lwc';

import loadApprovals from '@salesforce/apex/EventApprovalInboxController.loadApprovals';
import bulkApprove from '@salesforce/apex/EventApprovalInboxController.bulkApprove';

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

export default class EventApprovalInbox extends LightningElement {
    sortedBy;
    sortedDirection = 'asc';

    eventRows = [];
    speakerRows = [];
    organizerRows = [];
    hopRows = [];

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

    hasSpeakerApproverPermission = false;
    hasOrganizerApproverPermission = false;
    hasHopApproverPermission = false;

    eventColumns = EVENT_COLUMNS;
    speakerColumns = SPEAKER_COLUMNS;
    organizerColumns = EVENT_COLUMNS;
    hopColumns = EVENT_COLUMNS;

    // Charge les approbations au chargement du composant
    connectedCallback() {
        this.load();
    }

    // Récupère les approbations et prépare les lignes pour les tableaux
    async load() {
        this.isLoading = true;

        try {
            const result = await loadApprovals();

            this.hasSpeakerApproverPermission =
                result?.hasSpeakerApproverPermission || false;

            this.hasOrganizerApproverPermission =
                result?.hasOrganizerApproverPermission || false;

            this.hasHopApproverPermission =
                result?.hasHopApproverPermission || false;

            // Ajoute l'URL Salesforce utilisée par les colonnes de type lien
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

            this.hopRows = (result?.hopRows || []).map(row => ({
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

    // Affiche la checkbox HOP uniquement si l'utilisateur a la permission
    get showHopApprovalFilter() {
        return this.hasHopApproverPermission;
    }

    // Affiche l'onglet HOP uniquement si le filtre est coché
    get showHopApprovalTable() {
        return this.showHopApprovals &&
            this.hasHopApproverPermission;
    }

    // Affiche la checkbox Other uniquement si l'utilisateur a la permission Speaker
    get showOtherFilter() {
        return this.hasSpeakerApproverPermission;
    }

    // Affiche la checkbox Organizer uniquement si l'utilisateur a la permission Organizer
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

    // Applique les filtres de checkbox sur chaque type d'approbation
    applyFilters() {
        const allowed = [];

        if (this.showAssignedToMe) {
            allowed.push('ME');
        }

        if (this.showAssignedToQueue) {
            allowed.push('QUEUE');
        }

        // Event : affiche uniquement mes demandes ou celles de mes queues
        this.filteredEventRows = this.eventRows.filter(row => {
            return row.assignmentType !== 'OTHER' &&
                allowed.includes(row.assignmentType);
        });

        this.filteredSpeakerRows = this.speakerRows.filter(row => {
            if (row.assignmentType !== 'OTHER') {
                return allowed.includes(row.assignmentType);
            }

            // Speaker OTHER : visible uniquement avec la permission dédiée
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

    // Met à jour les filtres quand une checkbox change
    handleFilterChange(event) {
        const field = event.target.name;

        this[field] = event.target.checked;

        this.applyFilters();
    }

    // Stocke les work items sélectionnés dans les tableaux
    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows.map(
            row => row.workItemId
        );
    }

    // Approuve en masse les lignes sélectionnées
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

    // Affiche un message toast
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    // Trie le tableau actif selon la colonne sélectionnée
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

        // Réinjecte les données triées dans le bon tableau
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
        } else {
            this.filteredEventRows = cloneData;
        }
    }

    // Label de l'onglet HOP avec compteur
    get hopTabLabel() {
        return `Head of Product approvals (${this.filteredHopRows.length})`;
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