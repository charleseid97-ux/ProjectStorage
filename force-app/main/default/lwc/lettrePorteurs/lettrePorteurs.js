import { LightningElement, api, wire } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LETTRE_FIELD from '@salesforce/schema/ProjectProduct__c.LettreRequise__c';
import COMMENTAIRE_FIELD from '@salesforce/schema/ProjectProduct__c.CommentaireLettre__c';

const FIELDS = [LETTRE_FIELD, COMMENTAIRE_FIELD];

export default class LettrePorteurs extends LightningElement {
  @api recordId;
  @api editable = false;

  // current values
  lettreValue;
  commentaire;

  // initial values (for change detection)
  initialLettreValue;
  initialCommentaire;

  isSaving = false;

  /* ===== LOAD DATA ===== */
  @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
  wiredRecord({ data }) {
    if (data) {
      this.lettreValue = data.fields.LettreRequise__c.value;
      this.commentaire = data.fields.CommentaireLettre__c.value;

      this.initialLettreValue = this.lettreValue;
      this.initialCommentaire = this.commentaire;
    }
  }

  /* ===== UI STATE ===== */

  get isReadOnly() {
    return !this.editable;
  }

  get isYes() {
    return this.lettreValue === 'Yes';
  }

  get isNo() {
    return this.lettreValue === 'No';
  }

  get isDirty() {
    return (
      this.lettreValue !== this.initialLettreValue ||
      this.commentaire !== this.initialCommentaire
    );
  }

  get showSaveButton() {
    return this.isDirty && !this.isSaving;
  }

  /* ===== HANDLERS ===== */

  handleLettreChange(event) {
    this.lettreValue = event.target.value;
  }

  handleCommentChange(event) {
    this.commentaire = event.target.value;
  }

  handleSave() {
    this.isSaving = true;

    const fields = {
      Id: this.recordId,
      [LETTRE_FIELD.fieldApiName]: this.lettreValue,
      [COMMENTAIRE_FIELD.fieldApiName]: this.commentaire
    };

    updateRecord({ fields })
      .then(() => {
        // reset dirty state
        this.initialLettreValue = this.lettreValue;
        this.initialCommentaire = this.commentaire;

        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Saved',
            message: 'Decision successfully saved',
            variant: 'success'
          })
        );
      })
      .catch(error => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error',
            message: error.body?.message || 'Unexpected error',
            variant: 'error'
          })
        );
      })
      .finally(() => {
        this.isSaving = false;
      });
  }
}