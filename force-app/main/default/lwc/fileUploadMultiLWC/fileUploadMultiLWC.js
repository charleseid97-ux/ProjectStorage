/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 10-14-2024
 * @last modified by  : SILA Nicolas
**/
import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import uploadNewFile from "@salesforce/apex/FileUploadMultiController.uploadNewFile";
import { deleteRecord} from 'lightning/uiRecordApi';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';

export default class FileUploadMultiLWC extends LightningElement {
  @api fileId;
  @api recordId;
  @track filesData;
  showSpinner = false;
  @api multipleFiles = false;
  @track csvData;
  @api filePrefix;
  @api isSource;
  @api isPublication;
  
  handleFinishFlow() {
    const navigateNextEvent = new FlowNavigationFinishEvent();
    this.dispatchEvent(navigateNextEvent);
  }

  connectedCallback(){
    this.filesData = [];
    if(this.multipleFiles === 'true'){
      this.multipleFiles = true;
    }else{
      this.multipleFiles = false;
    }
  }
  handleUploadFinished(event) {

    const uploadedFiles = event.detail.files;

    let filesDataTmp = [...this.filesData] ;
    uploadedFiles.forEach(file => {

      filesDataTmp.push({
        fileName: file.name,
        documentId: file.documentId,
        contentVersionId: file.contentVersionId
      });

    });
    this.filesData = [...filesDataTmp];
    this.dispatchEvent(new CustomEvent('uploadcomplete'));
    if(this.recordId){
      this.uploadLocalFiles(this.recordId);
    }
  }

  @api getExistingFileData() {
    return this.filesData.length;
  }
  
  @api uploadFiles(parentRecordId) {
    if (this.filesData.length === 0) {
      this.showToast("Error", "error", "Please select files first");
      return;
    }
    
    this.showSpinner = true;
    uploadNewFile({
      recordId: parentRecordId,
      fileData: JSON.stringify(this.filesData),
      filePrefix: this.filePrefix,
      isSource: this.isSource,
      isPublication: this.isPublication
    })
      .then(result => {
        if (result === "success") {
          this.filesData = [];
        } else {
          this.showToast("Error", "error", result);
        }
      })
      .catch(error => {
        if (error.body && error.body.message) {
          this.showToast("Error", "error", error.body.message);
        }
      })
      .finally(() => {this.dispatchEvent(new CustomEvent('finishupload'));this.showSpinner = false});
  }

  uploadLocalFiles(recordIdVar) {
    if (this.filesData.length === 0) {
      this.showToast("Error", "error", "Please select files first");
      return;
    }
    this.showSpinner = true;
    uploadNewFile({
      recordId: recordIdVar,
      fileData: JSON.stringify(this.filesData),
      filePrefix: '',
      isSource: false,
      isPublication: false
    })
      .then(result => {
        if (result === "success") {
          this.filesData = [];
          this.handleFinishFlow();
        } else {
          this.showToast("Error", "error", result);
        }
      })
      .catch(error => {
        if (error.body && error.body.message) {
          this.showToast("Error", "error", error.body.message);
        }
      })
      .finally(() => {this.dispatchEvent(new CustomEvent('finishupload'));this.showSpinner = false});
  }

  removeReceiptImage(event) {
    const index = event.currentTarget.dataset.id;
    deleteRecord(this.filesData[index].documentId);
    this.filesData.splice(index, 1);
  }

  showToast(title, variant, message) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        variant: variant,
        message: message
      })
    );
  }

}