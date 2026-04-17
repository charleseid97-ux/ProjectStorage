/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 03-02-2025
 * @last modified by  : Khadija EL GDAOUNI
**/

import { LightningElement, wire, track, api } from 'lwc'; 
import { getObjectInfo } from "lightning/uiObjectInfoApi"; 
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
import { NavigationMixin } from 'lightning/navigation'; 
import CASE_OBJECT from "@salesforce/schema/Case"; 
export default class ContentFeedback extends NavigationMixin(LightningElement) { 
    recordTypeId; 
    // Track les valeurs des sliders 
    @track sliderValues = { 
        overallRating: 5, 
        technicity: 5, 
        length: 5, 
        interestTopic: 5, 
        sentToClient: 5 
    }; 
    
    @wire(getObjectInfo, { objectApiName: CASE_OBJECT }) 
    handleObjectInfo({ error, data }) {
        if (data) { 
            const rtis = data.recordTypeInfos; 
            this.recordTypeId = Object.keys(rtis).find( 
                (rti) => rtis[rti].name === "Marketing Feedback" ); 
        } 
    } 
    // Handlers pour chaque slider 
    handleOverallRatingChange(event) { 
        this.sliderValues.overallRating = event.detail.value; 
    } 
    handleTechnicityChange(event) { 
        this.sliderValues.technicity = event.detail.value; 
    } 
    handleLengthChange(event) { 
        this.sliderValues.length = event.detail.value; 
    } 
    handleInterestTopicChange(event) { 
        this.sliderValues.interestTopic = event.detail.value; 
    } 
    handleSentToClientChange(event) { 
        this.sliderValues.sentToClient = event.detail.value; 
    } 
    // Handler pour la soumission du formulaire 
    handleSubmit(event) { 
        event.preventDefault(); 
        const fields = event.detail.fields; 
        // Ajout des valeurs des sliders aux champs correspondants 
        fields.Overall_rating__c = this.sliderValues.overallRating; 
        fields.Technicity__c = this.sliderValues.technicity; 
        fields.Length__c = this.sliderValues.length; 
        fields.Interest_of_topic__c = this.sliderValues.interestTopic; 
        fields.Sent_to_client__c = this.sliderValues.sentToClient; 
        this.template.querySelector('lightning-record-edit-form').submit(fields); 
    } 
    // Handler pour le succès de la soumission 
    handleSuccess(event) { 
        const recordId = event.detail.id; 
        // Afficher le toast de succès 
        this.dispatchEvent( 
            new ShowToastEvent({ 
            title: 'Success', 
            message: 'Content Feedback created successfully!', 
            variant: 'success' }) 
        ); 
        // Redirection vers l'enregistrement créé 
        this[NavigationMixin.Navigate]({ 
            type: 'standard__recordPage', 
            attributes: { recordId: recordId, objectApiName: 'Case', actionName: 'view' } 
        }); 
    } 
}