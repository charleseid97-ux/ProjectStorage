import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
 
import getLinkedShareclasses from '@salesforce/apex/ShareclassNavigatorController.getLinkedShareclasses';
import getRecordId from '@salesforce/apex/ShareclassNavigatorController.getRecordId';
import createAndLinkShareclass from '@salesforce/apex/ShareclassNavigatorController.createAndLinkShareclass';
import getPicklistValues from '@salesforce/apex/ShareclassNavigatorController.getPicklistValues';
import getProjectShareclassChild from '@salesforce/apex/ShareclassNavigatorController.getProjectShareclassChild';
import cloneApexShareclass from '@salesforce/apex/ShareclassNavigatorController.cloneApexShareclass';
import canUserCreateShareclass from '@salesforce/apex/ShareclassNavigatorController.canUserCreateShareclass';
import getShareClassName from '@salesforce/apex/ShareclassNavigatorController.getShareClassName';
import deleteProjectShareclass from '@salesforce/apex/ShareclassNavigatorController.deleteProjectShareclass';
import getProjectProductRecordType from '@salesforce/apex/ShareclassNavigatorController.getProjectProductRecordType';
 
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
 
export default class shareclassNavigator extends NavigationMixin(LightningElement) {
    @api recordId;
    @track currentRecordId;
    @track shareclasses = [];
    @track isModalOpen = false;
    @track picklistValues = { Type__c: [], Currency__c: [], DividendPolicy__c: [], DividendFrequency__c: [],  CurrencyHedging__c: [] };
    @track newShareclass = { Name: '', Type__c: '', Currency__c: '', DividendPolicy__c: '', DividendFrequency__c: [], CurrencyHedging__c: []};
    @track shareclassTitle = 'Shareclass Creation';
    @track isSelectionModalOpen = false;
    @track selectedCreationOption = 'scratch';
    @track isLookupModalOpen = false;
    @track lookupObjectApiName = '';
    @track lookupModalTitle = '';
    @track selectedShareclassId = null;
    @track newCloneName = '';
    @track canCreateShareclass = false;
    @track columnsWithDelete;
    isFieldSelectorModalOpen = false;
    @track recordType;
    @track shareclassDoNotProcess = new Map();
    shareClassWithoutSelectedFields =[];
    shareClassWithSelectedFields=[];
    @track teamParam;
    @track isSavingShareclass;
    @api isLoaded = false;
    @track isCloning = false;
 
