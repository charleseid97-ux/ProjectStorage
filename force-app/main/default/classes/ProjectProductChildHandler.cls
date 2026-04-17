public without sharing class ProjectProductChildHandler {

    static final Id fundCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();  
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
    static final Id shareClassCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('ShareclassCreation').getRecordTypeId();     
    
    public static void updatePhaseStatusWAllTeamValidation(Map<Id, ProjectProductChild__c> newProjectProductChild, Map<Id, ProjectProductChild__c> oldProjectProductChild) {
        List<ProjectProductChild__c> listProjectProductChildToUpdate = new List<ProjectProductChild__c>();
        Set<Id> setProjectProductParentId = new Set<Id>();

        for (ProjectProductChild__c projectProductChild : newProjectProductChild.values()) {
            if (projectProductChild.TECH_TeamValidation__c != null && projectProductChild.TECH_TeamValidation__c != oldProjectProductChild.get(projectProductChild.Id).TECH_TeamValidation__c && projectProductChild.Status__c != 'Completed') {
                listProjectProductChildToUpdate.add(projectProductChild);
            }
        }

        if (!listProjectProductChildToUpdate.isEmpty()) {
            //On récupère le nombre de record pour avoir le nombre d'équipe total
            List<ProductProjectSettings__c> listProductProjectSettings = [SELECT Id
                                                                            FROM ProductProjectSettings__c
                                                                            WHERE ProjectType__c = 'Creation' AND Stage__c = 'Design'
                                                                            AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20)
                                                                        ];

            if (!listProductProjectSettings.isEmpty()) {
                for (ProjectProductChild__c projectProductChild : listProjectProductChildToUpdate) {
                    if (projectProductChild.TECH_TeamValidation__c.contains(';')) {
                        List<String> listTeamValidation = projectProductChild.TECH_TeamValidation__c.split(';');
                        if (listTeamValidation.size() == listProductProjectSettings.size()) {
                            //We need to update Design if all teams are validated on Proposal phase
                            if (projectProductChild.Name == 'Proposal') {
                                setProjectProductParentId.add(projectProductChild.ProjectProductParent__c);
                            }
                            projectProductChild.Status__c = 'Completed';
                        }
                    }
                }
            }
            if (!setProjectProductParentId.isEmpty()) {
                ProjectProductChildHandlerUtilities.updateDesignStatusPhase(setProjectProductParentId);
            }    
        }
    }

