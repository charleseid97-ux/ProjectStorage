import {LightningElement, api, track} from 'lwc';
import getPreviewRecords from '@salesforce/apex/CampaignMemberLoaderController.getPreviewRecords';
import deleteDocument from '@salesforce/apex/CampaignMemberLoaderController.deleteDocument';
import insertRecords from '@salesforce/apex/CampaignMemberLoaderController.insertRecords';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import CSV_TEMPLATE_URL from '@salesforce/label/c.CAMPAIGN_MEMBER_TEMPLATE_URL';

const DEFAULT_FIELDS_SEPARATOR = ',';
const PROCESSING_MESSAGE = "Import registered. It might take up to a minute for changes to apply!";
const CHECK_EMAIL_MESSAGE = "A summary email will be sent when the import is completed."

// noinspection JSUnusedGlobalSymbols
export default class CampaignMemberLoader extends LightningElement {
    @api campaignId;
    @track previewData;

    displayProcessingMessage = false;
    displaySeparatorInput = true;
    displayHeaderToggle = false;

    templateURL = CSV_TEMPLATE_URL;
    isVisiblePreviewModal = false;
    fieldsSeparator = DEFAULT_FIELDS_SEPARATOR;
    processingMessage = PROCESSING_MESSAGE;
    checkEmailMessage = CHECK_EMAIL_MESSAGE;
    headerToggle = true;
    loading = false;
    documentId;
    header;

    get notLoading() {
        return !this.loading
    }

    get keyField() {
        return this.columns[0];
    }

    get acceptedFormats() {
        return ['.csv'];
    }

    get customColumns() {
        return [
            {label: "Status", fieldName: "Status", hideDefaultActions:true, initialWidth: 100},
            {label: "First Name", fieldName: "FirstName", hideDefaultActions:true, initialWidth: 150},
            {label: "Last Name", fieldName: "LastName", hideDefaultActions:true, initialWidth: 150},
            {label: "Email", fieldName: "Email", hideDefaultActions:true, initialWidth: 200},
            {label: "Phone", fieldName: "Phone", hideDefaultActions:true, initialWidth: 130},
            {label: "Company", fieldName: "Company", hideDefaultActions:true, initialWidth: 170},
            {label: "Job Title", fieldName: "JobTitle", hideDefaultActions:true, initialWidth: 150},
            {label: "Country", fieldName: "Country", hideDefaultActions:true, initialWidth: 100},
            {label: "Mailing Country", fieldName: "MailingCountry", hideDefaultActions:true, initialWidth: 140},
            {label: "City", fieldName: "City", hideDefaultActions:true, initialWidth: 100},
            {label: "Postal Code", fieldName: "PostalCode", hideDefaultActions:true, initialWidth: 130},
            {label: "Street", fieldName: "Street", hideDefaultActions:true, initialWidth: 150},
            {label: "Attendance Rate", fieldName: "AttendanceRate", hideDefaultActions:true, initialWidth: 140},
            {label: "Attendance Duration", fieldName: "AttendanceDuration", hideDefaultActions:true, initialWidth: 150},
            {label: "IP City", fieldName: "IPCity", hideDefaultActions:true, initialWidth: 150},
            {label: "Action", fieldName: "Action", hideDefaultActions:true, initialWidth: 140},
        ]
    }

    get columns() {
        if (this.customColumns) {
            return this.customColumns
        }
        if (!this.header) {
            return [];
        }
        return this.header.split(this.fieldsSeparator).map(f => ({label: f, fieldName: f}))
    }

    openPreviewModal() {
        this.isVisiblePreviewModal = true;
    }

    hidePreviewModal() {
        this.deleteDocument();
        this.isVisiblePreviewModal = false;
    }

    toggleHeader(e) {
        this.headerToggle = e.target.checked;
        this.updatePreviewData();
    }

    displaySpinner() {
        this.loading = true;
    }

    hideSpinner() {
        this.loading = false;
    }

    updateFieldSeparator(e) {
        let newValue = e.target.value;
        if (newValue == null || newValue.length === 0) {
            this.fieldsSeparator = DEFAULT_FIELDS_SEPARATOR;
        }
        else {
            this.fieldsSeparator = newValue;
        }
        this.updatePreviewData();
    }

    handleUploadFinished(e) {
        this.documentId = e.detail.files[0].documentId;
        this.updatePreviewData();
    }

    handleUploadFileClicked() {
        this.displayProcessingMessage = false;
    }

    insertRecords() {
        this.displaySpinner();
        insertRecords(
            {
                documentId: this.documentId,
                recordId: this.campaignId,
                fieldsSeparator: this.fieldsSeparator,
                skipFirstRow: this.headerToggle
            }
        ).then(
            _ => {
                this.displayProcessingMessage = true;
                this.hidePreviewModal();
                this.hideSpinner();
            }
        ).catch(
            error => {
                this.displayError("Error", error.body?.message);
                this.hideSpinner();
            }
        );
    }

    updatePreviewData () {
        this.displaySpinner();
        getPreviewRecords(
            {
                documentId: this.documentId,
                recordId: this.campaignId,
                fieldsSeparator: this.fieldsSeparator,
                skipFirstRow: this.headerToggle
            }
        ).then(
            result => {
                this.createPreviewData(result);
                this.openPreviewModal();
                this.hideSpinner();
            }
        ).catch(
            error => {
                console.log(error);
                this.displayError("Error", error.body?.message);
                this.hideSpinner();
            }
        )
    }

    deleteDocument () {
        deleteDocument({documentId: this.documentId});
    }

    displayInfo(title, message) {
        this.displayToast(title, message, 'info');
    }

    displaySuccess(title, message) {
        this.displayToast(title, message, 'success');
    }

    displayError(title, message) {
        this.displayToast(title, message, 'error');
    }

    displayToast(title, message, variant) {
        this.dispatchEvent (
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    createPreviewData(previewRecords) {
        if (previewRecords && !this.header) {
            this.header = this.createHeaderStub(previewRecords[0].split(this.fieldsSeparator).length)
        }
        this.previewData = previewRecords.map(
            r => r.split(this.fieldsSeparator).reduce((d, f, i) => ({...d, [this.columns[i].fieldName]: f}), {})
        );
    }

    createHeaderStub(columnsCount) {
        return [...Array(columnsCount).keys()].map(i => "col" + (i + 1)).join(this.fieldsSeparator);
    }
}