import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import PROJECT_STEP_NAME from '@salesforce/schema/ProjectProductChild__c.Name'
import getUserPermissions from '@salesforce/apex/ProjectChildTeamValidationController.getUserPermissions';
import getProjectChild from '@salesforce/apex/ProjectChildTeamValidationController.getProjectChild';
import updateTeamValidation from '@salesforce/apex/ProjectChildTeamValidationController.updateTeamValidation';
import checkRequiredFieldsNotEmpty from '@salesforce/apex/ProjectChildTeamValidationController.checkRequiredFiledsIsEmpty';
import getFund from '@salesforce/apex/ProjectChildTeamValidationController.getFund';
import getShareClasses from '@salesforce/apex/ProjectChildTeamValidationController.getShareClasses';
import hasProposalPortfolioManager from '@salesforce/apex/ProjectChildTeamValidationController.hasProposalPortfolioManager';
import getRecordId from '@salesforce/apex/ProjectChildTeamValidationController.getRecordId';
import getRecordTypeName from '@salesforce/apex/ProjectChildTeamValidationController.getRecordTypeName';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMetadataFields from '@salesforce/apex/ProjectChildTeamValidationController.getMetadataFields';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getAllFieldsByRecordId from '@salesforce/apex/PageLayoutController.getAllFieldsByRecordId';
import getPMTConfigurationWarning from '@salesforce/apex/PageLayoutController.getPMTConfigurationWarning';
import getFundMatrix from '@salesforce/apex/ProjectChildTeamValidationController.getFundMatrix';
import getShareClassesMatrix from '@salesforce/apex/ProjectChildTeamValidationController.getShareClassesMatrix';

export default class ProjectChildTeamValidation extends NavigationMixin(LightningElement)  {
    @api recordId;
    @track teamName;
    @track teamNameWithoutSpace;
    @track stepName;
    @track hasPermission = false;
    @track isValidated = false;
    @track isModalOpen = false;
    @track isEmptyRequiredFields = false;
    @track emptyFundRequiredFields;
    @track isEmptyFundRequiredFields = false;
    @track emptySCRequiredFields;
    @track shouldDisplay = false; // Nouveau boolean pour afficher ou non le composant
    @track currentRecordId;
    recordTypeName;
    fundMatrix;
    fund;
    shareClasses;
    availableFields = [];
    availableFieldsSc = [];
    shareClassesMatrix;
    @track isLoading = false;

    teamsMap= new Map([
      ['ProductStrategy', 'Product Strategy'],
      ['Legal', 'Legal'],
      ['Tax', 'Tax'],
      ['OPS', 'OPS'],
      ['Risk', 'Risk'],
      ['ESG', 'ESG'],
      ['Compliance', 'Compliance'],
      ['DCO', 'DCO'],
      ['DCR', 'DCR'],
      ['Finance', 'Finance'],
      ['Communication', 'Communication'],
      ['Technology', 'Technology'],
      ['InvestmentPerf', 'Investment Perf'],
      ['IS', 'IS'],
    ]);

    get fields(){
        return [PROJECT_STEP_NAME];
    }

    @wire(getRecordId, {currentRecordId: '$recordId'})
        getRecordId({error, data}){
            if(data){
                // console.log('data'+data);
                this.currentRecordId = data;
            }else if(error){
                console.log('error'+error.message + error.body);
                console.log('error'+JSON.stringify(error.message) + JSON.stringify(error.body));
            }
    }

    connectedCallback() {
        this.showConfigurationWarning();
        // Charger les règles dynamiques pour le champ Product
        const objectsToFetch = ['ProjectProductChild__c', 'ProjectShareclassChild__c'];

        getMetadataFields({ objectApiNames: objectsToFetch })
          .then((data) => {

            if (data && data.length > 0) {
            this.availableFields = data.map(field => ({
                label: field.label,
                value: field.value
              }));
              console.log('✅ Combined availableFields:', this.availableFields);
            } else {
              console.error('⚠️ No metadata fields returned');
            }
          })
          .catch((error) => {
            console.error('❌ Error fetching metadata fields:', error);
          });
    }

