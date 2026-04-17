import { LightningElement, track, wire, api } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getDocuments from '@salesforce/apex/ProjectDocumentController.getDocuments';
import linkFilesToRecord from '@salesforce/apex/ProjectDocumentController.linkFilesToRecord';
import getFilesForRecord from '@salesforce/apex/ProjectDocumentController.getFilesForRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

export default class ProjectDocumentManager extends NavigationMixin(LightningElement)  {
    @track isModalOpen = false;
    @track documents = [];
    @track uploadedFiles = [];
    @api isCore = false;
    @api isMeetingNote = false;
    @api isOtherDoc = false;
    recordTypeId;
    @api recordId;
    @track rowRecordId;
    tempRecordId; // Temporary holder for file uploads
    wiredDocumentResult;
 
    core_columns = [
        {
            label: 'Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }
        },
        { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' },
        { label: 'Type', fieldName: 'Type__c', type: 'text' },
        { label: 'One Drive URL', fieldName: 'OneDriveLink__c', type: 'url' },
        {
            type: 'button-icon',
            fixedWidth: 50,
            typeAttributes: { 
                iconName: 'utility:download', 
                name: 'downloadFiles', 
                title: 'Download All Files', 
                variant: 'border-filled'
            }
        }
    ];
    other_columns = [
        {
            label: 'Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }
        },
        { label: 'Created By', fieldName: 'CreatedByName', type: 'text' },
        { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' },
        { label: 'One Drive URL', fieldName: 'OneDriveLink__c', type: 'url' },
        {
            type: 'button-icon',
            fixedWidth: 50,
            typeAttributes: { 
                iconName: 'utility:download', 
                name: 'downloadFiles', 
                title: 'Download All Files', 
                variant: 'border-filled'
            }
        }
    ];

    mn_columns = [
        {
            label: 'Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }
        },
        { label: 'Created By', fieldName: 'CreatedByName', type: 'text' },
        { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' },
        { label: 'Meeting Date', fieldName: 'Date__c', type: 'date' },
        {
            type: 'button-icon',
            fixedWidth: 50,
            typeAttributes: { 
                iconName: 'utility:download', 
                name: 'downloadFiles', 
                title: 'Download All Files', 
                variant: 'border-filled'
            }
        }
    ];
    get hasDocuments() {
        return this.documents.length > 0;
    }
    @wire(getObjectInfo, { objectApiName: 'ProjectDocuments__c' })
    handleObjectInfo({error, data}) {
        if (data) {
            const rtis = data.recordTypeInfos;
            if(this.isCore){
                this.recordTypeId = Object.keys(rtis).find(rti => rtis[rti].name === 'Core Document');
            }else if(this.isMeetingNote){
                this.recordTypeId = Object.keys(rtis).find(rti => rtis[rti].name === 'Meeting Note');
            }else{
                this.recordTypeId = Object.keys(rtis).find(rti => rtis[rti].name === 'Other Document');
            }
        }

    }
    connectedCallback() {
    }

    @wire(getDocuments,{ recordId: '$recordId',recordTypeId: '$recordTypeId' })
    wiredDocuments(result) {
        this.wiredDocumentResult = result;
        if (result.data) {
            this.documents = result.data.map(doc => ({
                ...doc,
                recordUrl: '/lightning/r/ProjectDocuments__c/' + doc.Id + '/view',
                CreatedByName: doc.CreatedBy.Name
            }));
            console.log('doc:', this.documents);

        } else if (result.error) {
            console.error('Error fetching documents:', result.error);
            this.showToast('Error', 'Failed to load documents', 'error');
        }
    }

    openModal() {
        this.isModalOpen = true;
        this.uploadedFiles = [];
    }

    closeModal() {
        this.isModalOpen = false;
    }

    async handleSuccess(event) {
        this.rowRecordId = event.detail.id;
        this.showToast('Success', 'Document created successfully!', 'success');
        
        if (this.uploadedFiles.length > 0) {
            await this.attachFilesToRecord();
        }
        
        this.refreshData();
        this.closeModal();
    }

    async refreshData() {
        this.isLoading = true;
        await refreshApex(this.wiredDocumentResult);
        this.documents = [...this.documents];  // Forcer la mise à jour en mémoire
        this.isLoading = false;
    }

    handleError(event) {
        this.showToast('Error', 'Failed to create document', 'error');
    }

    // handleFileUpload(event) {
    //     for (let file of event.detail.files) {
    //         this.uploadedFiles.push({ name: file.name, documentId: file.documentId });
    //     }
    // }

    handleFileUpload(event) {
        for (let file of event.detail.files) {
            this.uploadedFiles.push({ name: file.name, documentId: file.documentId });
        }
        this.refreshData();
    }
    handleDeleteFile(event) {
        const fileId = event.target.dataset.id;
        this.uploadedFiles = this.uploadedFiles.filter(file => file.documentId !== fileId);
    }
    async attachFilesToRecord() {
        try {
            const fileIds = this.uploadedFiles.map(file => file.documentId);
            await linkFilesToRecord({ recordId: this.rowRecordId, contentDocumentIds: fileIds });
            this.showToast('Success', 'Files attached to the document', 'success');

            this.refreshData();
        } catch (error) {
            console.error('Error linking files:', error);
            this.showToast('Error', 'Failed to attach files', 'error');
        }
    }
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'downloadFiles') {
            this.downloadAllFiles(row.Id);
        }
    }

    async downloadAllFiles(recordId) {
        try {
            const files = await getFilesForRecord({ recordId });
            if (!files || files.length === 0) {
                this.showToast('No Files', 'No files attached to this document.', 'warning');
                return;
            }

            files.forEach(file => {
                const fileUrl = '/sfc/servlet.shepherd/version/download/'+file.LatestPublishedVersionId;
                this.downloadFile(fileUrl, file.Title + file.FileExtension);
            });

            this.showToast('Download Started', 'Downloading all attached files.', 'success');
        } catch (error) {
            console.error('Error fetching files:', error);
            this.showToast('Error', 'Failed to fetch attached files.', 'error');
        }
    }

    downloadFile(fileUrl, fileName) {
        const link = document.createElement('a');
        link.href = fileUrl;
        link.setAttribute('download', fileName);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}