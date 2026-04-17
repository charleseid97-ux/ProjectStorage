import { api, LightningElement, track , wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getStepsWithTeam  from '@salesforce/apex/TaskCompletionByTeamController.getStepWithTeams';
import getCompletionRatesBulk  from '@salesforce/apex/TaskCompletionByTeamController.getCompletionRatesBulk';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import VEHICLE_TYPE from '@salesforce/schema/ProjectProduct__c.VehicleType__c';
 
export default class Lwc_TaskCompletionByTeam  extends NavigationMixin(LightningElement)  {  
    @api recordId;
    @track isModalOpen = false;
    @track steps=[];
    @track stepactive='Design & Proposal';
    @track isLoading=true;
    @track ownerfield;
    @track isModalOpen = false; // Controls modal visibility
    wiredresultdata;
    istepactive=false;
    stepsdata=[];
    vehicleType;
   
    columns = [ 
      { label: 'Team', fieldName: 'team', type: 'text' },
      { label: 'Owner', fieldName: 'owner', type: 'text' },
      {
        label: ' ',
        type: 'button-icon',
        initialWidth: 80,
        typeAttributes: {
            name: 'modify_owner',
            iconName: 'utility:edit',
            alternativeText: 'Edit Owner',
            title: 'Edit Owner'
        }
    },
        { label: 'Completion', fieldName: 'completionRate', type: 'percent' },
        { label: 'Status', fieldName: 'status', type: 'text' },
        {
            label: ' ',
            initialWidth: 80,
            fieldName: 'dynamicIcon'  
        },
        {
            label: 'Form',
            type: 'button',
            initialWidth: 120,
            typeAttributes: { label: 'Link' ,name: 'open_url', target: '_blank' }
        }
    ];
     
   
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
 
        if (actionName === 'open_url') {
           this.handleRedirect(event);
        } else if (actionName === 'modify_owner') {
            const rowData= event.detail.row;
            this.ownerfield= rowData.team.replace(/\s+/g,'')+'__c';
            this.isModalOpen= true;
        }
    }
 
    handleRedirect(event) {
        const rowData= event.detail.row;
        const psTeam= 'PRP'+rowData.team.replace(/\s+/g,'');
        const pageReference = {
          type: 'standard__recordPage',
          attributes: {
              recordId: rowData.stepid,
              actionName: 'view',
          },
          state: {
              c__team: psTeam // Ajout du paramètre
          }
      };
 
      this[NavigationMixin.Navigate](pageReference);
    }
    handleSuccess() {
        this.isModalOpen = false;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Record updated successfully!',
                variant: 'success',
            })
        );
      this.isLoading=true;
      this.getStepsWithTeam();
    }
 
 
    // Close modal
    closeModal() {
        this.isModalOpen = false;
    }
    saveChanges() {
        // Soumet le formulaire d'édition
        const form = this.template.querySelector('lightning-record-edit-form');
        form.submit();
    }
   
    @wire(getRecord, { recordId: '$recordId', fields: [VEHICLE_TYPE] })
    wiredRecord({ error, data }) {
        if (data) {
            this.vehicleType = data.fields.VehicleType__c.value;
            this.getStepsWithTeam(); // Une fois qu'on a le type de véhicule, on charge les steps filtrés
        } else if (error) {
            console.error('Erreur récupération :', error);
        }
    }
   
    async getStepsWithTeam() {
        const result = await getStepsWithTeam({ recordId: this.recordId });
        const stepsArray = JSON.parse(result);
        const vehicleType = (this.vehicleType || '').toLowerCase();
     
        const teamToExclude = (type) => {
            if (['funds', 'umbrella'].includes(type)) return 'IS';
            if (['mandate', 'dedicated'].includes(type)) return 'Product Strategy';
            return null;
        };
     
        const excludedTeam = teamToExclude(vehicleType);
     
        this.steps = stepsArray.map(step => {
            let filteredTeams = step.teams;
            if (excludedTeam) {
                filteredTeams = step.teams.filter(team =>
                    team.name.toLowerCase() !== excludedTeam.toLowerCase()
                );
            }
     
            return {
                id: step.id || null,
                name: step.name || 'Unnamed Step',
                statustep: step.statustep || 'Unnamed Step',
                teams: filteredTeams.map(team => ({
                    id: team.id || null,
                    stepid: step.id || null,
                    team: team.name || 'Unnamed Milestone',
                    owner: team.owner || 'Unknown',
                    status: team.status || 'null',
                    dynamicIcon: team.dynamicIcon
                }))
            };
        });
    
        this.prepareData();
    }
 
    async prepareData() {
        try {
            this.isLoading = true;
            let recordIds = [];
            let stepNames = [];
            let teamNames = [];
 
            this.steps.forEach(step => {
                step.teams.forEach(team => {
                recordIds.push(step.id);
                stepNames.push(step.name === 'Design & Proposal' ? 'Proposal' : step.name);
                teamNames.push(team.team);
                });
            });
 
            const completionRates = await getCompletionRatesBulk({ recordIds, stepNames, teamNames });
 
            let completionMap = new Map();
            completionRates.forEach(item => {
                completionMap.set(`${item.recordId}-${item.stepName}-${item.teamName}`, item.completionRate);
            });
 
            this.stepsData = this.steps.map(step => ({
                ...step,
                teams: step.teams.map(team => ({
                    ...team,
                    completionRate: completionMap.get(`${step.id}-${step.name === 'Design & Proposal' ? 'Proposal' : step.name}-${team.team}`) || 0
                }))
            }));
 
            this.isLoading = false;
        } catch (error) {
            console.error('❌ Error preparing data:', error);
            this.isLoading = false;
        }
    }
}