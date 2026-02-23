import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord } from 'lightning/uiRecordApi';
import FORM_FACTOR from '@salesforce/client/formFactor';
import getContacts from '@salesforce/apex/CTL_MeetingNotes.getNeededContacts';
import getClientContacts from '@salesforce/apex/CTL_MeetingNotes.getClientContacts';
import createRelatedObjects from '@salesforce/apex/CTL_MeetingNotes.createRelatedObjects';
import { NavigationMixin } from 'lightning/navigation';
import USER_ID from '@salesforce/user/Id';

export default class AiMeetingNote extends NavigationMixin(LightningElement) {
  @api recordId;
  @api objectApiName;
  @track isLoading = true;
  @track meetingDate;
  @track meetingNote = {};
  @track taskObjects = [];
  initialMeetingName = 'AI Generated Meeting Note';
  clientSearchKey = '';

  // --- Attendees ---
  @track externalContacts = [];
  @track internalContacts = [];
  @track selectedClients = [];
  @track selectedInternals = [];
  @track clientPills = [];
  @track internalPills = [];
  @track mapContacts = {};
  @track mapIntContacts = {};
  @track allSelectedClients = [];
  @track prevSelectedCont = [];

  // Guidance toggle
  @track showGuidance = false;

  defaultMeetingType = 'Meeting';
  fieldsInitialized = false;

  renderedCallback() {
    if (this.fieldsInitialized) return;

    const today = new Date().toISOString().split('T')[0];

    const dateField = this.template.querySelector('[data-field="date"]');
    if (dateField && !dateField.value) {
      dateField.value = today;
    }

    const meetingTypeField = this.template.querySelector('[data-field="meetingType"]');
    if (meetingTypeField && !meetingTypeField.value) {
      meetingTypeField.value = this.defaultMeetingType;
    }

    this.fieldsInitialized = true;
  }


  get guidanceIcon() {
    return this.showGuidance ? 'utility:chevrondown' : 'utility:chevronright';
  }
  toggleGuidance() {
    this.showGuidance = !this.showGuidance;
  }

  // ---- preload launching contact ----
  get fieldsList() {
    return [
      'Contact.Id',
      'Contact.Name',
      'Contact.Email',
      'Contact.AccountId',
      'Contact.Account.Name'
    ];
  }

  @wire(getRecord, { recordId: '$recordId', fields: '$fieldsList' })
  wiredContact({ data, error }) {
    if (data && data.fields) {
      const contactId = data.fields.Id.value;
      const contactName = data.fields.Name.value;
      const accountName = data.fields?.Account?.displayValue || '';
      const accountId = data.fields?.Account?.value?.fields?.Id?.value || '';
      this.mapContacts[contactId] = {
        Id: contactId,
        Name: contactName,
        Account: { Name: accountName, Id: accountId }
      };
      this.selectedClients = [contactId];
      this.allSelectedClients = [contactId];
      this.clientPills = this.contactsPills([contactId], 'standard:contact');
    } else if (error) {
      console.error('Error loading contact record:', error);
    }
  }

  // ---- Attendees Apex wires ----
  @wire(getContacts)
  handleInternalContacts({ data, error }) {
    if (data) {
        data.forEach(cont => {
            this.mapIntContacts[cont.Id] = cont;

        });
      this.internalContacts = data.map(c => ({
        label: c.Name,
        value: c.Id,
        Id: c.Id,
        user: c.User__c
      }));
    } else if (error) {
      console.error('Error loading internal contacts', error);
    }
  }

  @wire(getClientContacts, { searchKey: '$clientSearchKey', selectedIds: '$allSelectedClients' })
  handleClientContacts({ data, error }) {
    if (data && data.length) {
      const external = [];
      const mapCont = { ...this.mapContacts };
      data.forEach(c => {
        external.push({ label: `${c.Name} | ${c.Account?.Name}`, value: c.Id });
        mapCont[c.Id] = c;
      });
      this.externalContacts = external;
      this.mapContacts = mapCont;
    } else if (error) {
      console.error('Error loading client contacts', error);
    }
    this.isLoading = false;
  }

  connectedCallback() {
    const today = new Date();
    this.meetingDate = today.toISOString().split('T')[0];
  }