    @wire(getRecordId, { currentRecordId: '$recordId' })
    wiredRecordId({ error, data }) {
        if (data) {
            this.currentRecordId = data;
            console.log('Current Record ID:', this.currentRecordId);
        } else if (error) {
            console.error('Error fetching record ID:', error);
        }
    }


    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            this.teamParam = currentPageReference.state.c__team || '';
        }
    }
 
    get withSelectedFields() {
        return this.shareClassWithSelectedFields.length > 0 ;
    }
    get withoutSelectedFields() {

        return this.shareClassWithoutSelectedFields.length > 0 ;
    }
    _wiredShareclasses;

    columns = [
        { label: 'Name', fieldName: 'recordLinkChildName', type: 'url', initialWidth: 333, typeAttributes: { label: { fieldName: 'Share_Class_Name__c' }, target: '_self' } },
        { label: 'Type', fieldName: 'Type__c' },
        { label: 'Currency', fieldName: 'Currency__c' },
        { label: 'Dividend', fieldName: 'DividendPolicy__c' },
        { label: 'Frequency', fieldName: 'DividendFrequency__c' },
        { label: 'Hedged', fieldName: 'CurrencyHedging__c'},
        { label: 'Cloned From', fieldName: 'clonedByLink', type: 'url', initialWidth: 333, typeAttributes: { label: { fieldName: 'clonedByName' }, target: '_self' } },
    ];
    
    // Colonne "Trash" affichée uniquement si l'utilisateur a la permission PRPProductStrategy
    deleteColumn = {
        type: 'button-icon',
        typeAttributes: {
            iconName: 'utility:delete',
            title: 'Delete',
            variant: 'bare',
            alternativeText: 'Delete',
            name: 'delete'  // ✅ Ajout du `name`
        }
    };
    
    creationOptions = [
        { label: 'Create Shareclass from Scratch', value: 'scratch' },
        { label: 'Clone Shareclass from Project', value: 'project' },
        { label: 'Clone Shareclass from Referential', value: 'referential' }
    ];

    @wire(getProjectProductRecordType, { projectProductChildId: '$currentRecordId' })
    wiredRecordType({ error, data }) {
        if (data) {
            this.recordType = data;
            this.updateColumns();
        } else if (error) {
            console.error('Error fetching record type:', error);
        }
    }

    @wire(canUserCreateShareclass, { currentRecordId: '$currentRecordId' })
    wiredUserPermission({ error, data }) {
        if (data !== undefined) {
            this.canCreateShareclass = Boolean(data) && (this.recordId === this.currentRecordId) ;
            console.log(`canUserCreateShareclass: ${this.canCreateShareclass}`);
            console.log(`recordId: ${this.recordId}`);
            console.log(`currentRecordId: ${this.currentRecordId}`);
            console.log('data:',data);
            this.updateColumns();
        } else if (error) {
            console.error('Error fetching permissions:', error);
        }
    }


    updateColumns() {
        this.columnsWithDelete = [
            {
                label: 'Name',
                fieldName: 'recordLinkChildName',
                type: 'url',
                initialWidth: 333,
                typeAttributes: { label: { fieldName: 'Share_Class_Name__c' }, target: '_self' }
            },
            { label: 'Type', fieldName: 'Type__c' },
            { label: 'Currency', fieldName: 'Currency__c' },
            { label: 'Dividend', fieldName: 'DividendPolicy__c' },
            { label: 'Frequency', fieldName: 'DividendFrequency__c' },
            { label: 'Hedged', fieldName: 'CurrencyHedging__c'},
            {
                label: 'Cloned From',
                fieldName: 'clonedByLink',
                type: 'url',
                initialWidth: 333,
                typeAttributes: { label: { fieldName: 'clonedByName' }, target: '_self' }
            }
        ];  

        if(this.recordType === 'FundShareClassModification') {
            this.columnsWithDelete = [
                  {
                label: '',
               type: 'button',
               initialWidth: 160,
               typeAttributes: { label: 'Select Fields' ,name: 'open_field_selector', target: '_blank' }
           },
            {
                label: 'Name',
                fieldName: 'recordLinkChildName',
                type: 'url',
            
                typeAttributes: { label: { fieldName: 'Share_Class_Name__c' }, target: '_self' }
            },
            { label: 'Type', fieldName: 'Type__c' },
            { label: 'Currency', fieldName: 'Currency__c' },
            { label: 'Dividend', fieldName: 'DividendPolicy__c' },
            { label: 'Frequency', fieldName: 'DividendFrequency__c' },
            { label: 'Hedged', fieldName: 'CurrencyHedging__c'},
            {
                label: 'Cloned From',
                fieldName: 'clonedByLink',
                type: 'url',
                typeAttributes: { label: { fieldName: 'clonedByName' }, target: '_self' }
            }];
                

        }
    }
        
    isDeleteAllowed() {
        if (this.recordType === 'FundModification') {
            return false;
        }
 
        if (this.recordType === 'ShareclassModification') {
            return !this.shareclassDoNotProcess.get(this.currentRecordId);
        }
        return true;
    }
 
    get showNewShareclassButton() {
        return (
            this.canCreateShareclass &&
            this.recordId === this.currentRecordId &&
            this.recordType !== 'FundShareClassModification'
        );
    }

    @wire(getLinkedShareclasses, { projectChildId: '$currentRecordId' })
    wiredShareclasses(result) {
        this._wiredShareclasses = result;
        if (result.data) {
            let shareclassPromises = result.data.map(wrapper => {
                const shareclass = wrapper.shareclass;
                return getProjectShareclassChild({
                    projectChildId: this.currentRecordId,
                    shareclassId: shareclass.Id
                }).then(shareclassChildId => {
                    let clonedById = shareclass.ClonedByReferential__c || shareclass.ClonedByProjectShareclass__c;
                    let haveSelectedFields = shareclass.TECH_FieldsToModify__c? true : false;
                    let clonedByName = shareclass.ClonedByReferential__r?.Name ?? shareclass.ClonedByProjectShareclass__r?.Share_Class_Name__c ?? '';
                    let clonedByObjectApiName = shareclass.ClonedByReferential__c
                                                ? 'Share_Class__c'
                                                : shareclass.ClonedByProjectShareclass__c
                                                ? 'ProjectShareclass__c'
                                                : null;
                    return {
                        ...shareclass,
                        recordLink: `/lightning/r/ProjectShareclass__c/${shareclass.Id}/view?c__team=${this.teamParam}`,
                        recordLinkChildName: shareclassChildId
                                            ? `/lightning/r/ProjectShareclassChild__c/${shareclassChildId}/view?c__team=${this.teamParam}`
                                            : null,
                        clonedByLink: clonedById && clonedByObjectApiName 
                                        ? `/lightning/r/${clonedByObjectApiName}/${clonedById}/view?c__team=${this.teamParam}`
                                        : null,
                        clonedByName: clonedByName || 'N/A',
                        haveSelectedFields: haveSelectedFields

                    };
                });
            });        
            
            Promise.all(shareclassPromises)
                .then(shareclassList => {
                    this.shareclasses = shareclassList;
                    this.shareClassWithSelectedFields = shareclassList.filter(shareclass => shareclass.haveSelectedFields);
                    this.shareClassWithoutSelectedFields = shareclassList.filter(shareclass => !shareclass.haveSelectedFields);
                    console.log('this.shareclasses:', this.shareclasses);   
                })
                .catch(error => {
                    console.error('🚨 Error processing Shareclass wrappers:', error);
                });
        } else if (result.error) {
            console.error('🚨 Error fetching Shareclasses:', result.error);
        }
    }
    
    resolveCloneSource(clonedById, objectApiName) {
        return new Promise((resolve, reject) => {
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: clonedById,
                    actionName: 'view',
                    objectApiName: objectApiName
                }
            }).then(url => {
                resolve(clonedById);
            }).catch(error => {
                console.error('Error generating URL:', error);
                reject(error);
            });
        });
    }
    
    
 
    @wire(getPicklistValues)
    wiredPicklists({ error, data }) {
        if (data) {
            this.picklistValues = {
                Type__c: data.Type__c.map(value => ({ label: value, value: value })),
                Currency__c: data.Currency__c.map(value => ({ label: value, value: value })),
                DividendPolicy__c: data.DividendPolicy__c.map(value => ({ label: value, value: value })),
                DividendFrequency__c: data.DividendFrequency__c.map(value => ({ label: value, value: value })),
                CurrencyHedging__c: data.CurrencyHedging__c.map(value => ({ label: value, value: value })),

            };
        } else if (error) {
            console.error('Error fetching picklist values:', error);
        }
    }
 
    openModal() {
        this.isModalOpen = true;
    }
 
    closeModal() {
        this.isModalOpen = false;
        this.isFieldSelectorModalOpen = false;
        this.newShareclass = { Name: '', Type__c: '', Currency__c: '', DividendPolicy__c: '', DividendFrequency__c: '', CurrencyHedging__c: '' };
        this.refreshData();
    }
 
    handleFieldChange(event) {
        const field = event.target.name;
            if (event.target.type === 'checkbox') {
                this.newShareclass[field] = event.target.checked;
            } else {
                this.newShareclass[field] = event.target.value;
            }
        }
        
 
        saveShareclass() {
            this.isSavingShareclass = true;
            this.isLoaded = true;
            if (!this.newShareclass.Type__c || !this.newShareclass.Currency__c || !this.newShareclass.DividendPolicy__c 
                || !this.newShareclass.DividendFrequency__c || !this.newShareclass.CurrencyHedging__c) {
                this.showToast('Error', 'A field is not filled in', 'error');
                this.isSavingShareclass = false;
                return;
            }
                
            createAndLinkShareclass({
                projectChildId: this.currentRecordId,
                type: this.newShareclass.Type__c,
                ocurrency: this.newShareclass.Currency__c,
                dividendPolicy: this.newShareclass.DividendPolicy__c,
                dividendFrequency: this.newShareclass.DividendFrequency__c,
                currencyHedging: this.newShareclass.CurrencyHedging__c
            })
            .then(() => {
                this.showToast('Success', 'The Shareclass has been created and linked successfully.', 'success');
                this.closeModal();
                this.refreshData().then(() => {
                    console.log('Data refreshed successfully');
                });
                this.resetShareclass();
                this.isSavingShareclass = false;
                this.isLoaded = false;
            })
            .catch((error) => {
                console.error('Error creating and linking Shareclass:', error);
                this.isSavingShareclass = false;
                 this.isLoaded = false;
                //Body génère une erreur
                //this.showToast('Error', body.fieldErrors.VARMethod__c[0].message,   'error');
            });
        }
            
 
    refreshData() {
        return refreshApex(this._wiredShareclasses);
    }
 
    resetShareclass() {
        this.newShareclass = { Name: '', Type__c: '', Currency__c: '', DividendPolicy__c: '', DividendFrequency__c: '', CurrencyHedging__c: ''};
    }
 
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'view':
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: row.Id,
                        objectApiName: 'ProjectShareclass__c',
                        actionName: 'view'
                    }
                });
            break;
            case 'navigate':
                this.navigateToShareclassChild(row);
                break;
            case 'navigateClonedBy':
                if (row.clonedById && row.clonedByObjectApiName) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: row.clonedById,
                            objectApiName: row.clonedByObjectApiName,
                            actionName: 'view'
                        }
                    });
                } else {
                    this.showToast('Error', 'No valid source for this cloned Shareclass.', 'error');
                }
                break;
            case 'open_field_selector':
                this.openSelectorModal(row.Id);
                break;
            case 'delete':
                this.deleteShareclass(row.Id);
                break;
                default:
                console.error(`🚨 Unhandled action: ${actionName}`); // ✅ Ajout d'un log d'erreur
                this.showToast('Error', `Unhandled action: ${actionName}`, 'error');
            
        }
    }
         
    openSelectorModal(rowId) {
        this.selectedShareclassId = rowId;
        console.log('Selected Shareclass ID:', this.selectedShareclassId);
        this.isFieldSelectorModalOpen = true;
    }
    deleteShareclass(shareclassId) {
        if (!confirm('Are you sure you want to delete this Shareclass? This action is irreversible.')) {
            return;
        }
        
        deleteProjectShareclass({ shareclassId: shareclassId, projectProductChildId: this.currentRecordId})
        .then(() => {
            this.showToast('Success', 'Shareclass deleted successfully.', 'success');
            this.refreshData();
        })
        .catch(error => {
            console.error('Error deleting Shareclass:', error);
            this.showToast('Error', 'Failed to delete Shareclass.', 'error');
        });
    }
        

    navigateToShareclassChild(row) {
        getProjectShareclassChild({ projectChildId: this.currentRecordId, shareclassId: row.Id })
        .then(shareclassChildId => {
            if (shareclassChildId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: shareclassChildId,
                        objectApiName: 'ProjectShareclassChild__c',
                        actionName: 'view'
                    },
                    state: { c__team: this.teamParam }
                });
            } else {
                this.showToast('Error', 'No matching ShareclassChild found.', 'error');
            }
        })
        .catch(error => {
            console.error('Error navigating to ProjectShareclassChild:', error);
            this.showToast('Error', 'Failed to navigate to ShareclassChild.', 'error');
        });
    }
            
        
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
 
    openSelectionModal() {
        this.isSelectionModalOpen = true;
    }
 
    closeSelectionModal() {
        this.isSelectionModalOpen = false;
    }
 
    handleCreationSelection(event) {
        this.selectedCreationOption = event.detail.value;
    }
 
    handleCreationNext() {
        this.closeSelectionModal();
        if (this.selectedCreationOption === 'scratch') {
            this.isModalOpen = true;
        } else {
            this.openLookupModal();
        }
    }
 
    openLookupModal() {
        if (this.selectedCreationOption === 'referential') {
            this.lookupObjectApiName = 'Share_Class__c';
            this.lookupModalTitle = 'Clone from Referential';
        } else if (this.selectedCreationOption === 'project') {
            this.lookupObjectApiName = 'ProjectShareclass__c';
            this.lookupModalTitle = 'Clone from Project';
        }
        this.isLookupModalOpen = true;
    }
 
    closeLookupModal() {
        this.selectedCreationOption === 'scratch';
        this.isLookupModalOpen = false;
        this.newCloneName = '';
    }
 
    handleLookupSelection(event) {
        if (event.detail && event.detail.recordId) {
            this.selectedShareclassId = event.detail.recordId;

            // Vérification impérative du type d'objet sélectionné
            if (this.lookupObjectApiName === 'ProjectShareclass__c') {
                // ✅ Nom récupéré directement depuis le custom lookup
                this.newCloneName = event.detail.recordName || 
                    (this.shareclasses.find(sc => sc.Id === this.selectedShareclassId)?.Share_Class_Name__c || '');
            } else if (this.lookupObjectApiName === 'Share_Class__c') {
                // ✅ Requête Apex pour récupérer le nom du Share_Class__c
                getShareClassName({ shareClassId: this.selectedShareclassId })
                    .then(result => {
                        this.newCloneName = result || '';
                    })
                    .catch(error => {
                        console.error('❌ Error fetching Share_Class name:', error);
                        this.newCloneName = '';
                    });
            }
        } else {
            console.error('❌ Missing recordId in event.detail');
            this.selectedShareclassId = null;
            this.newCloneName = '';
        }
    }

    
    
 
