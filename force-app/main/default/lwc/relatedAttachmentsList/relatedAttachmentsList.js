/**
 * @description       :
 * @author            : SILA Nicolas
 * @group             :
 * @last modified on  : 17-12-2024
 * @last modified by  : Khadija EL GDAOUNI
 **/
import { LightningElement, api, wire, track } from "lwc";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import { NavigationMixin } from "lightning/navigation";

import getFilteredAttachments from "@salesforce/apex/AttachmentController.getFilteredAttachments";
import deleteFile from "@salesforce/apex/AttachmentController.deleteFile";
import { refreshApex } from "@salesforce/apex";
import {
  deleteRecord,
  updateRecord,
  getFieldValue,
  getRecord
} from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";
import STATUS_FIELD from "@salesforce/schema/Case.Status";
import ID_FIELD from "@salesforce/schema/Case.Id";
import PARENTID_FIELD from "@salesforce/schema/Case.ParentId";

import TRANSLATIONMODE_FIELD from "@salesforce/schema/Case.Translation_mode__c";
import RECORDTYPE_FIELD from "@salesforce/schema/Case.RecordTypeId";
import PREVIEWURL_FIELD from "@salesforce/schema/Case.Publication_Preview_URL__c";
import TRANSLATION_REQUEST from "@salesforce/schema/Case.Translation_Request_Type__c";
import FILES_LENGTH from "@salesforce/schema/Case.Tech_NbrSourceFiles__c";
import CASE_OBJECT from "@salesforce/schema/Case";

const fields = [
  STATUS_FIELD,
  PARENTID_FIELD,
  ID_FIELD,
  TRANSLATIONMODE_FIELD,
  TRANSLATION_REQUEST,
  RECORDTYPE_FIELD,
  PREVIEWURL_FIELD,
  FILES_LENGTH
];

