import { LightningElement, wire, track, api } from 'lwc';
import { getRecord, getFieldValue, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import getFieldsToModify from '@salesforce/apex/FieldModificationController.getFieldsToModify';
import updateFieldValue from '@salesforce/apex/FieldModificationController.updateFieldVal';
import getMetadataFields from '@salesforce/apex/FieldSelectorController.getMetadataFields';
import TECH_FIELDS_TO_MODIFY from '@salesforce/schema/ProjectProduct__c.TECH_FieldsToModify__c';
import { subscribe, MessageContext } from 'lightning/messageService';
import TECH_FIELDS_CHANNEL from '@salesforce/messageChannel/techFieldsMessageChannel__c';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import hasEdit from '@salesforce/customPermission/PRPProductStrategy';

const COMMON_ACTIONS = [
    {
    type: 'button-icon',
    initialWidth: 40,
    typeAttributes: {
    iconName: 'utility:edit',
    name: 'edit_field',
    title: 'Edit',
    variant: 'border-filled',
    alternativeText: 'Edit'
    }
    },
    {
    label: '',
    type: 'button',
    initialWidth: 120,
    typeAttributes: {
    label: 'Link',
    name: 'open_url',
    target: '_blank'
    }
    }
    ];

const FUND_COLUMNS = [
    { label: 'Field Name', fieldName: 'fieldName', type: 'text' },
    { label: 'Team Owner', fieldName: 'teamOwner', type: 'text' },
    { label: 'Phase', fieldName: 'phase', type: 'text' },
    { label: 'Previous Value', fieldName: 'previousValue', type: 'text' },
    { label: 'New Value', fieldName: 'newValue', type: 'text' },
    {
        label: 'Status',
        fieldName: 'status',
        initialWidth: 80
        
    },
    ...COMMON_ACTIONS
];

const SHARECLASS_COLUMNS = [
    { label: 'Share Class', fieldName: 'shareclass', type: 'text' },
    { label: 'ISIN', fieldName: 'isin', type: 'text' }, // <- 🔁 ici au lieu de "Phase"
    { label: 'Field Name', fieldName: 'fieldName', type: 'text' },
    { label: 'Team Owner', fieldName: 'teamOwner', type: 'text' },
    { label: 'Previous Value', fieldName: 'previousValue', type: 'text' },
    { label: 'New Value', fieldName: 'newValue', type: 'text' },
    ...COMMON_ACTIONS
];

export default class FieldModificationList extends NavigationMixin(LightningElement)  {
    @track fields = [];
    @track filteredFields = [];
    @track selectedTeamOwner = '';
    @track selectedShareClass = '';
    @track isModalOpen = false;
    @track selectedRow = {};
    @track objectApiName='';
    @track isSaving = false; 
    @track canEdit = hasEdit;

    @api recordId;
    @api objectName = 'Product__c';
    @api objectName2;
    // shareClass = false;
    wiredFieldsResult;
    availableFields = [];
    listTitle = 'Field Modification at Product Level';

    @wire(MessageContext)
    messageContext;
    fund = true;
    subscription = null;


    connectedCallback() {
        if(this.objectName === 'Share_Class__c') {
            //this.columns = SHARECLASS_COLUMNS;
            this.objectApiName =  'ProjectShareclassChild__c';
            this.listTitle = 'Field Modification at Shareclass Level';
            this.fund = false;

        } else{
            //this.columns =  FUND_COLUMNS ;
            this.fund = true;
            this.objectApiName =  'ProjectProductChild__c';

        }
        this.subscribeToMessageChannel();
        console.log('this.objectApiName :' + this.objectApiName);
    }

    get columns() {
        const common = [
        { label: 'Field Name', fieldName: 'fieldName', type: 'text' },
        { label: 'Team Owner', fieldName: 'teamOwner', type: 'text' },
        { label: 'Previous Value', fieldName: 'previousValue', type: 'text' },
        { label: 'New Value', fieldName: 'newValue', type: 'text' },
        { label: 'Status',
            fieldName: 'status',
            initialWidth: 80 }
        
        ];

        const shareClassExtra = [
        { label: 'Share Class', fieldName: 'shareclass', type: 'text' },
        { label: 'ISIN', fieldName: 'isin', type: 'text' } // <- 🔁 ici au lieu de "Phase"
        ];
        
        const linkButton = {
        label: '',
        type: 'button',
        initialWidth: 120,
        typeAttributes: { label: 'Link', name: 'open_url', target: '_blank' }
        };
        
        const editButton = {
            type: 'button-icon',
            initialWidth: 40,
            typeAttributes: {
            iconName: 'utility:edit',
            name: 'edit_field',
            title: 'Edit',
            variant: 'border-filled',
            alternativeText: 'Edit'
        }
        };
        
        let columns = [];
        
        if (this.fund) {
        columns = [...common];
        } else {
        columns = [...shareClassExtra, ...common];
        }
        
        if (this.canEdit) {
        columns.push(editButton);
        }
        columns.push(linkButton);
        
        return columns;
    }

    get teamOwnerOptions() {
        let options = [
            { label: 'All', value: '' },
            ...Array.from(new Set(this.fields.map(f => f.teamOwner))).map(owner => ({ label: owner, value: owner }))
        ];
        console.log('this.fields',this.fields);

        return options;
    }
    get shareClassOptions() {
        let options = [
            { label: 'All', value: '' },
            ...Array.from(new Set(this.fields.map(f => f.shareclass))).map(sc => ({ label: sc, value: sc }))
        ];
        console.log('this.fields',this.fields);
        return options;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        if (actionName === 'open_url') {
            this.handleRedirect(event);
        } else if (actionName === 'edit_field') {
            this.selectedRow = row;
            this.isModalOpen = true;
            console.log('this.objectApiName : '+this.objectApiName);
            console.log('this.selectedRow:', this.selectedRow);
        }
    }

    handleRedirect(event) {
           
        const rowData= event.detail.row;
        const psTeam= 'PRP'+rowData.teamOwner.replace(/\s+/g,'');
        console.log('psTeam:', psTeam);
        console.log('childRecordId:', rowData.childRecordId);
        const pageReference = {
          type: 'standard__recordPage',
          attributes: {
              recordId: rowData.childRecordId, 
              actionName: 'view',
          },
          state: {
              c__team: psTeam // Ajout du paramètre
          }
      };
  
      // Redirection vers l'URL avec le paramètre
      this[NavigationMixin.Navigate](pageReference);
      
    }

    closeModal() {
        this.isModalOpen = false;
        this.selectedRow = {};
    }

    handleSubmit(event) {
        event.preventDefault(); 
        this.isSaving = true;
    
        const fields = event.detail.fields;
    
        const recordId = this.selectedRow.childRecordId;
        const fieldApiName = this.selectedRow.fieldApiName;
        var newValue = fields[fieldApiName];
        const objectApiName = this.objectApiName; // 'ProjectProductChild__c' ou 'ProjectShareclassChild__c'
        if (newValue.includes('%')) {
            newValue.replace('%', '');
        }
        updateFieldValue({ objectApiName, recordId, fieldApiName, newValue })
            .then(() => {
                this.handleSuccess(); // ✅ Réutilise ta méthode existante
            })
            .catch(error => {
                this.handleError(error);
            })
            .finally(() => {
                this.isSaving = false;
            });
    }
    
        
    handleSuccess() {
        this.isSaving = false;
        this.closeModal();
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Record updated Successfully!',
                variant: 'success'
            })
        );
        refreshApex(this.wiredFieldsResult);
    }

   handleError(error) {
        this.isSaving = false;
        
        this.closeModal();

        let message = 'An unexpected error occurred.';
        console.log('error '+error);
        console.log('here '+error.body);
        if(error && error.body){
            console.log('here 2'+error.body);
           if(Array.isArray(error.body)){
            console.log('array');
                message = error.body.map(e => e.message).join(', ');
            }else if(typeof error.body.message === 'string'){
                console.log('else');
                message = error.body.message;
            } 
        }
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                  message: message,
                variant: 'error'
            })
        );
        //console.error('Erreur lors de la sauvegarde :', event.detail.message);
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                TECH_FIELDS_CHANNEL,
                (message) => this.handleMessage(message)
            );
        }
    }

    handleMessage(message) {
        if (message.recordId === this.recordId) {
            console.log('Record changed! Refreshing LDS...');
            getRecordNotifyChange([{ recordId: this.recordId }]); // 🚀 Force LDS refresh
            refreshApex(this.wiredFieldsResult);
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [TECH_FIELDS_TO_MODIFY] })
    wiredRecord({ error, data }) {
        if (data) {
            refreshApex(this.wiredFieldsResult);
        } else if (error) {
            console.error('Error fetching record:', error);
        }
    }

     @wire(getFieldsToModify, { recordId: '$recordId' , objectApiName: '$objectName' })
    wiredFields(result) {
        this.wiredFieldsResult = result;
        console.log('Wired fields result:', result);

        if (result.data) {
            this.processFields(result.data);
            this.handleScChange();
            this.handleFilterChange();
        } else if (result.error) {
            console.error(result.error);
        }
    }

    @wire(getMetadataFields, { objectApiName: '$objectName' })
    wiredMetadataFields({ error, data }) {
        if (data) {
            console.log('Metadata fields:', data);
            //this.availableFields = data.map(field => ({ label: field.label, value: field.value }));
            this.availableFields = data.map(field => ({
                label: field.label,
                value: field.value,
                type: field.type // stocke aussi le type
            }));
            this.processFields(this.fields); // Update fields with labels
        } else if (error) {
            console.error('Error fetching metadata fields:', error);
        }
    }

   processFields(fieldData) {
    if (!fieldData || fieldData.length === 0) return;
this.fields = fieldData.map(field => {
        const fieldMetadata = this.availableFields.find(f => f.value === field.fieldName);
        const isPercent = fieldMetadata && fieldMetadata.type === 'PERCENT';
 
        let formattedNewValue = field.newValue || '';
        let formattedPreviousValue = field.previousValue || '';
 
        if (isPercent) {
            try {
                if (formattedNewValue !== '') {
                    let num = parseFloat(formattedNewValue);
                    if (!isNaN(num)) {
                        formattedNewValue = `${num}%`;
                    }
                }
                if (formattedPreviousValue !== '') {
                    let prevNum = parseFloat(formattedPreviousValue);
                    if (!isNaN(prevNum)) {
                        formattedPreviousValue = `${prevNum}%`;
                    }
                }
            } catch (e) {
                console.warn('Erreur de format %', formattedNewValue, formattedPreviousValue);
            }
        }
 
        const statusValue = field.statusValue || 'Invalid';
        const circleStatus = statusValue === 'Valid' ? '🟢' : '🔴';
 
        return {
            id: `${field.childRecordId}_${field.fieldName}`,
            fieldName: fieldMetadata ? fieldMetadata.label : field.fieldName,
link: '/' + field.link,
            childRecordId: field.childRecordId,
            teamOwner: field.teamOwner || 'Unknown',
            isin: field.isin || '',
            phase: field.phase || 'Unknown',
            shareclass: field.shareclass || 'Unknown',
            fieldApiName: field.fieldName,
            previousValue: formattedPreviousValue,
            newValue: formattedNewValue,
            status: circleStatus,
            statusValue: statusValue
        };
    });
    this.filteredFields = [...this.fields];
    console.log('Processed fields:', this.fields);
}

    handleFilterChange(event) {
        if(event){
            this.selectedTeamOwner = event.detail.value;
        }
        console.log('selectedTeamOwner:', this.selectedTeamOwner);

        this.filteredFields = this.selectedTeamOwner
            ? this.fields.filter(field => field.teamOwner === this.selectedTeamOwner)
            : [...this.fields];
    }
    handleScChange(event) {
        if(event){
            this.selectedShareClass = event.detail.value;
        }
        console.log('shareClass:', this.selectedShareClass);
        this.filteredFields = this.selectedShareClass
            ? this.fields.filter(field => field.shareclass === this.selectedShareClass)
            : [...this.fields];
    }
}