  // ---- Attendee handlers ----
  handleClients(e) {
    this.clientSearchKey = e.detail.searchKey;
    this.selectedClients = [...e.detail.selectedValues];
    this.allSelectedClients = [...new Set([...this.prevSelectedCont, ...this.selectedClients])];
    this.clientPills = this.contactsPills(this.allSelectedClients, 'standard:contact');
  }

  handleInternal(e) {
    this.selectedInternals = [...e.detail.selectedValues];
    this.internalPills = this.intPills(this.selectedInternals, 'standard:user');
  }

  handleItemRemove(e) {
    const origin = e.target.dataset.item;
    const index = e.detail.index;
    if (origin === 'Client') {
      this.clientPills.splice(index, 1);
      const removed = this.allSelectedClients.splice(index, 1);
      const id = removed[0];
      this.selectedClients = this.selectedClients.filter(c => c !== id);
    } else if (origin === 'Internal') {
      this.internalPills.splice(index, 1);
      this.selectedInternals.splice(index, 1);
    }
  }

  contactsPills(allCont, icon) {
    return allCont.map(id => ({
      type: 'icon',
      label: this.mapContacts[id]?.Name,
      name: id,
      iconName: icon,
      alternativeText: 'contact',
      isLink: true,
      href: '/' + id
    }));
  }

  intPills(allCont, icon) {
    return allCont.map(id => ({
      type: 'icon',
      label: this.mapIntContacts[id]?.Name,
      name: id,
      iconName: icon,
      alternativeText: 'contact',
      isLink: true,
      href: '/' + id
    }));
  }
  
  // ---- Form actions ----
  handleSubmit(evt) {
    evt.preventDefault();
    this.isLoading = true;

    const fields = evt.detail.fields;

    const rawNote = fields.Raw_Note__c ? fields.Raw_Note__c.trim() : '';
    if (rawNote.length < 500) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Too Short',
          message: 'Please enter at least 500 characters in the raw note field.',
          variant: 'error'
        })
      );
      this.isLoading = false;
      return;
    }

    // Champs déjà forcés
    //fields.Date__c = this.meetingDate;
    fields.SalesPresentation__c = true;

   
    this.template.querySelector('lightning-record-edit-form').submit(fields);
  }


  async handleSuccess(event) {
    this.isLoading = true;
    try {
      const meetingId = event.detail.id;
      const meetingName = event.detail.fields.Name.value;
      const meetingDate = event.detail.fields.Date__c?.value;

      const today = new Date();
      const start = new Date(meetingDate);
      const startDT = new Date(start.getFullYear(), start.getMonth(), start.getDate(), today.getHours(), today.getMinutes());
      const endDT = new Date(startDT.getTime() + 30 * 60000);

      const evtSalesforce = {
        StartDateTime: startDT.toISOString(),
        EndDateTime: endDT.toISOString(),
        Subject: meetingName,
        Meeting_Note__c: meetingId,
        WhoId: this.allSelectedClients[0],
        WhatId: this.mapContacts[this.allSelectedClients[0]]?.Account?.Id
      };

      const attendees = [...this.allSelectedClients.slice(1), ...this.selectedInternals];

      const res = await createRelatedObjects({
        evt: evtSalesforce,
        participants: attendees,
        prodInterest: [],
        tasks: this.taskObjects
      });

      const eventId = res?.eventId;
      console.log('===Related records created successfully', res);
      console.log('===Event ID:', eventId);
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Meeting Note Created',
          message: 'Meeting Note and related Event created successfully.',
          variant: 'success'
        })
      );

      if (eventId) {
        this[NavigationMixin.Navigate]({
          type: 'standard__recordPage',
          attributes: {
            recordId: eventId,
            objectApiName: 'Event',
            actionName: 'view'
          }
        });
      } else {
        this.dispatchEvent(new CloseActionScreenEvent());
      }

      this.isLoading = false;
    } catch (error) {
      console.error('Error creating related records', error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Error',
          message: error?.body?.message || 'Error creating related records',
          variant: 'error'
        })
      );
      this.isLoading = false;
    }
  }


  handleError(e) {
    this.isLoading = false;
    this.dispatchEvent(
      new ShowToastEvent({
        title: 'Error',
        message: e.detail?.message || 'Error saving Meeting Note.',
        variant: 'error'
      })
    );
  }

  handleCancel() {
    if (FORM_FACTOR === 'Small' || FORM_FACTOR === 'Medium') window.history.back();
    else this.dispatchEvent(new CloseActionScreenEvent());
  }
}