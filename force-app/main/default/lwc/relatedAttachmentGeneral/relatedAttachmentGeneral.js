import { LightningElement, api, wire, track } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";

import getAttachments from "@salesforce/apex/GenericAttachmentController.getAttachments";
import deleteFile from "@salesforce/apex/GenericAttachmentController.deleteFile";

// Champ Answer__c (Rich Text) du Case
import ANSWER_FIELD from "@salesforce/schema/Case.Answer__c";
// Champ Description standard du Case
import DESCRIPTION_FIELD from "@salesforce/schema/Case.DescriptionV2__c";
import SUBJECT_FIELD from "@salesforce/schema/Case.Subject";

export default class RelatedAttachmentGeneral extends LightningElement {
  @api recordId;

  // pour garder le composant configurable
  @api title = "Attachments";
  @api filePrefix = "File_"; // on se base sur ce préfixe
  @api hideUpload = false;
  @api hideUpdate = false;
  @api hideDelete = false;
  @api answerMode = "view"; // 'view' | 'readonly'

  // === on n'a plus fields statique ; on fournit un getter dynamique ===

  get isReadOnly() {
    return this.answerMode === "readonly";
  }

  // Détecte si le prefixe indique qu'on doit afficher Answer__c
  get isAnswerSection() {
    return (
      !!this.filePrefix &&
      this.filePrefix.toLowerCase().startsWith("answer_")
    );
  }

  // Détecte si le prefixe indique qu'on doit afficher Description
  get isDescriptionSection() {
    return (
      !!this.filePrefix &&
      this.filePrefix.toLowerCase().startsWith("description")
    );
  }

  // Booléen simple pour le template : affiche une "zone de contenu" si l'un des deux
  get showContentField() {
    return this.isAnswerSection || this.isDescriptionSection;
  }

  // Fournit la liste des fields à passer à lightning-record-form
  get computedFields() {
    if (this.isAnswerSection) return [ANSWER_FIELD];
    if (this.isDescriptionSection) return [SUBJECT_FIELD,DESCRIPTION_FIELD];
    return [];
  }

  // Quand on a besoin du nom API pour lightning-output-field en lecture seule
  get displayFieldApiName() {
    if (this.isAnswerSection) return "Answer__c";
    if (this.isDescriptionSection) return "Description";
    return "";
  }

  isModalOpen = false;
  currentFileId;

  @track attachments;
  attachmentsData;
  error;

  get showUpload() {
    return !this.hideUpload;
  }

  get showUpdate() {
    return !this.hideUpdate;
  }

  get showDelete() {
    return !this.hideDelete;
  }

  @wire(getAttachments, { parentId: "$recordId", filePrefix: "$filePrefix" })
  wiredAttachments(result) {
    this.attachmentsData = result;

    if (result.data) {
      this.attachments = result.data.map((a) => ({
        Id: a.contentDocumentId,
        url: "/" + a.contentDocumentId,
        fileName: a.title
      }));
      this.error = undefined;
    } else if (result.error) {
      this.error = result.error;
      this.attachments = undefined;
    }
  }

  handleOpenModal(event) {
    this.isModalOpen = true;
    this.currentFileId = event.target.dataset.fileId;
  }

  handleCloseModal() {
    this.isModalOpen = false;
    this.currentFileId = null;
  }

  refreshAttachments = () => {
    this.handleCloseModal();
    return refreshApex(this.attachmentsData);
  };

  async handleDeleteFile(event) {
    const fileId = event.target.dataset.fileId;

    const ok = await LightningConfirm.open({
      message: "Are you sure you want to delete this file?",
      variant: "header",
      label: "Please Confirm",
      theme: "error"
    });

    if (!ok) return;

    try {
      await deleteFile({ contentDocumentId: fileId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "File deleted successfully",
          variant: "success"
        })
      );
      await this.refreshAttachments();
    } catch (e) {
      const msg = e?.body?.message || e?.message || "Unknown error";
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error deleting file",
          message: msg,
          variant: "error"
        })
      );
    }
  }

  handleUploadFile() {
    const oldFileId = this.currentFileId;

    this.template
      .querySelector("c-file-upload-multi-l-w-c")
      ?.uploadFiles(this.recordId);

    // si on est en mode update (modal), on supprime l'ancien
    if (oldFileId) {
      deleteFile({ contentDocumentId: oldFileId })
        .then(() => {
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Success",
              message: "File updated successfully",
              variant: "success"
            })
          );
          this.refreshAttachments();
        })
        .catch((e) => {
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Error",
              message: e?.body?.message || e?.message,
              variant: "error"
            })
          );
        });
    } else {
      // upload simple (pas update)
      this.refreshAttachments();
    }
  }

  handleAnswerSuccess(event) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Success",
        message: "Answer saved successfully.",
        variant: "success"
      })
    );
  }
}