    @wire(getRecord , {
        recordId: '$currentRecordId',
        fields: '$fields'
    })
    loadData({error, data}){
        if(data){
              this.stepName = getFieldValue(data,PROJECT_STEP_NAME);
              console.log('this.stepName'+this.stepName);

        } else if(error){
            console.log('error'+error.message + error.body);
        }
    }

    // Getter pour désactiver le bouton si l'étape est déjà validée ou si l'utilisateur n'a pas la permission
    get isButtonDisabled() {
        return this.isValidated || !this.hasPermission;
    }

    // Récupérer `c__team` depuis l'URL
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            const teamParam = currentPageReference.state.c__team;
            if (teamParam && teamParam.startsWith('PRP')) {
                this.teamName = teamParam.replace('PRP', ''); // Supprime "PRP"
                this.teamNameWithoutSpace = this.teamsMap.get(this.teamName);
                console.log('this teamName'+this.teamNameWithoutSpace);
            }
        }
    }

    // Vérifier si l'utilisateur a la permission correspondante
    @wire(getUserPermissions)
    wiredUserPermissions({ error, data }) {
        if (data && this.teamName) {
            console.log('this data'+JSON.stringify(data));
            console.log('this teamName'+this.teamName);
            this.hasPermission = data.includes(`PRP${this.teamName}`);
            this.shouldDisplay = true; // Toujours afficher, mais masquer le bouton si pas de permission
            console.log('this shouldDisplay'+this.shouldDisplay);
        } else if (error) {
            console.error('Error fetching user permissions:', error);
        }
    }

    // Récupérer les valeurs actuelles de `TECH_TeamValidation__c`
    @wire(getProjectChild, { recordId: '$currentRecordId' })
    wiredProjectChild({ error, data }) {
        if (data && this.teamName) {
            const validatedTeams = data.TECH_TeamValidation__c ? data.TECH_TeamValidation__c.split(';') : [];
            this.isValidated = validatedTeams.includes(this.teamName);
        } else if (error) {
            console.error('Error fetching project child:', error);
        }
    }

    get statusLabel() {
        return this.isValidated ? 'Completed' : 'Draft';
    }

    get statusIcon() {
        return this.isValidated ? 'utility:success' : 'utility:note';
    }

    get iconColor() {
        return this.isValidated ? 'completedIcon' : 'draftIcon';
    }

    get iconType() {
        return this.isValidated ?'✅' :  '📝';
    }

    // Ouvrir le popup
    openModal() {
        this.isModalOpen = true;
        this.isEmptyRequiredFields= false;
    }

    // Fermer le popup
    closeModal() {
        this.isModalOpen = false;
    }

    // Confirmer la validation et mettre à jour la multipicklist
    updateTeamValidation() {
        this.isLoading = true;
        updateTeamValidation({ recordId: this.currentRecordId, teamName: this.teamName })
            .then(() => {
                this.isValidated = true;
                this.showToast('Success', 'Step validated successfully!', 'success');
                this.closeModal();
            })
            .catch(error => {
                console.error('Error updating validation:', error);
                this.showToast('Error', 'Failed to validate step. \n' + error.body ? error.body.pageErrors[0].message : 'Unknown error');
                // body.pageErrors[0].message
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    @wire(getFund, { recordId: '$currentRecordId',
        teamName: '$teamNameWithoutSpace',
        stepName: '$stepName'})
    wiredFund({ error, data }) {
        if (data) {
            this.fund = data;
            console.log('Fund data:', (data));
        } else if (error) {
            console.error('Error fetching fund data:', error);
            this.showToast('Error', 'Failed to fetch fund data.', 'error');
        }
    }

    // @wire(getAllFieldsByRecordId, { recordId: '$currentRecordId' })
    // wiredFieldRules({ error, data }) {
    //     if (data) {
    //         console.log('getAllFieldsByRecordId',data);
    //         this.allData = data;

    //     } else if (error) {
    //         console.error('❌ Erreur chargement règles dynamiques :', error);
    //     }
    // }

    @wire(getShareClasses, { recordId: '$currentRecordId',
        teamName: '$teamNameWithoutSpace',
        stepName: '$stepName'})
        wiredShareClasses({ error, data }) {
            if (data) {
                console.log('ShareClasses data:', data);
                this.shareClasses = data;
            } else if (error) {
                console.error('Error fetching share classes data:', error);
                this.showToast('Error', 'Failed to fetch share classes data.', 'error');
            }
    }

    @wire(getShareClassesMatrix, { recordId: '$currentRecordId',
        teamName: '$teamNameWithoutSpace',
        stepName: '$stepName'})
        wiredShareClassesMatrix({ error, data }) {
            if (data) {
                console.log('ShareClasses data:', data);
                this.shareClassesMatrix = data;
            } else if (error) {
                console.error('Error fetching share classes data:', error);
                this.showToast('Error', 'Failed to fetch share classes data.', 'error');
            }
    }

    @wire(getFundMatrix, {
            recordId: '$currentRecordId',
            teamName: '$teamNameWithoutSpace',
            stepName: '$stepName'})
        wiredFundMatrix({ error, data }) {
            if (data) {
                console.log('Fund data:', data);
                this.fundMatrix = data;
            } else if (error) {
                console.error('Error fetching share classes data:', error);
                this.showToast('Error', 'Failed to fetch share classes data.', 'error');
            }
    }

    handleShareClassClick(event) {
        event.preventDefault();
        console.log('handleShareClassClick called');
        const recordId = event.currentTarget.dataset.id;
        console.log('this.teamName', this.teamName);
        console.log('recordId', recordId);
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'ProjectShareclassChild__c', // update if needed
                actionName: 'view'
            },
            state: {
                c__team: 'PRP'+this.teamName
            }
        });
    }

    @wire(getRecordTypeName, {currentRecordId: '$currentRecordId'})
        getRecordTypeName({error, data}){
            if(data){
                console.log('record type name : '+data);
                this.recordTypeName = data;
            }else if(error){
                console.log('error record type name '+error.message + error.body);
                console.log('error record type name '+JSON.stringify(error.message) + JSON.stringify(error.body));
            }
    }



    /**
     * Refactor SONAR: réduction de l’imbrication des callbacks/fonctions
     * => Extraction du traitement Fund / ShareClass dans des méthodes dédiées
     * => AUCUN changement de logique métier : mêmes comparaisons, mêmes boucles, mêmes mutations
     */
    checkRequiredField() {
        checkRequiredFieldsNotEmpty({
            recordId: this.currentRecordId,
            teamName: this.teamNameWithoutSpace,
            stepName: this.stepName
        })
        .then((data) => {
                console.log('data', JSON.stringify(data));
                console.log('data.Fund before refresh ', data.Fund);
                console.log('data', JSON.stringify(data));
                refreshApex(this.fund);
                refreshApex(this.shareClasses);
                console.log('data.Fund after refresh ', data.Fund);

                // Traitement FUND (extrait tel quel)
                if(this.recordTypeName != 'ShareclassCreation'){
                    this.handleFundRequiredFields(data);
                }else{
                    this.emptyFundRequiredFields = []
                }

                // Traitement SHARECLASS (extrait tel quel)
                this.handleShareClassRequiredFields(data);

                console.log('emptySCRequiredFields', this.emptySCRequiredFields);
                console.log('this.emptyFundRequiredFields',this.emptyFundRequiredFields);

                if (this.emptySCRequiredFields.length > 0 ||  this.emptyFundRequiredFields.length > 0  ){
                    this.isEmptyRequiredFields = true;
                    this.showToast('Error', 'Please fill in all required fields to validate this step.', 'error');
                } else {
                    console.log('all required fields are full');
                    this.updateTeamValidation();
                }
        })
        // .catch(error => {
        //     console.error('Error updating validation:', error);
        //     this.showToast('Error', 'Failed to validate step.', 'error');
        // });
    }

    /**
     * Extraction du bloc "Traitement FUND" sans changer la logique
     */
    handleFundRequiredFields(data) {
        this.buildEmptyFundRequiredFieldsFromApex(data);
        
        console.log('emptyFundRequiredFields', this.emptyFundRequiredFields);
    }

    buildEmptyFundRequiredFieldsFromApex(data) {
        if (data.Fund && data.Fund.length > 0) {
            console.log('data.Fund inside if ', data.Fund);
            this.emptyFundRequiredFields = data.Fund.map(map => {
                const [key, fields] = Object.entries(map)[0];
                return { name: key, fields: fields };
            });
        } else {
            console.log('data.Fund Empty');
            this.emptyFundRequiredFields = [];
        }
    }

    /**
     * Extraction du bloc "Traitement SHARECLASS" sans changer la logique
     */
    handleShareClassRequiredFields(data) {
        this.buildEmptyShareClassRequiredFieldsFromApex(data);
        // US-20194 V1.2: the required fields (conditions included) come from Apex; only the share class Ids are added here
        if(this.recordTypeName != 'FundShareClassModification'){
            this.shareClassesMatrix.forEach(sc => {
                this.emptySCRequiredFields.forEach(item => {
                    if (item.name === sc.shareClassName__c) item.id = sc.Id;
                });
            });
        }
        this.cleanupEmptyShareClassRequiredFields();
    }

    buildEmptyShareClassRequiredFieldsFromApex(data) {
        if (data.ShareClass && data.ShareClass.length > 0) {
            console.log('data.ShareClass inside if ', data.ShareClass);
            this.emptySCRequiredFields = data.ShareClass.map(map => {
                const [key, fields] = Object.entries(map)[0];
                return { name: key, fields: fields, id: key };
            });
        } else {
            this.emptySCRequiredFields = [{ name: 'Share Classes', fields: [], id : '' }];
        }
    }

    cleanupEmptyShareClassRequiredFields() {
        this.emptySCRequiredFields.forEach(sc => {
            if( sc.fields.length === 0) {
                // Si aucun champ requis n'est vide, on supprime l'entrée
                this.emptySCRequiredFields = this.emptySCRequiredFields.filter(item => item.name !== sc.name);
            }
        });
        // if(this.emptyFundRequiredFields[0].fields.length <= 0) {
        //     this.emptyFundRequiredFields = null;
        // }
    }

    checkPortfolioManager() {
          hasProposalPortfolioManager({
            recordId: this.currentRecordId,
        }).then((data) => {
            // console.log('kevin data:' + data);
            if (!data) {
                 this.showToast('Error', 'At least one Portfolio Manager must be assigned to the fund before moving to the Proposal stage.', 'error');
                this.closeModal();
            } else {
                 this.checkRequiredField();
            }

        })
        .catch(error => {
            console.error('Error checking FundManagerAssignement validation:', error);
            this.showToast('Error', 'Failed to validate step.', 'error');
        });
    }

    confirmValidation() {
        // if (this.teamNameWithoutSpace == 'Product Strategy' || this.teamNameWithoutSpace == 'IS') {
            // this.checkPortfolioManager();
            //we check required field in the checkportfolio manager function for PS and IS
        // } else {
            this.checkRequiredField();
        // }

    }

    // US-20194 V1.2: PMT lines pointing to fields missing in this org (configuration to fix); an invalid condition is reported by the screen's own calls
    showConfigurationWarning() {
        getPMTConfigurationWarning()
            .then(message => { if (message) this.showToast('Warning', message, 'warning', 'sticky'); })
            .catch(() => {});
    }

    // Afficher une notification toast
    showToast(title, message, variant, mode = 'dismissible') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }
}