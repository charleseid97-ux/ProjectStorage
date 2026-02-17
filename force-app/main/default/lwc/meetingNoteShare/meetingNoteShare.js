import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import getContacts from '@salesforce/apex/CTL_MeetingNotes.getNeededContacts';
import getEmailTemplate from '@salesforce/apex/CTL_MeetingNotes.getEmailTemplate';
import sendEmailMeeting from '@salesforce/apex/CTL_MeetingNotes.sendEmailMeeting';
import getMeetingNoteIdByEvent from '@salesforce/apex/MeetingNoteShareController.getMeetingNoteIdByEvent';

export default class MeetingNoteShare extends LightningElement {
    @api recordId; // Event Id (quick action context)

    @track allContactShare;
    @track selectedContactShare = [];
    @track contactPills = [];
    @track isLoading = true;

    @track emailTemplate;
    @track meetingNoteId; // Id de la Meeting Note liée à l'Event

    mapContacts = {};

    // 🔹 Récupérer l'Id de la Meeting Note à partir de l'Event via Apex
    @wire(getMeetingNoteIdByEvent, { eventId: '$recordId' })
    wiredMeetingNoteId({ data, error }) {
        console.log('wiredMeetingNoteId recordId (Event) = ', this.recordId);
        console.log('wiredMeetingNoteId data = ', data);
        console.log('wiredMeetingNoteId error = ', error);

        if (data) {
            this.meetingNoteId = data;
            console.log('=> meetingNoteId = ', this.meetingNoteId);
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading Meeting Note Id from Event', error);
            this.showToast(
                'Error while loading the related Meeting Note from Event.',
                'error',
                'Error'
            );
        }
    }

    // 🔹 Charger les contacts Carmignac
    @wire(getContacts)
    allContacts({ data, error }) {
        if (data && data.length) {
            const internal = [];
            const mapCont = { ...this.mapContacts };

            data.forEach(cont => {
                internal.push({
                    label: cont.Name,
                    value: cont.Id,
                    user: cont.User__c
                });
                mapCont[cont.Id] = { ...cont };
            });

            this.allContactShare = internal;
            this.mapContacts = mapCont;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading contacts', error);
            this.showToast('Error while loading contacts', 'error', 'Error');
        }
        this.isLoading = false;
    }

    // 🔹 Charger le template d'email existant (comme dans le LWC principal)
    @wire(getEmailTemplate, { name: 'MeetingNoteEmail' })
    wiredTemplate({ data, error }) {
        if (data) {
            this.emailTemplate = data;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading email template', error);
        }
    }

    handleShareOther(event) {
        this.selectedContactShare = [...event.detail.selectedValues];
        this.contactPills = [...this.contactsPills(this.selectedContactShare, 'standard:user')];
    }

    handleItemRemove(event) {
        const index = event.detail.index;
        this.contactPills.splice(index, 1);
        this.selectedContactShare.splice(index, 1);
        this.contactPills = [...this.contactPills];
        this.selectedContactShare = [...this.selectedContactShare];
    }

    handleShare() {
        if (!this.selectedContactShare || !this.selectedContactShare.length) {
            this.showToast(
                'Please select at least one contact to share with.',
                'error',
                'No recipients'
            );
            this.dispatchEvent(
                new CustomEvent('done', {
                bubbles: true,
                composed: true
                })
            );
            return;
        }

        // ⚠️ On est sur Event, on doit avoir une Meeting Note liée
        if (!this.meetingNoteId) {
            this.showToast(
                'This Event is not linked to a Meeting Note (Meeting_Note__c is empty).',
                'error',
                'Configuration error'
            );
            return;
        }

        if (!this.emailTemplate) {
            this.showToast(
                'Email template not available. Please contact your administrator.',
                'error',
                'Configuration error'
            );
            return;
        }

        const contShareList = [];
        this.selectedContactShare.forEach(id => {
            const c = this.mapContacts[id];
            if (c) {
                contShareList.push(c);
            }
        });

        if (!contShareList.length) {
            this.showToast(
                'Unable to resolve selected contacts. Please try again or contact your administrator.',
                'error',
                'Error'
            );
            return;
        }

        this.isLoading = true;

        const tmpEmail = {
            HtmlValue: this.emailTemplate.HtmlValue,
            Subject: this.emailTemplate.Subject,
            EnhancedLetterheadId: this.emailTemplate.EnhancedLetterheadId
        };

        // 🔁 Réutilisation de ton Apex existant
        sendEmailMeeting({
            et: tmpEmail,
            participants: contShareList,
            meetingNoteId: this.meetingNoteId // 👉 Id de la Meeting Note, pas l'Event
        })
            .then(() => {
                this.showToast('Meeting Note shared successfully.', 'success', 'Success');
                this.closeAction();
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error sharing meeting note', error);
                const message =
                    error && error.body && error.body.message
                        ? error.body.message
                        : 'Unexpected error while sharing the meeting note.';
                this.showToast(message, 'error', 'Error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.closeAction();
    }

    closeAction() {
        this.dispatchEvent(
            new CustomEvent('done', {
            bubbles: true,
            composed: true
            })
        );
    }

    contactsPills(allCont, icon) {
        const items = [];
        allCont.forEach(contId => {
            const cont = this.mapContacts[contId];
            if (cont) {
                items.push({
                    type: 'icon',
                    label: cont.Name,
                    name: cont.Id,
                    iconName: icon,
                    alternativeText: 'contact',
                    isLink: true,
                    href: '/' + cont.Id
                });
            }
        });
        return items;
    }

    showToast(message, variant, title) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
}