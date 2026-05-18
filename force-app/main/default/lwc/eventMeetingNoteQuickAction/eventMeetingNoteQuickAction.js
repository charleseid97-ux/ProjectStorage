import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import getPayload from '@salesforce/apex/EventMeetingNoteQuickActionCTRL.getPayload';
import saveMeetingNote from '@salesforce/apex/EventMeetingNoteQuickActionCTRL.save';
import LightningAlert from 'lightning/alert';
export default class EventMeetingNoteQuickAction extends NavigationMixin(LightningElement) {

    @track loading = false;
    @track error;

    @track hasMeetingNote = false;
    @track meetingNoteId;
    @track standardEventId;
    @track meetingNoteName;
    @track meetingNoteDate;
    @track meetingType;

    @track noteHtml = '';

    // UI state
    @track editMode = false;
    @track draftNoteHtml = '';
    _recordId;

    @api
    set recordId(value) {
        this._recordId = value;

        // Charge les données quand le recordId est disponible
        if (value) {
            this.load();
        }
    }

    get recordId() {
        return this._recordId;
    }

    get title() {
        return this.hasMeetingNote ? 'Meeting Note' : 'Create Meeting Note';
    }

    get primaryLabel() {
        if (!this.hasMeetingNote) return 'Create Meeting note';
        return this.editMode ? 'Save changes' : 'Edit';
    }

    get showReadOnly() {
        return this.hasMeetingNote && !this.editMode;
    }

    get showEditor() {
        return !this.hasMeetingNote || this.editMode;
    }

    get showCancel() {
        return this.editMode;
    }

    get showClose() {
        return !this.editMode;
    }

    get standardEventUrl() {
        return this.standardEventId ? '/' + this.standardEventId : null;
    }

    get formattedMeetingNoteDate() {
        if (!this.meetingNoteDate) return '';

        const d = new Date(this.meetingNoteDate);

        // Formatte la date en dd/mm/yy
        const day = String(d.getDate()).padStart(2, '0');
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const year = String(d.getFullYear()).slice(-2);

        return `${day}/${month}/${year}`;
    }

    // Charge le payload depuis Apex
    async load() {
        this.loading = true;
        this.error = null;

        try {
            const p = await getPayload({ eventId: this.recordId });

            this.hasMeetingNote = !!p?.hasMeetingNote;
            this.meetingNoteId = p?.meetingNoteId;
            this.standardEventId = p?.standardEventId;
            this.meetingNoteName = p?.meetingNoteName;
            this.meetingNoteDate = p?.meetingNoteDate;
            this.meetingType = p?.meetingType;

            this.noteHtml = p?.noteHtml || '';
            this.draftNoteHtml = this.noteHtml;

            // Ouvre l'éditeur uniquement en création
            this.editMode = !this.hasMeetingNote;
        } catch (e) {
            this.error = e;
        } finally {
            this.loading = false;
        }
    }

    // Met à jour le brouillon depuis le rich text
    handleNoteChange(event) {
        this.draftNoteHtml = event.detail.value;
    }

    // Navigation vers l'Event standard
    handleNavigateToEvent() {
        if (!this.standardEventId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.standardEventId,
                objectApiName: 'Event',
                actionName: 'view'
            }
        });
    }

    // Gère le bouton principal
    async handlePrimary() {
        if (this.loading) return;

        if (this.hasMeetingNote && !this.editMode) {
            this.editMode = true;
            this.draftNoteHtml = this.noteHtml;
            return;
        }

        await this.save();
    }

    // Sauvegarde la note via Apex
    async save() {
        const rte = this.template.querySelector('lightning-input-rich-text');

        if (rte) {
            this.draftNoteHtml = rte.value || '';
        }

        this.loading = true;
        this.error = null;

        try {
            saveMeetingNote({
                eventId: this.recordId,
                noteHtml: this.draftNoteHtml || ''
            });

           
            await LightningAlert.open({
                message: 'The meeting note is being created. It will be ready in less than 20 seconds.',
                theme: 'info',
                label: 'Creation in progress'
            });
            // ferme immédiatement la popup
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            this.error = e;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: e?.body?.message || e?.message || 'Unknown error',
                    variant: 'error'
                })
            );
        } finally {
            this.loading = false;
        }
    }

    // Annule l'édition ou ferme l'action
    handleCancel() {
        if (this.hasMeetingNote) {
            this.editMode = false;
            this.draftNoteHtml = this.noteHtml;
        } else {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }

    // Ferme l'action rapide
    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}