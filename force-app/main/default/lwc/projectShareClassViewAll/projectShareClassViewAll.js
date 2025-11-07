/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 21-02-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
import { LightningElement, api, wire } from 'lwc'; 
import getProjectShareclasses from '@salesforce/apex/ShareClassViewAllController.getProjectShareclasses';
import SHARECLASS_OBJECT from '@salesforce/schema/ProjectShareclass__c';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

export default class ProjectShareClassViewAll extends LightningElement {
    @api recordId;
    shareClasses = [];
    error;
    isLoading = true;
    selectedShareClassId = ''; // ID de la ShareClass sélectionnée
    selectedShareClass = null; // Objet de la ShareClass sélectionnée

    get shareClassOptions() {
        return [{ label: 'All ShareClasses', value: '' }, 
                ...this.shareClasses.map(sc => ({ label: sc.name, value: sc.id }))];
    }

    handlePicklistChange(event) {
        this.selectedShareClassId = event.target.value;
        this.selectedShareClass = this.shareClasses.find(sc => sc.id === this.selectedShareClassId) || null;
    }

    resetFilter() {
        this.selectedShareClassId = '';
        this.selectedShareClass = null;
    }

    // Génération du lien pour la ShareClass sélectionnée
    get selectedShareClassUrl() {
        return this.selectedShareClass ? '/lightning/r/ProjectShareclass__c/'+ this.selectedShareClass.id+'/view' : '';
    }

    // Ajout de l'URL pour chaque ShareClass (utilisé dans la liste complète)
    // get shareClassesWithUrls() {
    //     return this.shareClasses.map(sc => ({
    //         ...sc,
    //         url: '/lightning/r/ProjectShareclass__c/'+sc.id+'/view'
    //     }));
    // }

    @wire(getProjectShareclasses, { parentId: '$recordId' })
    wiredShareClasses({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.shareClasses = data.map(wrapper => ({
                id: wrapper.recordId,
                name: wrapper.name,
                url: '/lightning/r/ProjectShareclass__c/'+wrapper.recordId+'/view',
                fields: wrapper.fields.map(field => ({
                    apiName: field.apiName,
                    label: field.label,
                    value: field.value
                }))
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.shareClasses = [];
        }
    }

    handleSectionToggle(event) {
        const sectionId = event.currentTarget.dataset.sectionId;
        const section = event.currentTarget.closest('.slds-section');
       
        if (section.classList.contains('slds-is-open')) {
            section.classList.remove('slds-is-open');
            event.currentTarget.setAttribute('aria-expanded', 'false');
        } else {
            section.classList.add('slds-is-open');
            event.currentTarget.setAttribute('aria-expanded', 'true');
        }
    }

    
}