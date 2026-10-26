/* eslint-disable @lwc/lwc/no-inner-html */
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getContacts from '@salesforce/apex/CTL_MeetingNotes.getNeededContacts';
import getEmailTemplate from '@salesforce/apex/CTL_MeetingNotes.getEmailTemplate';
import sendEmailMeeting from '@salesforce/apex/CTL_MeetingNotes.sendEmailMeeting';
import getMeetingNoteIdByEvent from '@salesforce/apex/MeetingNoteShareController.getMeetingNoteIdByEvent';
import getOrgId from '@salesforce/apex/CTL_MeetingNotes.getOrgId';
import getMeetingNoteEmailData from '@salesforce/apex/MeetingNoteShareController.getMeetingNoteEmailData';

export default class MeetingNoteShare extends LightningElement {
    @api recordId; // Id de l’Event

    @track allContactShare;
    @track selectedContactShare = [];
    @track contactPills = [];
    @track isLoading = true;

    @track emailTemplate;
    @track meetingNoteId;

    // Données nécessaires pour buildEmail (mêmes structures que MeetingNote.js)
    @track clientPills = [];
    @track internalPills = [];
    @track clientInterest = [];
    @track taskObjects = [];
    @track isSalesPres = true;

    @track orgId = '';
    @track meetingNoteName = '';

    mapContacts = {};

    // Récupère l’Id de la Meeting Note associée à l’Event
    @wire(getMeetingNoteIdByEvent, { eventId: '$recordId' })
    wiredMeetingNoteId({ data, error }) {
        if (data) {
            this.meetingNoteId = data;
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

    // OrgId (utilisé pour construire l’url des images rating)
    @wire(getOrgId)
    wiredOrgId({ data, error }) {
        if (data) this.orgId = data;
        else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading Org ID', error);
        }
    }

    // Charge les contacts internes disponibles pour le partage
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

    // Charge le template d’email
    @wire(getEmailTemplate, { name: 'MeetingNoteEmail' })
    wiredTemplate({ data, error }) {
        if (data) {
            this.emailTemplate = data;
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading email template', error);
        }
    }

    // Récupère toutes les données nécessaires à buildEmail
    @wire(getMeetingNoteEmailData, { meetingNoteId: '$meetingNoteId' })
    wiredEmailData({ data, error }) {
        if (data) {
            this.isSalesPres = !!data.isSalesPres;
            this.meetingNoteName = data.meetingNoteName || '';

            this.clientPills = data.clientPills ? [...data.clientPills] : [];
            this.internalPills = data.internalPills ? [...data.internalPills] : [];
            this.clientInterest = data.clientInterest ? [...data.clientInterest] : [];
            this.taskObjects = data.taskObjects ? [...data.taskObjects] : [];
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading email data from MeetingNote', error);
            this.showToast(
                'Error while loading Meeting Note email data.',
                'error',
                'Error'
            );
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
            this.dispatchEvent(new CustomEvent('done', { bubbles: true, composed: true }));
            return;
        }

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
            if (c) contShareList.push(c);
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
            HtmlValue: this.buildEmail(this.emailTemplate.HtmlValue),
            Subject: this.emailTemplate.Subject,
            EnhancedLetterheadId: this.emailTemplate.EnhancedLetterheadId
        };

        sendEmailMeeting({
            et: tmpEmail,
            participants: contShareList,
            meetingNoteId: this.meetingNoteId
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

    closeAction() {
        this.dispatchEvent(new CustomEvent('done', { bubbles: true, composed: true }));
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

    buildEmail(emailTemplateBasic) {
        const parser = new DOMParser();
        const orgUrl = window.location.origin;

        const doc = parser.parseFromString(emailTemplateBasic, 'text/html');

        // Remplace le merge field Meeting_Note__c.Name par un lien vers la Meeting Note
        const body = doc.body;
        const marker = '{{{Meeting_Note__c.Name}}}';
        if (body && this.meetingNoteId && body.innerHTML && body.innerHTML.includes(marker)) {
           const url = orgUrl + '/' + this.recordId; // ouvre l'Event
            const name = this.meetingNoteName || marker; // affiche le nom de la Meeting Note
            body.innerHTML = body.innerHTML.replace(marker, `<a href="${url}">${name}</a>`);
        }

        // client Attendees...
        const elmClient = doc.getElementById('companyAttList');
        elmClient?.replaceChildren();
        this.clientPills.forEach(parti => {
            const newNode = doc.createElement('li');
            newNode.innerText = parti.label;
            elmClient?.appendChild(newNode);
        });

        // Carmi Attendees...
        const elmCarmi = doc.getElementById('carmiAttList');
        elmCarmi?.replaceChildren();
        this.internalPills.forEach(parti => {
            const newNode = doc.createElement('li');
            newNode.innerText = parti.label;
            elmCarmi?.appendChild(newNode);
        });

        // Client Interest...
        if (this.isSalesPres) {
            const elmInterest = doc.getElementById('interestLines');
            this.clientInterest.forEach(inter => {
                const imgUrl = orgUrl + '/file-asset-public/' + inter.pic + '?oid=' + this.orgId;
                const newNode = doc.createElement('tr');
                newNode.innerHTML =
                    `<td><span>${inter.label}</span></td>` +
                    `<td><span><img alt=${inter.pic} src=${imgUrl} title=${inter.pic}/> </span></td>`;
                elmInterest?.appendChild(newNode);
            });
        } else {
            const interestHead = doc.getElementById('interestTableHeader');
            interestHead?.remove();
            const interestTable = doc.getElementById('interestTable');
            interestTable?.remove();
        }

        // Tasks...
        if (this.isSalesPres) {
            const elmTask = doc.getElementById('taskTable');
            this.taskObjects.forEach(task => {
                const newNode = doc.createElement('tr');
                const taskURL = orgUrl + '/' + task.Id;
                newNode.innerHTML =
                    `<td><span><a href="${taskURL}"> ${task.Subject}</a></span></td>` +
                    `<td><span>${task.Description || ''} </span></td>` +
                    `<td><span>${task.ActivityDate || ''} </span></td>` +
                    `<td><span>${task.OwnerLabel || ''} </span></td>`;
                elmTask?.appendChild(newNode);
            });
        } else {
            const taskHead = doc.getElementById('taskTableHeader');
            taskHead?.remove();
            const taskTable = doc.getElementById('taskTable');
            taskTable?.remove();
        }

        return `<html style="overflow-y: hidden;">${doc.documentElement.innerHTML}</html>`;
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
