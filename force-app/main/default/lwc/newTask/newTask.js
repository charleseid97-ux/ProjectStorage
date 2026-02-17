import EVENT_MEETINGNOTE from '@salesforce/schema/Event.Meeting_Note__c';
import { LightningElement, api, track, wire } from 'lwc';
import { createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import userId from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import UserName from '@salesforce/schema/User.Name';

import getUsers from '@salesforce/apex/CTL_MeetingNotes.getUsers';


export default class NewTask extends LightningElement {
  @api recordId; // Event Id

  @track allTasks = [
    { Description__c: '', ActivityDate: '', OwnerId: '', OwnerLabel: '', Index: 0, IsDelete: false }
  ];

  @track allUsers;
  @track mapUsers = {};
  @track currentUserName = '';

  isSaving = false;

  // -------- DEBUG helper
  debug(label, payload) {
    // eslint-disable-next-line no-console
    console.log(`[newTask] ${label}`, payload ?? '');
  }
    @wire(getRecord, { recordId: '$recordId', fields: [EVENT_MEETINGNOTE] })
        wiredEventMeetingNote({ data, error }) {
        if (data) {
            this.eventMeetingNoteId = data.fields.Meeting_Note__c?.value;
            console.log('[newTask] Event.Meeting_Note__c =', this.eventMeetingNoteId);
        } else if (error) {
            console.log('[newTask] Error loading Event.Meeting_Note__c', error);
        }
    }

  // -------- current user name (for label)
  @wire(getRecord, { recordId: userId, fields: [UserName] })
  wiredMe({ data, error }) {
    if (data?.fields?.Name?.value) {
      this.currentUserName = data.fields.Name.value;
      this.debug('Current user loaded', { userId, name: this.currentUserName });
      this.applyDefaultOwnerToAllTasks();
    } else if (error) {
      this.debug('Error loading current user', error);
    }
  }

  // -------- load users options (for selector)
  @wire(getUsers)
  users({ data, error }) {
    if (data && data.length) {
      const users = [];
      const mapUsers = {};
      data.forEach(u => {
        users.push({ label: u.Name, value: u.Id });
        mapUsers[u.Id] = u;
      });
      this.allUsers = users;
      this.mapUsers = mapUsers;

      this.debug('Users loaded', { count: users.length });
      this.applyDefaultOwnerToAllTasks();
    } else if (error) {
      this.debug('Error loading users', error);
    }
  }

  // default owner = connected user
  applyDefaultOwnerToAllTasks() {
    // only if we have current user name (or user present in map)
    if (!userId) return;

    // prefer wire name, fallback to mapUsers if available
    const label = this.currentUserName || this.mapUsers?.[userId]?.Name || 'Current User';

    const updated = this.allTasks.map(t => ({
      ...t,
      OwnerId: t.OwnerId || userId,
      OwnerLabel: t.OwnerLabel || label
    }));
    this.allTasks = updated;

    this.debug('Default owner applied', { ownerId: userId, ownerLabel: label, tasks: this.allTasks });
  }

  // -------- UI handlers
  handleAddTask() {
    this.debug('Add task clicked', { before: this.allTasks });

    const tasks = [...this.allTasks];
    const idx = tasks.length;

    tasks[idx - 1].IsDelete = false;

    // default owner also on new row
    const label = this.currentUserName || this.mapUsers?.[userId]?.Name || 'Current User';

    tasks.push({
      Description__c: '',
      ActivityDate: '',
      OwnerId: userId,
      OwnerLabel: label,
      Index: idx,
      IsDelete: true
    });

    this.allTasks = tasks;
    this.debug('Task added', { after: this.allTasks });
  }

  handleDeleteTask(e) {
    const index = parseInt(e.target.dataset.id, 10);
    this.debug('Delete task clicked', { index });

    const tasks = [...this.allTasks];
    tasks.splice(index, 1);

    if (tasks.length > 0) {
      tasks[tasks.length - 1].IsDelete = true;
    }

    // reindex to keep dataset indexes consistent
    this.allTasks = tasks.map((t, i) => ({ ...t, Index: i, IsDelete: i === tasks.length - 1 }));
    this.debug('Task deleted', { after: this.allTasks });
  }

  handleDescriptionChange(e) {
    const index = parseInt(e.target.dataset.id, 10);
    const value = e.target.value;

    this.allTasks[index].Description__c = value;
    this.debug('Description changed', { index, value });
  }

  handleDateChange(e) {
    const index = parseInt(e.target.dataset.id, 10);
    const value = e.target.value;

    this.allTasks[index].ActivityDate = value;
    this.debug('Date changed', { index, value });
  }

  handleUsers(e) {
    const index = parseInt(e.target.dataset.id, 10);
    const v = e.detail?.selectedValues;
    const ownerId = Array.isArray(v) ? v[0] : v;

    const ownerLabel = e.detail?.selectedLabel || this.mapUsers?.[ownerId]?.Name || '';

    this.allTasks[index].OwnerId = ownerId;
    this.allTasks[index].OwnerLabel = ownerLabel;

    this.debug('Owner selected', { index, ownerId, ownerLabel });
  }

    handleRemoveSelectedUser(e) { 
        const index = parseInt(e.target.dataset.id, 10);

        // ✅ vider pour faire réapparaître le selector "Assigned To"
        this.allTasks[index].OwnerId = '';
        this.allTasks[index].OwnerLabel = '';

        this.debug('Owner cleared (user can pick another)', { index });
    }


  // -------- save
  async handleSaveTasks() {
    this.debug('Save clicked', { recordId: this.recordId, tasks: this.allTasks });

    if (!this.recordId) {
      this.toast('Error', 'Missing Event recordId', 'error');
      return;
    }

    // validation (same spirit as original)
    const invalid = this.allTasks.some(t => !t.Description__c || !t.ActivityDate || !t.OwnerId);
    if (invalid) {
      this.toast('Error', 'Please fill Description, Due Date and Assigned To for each task.', 'error');
      return;
    }

    this.isSaving = true;

    try {
      for (const t of this.allTasks) {
        const fields = {
          Subject: 'Follow Up - Event',
          Description__c: t.Description__c,
          ActivityDate: t.ActivityDate,
          OwnerId: t.OwnerId,
          WhatId: this.eventMeetingNoteId,       // ✅ attach to MeetingNote
          Priority: 'Normal',
          Status: 'Not Started'
        };

        this.debug('Creating Task with fields', fields);

        await createRecord({ apiName: 'Task', fields });
      }

      this.toast('Success', 'Tasks created and attached to the Event.', 'success');

      // refresh page + close action
      // ✅ dire à Aura de fermer + refresh
        this.debug('Dispatching done event to Aura');
        this.dispatchEvent(new CustomEvent('done'));

      // Force refresh current record page
      // eslint-disable-next-line no-eval
      eval("$A.get('e.force:refreshView').fire();");

    } catch (error) {
      this.debug('Error creating tasks', error);
      this.toast('Error', error?.body?.message || 'Error creating tasks', 'error');
    } finally {
      this.isSaving = false;
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}