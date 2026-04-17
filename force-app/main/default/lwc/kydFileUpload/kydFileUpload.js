/**
 * Created by noorg on 12/07/2021.
 */

import { LightningElement, api } from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import uploadFileContent from '@salesforce/apex/KYD_UploadController.uploadFileContents';
export default class FileUploadLWC extends LightningElement {
    @api recordId;
    uploadedFileIds = [];
    error;
    get acceptedFormats() {
        return ['.pdf', '.png','.jpg','.jpeg'];
    }
    handleUploadFinished(event) {
        // Get the list of uploaded files
        const uploadedFiles = event.detail.files;
        let uploadedFileNames = '';
        console.log('NGO uploadedFiles : '+uploadedFiles);
        console.log('NGO record Id : '+this.recordId);
        for(let i = 0; i < uploadedFiles.length; i++) {
            uploadedFileNames += uploadedFiles[i].name + ', ';
            this.uploadedFileIds.push(uploadedFiles[i].documentId);
            console.log('NGO uploadedFiles : '+this.uploadedFileIds);
        }

        uploadFileContent({fileIds :this.uploadedFileIds, recordId:this.recordId})
        .then(result => {
            console.log('NGO result : '+result);
            this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: uploadedFiles.length + ' File has been uploaded Successfully to Elysée: ' + uploadedFileNames,
                            variant: 'success',
                        }),
                    );
                    location.reload();
        })
        .catch(error => {
            this.error = error;
            console.log('NGO error : '+error);
            this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Failed',
                            message: ' Upload failed, please contact your Salesforce Administrator. Error : ' + error,
                            variant: 'error',
                        }),
                    );
        });
    }
}