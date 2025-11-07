public without sharing class ProjectProductSetupHandler {

    static final Id shareClassCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('ShareclassCreation').getRecordTypeId();  
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
    static final Id fundCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();  

    public static Map<String, Set<String>> getPicklistValuesForStages() {
        Set<String> stageValues = new Set<String>();
        List<ProductProjectSettings__c> metadataRecords = [
            SELECT Stage__c,ProjectType__c 
            FROM ProductProjectSettings__c
            ORDER BY Order__c ASC
        ];
        Map<String, Set<String>> stageMap = new Map<String, Set<String>>();
        for (ProductProjectSettings__c record : metadataRecords) {
            if (!stageMap.containsKey(record.ProjectType__c )) {
                stageMap.put(record.ProjectType__c , new Set<String>());
            }
            stageMap.get(record.ProjectType__c ).add(record.Stage__c);
        }
        return stageMap;
    }
    public static void updateLegalOwner(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        List<ProjectProduct__c> listProjectProductToCheck = new List<ProjectProduct__c>();
        for (ProjectProduct__c projectProduct : newProjectProduct.values()) {
            if (projectProduct.LegalForm__c != null && projectProduct.LegalForm__c != oldProjectProduct.get(projectProduct.Id).LegalForm__c) {
                listProjectProductToCheck.add(projectProduct);
            }
        }
 
        if (!listProjectProductToCheck.isEmpty()) {
            User louiseUser = ProjectProductSetupHandlerUtilities.getUser('Louise BIERER');
            User petriUser = ProjectProductSetupHandlerUtilities.getUser('Petri HAMALAINEN');
            if (louiseUser == null || petriUser == null) {
                System.debug('[ERROR] updateLegalOwner : Louise BIERER OR Petri HAMALAINEN doesn\'t exist');
                return;
            }
            Map<Id, User> mapUserIdByUser = ProjectProductSetupHandlerUtilities.getLegalOwnerUsers(listProjectProductToCheck);
            if (mapUserIdByUser != null) {
                for (ProjectProduct__c projectProduct : listProjectProductToCheck) {
                    if (projectProduct.LegalForm__c == 'FCP' && mapUserIdByUser.get(projectProduct.Legal__c).Id != louiseUser.Id) {
                        projectProduct.Legal__c = louiseUser.Id;
 
                    } else if (projectProduct.LegalForm__c != 'FCP' && mapUserIdByUser.get(projectProduct.Legal__c).Id != petriUser.Id){
                        projectProduct.Legal__c = petriUser.Id;
                    }
                }
            }
        }
    }
    
    public static void nbOfFieldsGoal(Map<id,  ProjectProduct__c> newProjectProducts) {
        Set<String> fieldListFund = new Set<String>();
        Set<String> fieldListFundModif = new Set<String>();
        Map<String, Set<String>> fieldListByStage = new Map<String, Set<String>>();

        List<String> parentIds = new List<String>();
        Map<Id,String> parentToFields = new Map<Id,String>();
        
        for (ProductProjectSettings__c setting : [SELECT Stage__c, Team__c, RequiredFields__c 
                                                    FROM ProductProjectSettings__c 
                                                    WHERE ProjectType__c = 'Creation' ]) {
            
            // if (setting.RequiredFields__c != null) {
            
                if (!fieldListByStage.containsKey(setting.Stage__c)) {
                    fieldListByStage.put(setting.Stage__c, new Set<String>());
                }
            if (setting.RequiredFields__c != null) {
                
                fieldListByStage.get(setting.Stage__c).addAll(setting.RequiredFields__c.split(';'));        
        
            }
        }

        for (ProjectProduct__c  projparent : newProjectProducts.values()) {
            if(projparent.TECH_FieldsToModify__c != null){
                parentToFields.put(projparent.Id, projparent.TECH_FieldsToModify__c);
            }
        }

        if(parentToFields.isEmpty()){
            return;
        }

        Integer nbOfFields = 0;
        List<ProjectProductChild__c> projectChildrens = new List<ProjectProductChild__c>() ;

        for (ProjectProductChild__c proj : [SELECT ProjectProductParent__r.TECH_FieldsToModify__c,
                                            Tech_Childtype__c,ProjectProductParent__c,
                                            Parent_Record_Type_Id__c 
                                            FROM ProjectProductChild__c 
                                            WHERE ProjectProductParent__c in : newProjectProducts.keySet() ]) {

            String tmp = proj.Tech_Childtype__c;
            if(proj.Tech_Childtype__c == 'DesignAndProposal'){
                tmp = 'Proposal';
            }
            nbOfFields =  fieldListByStage.get(tmp) != null ?
            fieldListByStage.get(tmp).size() : 0;

            if(proj.Parent_Record_Type_Id__c == fundModificationRecordTypeId){
                nbOfFields = 0;
                if(parentToFields.get(proj.ProjectProductParent__c) != null){
                    for(String str : parentToFields.get(proj.ProjectProductParent__c).split(';')){
                        if(fieldListByStage.get(tmp)?.contains(str)){
                            fieldListFundModif.add(str);
                        }
                    }
                    nbOfFields = fieldListFundModif.size();
                }
            }

            proj.fundNbOfFields__c = nbOfFields;
            projectChildrens.add(proj);
        }
        update projectChildrens;
    }
    
    public void createProjectProduct(List<ProjectProduct__c> newProjectProducts) {
        if (newProjectProducts.isEmpty()) return;
    
        Set<String> stageValues = ProjectProductSetupHandlerUtilities.getPicklistValuesForStages('Creation');
        if (stageValues.isEmpty()) return;
    
        // Prepare all related records
        List<RoadToMarket__c> mainRoads = new List<RoadToMarket__c>();
        Map<Id, RoadToMarket__c> projectProductToMainRoadMap = new Map<Id, RoadToMarket__c>();
        
        for (ProjectProduct__c product : newProjectProducts) {
            RoadToMarket__c mainRoad = new RoadToMarket__c(
                Name = 'Road To Market ' + product.Name,
                Parent_Project__c = product.Id,
                Tech_Type__c = 'Parent'
            );
            mainRoads.add(mainRoad);
            projectProductToMainRoadMap.put(product.Id, mainRoad);
        }
    
        // Insert all main roads in one DML
        insert mainRoads;
        List<ProjectProduct__c> productsToUpdate = new List<ProjectProduct__c>();
        // Update ProjectProduct with the new RoadToMarket__c Ids
        for (ProjectProduct__c product : newProjectProducts) {
             RoadToMarket__c insertedRoad = projectProductToMainRoadMap.get(product.Id);
            if (insertedRoad != null) {
                  //product.RoadToMarket__c = insertedRoad.Id;
            	ProjectProduct__c updProduct = new ProjectProduct__c();
                updProduct.RoadToMarket__c = insertedRoad.Id;
                updProduct.Id = product.Id;
                productsToUpdate.add(updProduct);
             }
          }
        
         //Upsert all ProjectProducts in one go
         //upsert newProjectProducts;
         update productsToUpdate;    
        // Prepare children and road to markets
        List<ProjectProductChild__c> allChildren = new List<ProjectProductChild__c>();
        List<RoadToMarket__c> allOtherRoads = new List<RoadToMarket__c>();

        

        for (ProjectProduct__c product : newProjectProducts) {
            List<ProjectProductChild__c> children = createProjectProductChildren(product, 'Creation');
            if (!children.isEmpty()) {
                allChildren.addAll(children);
            }
    
            RoadToMarket__c mainRoad = projectProductToMainRoadMap.get(product.Id);
            List<RoadToMarket__c> otherRoads = createRoadToMarkets(product, mainRoad.Id);
            if (!otherRoads.isEmpty()) {
                allOtherRoads.addAll(otherRoads);
            }
        }
    
        if (!allChildren.isEmpty()) {
            insert allChildren;
        }
    
        if (!allOtherRoads.isEmpty()) {
            insert allOtherRoads;
        }
    }

    public static void setProjectName(List<ProjectProduct__c> newProjectProducts) {
        
        Set<Id> productIds = new Set<Id>();
        for (ProjectProduct__c target : newProjectProducts) {
                if (target.Product__c != null) {
                    productIds.add(target.Product__c);
                }
            
            //IF shareClassCreationRecordTypeIde donotprocess = true 
            if (target.RecordTypeId == shareClassCreationRecordTypeId ) {
                target.TECH_DoNotProcess__c = true;
            }
        }
        if (!productIds.isEmpty()) {

        }
    }

    public static void updatePPName(List<ProjectProduct__c> newProjectProducts) {
        List<ProjectProduct__c> ppToUpdate = new List<ProjectProduct__c>();
        
        for (ProjectProduct__c target : newProjectProducts) {
            if(target.RecordTypeId == fundCreationRecordTypeId && target.Product__c==null){
                ProjectProduct__c updatedRecord = new ProjectProduct__c(
        			Id = target.Id,
                    tech_ByPassVRname__c =true,
        			Name = 'Product Creation' + ' - ' + target.Name + ' - ' + Date.today().format()
    			);
                
                ppToUpdate.add(updatedRecord);
            }
        }
        if(!ppToUpdate.isEmpty()){
            update ppToUpdate;
        }
    }
    
    public static void cloneFund(List<ProjectProduct__c> newProjectProducts) {
        
        Set<Id> productIds = new Set<Id>();
        for (ProjectProduct__c target : newProjectProducts) {
            if(target.RecordTypeId == fundModificationRecordTypeId || target.RecordTypeId == shareClassCreationRecordTypeId || target.RecordTypeId == fundCreationRecordTypeId){
                if (target.Product__c != null) {
                    productIds.add(target.Product__c);
                }
            }
            if(target.RecordTypeId == fundCreationRecordTypeId && target.Product__c==null){
                //target.Name = 'Product Creation' + ' - ' + target.Name + ' - ' + Date.today().format();
                //target.tech_ByPassVRname__c =true;
            }
            //IF shareClassCreationRecordTypeIde donotprocess = true 
            if (target.RecordTypeId == shareClassCreationRecordTypeId ) {
                target.TECH_DoNotProcess__c = true;
            }
        }
        if (!productIds.isEmpty()) {

            // Query all related Productc records
            Map<Id, SObject> sourceRecords = new Map<Id, SObject>();
            try {
                for (SObject prod : Database.query('SELECT ' + RecordCloneHelper.getAllFieldNames('Product__c') + ' FROM Product__c WHERE Id IN :productIds')) {
                    sourceRecords.put((Id)prod.get('Id'), prod);
                }
            } catch (Exception e) {
                for (ProjectProduct__c target : newProjectProducts) {
                    target.addError('Error querying source records: ' + e.getMessage());
                }
                return; // Stop further processing
            }
        
            // Clone fields
            for (ProjectProduct__c target : newProjectProducts) {
                if (sourceRecords.containsKey(target.Product__c)) {
                    try {
                        RecordCloneHelper.cloneRecordFields(sourceRecords.get(target.Product__c), target);
                        String actionType = target.RecordTypeId == fundModificationRecordTypeId ? 'Modification' : target.RecordTypeId == shareClassCreationRecordTypeId ? 'Shareclass Creation' : 'Product Creation';
                        String productName = target.Product__c != null ? (String)sourceRecords.get(target.Product__c).get('Name') : target.Name;
                        target.Name = actionType + ' - ' + productName + ' - ' + Date.today().format();
                    } catch (Exception e) {
                        target.addError('Error cloning record: ' + e.getMessage());
                    }
                } else {
                    target.addError('No matching Product__c record found for cloning.');
                }
            }
        }
    }

    private List<ProjectProductChild__c> createProjectProductChildren(ProjectProduct__c projectProduct, String projectType) {

    List<ProductProjectSettings__c> settings1 = [
        SELECT Stage__c, DaysBeforeLastStep__c, Order__c, Team__c
        FROM ProductProjectSettings__c
        WHERE ProjectType__c = :projectType AND Team__c = 'Legal'
        ORDER BY Order__c ASC
    ];

    Integer nbOfFields = 0;
    Map<String, Set<String>> fieldListByStage = new Map<String, Set<String>>();

    for (ProductProjectSettings__c setting : [
        SELECT Stage__c, RequiredFields__c
        FROM ProductProjectSettings__c 
        WHERE ProjectType__c = :projectType
    ]) {
        if (setting.RequiredFields__c != null) {
            if (!fieldListByStage.containsKey(setting.Stage__c)) {
                fieldListByStage.put(setting.Stage__c, new Set<String>());
            }
            fieldListByStage.get(setting.Stage__c).addAll(setting.RequiredFields__c.split(';'));
        }
    }

    List<ProjectProductChild__c> projectProductChildren = new List<ProjectProductChild__c>();

    if (projectProduct.ProjectStartDate__c == null) {
        throw new IllegalArgumentException('La date de début du projet doit être spécifiée.');
    }

    Date currentStartDate = projectProduct.ProjectStartDate__c;
    Date currentEndDate;
    Integer daysToAdd;

    Map<String, List<String>> teamNoFieldsByStep = ProjectMatriceUtilities.getTeamwithNorequiredFieldsByStep();

    for (ProductProjectSettings__c setting : settings1) {

        if (projectProduct.RecordTypeId == fundModificationRecordTypeId) {
            daysToAdd = 30;
        } else {
            daysToAdd = Integer.valueOf(setting.DaysBeforeLastStep__c);
        } 
        currentEndDate = currentStartDate.addDays(daysToAdd);

        List<String> teamswithNofields = teamNoFieldsByStep.get(setting.Stage__c);
        ProjectProductChild__c child;

        if (setting.Stage__c != 'Design') {
            nbOfFields = fieldListByStage.get(setting.Stage__c)?.size() ?? 0;
            child = ProjectProductSetupHandlerUtilities.createProjectProductChild(
                setting.Stage__c,
                projectProduct.Id,
                currentStartDate,
                currentEndDate, 
                teamswithNofields,
                nbOfFields
            );

            if (projectProduct.RecordTypeId == fundModificationRecordTypeId) {
                child.tech_teamvalidation__c = 'ProductStrategy;Risk;Legal;Tax;OPS;ESG;Compliance;DCO;DCR;InvestmentPerf;Finance;Communication;Technology;IS';
                child.CompletionRateStep__c = 100;
            }
        } else {
            child = ProjectProductSetupHandlerUtilities.createProjectProductChild(
                setting.Stage__c,
                projectProduct.Id,
                currentStartDate,
                currentEndDate, 
                new List<String>(), 
                0
            );
            child.CompletionRateStep__c = 100;

            if (projectProduct.RecordTypeId == fundModificationRecordTypeId) {
                child.tech_teamvalidation__c = 'ProductStrategy;Risk;Legal;Tax;OPS;ESG;Compliance;DCO;DCR;InvestmentPerf;Finance;Communication;Technology;IS';
            }
        }

        projectProductChildren.add(child);
        currentStartDate = currentEndDate;
    }

    // 💡 APPEL NOUVELLE MÉTHODE POUR LA LOGIQUE SHARECLASS CREATION
    if (projectProduct.RecordTypeId == shareClassCreationRecordTypeId) {
        handleShareclassCreationTeamValidation(projectProductChildren, projectType);
    }

    return projectProductChildren;
}

    private void handleShareclassCreationTeamValidation(List<ProjectProductChild__c> projectProductChildren, String projectType) {
        
        // Mapping exact entre matrice et multipicklist Salesforce
        Map<String, String> teamNameToPicklistValue = new Map<String, String>{
            'Product Strategy' => 'ProductStrategy',
            'Legal' => 'Legal',
            'Tax' => 'Tax',
            'OPS' => 'OPS',
            'Risk' => 'Risk',
            'ESG' => 'ESG',
            'Compliance' => 'Compliance',
            'DCO' => 'DCO',
            'DCR' => 'DCR',
            'Investment Perf' => 'InvestmentPerf',
            'Finance' => 'Finance',
            'Communication' => 'Communication',
            'Technology' => 'Technology',
            'IS' => 'IS'
        };

        // Charger tous les settings par stage et équipe
        Map<String, Map<String, ProductProjectSettings__c>> scFieldsByStageTeam = new Map<String, Map<String, ProductProjectSettings__c>>();

        for (ProductProjectSettings__c setting : [
            SELECT Stage__c, Team__c, RequiredFieldsShareClass__c, NonRequiredFieldsShareClass__c
            FROM ProductProjectSettings__c 
            WHERE ProjectType__c = :projectType AND Stage__c != 'Design'
        ]) {
            if (!scFieldsByStageTeam.containsKey(setting.Stage__c)) {
                scFieldsByStageTeam.put(setting.Stage__c, new Map<String, ProductProjectSettings__c>());
            }
            scFieldsByStageTeam.get(setting.Stage__c).put(setting.Team__c, setting);
        }

        // Pour chaque étape (enfant) du projet
        for (ProjectProductChild__c child : projectProductChildren) {

            Set<String> currentTeams = new Set<String>();

            // Récupérer les équipes déjà présentes
            if (child.TECH_TeamValidation__c != null) {
                currentTeams.addAll(child.TECH_TeamValidation__c.split(';'));
            }

            // Settings pour l'étape actuelle
            String currentStep = child.Tech_Childtype__c;
            if (currentStep == 'DesignAndProposal') {
                currentStep = 'Proposal';
            }
            Map<String, ProductProjectSettings__c> teamSettings = scFieldsByStageTeam.get(currentStep);

            if (teamSettings != null) {
                // Vérification équipe par équipe
                for (String matrixTeamName : teamSettings.keySet()) {
                    
                    ProductProjectSettings__c setting = teamSettings.get(matrixTeamName);
                    Boolean hasNoShareClassFields =
                        String.isBlank(setting.RequiredFieldsShareClass__c) &&
                        String.isBlank(setting.NonRequiredFieldsShareClass__c);

                    // Si aucun champ shareclass, ajouter équipe à la multipicklist
                    if (hasNoShareClassFields && teamNameToPicklistValue.containsKey(matrixTeamName)) {
                        currentTeams.add(teamNameToPicklistValue.get(matrixTeamName));
                    }
                }
            }

            // Mise à jour de la multipicklist uniquement si des équipes sont ajoutées
            if (!currentTeams.isEmpty()) {
                child.TECH_TeamValidation__c = String.join(new List<String>(currentTeams), ';');
            }
        }
    }


    private List<RoadToMarket__c> createRoadToMarkets(ProjectProduct__c projectProduct, String mainRoadToMarketId) {
    List<RoadToMarket__c> l_roadToMarket = new List<RoadToMarket__c>();

    // Récupération de tous les enregistrements de la custom metadata
        for (RoadToMarketTask__mdt roadToMarketMdt : [SELECT MasterLabel, Name__c, Description__c, Team__c, Contributors__c, TeamOrder__c
                                                    FROM RoadToMarketTask__mdt
                                                    ORDER BY TeamOrder__c, MasterLabel]) {
            RoadToMarket__c roadToCreate = new RoadToMarket__c (
                Name = roadToMarketMdt.Name__c,
                RoadToMarket__c = mainRoadToMarketId,
                Description__c = roadToMarketMdt.Description__c,
                Team__c = roadToMarketMdt.Team__c,
                Contributors__c = roadToMarketMdt.Contributors__c,
                TECH_TeamOrder__c = roadToMarketMdt.TeamOrder__c,
                Status__c = 'To be Started',
                Tech_Type__c = 'Child'
            );

            l_roadToMarket.add(roadToCreate);
        }
        return l_roadToMarket;
    }

    /**
     * Méthode pour remplir le champ Tech_DateChangementStatus__c par today lors du changement de status du projet  
     * @param newProjectProduct
     * @param oldProjectProduct
     * handleBeforeUpdate 
    */
    public void updateProjectProductStatus(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct){
        for (Id projectId : newProjectProduct.keySet()){
            ProjectProduct__c oldProject = oldProjectProduct.get(projectId);
             ProjectProduct__c newProject = newProjectProduct.get(projectId);
            
            if(oldProject.ProjectStatus__c !=newProject.ProjectStatus__c){
                //met à jour la date du changement de statut 
                newProject.Tech_DateChangementStatus__c = Date.today();
            }
        }
    }

    public void updateProjectProductName(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct){
        for (Id projectId : newProjectProduct.keySet()){
            ProjectProduct__c oldProject = oldProjectProduct.get(projectId);
            ProjectProduct__c newProject = newProjectProduct.get(projectId);
            
            if(oldProject.InternalShortName__c !=newProject.InternalShortName__c){
                //met à jour la date du changement de statut 
                List<String> nameList =  newProject.Name.split('-');
                newProject.Name = nameList[0] + ' - ' + newProject.InternalShortName__c + ' - ' + nameList[2];
            }
        }
    }

    public void getOwnersTeam(List<ProjectProduct__c> projectProduct) {
        // Récupérer les settings par équipe
        List<ProductProjectSettings__c> settings = [
            SELECT Team__c, TeamOwner__c
            FROM ProductProjectSettings__c
            WHERE ProjectType__c = 'Creation' AND Stage__c = 'Design'
        ];
    
        // Construire une map: équipe → owner
        Map<String, Id> teamOwnerByTeam = new Map<String, Id>();
        for (ProductProjectSettings__c setting : settings) {
            if (setting.Team__c != null && setting.TeamOwner__c != null) {
                teamOwnerByTeam.put(setting.Team__c, setting.TeamOwner__c);
            }
        }
    	/*
        // Utilisateurs statiques par nom
        Map<String, String> staticUserNames = new Map<String, String>{
            'DM' => 'Arnaud Pommier',
            'Product Specialists' => 'Axelle Pinon',
            'Fund Marketing' => 'Josipa Fink',
            'DBS' => 'Thomas Coullon',
            'RFP' => 'Benoit Coffin',
            'DCP' => 'Pauline Walhain'
        };
    
        // Récupérer tous les utilisateurs nécessaires en une seule requête
        Map<String, User> userByName = new Map<String, User>();
        for (User u : [SELECT Id, Name FROM User WHERE Name IN :staticUserNames.values()]) {
            userByName.put(u.Name.toLowerCase(), u);
        }
    
        // Créer la map équipe → userId pour les membres statiques
        Map<String, Id> extraTeamOwners = new Map<String, Id>();
        for (String team : staticUserNames.keySet()) {
            String name = staticUserNames.get(team).toLowerCase();
            if (userByName.containsKey(name)) {
                extraTeamOwners.put(team, userByName.get(name).Id);
            } else {
                System.debug('User not found for team: ' + team + ' (Name: ' + name + ')');
            }
        }*/
    
        // Affectation des propriétaires d'équipe
        for (ProjectProduct__c oProjectProduct : projectProduct) {
            if (oProjectProduct.VehicleType__c == 'Funds') {
                oProjectProduct.ProductStrategy__c = teamOwnerByTeam.get('Product Strategy');
                oProjectProduct.IS__c = null;
            } else {
                oProjectProduct.IS__c = teamOwnerByTeam.get('IS');
                oProjectProduct.ProductStrategy__c = null;
            }
    
            oProjectProduct.Legal__c = teamOwnerByTeam.get('Legal');
            oProjectProduct.Tax__c = teamOwnerByTeam.get('Tax');
            oProjectProduct.OPS__c = teamOwnerByTeam.get('OPS');
            oProjectProduct.Risk__c = teamOwnerByTeam.get('Risk');
            oProjectProduct.ESG__c = teamOwnerByTeam.get('ESG');
            oProjectProduct.Compliance__c = teamOwnerByTeam.get('Compliance');
            oProjectProduct.DCO__c = teamOwnerByTeam.get('DCO');
            oProjectProduct.DCR__c = teamOwnerByTeam.get('DCR');
            oProjectProduct.InvestmentPerf__c = teamOwnerByTeam.get('Investment Perf');
            oProjectProduct.Finance__c = teamOwnerByTeam.get('Finance');
            oProjectProduct.Communication__c = teamOwnerByTeam.get('Communication');
            oProjectProduct.Technology__c = teamOwnerByTeam.get('Technology');
    
            oProjectProduct.DM__c = teamOwnerByTeam.get('DM');
            oProjectProduct.ProductSpecialists__c = teamOwnerByTeam.get('Product Specialists');
            oProjectProduct.FundMarketing__c = teamOwnerByTeam.get('Fund Marketing');
            oProjectProduct.DBS__c = teamOwnerByTeam.get('DBS');
            oProjectProduct.RFP__c = teamOwnerByTeam.get('RFP');
            oProjectProduct.DCP__c = teamOwnerByTeam.get('DCP');
            
            /*oProjectProduct.DM__c = extraTeamOwners.get('DM');
            oProjectProduct.ProductSpecialists__c = extraTeamOwners.get('Product Specialists');
            oProjectProduct.FundMarketing__c = extraTeamOwners.get('Fund Marketing');
            oProjectProduct.DBS__c = extraTeamOwners.get('DBS');
            oProjectProduct.RFP__c = extraTeamOwners.get('RFP');
            oProjectProduct.DCP__c = extraTeamOwners.get('DCP');*/
        }
    }
    
    public void createTaskList(List<ProjectProduct__c> projectProduct){
        List<ProjectTask__c> taskList = new List<ProjectTask__c>();
        Id ControlId = Schema.SObjectType.ProjectTask__c.getRecordTypeInfosByDeveloperName().get('ControlTask').getRecordTypeId();  
        Id TodoId = Schema.SObjectType.ProjectTask__c.getRecordTypeInfosByDeveloperName().get('TodoTask').getRecordTypeId();  
        for( ProjectProduct__c pp : projectProduct){
            if(pp.RecordTypeId == fundCreationRecordTypeId || pp.RecordTypeId == fundModificationRecordTypeId){
                for(Task_List__mdt task_mdt : Task_List__mdt.getAll().values()){
                    ProjectTask__c task = new ProjectTask__c();
                    task.Product__c = pp.Id;
                    task.Description__c = task_mdt.Description__c;
                    task.Action_Comment__c = task_mdt.Comment__c;
                    task.Team__c = task_mdt.Team__c;
                    task.Type__c = task_mdt.Task_Type__c;
                    task.Order__c = task_mdt.Order__c;
                    task.RecordTypeId = task_mdt.Task_Type__c == 'Control' ? ControlId : TodoId ;
                    taskList.add(task);
                }
            }            
        }
        if (!taskList.isEmpty()) {
            insert taskList;
        }
    }
    

    public void createGroupChatterForProject(List<ProjectProduct__c> projectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        Map<String, List<Id>> projectNameWithOwnersTeam = new Map<String, List<Id>>();
        Set<String> groupNameSet = new Set<String>();
        Set<Id> allMemberIds = new Set<Id>();
        Id currentUser = UserInfo.getUserId();
        
        // Récupérer les noms de tous les groupes existants
        for (CollaborationGroup groupe : [SELECT Name FROM CollaborationGroup]) {
            groupNameSet.add(groupe.Name);
        }
        
        // Collecter tous les IDs des utilisateurs associés aux projets "Active"
        Map<String, Set<Id>> tempProjectUserMap = new Map<String, Set<Id>>();
        for (ProjectProduct__c pp : projectProduct) {
            if (pp.ProjectStatus__c == 'Active' && oldProjectProduct.get(pp.Id).ProjectStatus__c != 'Active') {
                Set<Id> memberIds = new Set<Id>();
                
                if (pp.ProductStrategy__c != null && pp.ProductStrategy__c != currentUser) memberIds.add(pp.ProductStrategy__c);
                if (pp.Legal__c != null && pp.Legal__c != currentUser) memberIds.add(pp.Legal__c);
                if (pp.Tax__c != null && pp.Tax__c != currentUser) memberIds.add(pp.Tax__c);
                if (pp.OPS__c != null && pp.OPS__c != currentUser) memberIds.add(pp.OPS__c);
                if (pp.Risk__c != null && pp.Risk__c != currentUser) memberIds.add(pp.Risk__c);
                if (pp.ESG__c != null && pp.ESG__c != currentUser) memberIds.add(pp.ESG__c);
                if (pp.Compliance__c != null && pp.Compliance__c != currentUser) memberIds.add(pp.Compliance__c);
                if (pp.DCO__c != null && pp.DCO__c != currentUser) memberIds.add(pp.DCO__c);
                if (pp.DCR__c != null && pp.DCR__c != currentUser) memberIds.add(pp.DCR__c);
                if (pp.InvestmentPerf__c != null && pp.InvestmentPerf__c != currentUser) memberIds.add(pp.InvestmentPerf__c);
                if (pp.Finance__c != null && pp.Finance__c != currentUser) memberIds.add(pp.Finance__c);
                if (pp.Communication__c != null && pp.Communication__c != currentUser) memberIds.add(pp.Communication__c);
                if (pp.Technology__c != null && pp.Technology__c != currentUser) memberIds.add(pp.Technology__c);
                if (pp.IS__c != null && pp.IS__c != currentUser) memberIds.add(pp.IS__c);
                
                // Nettoyer le nom du groupe
                String cleaned = pp.Name.replaceAll('\\s*-\\s*', ''); // retire les tirets
                cleaned = cleaned.replaceAll('/', ''); // retire les slashes
                
                if (!groupNameSet.contains(cleaned)) {
                    if (!tempProjectUserMap.containsKey(cleaned)) {
                        tempProjectUserMap.put(cleaned, new Set<Id>());
                    }
                    tempProjectUserMap.get(cleaned).addAll(memberIds);
                    allMemberIds.addAll(memberIds);
                }
            }
        }
        
        // Récupérer une seule fois les utilisateurs actifs
        Set<Id> activeUserIds = new Set<Id>();
        if (!allMemberIds.isEmpty()) {
            for (User u : [SELECT Id FROM User WHERE Id IN :allMemberIds AND IsActive = TRUE]) {
                activeUserIds.add(u.Id);
            }
        }
        
        // Construire la map finale pour la création des groupes
        for (String groupName : tempProjectUserMap.keySet()) {
            Set<Id> members = tempProjectUserMap.get(groupName);
            List<Id> activeMembers = new List<Id>();
            
            for (Id userId : members) {
                if (activeUserIds.contains(userId)) {
                    activeMembers.add(userId);
                }
            }
            
            if (!activeMembers.isEmpty()) {
                projectNameWithOwnersTeam.put(groupName, activeMembers);
            }
        }
        
        // Création des groupes
        if (!projectNameWithOwnersTeam.isEmpty()) {
            List<Id> groupsId = ChatterGroupService.createGroupWithMembers(projectNameWithOwnersTeam, 'Description');
            ChatterGroupService.updateGroupMemberNotifications(groupsId, 'P');
        }
    }
    
}