export default class RelatedAttachmentsList extends NavigationMixin(
  LightningElement
) {
  @api recordId;
  @api isSource;
  @api isPublication = false;
  @api title;
  @api publciationTitle;
  @api ConfirmationButton ="Confirm Proofreading";
  isModalOpen = false;
  currentFileId;
  @track attachments;
  @track attachmentsData;
  recordTypeTranslationRequest;
  recordTypeSubTranslation;
  recordTypeSubPublication;
  attachmentExist = false;
  error;
  localIsSource;
  attachmentNotExist = true;
  showConfirmPopUp = false;

  @wire(getRecord, {
    recordId: "$recordId",
    fields
  })
  case;

  get isTranslationParent(){
    return getFieldValue(this.case.data, RECORDTYPE_FIELD) === this.recordTypeTranslationRequest;
  }
  
  get isRecTypepublication(){
    return getFieldValue(this.case.data, RECORDTYPE_FIELD) === this.recordTypeSubPublication;
  }
  
  get notifyPubCRM(){
    let statusVal = getFieldValue(this.case.data, STATUS_FIELD);
    let recType = getFieldValue(this.case.data, RECORDTYPE_FIELD);
    let previewUrl = getFieldValue(this.case.data, PREVIEWURL_FIELD);
    return statusVal == 'Work in progress' && recType === this.recordTypeSubPublication && this.isPublication && previewUrl !== null;
  }

  get toBeValidated(){
    let statusVal = getFieldValue(this.case.data, STATUS_FIELD);
    let recType = getFieldValue(this.case.data, RECORDTYPE_FIELD);

    return !this.isSource && 
    (
         (recType === this.recordTypeSubTranslation && statusVal !== 'Closed' && statusVal!=='Validated' && this.attachmentExist) 
      || (recType === this.recordTypeSubPublication && !this.notifyPubCRM && this.isPublication && statusVal ==="Preview"));
  }

  

  get isDeepLPro() {
    return getFieldValue(this.case.data, TRANSLATIONMODE_FIELD) === "IA only"
      ? true
      : false;
  }

  get filesLength(){
    return getFieldValue(this.case.data, FILES_LENGTH);
  }

  get statusClosed(){
    let statusVal = getFieldValue(this.case.data, STATUS_FIELD);
    return statusVal === 'Closed';
  }

  @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
  handleObjectInfo({ error, data }) {
    if (data) {
      const rtis = data.recordTypeInfos;
      // 012Aa000002YAevIAG
      this.recordTypeTranslationRequest = Object.keys(rtis).find(
        (rti) => rtis[rti].name === "Translation Request"
      );
      this.recordTypeSubTranslation = Object.keys(rtis).find(
        (rti) => rtis[rti].name === "Sub Translation Request"
      );
      this.recordTypeSubPublication = Object.keys(rtis).find(
        (rti) => rtis[rti].name === "Sub Publication Request"
      );
    }
  }

  connectedCallback() {
    this.localIsSource = this.isSource || false;
  }

  updateStatusRecord(status) {
    let fieldsMap = {};
    fieldsMap[ID_FIELD.fieldApiName] = this.recordId;
    fieldsMap[STATUS_FIELD.fieldApiName] = status;
    const recordInput = {
      fields: fieldsMap
    };
    updateRecord(recordInput);
  }
  

  handleDeleteFile(event) {
    const fileId = event.target.dataset.fileId;
    LightningConfirm.open({
      message: "Are you sure you want to delete this file?",
      variant: "header",
      label: "Please Confirm",
      theme: "error"
    }).then((result) => {
      if (result) {
        deleteRecord(fileId)
          .then(() => {
            this.dispatchEvent(
              new ShowToastEvent({
                title: "Success",
                message: "File deleted successfully",
                variant: "success"
              })
            );
            if(!this.isPublication){
              this.updateStatusRecord("Work in progress");
            }

            this.refreshAttachments();

            // Optionally, refresh the list or execute additional logic
          })
          .catch((error) => {
            this.dispatchEvent(
              new ShowToastEvent({
                title: "Error deleting file",
                message: error.body.message,
                variant: "error"
              })
            );
          });
      }
    });
  }
  validateCase() {
    let reqType = getFieldValue(this.case.data, RECORDTYPE_FIELD);
    if (reqType === this.recordTypeSubPublication) {
      this.updateStatusRecord("Validated");
    } else {

      this.updateStatusRecord("Closed");
      
    }
    this.toBeValidated();

  }

  validatePublication(){
    this.updateStatusRecord("Preview");

  }

  handleUploadFile() {
    console.log('upload file');
    const fileId = this.currentFileId;
    this.template
      .querySelector("c-file-upload-multi-l-w-c")
      .uploadFiles(this.recordId);


    let reqType = getFieldValue(this.case.data, RECORDTYPE_FIELD);

    if (reqType !== this.recordTypeSubPublication) {
      if(this.filesLength>1){
        this.showConfirmPopUp = true;
      }else{
        this.showConfirmPopUp = false;
      }
      if(this.showConfirmPopUp==false){
        //this.updateStatusRecord("Closed");
        // setTimeout(function () {
        /*this[NavigationMixin.Navigate]({
          type: 'standard__recordPage',
          attributes: {
              recordId: getFieldValue(this.case.data, PARENTID_FIELD),
              objectApiName: 'Case',
              actionName: 'view'
          },
        });*/
      }
      
    
    }

    if (fileId != null) {
      return deleteFile({ contentDocumentId: fileId })
        .then(() => {
          this.updateStatusRecord("Proofreading Validation");
          this.refreshAttachments();
          this.dispatchEvent(
              new ShowToastEvent({
                title: "Success",
                message: "File updated successfully",
                variant: "success"
              })
            );
            //window.location.reload();
            this[NavigationMixin.Navigate]({
              type: 'standard__recordPage',
              attributes: {
                recordId: this.recordId,
                objectApiName: 'Case', // ou autre objet selon ton composant
                actionName: 'view'
              },
            });
        })
        .catch((error) => {
          console.log("fileId", fileId);
          console.log("error", error);
        });
    }
    this.handleCloseModal();
    this.refreshAttachments();
  }

  @wire(getFilteredAttachments, {
    parentId: "$recordId",
    isPublication: "$isPublication",
    isSource: "$localIsSource"
  })
  wiredAttachments(result) {
    this.attachmentsData = result;
    this.attachmentNotExist = false;

    if (result.data?.length > 0) {
      this.attachments = result.data.map((attachment) => ({
        Id: attachment.contentDocumentId,
        url: this.localIsSource
          ? "/sfc/servlet.shepherd/document/download/" +
            attachment.contentDocumentId
          : "/" + attachment.contentDocumentId,
        fileName: attachment.title,
        urlPreview: "/" + attachment.contentDocumentId
      }));
      this.error = undefined;
      this.attachmentExist = true;
    } else if (result.error) {
      this.error = result.error;
      this.attachments = undefined;
      this.attachmentExist = false;
    } else {
      this.attachments = undefined;
      this.attachmentExist = false;
    }
    if (this.attachmentExist === false && this.localIsSource === false) {
      this.attachmentNotExist = true;
    }
  }

  handleOpenModal(event) {
    this.isModalOpen = true;
    this.currentFileId = event.target.dataset.fileId;
  }

  refreshAttachments() {
    this.handleCloseModal();
    return refreshApex(this.attachmentsData);
  }
  handleCloseModal() {
    this.isModalOpen = false;
    this.currentFileId = null;
  }
  handleClosePopUp(event){
    this.showConfirmPopUp = false;
    let buttonName = event.currentTarget.dataset.id;
    if(buttonName == 'no'){
        this.updateStatusRecord("Closed");
        // setTimeout(function () {
        this[NavigationMixin.Navigate]({
          type: 'standard__recordPage',
          attributes: {
              recordId: getFieldValue(this.case.data, PARENTID_FIELD),
              objectApiName: 'Case',
              actionName: 'view'
          },
        });
    }
  }
}