public static void blockValidationBeforeSPCValidated(Map<Id, ProjectProductChild__c> newProjectProductChild, Map<Id, ProjectProductChild__c> oldProjectProductChild) {
    Set<Id> projectProductIds = new Set<Id>();

    for (ProjectProductChild__c projectProductChild : newProjectProductChild.values()) {
         if (projectProductChild.TECH_TeamValidation__c != oldProjectProductChild.get(projectProductChild.id).TECH_TeamValidation__c && projectProductChild.ProjectProductParent__c != null && projectProductChild.TECH_ProjectRecordType__c != 'FundShareClassModification') {
            projectProductIds.add(projectProductChild.ProjectProductParent__c);
        }
    }
 
    Map<Id, Milestone__c> mapMilestoneByProjectId = new Map<Id, Milestone__c>();
    if (!projectProductIds.isEmpty()) {
        for (Milestone__c milestone : [SELECT Id, Project_product__c, Name, Status__c
                                        FROM Milestone__c
                                        WHERE Project_product__c IN :projectProductIds
                                        AND Name = 'SPC Final']) {
            mapMilestoneByProjectId.put(milestone.Project_product__c, milestone);
        }
    }
 
    for (ProjectProductChild__c projectProductChild : newProjectProductChild.values()) {
         if (projectProductChild.TECH_TeamValidation__c != oldProjectProductChild.get(projectProductChild.id).TECH_TeamValidation__c && projectProductChild.ProjectProductParent__c != null && projectProductChild.TECH_ProjectRecordType__c != 'FundShareClassModification') {
            Milestone__c milestone = mapMilestoneByProjectId.get(projectProductChild.ProjectProductParent__c);
            if (milestone == null || milestone.Status__c != 'Completed') {
                projectProductChild.addError('You cannot validate the phase until the "SPC Final" milestone is completed.');
            }
        }
    }
}
     
    
    public static void updateCompletionRate(Map<Id, ProjectProductChild__c> newProjectProductChild, Map<Id, ProjectProductChild__c> oldProjectProductChild) {
        //Si statut = Completed alors taux de completion = 100% pour les projets de modifications
        for (ProjectProductChild__c projectProductChild : newProjectProductChild.values()) {
            if((projectProductChild.Parent_Record_Type_Id__c == fundModificationRecordTypeId && projectProductChild.Status__c == 'Completed' 
                && projectProductChild.Status__c != oldProjectProductChild.get(projectProductChild.Id).Status__c) || projectProductChild.Name == 'Design'  ) {                 
                    projectProductChild.CompletionRateStep__c = 100;
            } else{
                projectProductChild.CompletionRateStep__c = projectProductChild.Completion_Rate_Test__c;
            }
        }
    }

    public static void calculNbOfFields(List<ProjectProductChild__c> newProjectProductChild) {
        System.debug('calculNbOfFields called with ' + newProjectProductChild.size() + ' records.');

        Map<Id, String> idToFields = new Map<Id, String>();
        List<String> parentList = new List<String>();
        Map<String, List<String>> requiredFieldsByStage = ProjectMatriceUtilities.getAllRequiredFieldsByStep();
        for (ProjectProductChild__c proj : newProjectProductChild) {
            proj.NbOfFilledFields__c  = 0;
            parentList.add(proj.ProjectProductParent__c);
        }
        
        for(ProjectProductChild__c proj : [SELECT id,ProjectProductParent__r.Tech_FieldsToModify__c FROM ProjectProductChild__c WHERE ProjectProductParent__c IN :parentList]){
            idToFields.put(proj.Id, proj.ProjectProductParent__r.Tech_FieldsToModify__c);
        }
        for (ProjectProductChild__c prod : newProjectProductChild) {
            List<String> fieldList = new List<String>();

            String prodChildType = prod.TECH_Childtype__c;
            if(prod.TECH_Childtype__c =='DesignAndProposal'){
                prodChildType = 'Proposal';
            }
            System.debug('Fund Stage : '+prodChildType+' setting: ' + requiredFieldsByStage.get(prodChildType));

            if (requiredFieldsByStage.get(prodChildType) != null) {
                List<String> fields = requiredFieldsByStage.get(prodChildType);
                if(prod.Parent_Record_Type_Id__c == fundModificationRecordTypeId){
                   
                    if(idToFields.get(prod.Id) != null){
                        for(String str : idToFields.get(prod.Id).split(';')){
                            if(fields?.contains(str)){
                                fieldList.add(str);
                            }
                        }
                    }
                } else {
                    fieldList.addAll(fields);
                }
                System.debug('Fund Stage : '+prodChildType+' have Field List: ' + fieldList);

                prod.NbOfFilledFields__c = ProjectProductSetupHandlerUtilities.countFilledFields(prod,fieldList);
            }
        }
    }

    public static void createRelatedShareClasses(List<ProjectProductChild__c> newProjectProducts) {
        
        Map<Id, SObject> sourceRecords = new Map<Id, SObject>();
        Map<Id, List<SObject>> shareClassMap = new Map<Id, List<SObject>>();
        Map<Id, SObject> projectProductMap = new Map<Id, SObject>();
        Map<Id, Id> projectProductIdsMap = new Map<Id, Id>();
        List<Share_Class__c> shareClassList = new List<Share_Class__c>();
        Set<Id> productIds = new Set<Id>();
        Set<Id> productProjIds = new Set<Id>();


        for (ProjectProductChild__c target : newProjectProducts) {
            if(target.Parent_Record_Type_Id__c == fundModificationRecordTypeId || target.Parent_Record_Type_Id__c == fundCreationRecordTypeId){
                if(target.ProjectProductParent__c != null ){
                    productProjIds.add(target.ProjectProductParent__c);
                }
            }
        }

        for (ProjectProduct__c project : [SELECT Id,Product__c,RecordTypeId FROM ProjectProduct__c WHERE id in :productProjIds]) {

            if(project.Product__c != null){
                productIds.add(project.Product__c);  
                projectProductMap.put(project.Product__c,project);  
                projectProductIdsMap.put(project.Id, project.Product__c) ; 
            }       
        }
        if (!productIds.isEmpty()) {

            List<ProjectShareclass__c> projectShareClassList = new List<ProjectShareclass__c>();

            for (SObject prod : Database.query('SELECT ' + RecordCloneHelper.getAllFieldNames('Share_Class__c') +  ' FROM Share_Class__c WHERE Fund__c IN :productIds AND Status__c = \'Active\'')) {
                sourceRecords.put((Id)prod.get('Id'), prod);
                shareClassList.add((Share_Class__c)prod);
                if(shareClassMap.containsKey((Id)prod.get('Fund__c'))){
                    
                    shareClassMap.get((Id)prod.get('Fund__c')).add(prod);
                }else{
                    shareClassMap.put((Id)prod.get('Fund__c'), new List<SObject>{prod});
                }
                
            }
            

            for (Share_Class__c shareClassElt : shareClassList) {
                Boolean donotDisplay = false;
                for (Id child : projectProductIdsMap.keySet()) {
                    
                    if (projectProductIdsMap.get(child) == shareClassElt.Fund__c) {  
                       /* if(projectProductMap.get(shareClassElt.Fund__c).get('RecordTypeId') == shareClassCreationRecordTypeId){
                            donotDisplay = true;
                        }*/
                        projectShareClassList.add(new ProjectShareclass__c(
                            Fund__c = shareClassElt.Fund__c,
                            CurrencyIsoCode = shareClassElt.CurrencyIsoCode,
                            DividendPolicy__c = shareClassElt.DividendPolicy__c,
                            Type__c = shareClassElt.Type__c,
                            Tech_ShareClass__c = shareClassElt.Id,
                            //TECH_DoNotProcess__c = donotDisplay,
                            projectProduct__c = child
                        ));
                        
                    }
                    
                }
            }

            List<ProjectShareclass__c> projectShareClassClonedList = new List<ProjectShareclass__c>();
            // Clone fields
            for (ProjectShareclass__c target : projectShareClassList) {
                if (sourceRecords.containsKey(target.Tech_ShareClass__c)) {
                    try {                
                        projectShareClassClonedList.add((ProjectShareclass__c)RecordCloneHelper.cloneRecordFields(sourceRecords.get(target.Tech_ShareClass__c), target));

                    } catch (Exception e) {
                        System.debug('Error cloning record: ' + e.getMessage());

                        target.addError('Error cloning record: ' + e.getMessage());
                    }
                } else {
                    target.addError('No matching Parent record found for cloning.');
                }
            }
            
            insert projectShareClassClonedList;

            List<ProjectChildJunction__c> junctions = new List<ProjectChildJunction__c>();
            for (ProjectProductChild__c sibling : newProjectProducts) {
                for (ProjectShareclass__c projShareClass : projectShareClassClonedList) {
                    if(sibling.ProjectProductParent__c == projShareClass.projectProduct__c){
                        junctions.add(new ProjectChildJunction__c(
                            ProjectProductChild__c = sibling.Id,
                            ProjectShareclass__c = projShareClass.Id
                        ));
                    }                                        
                }
            }

           

            if (!junctions.isEmpty()) {
                insert junctions;
            }
            
        }
    }

    public static void cloneParentProject(List<ProjectProductChild__c> newProjectProducts) {
        Set<Id> productIds = new Set<Id>();
        for (ProjectProductChild__c target : newProjectProducts) {
            if(target.Parent_Record_Type_Id__c == fundModificationRecordTypeId || target.Parent_Record_Type_Id__c == fundCreationRecordTypeId || target.Parent_Record_Type_Id__c == shareClassCreationRecordTypeId){
                if(target.ProjectProductParent__c != null ){
                    productIds.add(target.ProjectProductParent__c);
                }
            }
        }
    
        // Query all related Productc records
        if (!productIds.isEmpty()) {
            Map<Id, SObject> sourceRecords = new Map<Id, SObject>();

            try {
                for (SObject prod : Database.query('SELECT ' + RecordCloneHelper.getAllFieldNames('ProjectProduct__c') + ' FROM ProjectProduct__c WHERE Id IN :productIds')) {
                    sourceRecords.put((Id)prod.get('Id'), prod);
                }
            } catch (Exception e) {
                for (ProjectProductChild__c target : newProjectProducts) {
                    target.addError('Error querying source records: ' + e.getMessage());
                }
                return; // Stop further processing
            }
    
            // Clone fields
            for (ProjectProductChild__c target : newProjectProducts) {
                if (sourceRecords.containsKey(target.ProjectProductParent__c)) {
                    try {
                        RecordCloneHelper.cloneRecordFields(sourceRecords.get(target.ProjectProductParent__c), target);
                    } catch (Exception e) {
                        target.addError('Error cloning record: ' + e.getMessage());
                    }
                } else {
                    target.addError('No matching Parent record found for cloning.');
                }
            }
            
        }
    }


    // public static void updateProjectEndate(List<ProjectProductChild__c> l_projectProductChild, Date goliveEndDate) {
    //     //Need to bulkify
    //     ProjectProductChild__c productChild = l_projectProductChild[0];
    //     ProjectProduct__c projectProduct = [SELECT Id, EndDate__c FROM ProjectProduct__c WHERE Id =: productChild.ProjectProductParent__c];
    //     projectProduct.EndDate__c = goliveEndDate;
    //     update projectProduct;
    // }
    public static void updateProjectEndate(List<ProjectProductChild__c> projectProductChildren, Date goLiveEndDate) {
        Set<Id> parentIds = new Set<Id>();
        for (ProjectProductChild__c child : projectProductChildren) {
            if (child.ProjectProductParent__c != null) {
                parentIds.add(child.ProjectProductParent__c);
            }
        }
    
        if (parentIds.isEmpty()) return;
    
        List<ProjectProduct__c> toUpdate = [
            SELECT Id, EndDate__c FROM ProjectProduct__c WHERE Id IN :parentIds
        ];
    
        for (ProjectProduct__c parent : toUpdate) {
            parent.EndDate__c = goLiveEndDate;
        }
    
        update toUpdate;
    }

     /** 🔹 Création des milestones */
     public static Date createMilestones(List<ProjectProductChild__c> l_projectProductChild) {
        List<Milestone__c> l_milestoneToCreate = new List<Milestone__c>();
        Date goLiveEndDate;
 
        for (ProjectProductChild__c projectProductChild : l_projectProductChild) {
            switch on projectProductChild.Name {
                when 'Design' {
                    l_milestoneToCreate.add(ProjectProductChildHandlerUtilities.createMilestone(
                        'SPC 1', projectProductChild.ProjectProductParent__c, projectProductChild.Id, projectProductChild.EndDate__c
                    ));
                }
                when 'Proposal' {
                    l_milestoneToCreate.add(ProjectProductChildHandlerUtilities.createMilestone(
                    'SPC Final', projectProductChild.ProjectProductParent__c, projectProductChild.Id, projectProductChild.EndDate__c - 4
                    ));
                }
                when 'Engineering' {
                    l_milestoneToCreate.add(ProjectProductChildHandlerUtilities.createMilestone(
                        'Filing', projectProductChild.ProjectProductParent__c, projectProductChild.Id, projectProductChild.EndDate__c
                    ));
                }
                when 'Filing' {
                    l_milestoneToCreate.add(ProjectProductChildHandlerUtilities.createMilestone(
                        'Regulatory Approval', projectProductChild.ProjectProductParent__c, projectProductChild.Id, projectProductChild.EndDate__c
                    ));
                }
                when 'SetUp' {
                    l_milestoneToCreate.add(ProjectProductChildHandlerUtilities.createMilestone(
                        'Launch Date', projectProductChild.ProjectProductParent__c, projectProductChild.Id, projectProductChild.EndDate__c - 4
                    ));
                    goLiveEndDate = projectProductChild.EndDate__c - 4;
                }
            }
        }
 
        insert l_milestoneToCreate;
        return goLiveEndDate;
    }

   /** 🔹 Verrouillage des enregistrements après validation */
   public static void lockRecordProjectProductChild(Map<Id, ProjectProductChild__c> newProjectProductChild, Map<Id, ProjectProductChild__c> oldProjectProductChild) {
        ProjectChildTeamValidationController.lockRecordPPC(newProjectProductChild.values(), oldProjectProductChild.values());
    }


    public static void updateProjectProductParent(Map<Id, ProjectProductChild__c> newProjectProductChild, Map<Id, ProjectProductChild__c> oldProjectProductChild) {
        // Champs système et techniques à exclure
        Set<String> excludedFields = new Set<String>{ 
            'id', 'createddate', 'createdbyid', 'lastmodifieddate', 'lastmodifiedbyid',
            'systemmodstamp', 'ownerid', 'lastactivitydate', 'recordtypeid',
            'tech_childtype__c', 'tech_teamvalidation__c', 'enddate__c'
        };
 
        // Récupérer les Id des parents concernés
        Set<Id> parentIds = new Set<Id>();
        for (ProjectProductChild__c newChild : newProjectProductChild.values()) {
            if (newChild.ProjectProductParent__c != null) {
                parentIds.add(newChild.ProjectProductParent__c);
            }
        }
 
        if (parentIds.isEmpty()) {
            return;
        }
 
        // Récupérer les parents existants
        Map<Id, ProjectProduct__c> parentRecords = new Map<Id, ProjectProduct__c>(
            [SELECT Id FROM ProjectProduct__c WHERE Id IN :parentIds]
        );
 
        // Décrire les champs de l'objet enfant et parent
        Map<String, Schema.SObjectField> childFields = ProjectProductChild__c.SObjectType.getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> parentFields = ProjectProduct__c.SObjectType.getDescribe().fields.getMap();
 
        // Préparer les parents à mettre à jour
        Map<Id, ProjectProduct__c> parentsToUpdate = new Map<Id, ProjectProduct__c>();
 
        for (Id childId : newProjectProductChild.keySet()) {
            ProjectProductChild__c newChild = newProjectProductChild.get(childId);
            ProjectProductChild__c oldChild = oldProjectProductChild.get(childId);
 
            Id parentId = newChild.ProjectProductParent__c;
            Schema.DescribeSObjectResult targetDescribe = newChild.getSObjectType().getDescribe();
            Map<String, Schema.SObjectField> targetFields = targetDescribe.fields.getMap();

            // Si le parent est bien récupéré
            if (parentRecords.containsKey(parentId)) {
                ProjectProduct__c parentToUpdate;
                if (!parentsToUpdate.containsKey(parentId)) {
                    parentToUpdate = parentRecords.get(parentId).clone(false, true, false, false);
                    parentToUpdate.Id = parentId; // Restaurer l'Id car le clone met Id = null
                    parentsToUpdate.put(parentId, parentToUpdate);
                } else {
                    parentToUpdate = parentsToUpdate.get(parentId);
                }
 
                // Comparaison champ par champ pour détecter les changements
                for (String fieldName : childFields.keySet()) {
                    if (excludedFields.contains(fieldName) || !parentFields.containsKey(fieldName)) {
                        continue; // Champ système, technique, ou inexistant sur parent
                    }
 
                    Object newValue = newChild.get(fieldName);
                    Object oldValue = oldChild == null ? null : oldChild.get(fieldName);
                    if(!targetFields.get(fieldName).getDescribe().isCalculated()){

                        // Mise à jour uniquement si la valeur est différente
                        if ((newValue == null && oldValue != null) || (newValue != null && !newValue.equals(oldValue))) {
                            parentToUpdate.put(fieldName, newValue);
                        }
                    }
                }
            }
        }
 
        if (!parentsToUpdate.isEmpty()) {
            update parentsToUpdate.values();
        }
    }

    public static void logPhaseValidation(Map<Id, ProjectProductChild__c> newProjectProductChild, Map<Id, ProjectProductChild__c> oldProjectProductChild) {
        List<ProjectProductChild__c> projectProductChildToLog = new List<ProjectProductChild__c>();
        for (ProjectProductChild__c projectProductChild : newProjectProductChild.values()) {
            //TECH_TeamValidation__c has been changed and not null
            if (projectProductChild.TECH_TeamValidation__c != null && projectProductChild.TECH_TeamValidation__c != oldProjectProductChild.get(projectProductChild.Id).TECH_TeamValidation__c) {
                projectProductChildToLog.add(projectProductChild);
            }
        }

        if (!projectProductChildToLog.isEmpty()) {
            FieldHistoryLogger.logPhaseValidation(projectProductChildToLog, oldProjectProductChild);
        }
    }
}