cloneShareclasses() {
    if (!this.selectedShareclassId) {
        this.showToast('Error', 'Please select a Shareclass before cloning.', 'error');
        return;
    }

    this.isCloning = true; // Active le spinner et désactive le bouton immédiatement.

    const objectName = this.lookupObjectApiName === 'Share_Class__c' ? 'Share_Class__c' : 'ProjectShareclass__c';

    cloneApexShareclass({
        projectChildId: this.currentRecordId,
        shareClassId: this.selectedShareclassId,
        objectAPIName: objectName
    })
    .then(() => {
        this.showToast('Success', 'Shareclass cloned successfully!', 'success');
        this.refreshData();
        this.closeLookupModal();
    })
    .catch(error => {
        console.error('Error cloning Shareclass:', error);
        this.showToast('Error', 'Failed to clone Shareclass.', 'error');
    })
    .finally(() => {
        this.isCloning = false; // Réactive le bouton et enlève le spinner
    });
}
 
    openModal() {
        this.isModalOpen = true;
    }
 
    closeModal() {
        this.isFieldSelectorModalOpen = false;
        this.isModalOpen = false;
    }

 
    cloneShareclass(objectName) {
        if (!this.selectedShareclassId) {
            this.showToast('Error', 'Please select a Shareclass and enter a name to clone.', 'error');
            return;
        }
 
    cloneApexShareclass({
            projectChildId: this.currentRecordId,
            shareClassId: this.selectedShareclassId,
            objectAPIName: objectName
        })
        .then(() => {
            this.showToast('Success', 'Shareclass cloned successfully!', 'success');
            this.refreshData();
            this.closeLookupModal();
        })
        .catch(error => {
            console.error('Error cloning Shareclass:', error);
            this.showToast('Error', 'Failed to clone Shareclass.', 'error');
            this.closeLookupModal();
        });
    }
}