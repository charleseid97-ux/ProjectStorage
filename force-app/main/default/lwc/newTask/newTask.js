import EVENT_MEETINGNOTE from '@salesforce/schema/Event.Meeting_Note__c';
import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import userId from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import UserName from '@salesforce/schema/User.Name';

import getUsers from '@salesforce/apex/CTL_MeetingNotes.getUsers';
import createTasks from '@salesforce/apex/newTaskCTRL.createTasks';
import getMeetingNoteId from '@salesforce/apex/newTaskCTRL.getMeetingNoteId';

export default class NewTask extends LightningElement {
  @api recordId; // Event Id

  // Meeting Note linked to the Event (WhatId target)
  eventMeetingNoteId;

  allTasks = [
    { Description__c: '', ActivityDate: '', OwnerId: '', OwnerLabel: '', Index: 0, IsDelete: false }
  ];

  allUsers;
  mapUsers = {};
  currentUserName = '';

  isSaving = false;

  // -------- DEBUG helper
  debug(label, payload) {
    // eslint-disable-next-line no-console
    console.log(`[newTask] ${label}`, payload ?? '');
  }

  // -------- load Event.Meeting_Note__c
  @wire(getRecord, { recordId: '$recordId', fields: [EVENT_MEETINGNOTE] })
  wiredEventMeetingNote({ data, error }) {
    if (data) {
      this.eventMeetingNoteId = data.fields.Meeting_Note__c?.value;
      // eslint-disable-next-line no-console
      console.log('[newTask] Event.Meeting_Note__c =', this.eventMeetingNoteId);
    } else if (error) {
      // eslint-disable-next-line no-console
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
      data.forEach((u) => {
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

  // -------- small immutable helper to ensure rerender
  updateTask(index, patch) {
    this.allTasks = this.allTasks.map((t, i) => (i === index ? { ...t, ...patch } : t));
  }

  // default owner = connected user (do not override existing owner/label)
  applyDefaultOwnerToAllTasks() {
    if (!userId) return;

    // If we don't yet know a real label, skip to avoid freezing "Current User" forever
    const label = this.currentUserName || this.mapUsers?.[userId]?.Name;
    if (!label) return;

    this.allTasks = this.allTasks.map((t) => ({
      ...t,
      OwnerId: t.OwnerId || userId,
      OwnerLabel: t.OwnerLabel || label
    }));

    this.debug('Default owner applied', { ownerId: userId, ownerLabel: label, tasks: this.allTasks });
  }

  // -------- UI handlers
  handleAddTask() {
    this.debug('Add task clicked', { before: this.allTasks });

    const tasks = [...this.allTasks];
    const idx = tasks.length;

    // previous last row can't be deleted anymore
    if (tasks[idx - 1]) tasks[idx - 1] = { ...tasks[idx - 1], IsDelete: false };

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
    const index = Number(e.target.dataset.id);
    this.debug('Delete task clicked', { index });

    const tasks = [...this.allTasks];
    tasks.splice(index, 1);

    // reindex + only last is deletable
    this.allTasks = tasks.map((t, i) => ({
      ...t,
      Index: i,
      IsDelete: i === tasks.length - 1
    }));

    this.debug('Task deleted', { after: this.allTasks });
  }

  handleDescriptionChange(e) {
    const index = Number(e.target.dataset.id);
    this.updateTask(index, { Description__c: e.target.value });
    this.debug('Description changed', { index, value: e.target.value });
  }

  handleDateChange(e) {
    const index = Number(e.target.dataset.id);
    this.updateTask(index, { ActivityDate: e.target.value });
    this.debug('Date changed', { index, value: e.target.value });
  }

  handleUsers(e) {
    const index = Number(e.target.dataset.id);

    const v = e.detail?.selectedValues;
    const ownerId = Array.isArray(v) ? v[0] : v;

    const ownerLabel = e.detail?.selectedLabel || this.mapUsers?.[ownerId]?.Name || '';

    this.updateTask(index, { OwnerId: ownerId, OwnerLabel: ownerLabel });
    this.debug('Owner selected', { index, ownerId, ownerLabel });
  }

  handleRemoveSelectedUser(e) {
    const index = Number(e.target.dataset.id);

    // clear so selector appears again
    this.updateTask(index, { OwnerId: '', OwnerLabel: '' });

    this.debug('Owner cleared (user can pick another)', { index });
  }

  // -------- save
  async handleSaveTasks() {
    this.debug('Save clicked', { recordId: this.recordId, tasks: this.allTasks });

    if (!this.recordId) {
      this.toast('Error', 'Missing Event recordId', 'error');
      return;
    }
    if (!this.eventMeetingNoteId) {
      try {
        this.eventMeetingNoteId = await getMeetingNoteId({ eventId: this.recordId });
        console.log('[newTask] Apex fallback meetingNoteId =', this.eventMeetingNoteId);
      } catch (e) {
        console.log('[newTask] getMeetingNoteId error =', JSON.stringify(e));
      }
    }
    if (!this.eventMeetingNoteId) {
      this.toast('Error', 'This Event is not linked to a Meeting Note.', 'error');
      return;
    }

    const invalid = this.allTasks.some((t) => !t.Description__c || !t.ActivityDate || !t.OwnerId);
    if (invalid) {
      this.toast('Error', 'Please fill Description, Due Date and Assigned To for each task.', 'error');
      return;
    }

    this.isSaving = true;

    try {
      const tasksPayload = this.allTasks.map((t) => ({
        sobjectType: 'Task',
        Subject: 'Follow Up - Event',
        Description__c: t.Description__c,
        ActivityDate: t.ActivityDate,
        OwnerId: t.OwnerId,
        WhatId: this.eventMeetingNoteId,
        Priority: 'Normal',
        Status: 'Not Started'
      }));

      this.debug('Creating tasks via Apex', tasksPayload);

      await createTasks({ tasksToInsert: tasksPayload });

      this.toast('Success', 'Tasks created and attached to the Event.', 'success');

      // let Aura wrapper refresh/close if you use it
      this.dispatchEvent(new CustomEvent('done'));
    } catch (error) {
      this.debug('Error creating tasks (Apex)', error);
      const msg =
        error?.body?.message ||
        (Array.isArray(error?.body) ? error.body.map((e) => e.message).join(', ') : null) ||
        error?.message ||
        'Error creating tasks';
      this.toast('Error', msg, 'error');
    } finally {
      this.isSaving = false;
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}