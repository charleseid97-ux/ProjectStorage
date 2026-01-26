import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getPayload from '@salesforce/apex/EventMeetingNoteQuickActionCTRL.getPayload';
import saveMeetingNote from '@salesforce/apex/EventMeetingNoteQuickActionCTRL.save';

export default class EventMeetingNoteQuickAction extends LightningElement {

    @track loading = false;
    @track error;

    @track hasMeetingNote = false;
    @track meetingNoteId;
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

        // eslint-disable-next-line no-console
        console.log('===[MeetingNoteQA] recordId set:', value);

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

    async load() {
        console.log('Loading meeting note payload for event', this.recordId);   
        this.loading = true;
        this.error = null;
        try {
            const p = await getPayload({ eventId: this.recordId });

            this.hasMeetingNote = !!p?.hasMeetingNote;
            this.meetingNoteId = p?.meetingNoteId;
            this.meetingNoteName = p?.meetingNoteName;
            this.meetingNoteDate = p?.meetingNoteDate;
            this.meetingType = p?.meetingType;

            this.noteHtml = p?.noteHtml || '';
            this.draftNoteHtml = this.noteHtml;

            if (this.hasMeetingNote) {
                this.editMode = false;
            } else {
                this.editMode = true;
            }
        } catch (e) {
            this.error = e;
        } finally {
            this.loading = false;
        }
    }

    handleNoteChange(event) {
        this.draftNoteHtml = event.detail.value;
    }

   async handlePrimary() {
    
        console.log('[QA] handlePrimary', { hasMeetingNote: this.hasMeetingNote, editMode: this.editMode, loading: this.loading });

        if (this.loading) return;

        if (this.hasMeetingNote && !this.editMode) {
            console.log('[QA] switching to edit mode');
            this.editMode = true;
            this.draftNoteHtml = this.noteHtml;
            return;
        }

        console.log('[QA] calling save()');
        await this.save();
    }

    async save() {
        // Always read the latest value from the rich text input (avoid missing oninput/onchange timing)
        const rte = this.template.querySelector('lightning-input-rich-text');
        if (rte) {
            this.draftNoteHtml = rte.value || '';
        }

        console.log('[QA] save start', { recordId: this.recordId, draftLen: (this.draftNoteHtml || '').length });

        this.loading = true;
        this.error = null;

        try {
            const res = await saveMeetingNote({
                eventId: this.recordId,
                noteHtml: this.draftNoteHtml || ''
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: res?.created ? 'Meeting note created' : 'Meeting note updated',
                    message: res?.created ? 'The meeting note was created and linked to the event.' : 'Changes saved.',
                    variant: 'success'
                })
            );

            await this.load();
            this.editMode = false;

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


    handleCancel() {
        if (this.hasMeetingNote) {
            this.editMode = false;
            this.draftNoteHtml = this.noteHtml;
        } else {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    get showCancel() {
        return this.editMode;
    }

    get showClose() {
        return !this.editMode;
    }
}