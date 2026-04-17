import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getSteps from '@salesforce/apex/statusNavigatorController.getSteps';
import getParentRecord from '@salesforce/apex/statusNavigatorController.getParentRecord';
import getCurrentStep from '@salesforce/apex/statusNavigatorController.getCurrentStep';
import getProposalStep from '@salesforce/apex/statusNavigatorController.getProposalStep';
import getMatchingProjectProductChild from '@salesforce/apex/statusNavigatorController.getMatchingProjectProductChild';
 
export default class StatusNavigator extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName; // Identifie si on est sur ProjectProductChild ou ProjectShareclassChild
    @track steps = [];
    @track parentRecordId;
    @track currentStep;
    @track teamParam;
 
    @wire(CurrentPageReference) 
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            this.teamParam = currentPageReference.state.c__team || '';
        }
    }
 
    @wire(getCurrentStep, { recordId: '$recordId', objectApiName: '$objectApiName' })
    wiredCurrentStep({ error, data }) {
        if (data) {

            this.currentStep = data;
            this.updateHighlightClass();
        } else if (error) {
            console.error('❌ Erreur lors de la récupération de l\'étape actuelle:', error);
        }
    }
 


    connectedCallback() {
        this.getSteps();
        this.getParentRecord();
        this.matchingProjectProductChild();
    }

    matchingProjectProductChild() {
        if (this.objectApiName === 'ProjectShareclassChild__c') {
            this.isShareclass = true;
            getMatchingProjectProductChild({ shareclassChildId: this.recordId })
                .then(result => {
                    this.matchingProductChildId = result;
                })
                .catch(error => {
                    console.error('❌ Erreur récupération de l\'étape correspondante:', error);
                });
        }
    }

    getSteps() {
        getSteps({ recordId: this.recordId, objectApiName: this.objectApiName })
            .then(result => {
                if (!Array.isArray(result)) {
                    throw new Error('Les données reçues ne sont pas un tableau.');
                }
 
                let designStep = null;
                let proposalStep = null;
                let filteredSteps = [];
 
                result.forEach(step => {
                if (step.name === "Design") designStep = step;
                if (step.name === "Proposal") proposalStep = step;
                });
 
                if (designStep && proposalStep) {
                    filteredSteps.push({
                        id: proposalStep.id,
                        name: "Design & Proposal",
                        stylestep: proposalStep.status === 'Completed' ? 'background-color: rgba(106, 160, 102, 1);color:white;!important' :
                                    proposalStep.status === 'On track' ? 'background-color: #fff;border: 2px solid green;' :
                                    'background-color: #e5e4e2;'
                    });
                }
 
                result.forEach(step => {
                if (step.name !== "Design" && step.name !== "Proposal") {
                        filteredSteps.push({
                            id: step.id,
                            name: step.name,
                            stylestep: step.status === 'Completed' ? 'background-color: rgba(106, 160, 102, 1);color:white;!important' :
                                        step.status === 'On track' ? 'background-color: #fff;border: 2px solid green;' :
                                        'background-color: #e5e4e2;'
                        });
                    }
                });
 
                this.steps = filteredSteps;
                this.updateHighlightClass();
            })
            .catch(error => {
                console.error('Erreur lors de la récupération des étapes:', error);
            });
    }
 
    updateHighlightClass() {
        
        if (!this.currentStep || !this.steps.length) {
            return;
        }
     
        const stepMapping = {
            "DesignAndProposal": "Design & Proposal",
            "Engineering": "Engineering",
            "Filing": "Filing",
            "SetUp": "SetUp"
        };
     
        this.steps.forEach((step) => {
    let isCurrentStep = stepMapping[this.currentStep] === step.name;
     
            setTimeout(() => {
    let stepElement = this.template.querySelector(`[data-id="${step.id}"]`);
                if (stepElement) {
                    if (isCurrentStep) {
                        stepElement.classList.add('current-step');
                    } else {
                        stepElement.classList.remove('current-step');
                    }
                }
            }, 0);
        });
    }
    
 
    getParentRecord() {
        getParentRecord({ recordId: this.recordId, objectApiName: this.objectApiName })
            .then(result => {
                this.parentRecordId = result;
            })
            .catch(error => {
                console.error('Erreur lors de la récupération du parent:', error);
            });
    }
 
    navigateToParent() {
        if (this.parentRecordId) {
            let objectName = this.objectApiName === 'ProjectProductChild__c' ? 'ProjectProduct__c' : 'ProjectProductChild__c';
     
            if (this.objectApiName === 'ProjectShareclassChild__c') {
                getProposalStep({ shareclassChildId: this.recordId })
                    .then(proposalId => {
                        if (proposalId) {
                  
                            this[NavigationMixin.Navigate]({
                                type: 'standard__recordPage',
                                attributes: {
                                    recordId: proposalId,
                                    objectApiName: 'ProjectProductChild__c',
                                    actionName: 'view'
                                },
                                state: { c__team: this.teamParam }
                            }, true);
                        } else {
                            console.error('❌ Aucun record Proposal trouvé.');
                        }
                    })
                    .catch(error => {
                        console.error('❌ Erreur lors de la récupération du record Proposal:', error);
                    });
            } else {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.parentRecordId,
                        objectApiName: objectName,
                        actionName: 'view'
                    },
                    state: { c__team: this.teamParam }
                }, true);
            }
        }
    }

    navigateBack() {
        if (this.isShareclass && this.matchingProductChildId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.matchingProductChildId,
                    objectApiName: 'ProjectProductChild__c',
                    actionName: 'view'
                },
                state: { c__team: this.teamParam }
            });
        } else if (!this.isShareclass) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.parentRecordId,
                    objectApiName: 'ProjectProduct__c',
                    actionName: 'view'
                },
                state: { c__team: this.teamParam }
            }, true);
        }
    }

    handleStepClick(event) {
        const stepId = event.currentTarget.dataset.id;
        if (stepId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: stepId,
                    objectApiName: this.objectApiName,
                    actionName: 'view'
                },
                state: { c__team: this.teamParam }
            });
        }
    }
}