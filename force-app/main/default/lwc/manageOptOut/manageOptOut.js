/**
 * @description       :
 * @author            : SILA Nicolas
 * @last modified on  : 04-04-2024
 * @last modified by  : SILA Nicolas
 **/
import { LightningElement, api, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import updateRecord from "@salesforce/apex/PreferenceCenterController.updateRecord";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";

import HasOptedOutOfEmail_FIELD from "@salesforce/schema/Contact.HasOptedOutOfEmail";
import Invitation_Opt_Out__c_FIELD from "@salesforce/schema/Contact.Invitation_Opt_Out__c";
import Newsletter_Opt_Out__c_FIELD from "@salesforce/schema/Contact.Newsletter_Opt_Out__c";
import Prospace_Opt_Out__c_FIELD from "@salesforce/schema/Contact.Prospace_Opt_Out__c";
import GDPR_Flag_for_Deletion from "@salesforce/schema/Contact.To_Delete__c";
import GDPR_external_request_for_data_deletion from "@salesforce/schema/Contact.GDPR_external_request_for_data_deletion__c";
import HardBounced_FIELD from "@salesforce/schema/Contact.Global_Hardbounced__c";
import HardBouncedPadot_FIELD from "@salesforce/schema/Contact.pi__pardot_hard_bounced__c";
import HardBouncedMandrill_FIELD from "@salesforce/schema/Contact.HardBounced_Mandrill__c";
import Email_FIELD from "@salesforce/schema/Contact.Email";
import WebsiteLogin_FIELD from "@salesforce/schema/Contact.WebsiteLogin__c";

const fields = [
  HasOptedOutOfEmail_FIELD,
  WebsiteLogin_FIELD,
  Email_FIELD,
  Invitation_Opt_Out__c_FIELD,
  Newsletter_Opt_Out__c_FIELD,
  Prospace_Opt_Out__c_FIELD,
  HardBounced_FIELD,
  GDPR_external_request_for_data_deletion,
  GDPR_Flag_for_Deletion,
  HardBouncedMandrill_FIELD,
  HardBouncedPadot_FIELD
];

export default class manageOptOut extends LightningElement {
  // Flexipage provides recordId and objectApiName

  @api recordId;
  @track optOutField;
  OptReasonLoading = false;
  openModal = false;
  optOutModal = false;
  emailIsNotChanged = true;
  webLoginIsNotChanged = true;
  isNotChanged = true;
  hardBounceModal = false;
  @track email;
  @track hardbounceEmail;

  toggleSection(event) {
    let buttonid = event.currentTarget.dataset.buttonid;
    let currentsection = this.template.querySelector(
      '[data-id="' + buttonid + '"]'
    );
    if (currentsection.className.search("slds-is-open") === -1) {
      currentsection.className = "slds-section slds-is-open";
    } else {
      currentsection.className = "slds-section slds-is-close";
    }
  }

  @wire(getRecord, { recordId: "$recordId", fields })
  contact;

  get generalOptOut() {
    return getFieldValue(this.contact.data, HasOptedOutOfEmail_FIELD);
  }

  get InvitationOptOut() {
    return getFieldValue(this.contact.data, Invitation_Opt_Out__c_FIELD);
  }

  get newsletterOptOut() {
    return getFieldValue(this.contact.data, Newsletter_Opt_Out__c_FIELD);
  }
  get hardbouncePardot() {
    return getFieldValue(this.contact.data, HardBouncedPadot_FIELD);
  }
  get hardBounceMandrill() {
    return getFieldValue(this.contact.data, HardBouncedMandrill_FIELD);
  }

  get prospaceOptOut() {
    return getFieldValue(this.contact.data, Prospace_Opt_Out__c_FIELD);
  }
  get notHardbounced() {
    return !getFieldValue(this.contact.data, HardBounced_FIELD);
  }

  get hardbounced() {
    return getFieldValue(this.contact.data, HardBounced_FIELD);
  }

  get gdprFlag() {
    return (
      getFieldValue(
        this.contact.data,
        GDPR_external_request_for_data_deletion
      ) || getFieldValue(this.contact.data, GDPR_Flag_for_Deletion)
    );
  }

  updateToggle(event, category, nameValue, checkedValue) {
    let checked = checkedValue != null ? checkedValue : event.target.checked;
    let name = nameValue != null ? nameValue : event.target.name;
    updateRecord({ recordId: this.recordId, apiName: name, apiValue: checked })
      .then(() => {
        refreshApex(this.contact);
        this.showNotification(
          checked === true ? "Successfully Opted Out" : "Successfully Opted In",
          "",
          "success"
        );
      })
      .catch((error) => {
        console.log(error);
        this.showNotification("updateFail", "", "warning");
      })
      .finally(() => {
        this.OptReasonLoading = false;
      });
  }

  updateAllToggles(event) {
    this.OptReasonLoading = true;
    this.updateToggle(event);
  }

  handleSaveClick() {
    this.OptReasonLoading = true;
  }

  closeOptOutModalWithReason() {
    this.optOutModal = false;
    this.openModal = false;
    this.OptReasonLoading = false;
    this.updateToggle(null, "Preference", "HasOptedOutOfEmail", true);
  }

  deblockSave(event) {
    const fieldName = event.target.fieldName;
    const value = event.target.value;

    switch (fieldName) {
      case "Email":
        this.emailIsNotChanged = value === this.email;
        break;
      case "WebsiteLogin__c":
        this.webLoginIsNotChanged = value === this.hardbounceEmail;
        break;
      default:
        break;
    }
    this.isNotChanged = this.emailIsNotChanged && this.webLoginIsNotChanged;
  }

  closeHardBounceModalOnSubmit(event) {
    if (
      (this.hardbouncePardot && event.detail.fields.Email !== this.email) ||
      (this.hardBounceMandrill &&
        event.detail.fields.WebsiteLogin__c !== this.WebsiteLogin__c)
    ) {
      this.template.querySelector('[data-id="hardbounceToggle"]').value = true;
      this.template.querySelector(
        '[data-id="hardbounceToggle"]'
      ).checked = true;
    } else {
      this.template.querySelector('[data-id="hardbounceToggle"]').value = false;
      this.template.querySelector(
        '[data-id="hardbounceToggle"]'
      ).checked = false;
    }
  }

  closeHardBounceModalOnSuccess() {
    this.hardBounceModal = false;
    this.openModal = false;
    this.OptReasonLoading = false;
  }

  closeOptOutModal() {
    this.openModal = false;
    this.OptReasonLoading = false;

    if (this.optOutModal) {
      this.optOutModal = false;
      this.template.querySelector('[data-id="optOut"]').value = false;
      this.template.querySelector('[data-id="optOut"]').checked = false;
    } else if (this.hardBounceModal) {
      this.hardBounceModal = false;
      this.template.querySelector('[data-id="hardbounceToggle"]').value = true;
      this.template.querySelector('[data-id="hardbounceToggle"]').checked = true;

    }
  }

  handleFormError(event) {
    console.log("error", event.detail);
  }

  handleHardBounced(event) {
    let checked = event.target.checked;
    if (!checked) {
      this.openModal = true;
      this.hardBounceModal = true;
      this.email = this.contact.data.fields.Email.value;
      this.hardbounceEmail = this.contact.data.fields.WebsiteLogin__c.value;
    } else {
      this.hardBounceModal = false;
      this.openModal = false;
    }
  }

  updateToggleOptOut(event) {
    let checked = event.target.checked;
    if (checked) {
      this.optOutModal = true;
      this.openModal = true;
    } else {
      this.updateAllToggles(event);
      this.optOutModal = false;
      this.openModal = false;
    }
  }

  handleFormSuccess() {
    this.OptReasonLoading = false;
  }

  //Description : Displays a notification/toast
  showNotification(toastTitle, toastMessage, toastVariant) {
    const toastEvent = new ShowToastEvent({
      title: toastTitle,
      message: toastMessage,
      variant: toastVariant //Possible Values : info(default), success, warning, and error.
    });
    this.dispatchEvent(toastEvent);
  }
}