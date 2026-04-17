import { LightningElement, api , track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getrecord  from '@salesforce/apex/RoadToMarketFormController.getRoadToMarketrecordById';
import getStepsMilestones  from '@salesforce/apex/RoadToMarketFormController.getStepsWithMilestones';
import getUserPermissionSets from '@salesforce/apex/displayProjectChildReadOnlyController.getUserPermissionSets';
/**
 * @description       : 
 * @author            : Doha EL QOUSSI
 * @group             : 
 * @last modified on  : 27-02-2025
 * @last modified by  : Doha EL QOUSSI
**/

// Helper function to calculate the percentage position of a date
function calculateGlobalPosition(projectStart, projectEnd, targetDate) {
    const start = new Date(projectStart);
    const end = new Date(projectEnd);
    const target = new Date(targetDate);
   
    const totalDuration = end - start; // Total project duration in milliseconds
    const targetPosition = target - start; // Position of the target date in milliseconds
  
    return (targetPosition / totalDuration) * 100; // Convert to percentage
}

function invertDateFormat(dateString) {
    // Diviser la date en parties : année, mois, jour
    const [year, month, day] = dateString.split("-");

    // Réorganiser les parties pour obtenir jour-mois-année
    return `${day}/${month}/${year}`;
}


export default class lwc_TimelineV3 extends LightningElement {
    @track steps=[];
    @track roadToMarket ;


    stepsWithPositions = [];
    projectStartDate;
    @track  startDatProject;
    projectEndDate;
     colorstep ;
     colormilestone;
    @api recordId;
    @track roadtomarketactivate;
    @track stepStart;
    @track stepCompleted;
    @track stepInProgress;
    @track stepOnHold;
    @track isLoading=true;
    @track recordstepId;
    @track isModalOpen = false; // Contrôle l'affichage de la modale
    @track selectedStep = {}; // Étape sélectionnée
    @track selectedStatus = ''; // Statut sélectionné
    @track stepCompleted= false;

    
    connectedCallback() {
    try{
        this.getStepsMilestones();
        

    } catch(error){
       console.log(error);
    }
    
    }

    getCurrentUserPermissions() {
        getUserPermissionSets()
        .then(result => {
            console.log('PS result : '+result);
            if(result.includes('PRPProductStrategy')  ){
                console.log('user have PS productStrategy');
                this.isModalOpen = true;
            }
        })
        .catch(error => {
            console.log('doha get user permission'+error);
    });
    }

getrecord(){
    getrecord({ recordId:this.recordId})
        .then(result => {
            console.log('NGO result : '+result.Id);
              this.roadtomarketactivate = result.RoadToMarketStatus__c;
              const baseUrl = window.location.origin;
             const roadmarketurl = `${baseUrl}/${result.Id}`;
             //console.log('test url roadtomarket : '+roadmarketurl);
              this.roadToMarket = {
                url: roadmarketurl,
                startDate: result.StartDate__c,
                endDate: result.EndDate__c
            };
            this.calculateRoadToMarket();
        })
        .catch(error => {
            console.log('doha roadtomarket'+error);
    });
}
        
    getStepsMilestones(){
        getStepsMilestones({ recordId:this.recordId})
        .then(result => {
            try {
                // Convertir la chaîne JSON en un objet JavaScript
                const stepsArray = JSON.parse(JSON.stringify(result));
        
                // Vérifier si les données sont un tableau
                if (!Array.isArray(stepsArray)) {
                    throw new Error('Les données JSON reçues ne sont pas un tableau.');
                }
        
                // Mapper les données pour s'assurer que toutes les propriétés nécessaires sont bien présentes
                this.steps = stepsArray.map(step => {
                    return {
                        id: step.id || null, // Par défaut null si id est absent
                        name: step.name || 'Unnamed Step', // Valeur par défaut
                        startDate: step.startDate || null,
                        endDate: step.endDate || null,
                        status: step.status || 'Unknown', // Valeur par défaut
                        progress: step.progress || 0, // Valeur par défaut
                        milestones: Array.isArray(step.milestones) ? step.milestones.map(milestone => ({
                            id: milestone.id || null,
                            name: milestone.name || 'Unnamed Milestone',
                            status: milestone.status || 'Unknown',
                            date: milestone.date || null
                        })) : [] // Tableau vide si milestones n'est pas un tableau
                    };
                });
                
                
                this.calculateProjectPeriod();
                this.calculatePositions();
                this.getrecord();
                this.calculateStartStep();
                this.isLoading=false;
                
            } catch (error) {
                console.error('Erreur lors du traitement des données des étapes :', error);
                // Retourner un tableau vide en cas d'erreur
            }        
            
         //console.log('test doha'+ JSON.stringify(this.steps));
        })
        .catch(error=>{
          console.log('test stepmilestone error'+error);
        });
    }

    calculateProjectPeriod() {
        //console.log('test doha calculateProjectPeriod'+ JSON.stringify(this.steps));
        const startDates = this.steps.map((step) => new Date(step.startDate));
        const endDates = this.steps.map((step) => new Date(step.endDate));     
        this.projectStartDate = new Date(Math.min(...startDates)); // Première date
        this.projectEndDate = new Date(Math.max(...endDates)); // Dernière date
        const year=  this.projectStartDate.getFullYear();
        const month= String(this.projectStartDate.getMonth()+1).padStart(2,'0');
        const day= String(this.projectStartDate.getDate()).padStart(2,'0');
        this.startDatProject = `${day}/${month}/${year}`;
        //console.log('projectperiode'+this.projectStartDate );
        //console.log('projectperiode'+this.projectEndDate );
    }
    calculateStartStep(){
        const startStepPosition = calculateGlobalPosition(
            this.projectStartDate,
            this.projectEndDate,
            this.projectStartDate
        );
        this.stepStart = `left: ${startStepPosition}%;`;
    }
    calculatePositions() {
        //console.log('test doha calculatePositions'+ JSON.stringify(this.steps));
      try{
         this.stepsWithPositions = this.steps.map((step) => {
            // Position de l'étape (à sa date de fin)
            const endDatePosition = calculateGlobalPosition(
                this.projectStartDate,
                this.projectEndDate,
                step.endDate
            );
            const startDatePosition = calculateGlobalPosition(
                this.projectStartDate,
                this.projectEndDate,
                step.startDate
            );
            const lineWidth= endDatePosition - startDatePosition;
            const midPosition =( ((endDatePosition + startDatePosition) / 2));
        //color step
        //console.log('test step'+step.endDate);
        if(step.status =='Completed'){
            this.stepCompleted=true;
            this.colorstep='green';
            
        }else if(step.status =='On track'){
            this.stepCompleted=false;
            this.colorstep='orange';
            
        } else{
            this.stepCompleted=false;
            this.colorstep='lightgray';
          
        }
        const endDateconverted= invertDateFormat(step.endDate);
        //console.log('dd-mm-aaaa'+endDateconverted);
            // Position des jalons
            const milestonesWithPositions = step.milestones.map((milestone) => {
                const milestonePosition = calculateGlobalPosition(
                    this.projectStartDate,
                    this.projectEndDate,
                    milestone.date
                );
                //console.log('test step milestone'+milestone.date);
                const milestoneDateconverted= invertDateFormat(milestone.date);
                if(milestone.status =='Completed'){
                    this.colormilestone='green';
                    
                } else{
                    this.colormilestone='lightgray';
                  
                }
               //console.log("doha test milestonePosition"+milestonePosition );
              // console.log("doha test endDate"+endDatePosition );
                return {
                    ...milestone,
                    dateconverted: milestoneDateconverted,
                    style: `left: ${milestonePosition}%;`,
                    stylemilestone: ` background-color:  ${this.colormilestone};`,
                };
            });

            return {
                ...step,
                endDateConverted: endDateconverted,
                styleLine:`width: ${lineWidth}%;left:${startDatePosition}%;--progress: ${step.progress}%;`,
                style: `left: ${endDatePosition}%;`,
                styleText:`left: ${midPosition}%; transform: translateX(-50%);`,
                stylestep: ` background-color:  ${this.colorstep};`,
                stepCompleted: this.stepCompleted,
                milestones: milestonesWithPositions
            };
        });
    } 
    catch(error){
          console.log('test calcule position'+error);
    }
    }
    calculateRoadToMarket() {
        const startPosition = calculateGlobalPosition(
            this.projectStartDate,
            this.projectEndDate,
            this.roadToMarket.startDate
        );

        const endPosition = calculateGlobalPosition(
            this.projectStartDate,
            this.projectEndDate,
            this.roadToMarket.endDate
        );
        const endDateconverted= invertDateFormat( this.roadToMarket.endDate);
        const startDateconverted= invertDateFormat(this.roadToMarket.startDate);
        //console.log('test road to market'+endPosition);
        //console.log('test road to market'+startPosition);
        const midPosition = (startPosition + endPosition) / 2;
       // console.log('test road to market'+midPosition);
        this.roadToMarket = {
            url: this.roadToMarket.url,
            startDate: startDateconverted,
            endDate: endDateconverted,
            startStyle: `left: ${startPosition}%; transform: translateX(-25%);`,
            endStyle: `left: ${endPosition}%;transform: translateX(-25%);`,
            lineStyle: `
                left: ${startPosition}%;
                width: ${endPosition - startPosition}%;
            `,
            textStyle: `left: ${midPosition}%; transform: translateX(-50%);`
        };
    }

    // Gérer le clic sur une étape
    handleStepClick(event) {
         this.recordstepId = event.target.closest('.step').dataset.id;
         //console.log('doha test popup'+this.recordstepId);
         this.getCurrentUserPermissions();
    }


    handleSuccess() {
        console.log('handlesuccess');
     this.isModalOpen = false;
     this.isLoading=false;
    this.dispatchEvent(
      new ShowToastEvent({
          title: 'Success',
          message: 'Record updated successfully!',
          variant: 'success',
      })
      );
      this.isLoading=true;
      this.getStepsMilestones();
}
    // Fermer la modale
    closeModal() {
        this.isModalOpen = false;
        this.isLoading=true;
        this.getStepsMilestones();
    }

        
}