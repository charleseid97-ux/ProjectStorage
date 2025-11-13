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
import getFieldRules from '@salesforce/apex/FieldDisplayRuleService.getRulesForObject';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMetadataFields from '@salesforce/apex/ProjectChildTeamValidationController.getMetadataFields';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getAllFieldsByRecordId from '@salesforce/apex/PageLayoutController.getAllFieldsByRecordId';
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
    fundMatrix;
    scDynamicRules;
    fundDynamicRules;
    fund;
    shareClasses;
    availableFields = [];
    availableFieldsSc = [];
    shareClassesMatrix;

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
        console.log('connectedCallback called');
        // Charger les règles dynamiques pour le champ Product
        this.loadDynamicRules();
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

    loadDynamicRules() {
        console.log('loadDynamicRules called');
        // Appel de la méthode Apex pour récupérer les règles dynamiques
        getFieldRules({ objectApiName: 'ProjectProductChild__c' })
            .then((rules) => {
                this.fundDynamicRules = rules;
                console.log('✅ Règles dynamiques chargées :', this.fundDynamicRules);
            })
            .catch(error => {
                console.error('❌ Erreur chargement règles dynamiques :', error);
            });

            getFieldRules({ objectApiName: 'ProjectShareclassChild__c' })
            .then((rules) => {
                this.scDynamicRules = rules;
                console.log('✅ Règles dynamiques chargées :', this.scDynamicRules);
            })
            .catch(error => {
                console.error('❌ Erreur chargement règles dynamiques :', error);
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
                
            // Traitement FUND
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

                Object.keys(this.fundMatrix).forEach(element => {        
                    const rule = this.fundDynamicRules?.find(r => r.fieldApiName === element);
                    // const rec = this.fundMatrix?.find(r => r.Id === element.Id);
                    console.log('fundDynamicRules rule', rule);
                    console.log('fundDynamicRules element.fieldApiName', element);
                    console.log('fundDynamicRules this.fund[element.fieldApiName]', this.fund[element]);
                    let IsMandatory = false;
                    if(rule) {
                        IsMandatory = this.evaluateMandatoryRuleCondition(rule, this.fund);
                    }
                    if(IsMandatory && this.fund[element] === "" ) {  
                        

                        // si le bloc Fund n’existe pas encore, on le crée à la volée
                        if (this.emptyFundRequiredFields.length != 0) {
                            this.isEmptyRequiredFields = true;
                            this.isEmptyFundRequiredFields = false;
                            //this.emptyFundRequiredFields.push({ name: 'FundName', fields: [] }); // ou 'Fund' selon ton choix
                            const fieldMetadata = this.availableFields.find(f => f.value === element.toLowerCase());

                            console.log('fieldMetadata', fieldMetadata);
                            // console.log('element.fieldApiName', element.fieldApiName);
                            // console.log('this.emptyFundRequiredFields', this.emptyFundRequiredFields);
                            this.emptyFundRequiredFields[0].fields.push(fieldMetadata ? fieldMetadata.label : element);
                        }else{
                            this.isEmptyFundRequiredFields = true;
                        }

                        

                    }
                });
                console.log('emptyFundRequiredFields', this.emptyFundRequiredFields);

                // Traitement SHARECLASS
                if (data.ShareClass && data.ShareClass.length > 0) {
                    console.log('data.ShareClass inside if ', data.ShareClass);
                    this.emptySCRequiredFields = data.ShareClass.map(map => {
                        const [key, fields] = Object.entries(map)[0];
                        return { name: key, fields: fields, id: key };
                    });
                } else {
                    this.emptySCRequiredFields = [{ name: 'Share Classes', fields: [], id : '' }];
                }
                
                this.shareClassesMatrix.forEach(sc => {
                    // console.log('sc', sc);
                    this.scDynamicRules.forEach(element => {    
                        const rule = this.scDynamicRules?.find(r => r.fieldApiName === element.fieldApiName);
                        const rec = this.shareClasses?.find(r => r.Id === sc.Id);
                        console.log('scDynamicRules rule', rule);
                        console.log('scDynamicRules this.sc[element.fieldApiName]', sc[element.fieldApiName]);
                        console.log('scDynamicRules rec', rec);
                        let IsMandatory = this.evaluateMandatoryRuleCondition(rule, rec);
                        // console.log('IsMandatory', IsMandatory);
                        // console.log('sc[element.fieldApiName]', sc[element.fieldApiName]);
                        if(IsMandatory && sc[element.fieldApiName] === ""){
                            this.isEmptyRequiredFields = true;
                            const fieldMetadata = this.availableFields.find(f => f.value === element.fieldApiName.toLowerCase());
                            // console.log('fieldMetadata', fieldMetadata);   
                            // console.log('element.fieldApiName', element.fieldApiName);
                            this.emptySCRequiredFields.forEach((item) => {
                                // console.log('item.name', item.name);
                                // console.log('sc.shareClassName__c', sc.shareClassName__c);
                                if (item.name === sc.shareClassName__c) {
                                    item.fields = item.fields || [];
                                    item.fields.push(fieldMetadata ? fieldMetadata.label : element.fieldApiName);
                                }
                            });
                        }
                        this.emptySCRequiredFields.forEach((item) => {
                            
                            if (item.name === sc.shareClassName__c) {
                                item.id = sc.Id;
                            }
                        });
                    });
                    
                });
                this.emptySCRequiredFields.forEach(sc => {
                    if( sc.fields.length === 0) {
                        // Si aucun champ requis n'est vide, on supprime l'entrée
                        this.emptySCRequiredFields = this.emptySCRequiredFields.filter(item => item.name !== sc.name);
                    }
                });
                // if(this.emptyFundRequiredFields[0].fields.length <= 0) {
                //     this.emptyFundRequiredFields = null;
                // }
                
                console.log('emptySCRequiredFields', this.emptySCRequiredFields);
                console.log('this.emptyFundRequiredFields',this.emptyFundRequiredFields);

                if (this.emptySCRequiredFields.length > 0 || (this.emptySCRequiredFields.length > 0 ? this.emptyFundRequiredFields[0].fields?.length > 0 : false) ){
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

    evaluateMandatoryRuleCondition(rule, record) {
        console.log(`🧾 Données du record :`, record);
        console.log(`🔍 Évaluation de la règle pour le champ ${rule.fieldApiName}`);
        console.log(`🔍 Évaluation de la règle  ${rule.mandatoryCondition}`);

        if (!rule || !rule.mandatoryCondition) {
            return false;
        }
     
        try {
            const condition = rule.mandatoryCondition.trim().replaceAll("'",'"');
     
            // console.log(`🔍 Évaluation de la règle pour le champ ${rule.fieldApiName}`);
            // console.log(`➡️ Condition : ${condition}`);
            // console.log(`🧾 Données du record :`, record);
            const evaluator = new Function('record', `return (${condition});`);
            const result = evaluator(record);
            console.log(`✅ Résultat de l'évaluation : ${result}`);
            return result;
        } catch (error) {
            console.error(`❌ Erreur d’évaluation pour ${rule.fieldApiName} :`, error);
            return false; // on masque le champ si erreur
        }
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
     
 
    // Afficher une notification toast
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}