/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 02-01-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getEmailsList from '@salesforce/apex/CaseEmailReplyController.getEmailsList'; 
import sendEmailReply from '@salesforce/apex/CaseEmailReplyController.sendEmailReply'; 

export default class CaseEmailReplyPopUp extends LightningElement {
    @api recordId; // Case Id 
    emailBody = ''; 
    files = []; 
    isLoading = false; 
    recipientEmails = '';
    invalidEmails = [];
    invalidEmailsString = ''; 
    error; 
    @wire(getEmailsList, { caseId: '$recordId' }) 
    wiredCase({ error, data }) { 
        if (data) { 
            this.recipientEmails = data.join('; '); 
            this.error = undefined; 
            console.log('emails : '+this.recipientEmails)
        } else if (error) { 
            this.error = error; 
            this.recipientEmails = undefined; 
            this.showToast('Erreur', 'Impossible de charger les détails du case', 'error'); 
        } 
    } 
    handleEmailChange(event) { 
        this.recipientEmails = event.target.value; 
        this.validateEmails();
    } 
    validateEmails(){
        const emails = this.recipientEmails.split(';').map(email => email.trim());
        const emailRegex =  /^[^\s@]+@[^\s@]+\.[^\s@]+$/; 
        this.invalidEmails = emails.filter(email =>!emailRegex.test(email));
        this.invalidEmailsString = this.invalidEmails.length > 0 ? this.invalidEmails.join(', ') : '';
    }
    handleRichTextChange(event) { 
        this.emailBody = event.target.value; 
    } 
    handleUploadFinished(event) { 
        const uploadedFiles = event.detail.files; 
        this.files = [...this.files, ...uploadedFiles]; 
        this.showToast('Succès', `${uploadedFiles.length} fichier(s) téléchargé(s)`, 'success'); 
    } 
    removeFile(event) { 
        const fileId = event.target.dataset.id; 
        this.files = this.files.filter(file => file.documentId !== fileId); 
    } 
    async handleSend() { 
        if (!this.validateFields()) { 
            return; 
        } 
        this.isLoading = true; 
        console.log('recipientEmails : '+this.recipientEmails)
        try { 
            await sendEmailReply({ 
                caseId: this.recordId,
                recipientEmails: this.recipientEmails, 
                emailBody: this.emailBody, 
                fileIds: this.files.map(file => file.documentId) 
            }); 
            this.dispatchEvent(new CloseActionScreenEvent());
            this.showToast('Succès', 'Email envoyé avec succès', 'success'); 
            this.resetForm(); 
        } catch (error) { 
            this.showToast('Erreur', 'Erreur lors de l\'envoi de l\'email: ' + error.message, 'error'); 
        } finally { 
            this.isLoading = false; 
        } 
    } 
    validateFields() { 
        if (!this.emailBody.trim()) { 
            this.showToast('Erreur', 'Le corps de l\'email ne peut pas être vide', 'error'); 
            return false; 
        }
        this.validateEmails();
        if (this.invalidEmails.length > 0) { 
            this.showToast('Erreur', 'These emails adresses are not valid : '+ this.invalidEmailsString, 'error'); 
            return false; 
        } 
        return true; 
    } 
    resetForm() { 
        this.emailBody = ''; 
        this.files = []; 
        this.recipientEmails = '';
        const richText = this.template.querySelector('lightning-input-rich-text'); 
        if (richText) { 
            richText.value = ''; 
        } 
    } 
    showToast(title, message, variant) { 
        this.dispatchEvent(new ShowToastEvent({ 
            title, 
            message, 
            variant 
        })); 
    } 
   
}