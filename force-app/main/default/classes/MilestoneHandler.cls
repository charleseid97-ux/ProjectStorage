public class MilestoneHandler {
    
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
    static final Id fundCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();  

    public static void linkStepToMilestone (Milestone__c  milestone){
        List<ProjectProductChild__c> steps=[Select Id , Name , StartDate__c , EndDate__c , ProjectProductParent__c FROM ProjectProductChild__c where ProjectProductParent__c = :milestone.Project_product__c  ];
        for(ProjectProductChild__c step: steps){
            if(step.StartDate__c <= milestone.StartDate__c && step.EndDate__c >= milestone.StartDate__c  ){
                milestone.Project_Product_Child__c = step.id;
            }
        }
    }

    public static void updateProjectLaunchDate(Map<Id, Milestone__c> newMilestone, Map<Id, Milestone__c> oldMilestone) {
        List<Milestone__c> listMilestoneToCheck = new List<Milestone__c>();
        List<ProjectProduct__c> listProjectProductToUpdate = new List<ProjectProduct__c>();
        Set<Id> setProjectProductId = new Set<Id>();
        for (Milestone__c milestone : newMilestone.values()) {
            if (milestone.Name == 'Launch Date' && milestone.StartDate__c != oldMilestone.get(milestone.Id).StartDate__c && milestone.StartDate__c != null) {
                listMilestoneToCheck.add(milestone);
                setProjectProductId.add(milestone.Project_Product__c);
            }
        }

        if (!setProjectProductId.isEmpty()) {
            Map<Id, ProjectProduct__c> mapProjectProductById = new Map<Id, ProjectProduct__c>([SELECT Id, EndDate__c FROM ProjectProduct__c WHERE Id IN :setProjectProductId]);
            //We recheck to avoid multiple trigger call (Because we double synchronise the dates ProjectProduct EndDate and Milestone (GOLIVE) StartDate)
            for (Milestone__c milestone : listMilestoneToCheck){
                if (mapProjectProductById.containsKey(milestone.Project_product__c)) {
                    if (milestone.StartDate__c != mapProjectProductById.get(milestone.Project_product__c).EndDate__c) {
                        mapProjectProductById.get(milestone.Project_product__c).EndDate__c = milestone.StartDate__c;
                        listProjectProductToUpdate.add(mapProjectProductById.get(milestone.Project_product__c));
                    }
                }
            }

            if (!listProjectProductToUpdate.isEmpty()) {
                update listProjectProductToUpdate;
            }
        }
    }

    public static void updateOwnerOnProjectProduct(Map<Id, Milestone__c> newMilestones, Map<Id, Milestone__c> oldMilestones) {
        List<ProjectProduct__c> listProjectProductToUpdate = new List<ProjectProduct__c>();
        Set<Id> setProjectProductId = new Set<Id>();
        for (Milestone__c milestone : newMilestones.values()) {
            if (milestone.Name == 'SPC Final' && milestone.Status__c != oldMilestones.get(milestone.Id).Status__c && milestone.Status__c == 'Completed') {
                setProjectProductId.add(milestone.Project_Product__c);
            }
        }
        String fieldsToModifyProduct = '';
        String fieldsToModifySC = '';
        List<ProductProjectSettings__c> matriceRecords = [SELECT Id, TeamOwner__c, Team__c, RequiredFields__c, RequiredFieldsShareClass__c, NonRequiredFieldsFund__c, NonRequiredFieldsShareClass__c  FROM ProductProjectSettings__c ];
        List<ProjectProduct__c> pp = [SELECT Id, TECH_FieldsToModify__c, (Select Id, TECH_FieldsToModify__c  from ProjectShareclasses__r) FROM ProjectProduct__c WHERE Id IN :setProjectProductId AND RecordTypeId =: fundModificationRecordTypeId];
        
        for  (ProjectProduct__c projectProduct : pp) {
            if(projectProduct.TECH_FieldsToModify__c != Null) {
                fieldsToModifyProduct = projectProduct.TECH_FieldsToModify__c ;
            }
            if (projectProduct.ProjectShareclasses__r.size() > 0) {
                for (ProjectShareclass__c psc : projectProduct.ProjectShareclasses__r) {
                    if(psc.TECH_FieldsToModify__c != Null){
                        fieldsToModifySC += psc.TECH_FieldsToModify__c + ';';
                    }
                }
            }
            Map<String,Id> teamOwner = new Map<String,String>();
            for(String field : fieldsToModifyProduct.split(';')) {
                for(ProductProjectSettings__c ppc : matriceRecords) {
                    if((ppc.RequiredFields__c != null && ppc.RequiredFields__c.contains(field)) || (ppc.NonRequiredFieldsFund__c != null && ppc.NonRequiredFieldsFund__c.contains(field))){
                        if(!teamOwner.containsKey(ppc.Team__c)){
                            teamOwner.put(ppc.Team__c,ppc.TeamOwner__c);
                            break;
                        }
                    }
                }
            }
            for(String field : fieldsToModifySC.split(';')) {
                for(ProductProjectSettings__c ppc : matriceRecords) {
                    if((ppc.RequiredFieldsShareClass__c != null && ppc.RequiredFieldsShareClass__c.contains(field)) || (ppc.NonRequiredFieldsShareClass__c != null && ppc.NonRequiredFieldsShareClass__c.contains(field))){
                        if(!teamOwner.containsKey(ppc.Team__c)){
                            teamOwner.put(ppc.Team__c,ppc.TeamOwner__c);
                            break;
                        }
                    }
                }
            }
            system.debug('fieldsToModifyProduct: ' + fieldsToModifyProduct);
            system.debug('fieldsToModifySC: ' + fieldsToModifySC);
            fieldsToModifyProduct = '';
            fieldsToModifySC = '';
            system.debug('teamOwner: ' + teamOwner);
            //projectProduct.ProductStrategy__c = teamOwner.get('Product Strategy') != null ? teamOwner.get('Product Strategy') : Null;
            projectProduct.Legal__c          = teamOwner.get('Legal') != null ? teamOwner.get('Legal') : Null;
            projectProduct.Tax__c            = teamOwner.get('Tax') != null ? teamOwner.get('Tax') : Null;
            projectProduct.OPS__c            = teamOwner.get('OPS') != null ? teamOwner.get('OPS') : Null;
            projectProduct.Risk__c           = teamOwner.get('Risk') != null ? teamOwner.get('Risk') : Null;
            projectProduct.ESG__c            = teamOwner.get('ESG') != null ? teamOwner.get('ESG') : Null;
            projectProduct.Compliance__c     = teamOwner.get('Compliance') != null ? teamOwner.get('Compliance') : Null;
            projectProduct.DCO__c            = teamOwner.get('DCO') != null ? teamOwner.get('DCO') : Null;
            projectProduct.DCR__c            = teamOwner.get('DCR') != null ? teamOwner.get('DCR') : Null;
            projectProduct.InvestmentPerf__c = teamOwner.get('Investment Perf') != null ? teamOwner.get('Investment Perf') : Null;
            projectProduct.Finance__c        = teamOwner.get('Finance') != null ? teamOwner.get('Finance') : Null;
            projectProduct.Communication__c  = teamOwner.get('Communication') != null ? teamOwner.get('Communication') : Null;
            projectProduct.Technology__c     = teamOwner.get('Technology') != null ? teamOwner.get('PTechnology') : Null;
            projectProduct.DM__c                 = Null;
            projectProduct.ProductSpecialists__c = Null;
            projectProduct.FundMarketing__c      = Null;
            projectProduct.DBS__c                = Null;
            projectProduct.RFP__c                = Null;
            projectProduct.DCP__c                = Null;
            
            listProjectProductToUpdate.add(projectProduct);
        }
        if(listProjectProductToUpdate.size()>0){
            update listProjectProductToUpdate;
        }

    }

    public static void validatePhasesESG(Map<Id, Milestone__c> newMilestones, Map<Id, Milestone__c> oldMilestones){
        Set<Id> projectIds = new Set<Id>();
        for (Milestone__c milestone : newMilestones.values()) {
            if(milestone.Name == 'SPC Final' && 
                milestone.Status__c != oldMilestones.get(milestone.Id).Status__c 
                && milestone.Status__c == 'Completed' 
                ){
                    system.debug('milestone.Project_Product__c: ' + milestone.Project_Product__c);
                    projectIds.add(milestone.Project_Product__c);
            }
        }
        List<ProjectProductChild__c> children = [SELECT Id, ProjectProductParent__c, TECH_TeamValidation__c FROM ProjectProductChild__c 
                                                    WHERE ProjectProductParent__c IN :projectIds
                                                    AND ProjectProductParent__r.RecordTypeId =: fundCreationRecordTypeId 
                                                    AND ProjectProductParent__r.SFDRcategory__c = '0'];
        for(ProjectProductChild__c child : children){
            Set<String> currentTeams = new Set<String>();
            if (child.TECH_TeamValidation__c != null) {
                currentTeams.addAll(child.TECH_TeamValidation__c.split(';'));
            }
            currentTeams.add('ESG');
            child.TECH_TeamValidation__c = String.join(new List<String>(currentTeams), ';');
        }
        update children;
    }
}