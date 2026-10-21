/** ──────────────────────────────────────
 * @description Trigger logic for ProjectProduct__c (PMT projects): Scope (PS/IS) and team owners at creation, owner
 *                  rules on update, fields goal per stage, project structure (Road To Market, Project Product Child per
 *                  stage with its dates and pre-validated teams), cloning from the Product, names, status date, task
 *                  list and Chatter group.
 *              Stages, durations, validation teams, fields and owners come from the PMT matrix (PMTMatrix, FIX-20178),
 *                  restricted to the project's Scope where PS and IS are mutually exclusive.
 *              US-20194: the matrix follows the project's conditions (PMTMatrix.forConditions / forProject); resyncConditionalValues
 *                  realigns (asynchronously) the goals and the automatically validated teams when a field read by a condition changes.
 * @lastModifiedBy Charles EID   [21-10-26]
 * @testClass Test_ProjectProductTrigger
 * @coverage 94%   [21-10-26]
 ────────────────────────────────────── */
public without sharing class ProjectProductSetupHandler {

    static final Id shareClassCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('ShareclassCreation').getRecordTypeId();
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
    static final Id fundCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();

    // FIX-20178: reapplies the PMT owner rules (PMTOwnerRule__mdt, e.g. Legal owner by LegalForm__c) of the teams whose rule field changed. Replaces updateLegalOwner and its hardcoded user names. No applicable rule or an owner not found keeps the current owner.
    // US-20194: a rule applies when its condition (PMTOwnerRule__mdt.Condition__c) is true; its fields are the fields read by the condition.
    public static void applyOwnerRules(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        PMTMatrix matrix = PMTMatrix.get();
        if (matrix.getOwnerRuleFields().isEmpty()) return;

        for (ProjectProduct__c projectProduct : newProjectProduct.values()) {
            ProjectProduct__c oldProject = oldProjectProduct.get(projectProduct.Id);
            Map<String, Id> ruleOwnerIdByTeam = PMTMatrix.forProject(projectProduct).getRuleOwnerIdByTeam(projectProduct);

            for (String teamName : ruleOwnerIdByTeam.keySet()) {
                Id ownerId = ruleOwnerIdByTeam.get(teamName);
                if (ownerId == null) continue;

                Boolean ruleFieldChanged = false;
                for (String field : matrix.getOwnerRuleFields(teamName)) {
                    if (projectProduct.get(field) != oldProject.get(field)) ruleFieldChanged = true;
                }
                if (ruleFieldChanged) projectProduct.put(matrix.getTeam(teamName).key + '__c', ownerId);
            }
        }
    }

    // Fields goal (fundNbOfFields__c) of each phase: the required Fund fields of its stage; on a modification project, only the selected fields (TECH_FieldsToModify__c) of its stage.
    // FIX-20270: the selected fields are counted per phase. Before, one set accumulated across the phases, so a phase also counted the fields of the stages read before it.
    public static void nbOfFieldsGoal(Map<id, ProjectProduct__c> newProjectProducts) {
        Map<Id, String> parentToFields = new Map<Id, String>();

        for (ProjectProduct__c projparent : newProjectProducts.values()) {
            if (projparent.TECH_FieldsToModify__c != null) parentToFields.put(projparent.Id, projparent.TECH_FieldsToModify__c);
        }

        if (parentToFields.isEmpty()) return;

        Integer nbOfFields = 0;
        List<ProjectProductChild__c> projectChildrens = new List<ProjectProductChild__c>();

        for (ProjectProductChild__c proj : [SELECT ProjectProductParent__r.TECH_FieldsToModify__c, Tech_Childtype__c, ProjectProductParent__c, Parent_Record_Type_Id__c
                                            FROM ProjectProductChild__c
                                            WHERE ProjectProductParent__c in :newProjectProducts.keySet()]) {
            String tmp = proj.Tech_Childtype__c;
            if (proj.Tech_Childtype__c == 'DesignAndProposal') tmp = 'Proposal';

            // FIX-20178 / US-20194: champs Fund requis de l'étape, depuis la matrice PMT selon les conditions du projet
            List<String> stageFields = PMTMatrix.get().forConditions(newProjectProducts.get(proj.ProjectProductParent__c)).getRequiredFieldsByStage(true).get(tmp);
            nbOfFields = stageFields != null ? stageFields.size() : 0;

            if (proj.Parent_Record_Type_Id__c == fundModificationRecordTypeId) {
                nbOfFields = 0;
                Set<String> fieldListFundModif = new Set<String>();
                if (parentToFields.get(proj.ProjectProductParent__c) != null) {
                    for (String str : parentToFields.get(proj.ProjectProductParent__c).split(';')) {
                        if (stageFields?.contains(str)) fieldListFundModif.add(str);
                    }
                    nbOfFields = fieldListFundModif.size();
                }
            }

            proj.fundNbOfFields__c = nbOfFields;
            projectChildrens.add(proj);
        }
        update projectChildrens;
    }

    // US-20194: a field read by the PMT conditions changed on a creation project (e.g. LegalForm__c or DomiciledIn__c filled during the project): the values computed from the matrix at creation have to follow (resyncPhases). Asynchronous: the change usually comes from a phase whose values are copied to the project (updateProjectProductParent), and that phase cannot be updated again within its own trigger. Modification projects are left out: their validations follow the selected fields (validateSteps).
    public static void resyncConditionalValues(Map<Id, ProjectProduct__c> newProjectProducts, Map<Id, ProjectProduct__c> oldProjectProducts) {
        Set<String> conditionFields = PMTMatrix.get().getConditionFields();
        if (conditionFields.isEmpty()) return;

        Map<Id, ProjectProduct__c> oldChangedProjects = new Map<Id, ProjectProduct__c>();
        for (ProjectProduct__c project : newProjectProducts.values()) {
            if (project.RecordTypeId == fundModificationRecordTypeId) continue;
            for (String field : conditionFields) {
                if (project.get(field) != oldProjectProducts.get(project.Id).get(field)) {
                    oldChangedProjects.put(project.Id, oldProjectProducts.get(project.Id));
                    break;
                }
            }
        }
        if (oldChangedProjects.isEmpty()) return;

        // An asynchronous context (batch, queueable) can enqueue a single job: once it is used, the realignment runs in the transaction
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) System.enqueueJob(new ResyncConditionalValuesJob(oldChangedProjects));
        else resyncPhases(oldChangedProjects);
    }

    // Share class goals (NbOfFieldsGoal__c) of the projects, then their phases not yet Completed (Design excepted), from their values before the change: the fields goal (fundNbOfFields__c) and the teams validated automatically (a team that gains fields at the stage has to validate it, a team left without fields is validated). The share class goals come first: the phase save computes the completion rate from them.
    public static void resyncPhases(Map<Id, ProjectProduct__c> oldProjectProducts) {
        Map<Id, ProjectProduct__c> newProjectProducts = PMTMatrix.loadProjects(oldProjectProducts.keySet());

        List<ProjectShareclass__c> shareClasses = [SELECT Id FROM ProjectShareclass__c WHERE ProjectProduct__c IN :newProjectProducts.keySet()];
        if (!shareClasses.isEmpty()) {
            ProjectShareclassTriggerHandler.isUpdatingNbOfGoals = true; // as in the trigger: no copy back to the share class from its children
            try {
                ProjectShareclassHandler.nbOfFieldsGoal(new Map<Id, ProjectShareclass__c>(shareClasses));
            }
            finally {
                ProjectShareclassTriggerHandler.isUpdatingNbOfGoals = false;
            }
        }

        List<ProjectProductChild__c> phasesToUpdate = new List<ProjectProductChild__c>();
        for (ProjectProductChild__c phase : [SELECT Id, Name, ProjectProductParent__c, TECH_TeamValidation__c, fundNbOfFields__c
                                             FROM ProjectProductChild__c
                                             WHERE ProjectProductParent__c IN :newProjectProducts.keySet() AND Name != 'Design' AND Status__c != 'Completed']) {
            ProjectProduct__c oldProject = oldProjectProducts.get(phase.ProjectProductParent__c);
            PMTMatrix newMatrix = PMTMatrix.get().forConditions(newProjectProducts.get(oldProject.Id));
            PMTMatrix oldMatrix = PMTMatrix.get().forConditions(oldProject);
            Boolean shareClassCreation = oldProject.RecordTypeId == shareClassCreationRecordTypeId;

            Set<String> validatedTeams = ProjectProductSetupHandlerUtilities.splitMultiPicklist(phase.TECH_TeamValidation__c);
            for (PMTMatrix.Team team : newMatrix.getValidationTeams()) {
                Boolean hadNoFields = hasNoFieldsToValidate(oldMatrix.getRule(team.name, phase.Name), shareClassCreation);
                Boolean hasNoFields = hasNoFieldsToValidate(newMatrix.getRule(team.name, phase.Name), shareClassCreation);
                if (hadNoFields && !hasNoFields) validatedTeams.remove(team.key);
                else if (!hadNoFields && hasNoFields) validatedTeams.add(team.key);
            }

            String teamValidation = String.join(new List<String>(validatedTeams), ';');
            Integer nbOfFields = newMatrix.getRequiredFieldsByStage(true).get(phase.Name)?.size() ?? 0;
            if (teamValidation == (phase.TECH_TeamValidation__c ?? '') && nbOfFields == phase.fundNbOfFields__c) continue;

            phase.TECH_TeamValidation__c = teamValidation;
            phase.fundNbOfFields__c = nbOfFields;
            phasesToUpdate.add(phase);
        }

        if (phasesToUpdate.isEmpty()) return;

        ProjectProductChildTriggerHandler.isSyncingTeamValidation = true;
        try {
            update phasesToUpdate;
        }
        finally {
            ProjectProductChildTriggerHandler.isSyncingTeamValidation = false;
        }
    }

    // A team is validated automatically at a stage where it has no field (Share Class creation: no Share Class field).
    private static Boolean hasNoFieldsToValidate(PMTMatrix.FieldRule rule, Boolean shareClassCreation) {
        return shareClassCreation ? rule.getAllShareClass().isEmpty() : rule.isEmpty();
    }

    public void createProjectProduct(List<ProjectProduct__c> newProjectProducts) {
        if (newProjectProducts.isEmpty()) return;

        // FIX-20178: no PMT stage configured, no project structure to create
        if (PMTMatrix.get().stages.isEmpty()) return;

        // Prepare all related records
        List<RoadToMarket__c> mainRoads = new List<RoadToMarket__c>();
        Map<Id, RoadToMarket__c> projectProductToMainRoadMap = new Map<Id, RoadToMarket__c>();

        for (ProjectProduct__c product : newProjectProducts) {
            RoadToMarket__c mainRoad = new RoadToMarket__c(Name = 'Road To Market ' + product.Name, Parent_Project__c = product.Id, Tech_Type__c = 'Parent');
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
                ProjectProduct__c updProduct = new ProjectProduct__c();
                updProduct.RoadToMarket__c = insertedRoad.Id;
                updProduct.Id = product.Id;
                productsToUpdate.add(updProduct);
            }
        }

        update productsToUpdate;
        // Prepare children and road to markets
        List<ProjectProductChild__c> allChildren = new List<ProjectProductChild__c>();
        List<RoadToMarket__c> allOtherRoads = new List<RoadToMarket__c>();

        for (ProjectProduct__c product : newProjectProducts) {
            List<ProjectProductChild__c> children = createProjectProductChildren(product);
            if (!children.isEmpty()) allChildren.addAll(children);

            RoadToMarket__c mainRoad = projectProductToMainRoadMap.get(product.Id);
            List<RoadToMarket__c> otherRoads = createRoadToMarkets(product, mainRoad.Id);
            if (!otherRoads.isEmpty()) allOtherRoads.addAll(otherRoads);
        }

        if (!allChildren.isEmpty()) insert allChildren;

        if (!allOtherRoads.isEmpty()) insert allOtherRoads;
    }

    public static void setProjectName(List<ProjectProduct__c> newProjectProducts) {
        Set<Id> productIds = new Set<Id>();
        for (ProjectProduct__c target : newProjectProducts) {
            if (target.Product__c != null) productIds.add(target.Product__c);

            //IF shareClassCreationRecordTypeIde donotprocess = true
            if (target.RecordTypeId == shareClassCreationRecordTypeId) target.TECH_DoNotProcess__c = true;
        }
    }

    public static void updatePPName(List<ProjectProduct__c> newProjectProducts) {
        List<ProjectProduct__c> ppToUpdate = new List<ProjectProduct__c>();

        for (ProjectProduct__c target : newProjectProducts) {
            if (target.RecordTypeId == fundCreationRecordTypeId && target.Product__c == null) {
                ProjectProduct__c updatedRecord = new ProjectProduct__c(
           Id = target.Id,
                    tech_ByPassVRname__c = true,
           Name = 'Product Creation' + ' - ' + target.Name + ' - ' + Date.today().format()
       );

                ppToUpdate.add(updatedRecord);
            }
        }
        if (!ppToUpdate.isEmpty()) update ppToUpdate;
    }

    public static void cloneFund(List<ProjectProduct__c> newProjectProducts) {
        Set<Id> productIds = new Set<Id>();
        for (ProjectProduct__c target : newProjectProducts) {
            if (target.RecordTypeId == fundModificationRecordTypeId || target.RecordTypeId == shareClassCreationRecordTypeId || target.RecordTypeId == fundCreationRecordTypeId) if (target.Product__c != null) productIds.add(target.Product__c);
            //IF shareClassCreationRecordTypeIde donotprocess = true
            if (target.RecordTypeId == shareClassCreationRecordTypeId) target.TECH_DoNotProcess__c = true;
        }
        if (!productIds.isEmpty()) {
            // Query all related Productc records
            Map<Id, SObject> sourceRecords = new Map<Id, SObject>();
            try {
                for (SObject prod : Database.query('SELECT ' + RecordCloneHelper.getAllFieldNames('Product__c') + ' FROM Product__c WHERE Id IN :productIds')) {
                    sourceRecords.put((Id)prod.get('Id'), prod);
                }
            }
            catch (Exception e) {
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

                        if (target.RecordTypeId == shareClassCreationRecordTypeId) target.InternalShortName__c = (String)sourceRecords.get(target.Product__c).get('InternalShortName__c');
                    }
                    catch (Exception e) {
                        target.addError('Error cloning record: ' + e.getMessage());
                    }
                }
                else {
                    target.addError('No matching Product__c record found for cloning.');
                }
            }
        }
    }

    private List<ProjectProductChild__c> createProjectProductChildren(ProjectProduct__c projectProduct) {
        // FIX-20178: stages (order and duration), required fields and teams without fields come from the PMT matrix (US-20194: according to the project's conditions)
        PMTMatrix matrix = PMTMatrix.get().forConditions(projectProduct);

        Integer nbOfFields = 0;
        Map<String, List<String>> fieldListByStage = matrix.getRequiredFieldsByStage(true);

        // Every validation team (Product Strategy and IS included), validated upfront on modification projects
        String allTeamsValidated = String.join(matrix.getValidationTeamKeys(), ';');

        List<ProjectProductChild__c> projectProductChildren = new List<ProjectProductChild__c>();

        if (projectProduct.ProjectStartDate__c == null) throw new IllegalArgumentException('La date de début du projet doit être spécifiée.');

        Date currentStartDate = projectProduct.ProjectStartDate__c;
        Date currentEndDate;
        Integer daysToAdd;

        Map<String, List<String>> teamNoFieldsByStep = matrix.getTeamsWithoutFieldsByStage();

        for (PMTMatrix.Stage stage : matrix.stages) {
            if (projectProduct.RecordTypeId == fundModificationRecordTypeId) {
                daysToAdd = 30;
            }
            else {
                daysToAdd = stage.durationDays;
            }
            currentEndDate = currentStartDate.addDays(daysToAdd);

            List<String> teamswithNofields = teamNoFieldsByStep.get(stage.name);
            ProjectProductChild__c child;

            if (stage.name != 'Design') {
                nbOfFields = fieldListByStage.get(stage.name)?.size() ?? 0;
                child = ProjectProductSetupHandlerUtilities.createProjectProductChild(stage.name, projectProduct.Id, currentStartDate, currentEndDate, teamswithNofields, nbOfFields);

                if (projectProduct.RecordTypeId == fundModificationRecordTypeId) {
                    child.tech_teamvalidation__c = allTeamsValidated;
                    child.CompletionRateStep__c = 100;
                }
            }
            else {
                child = ProjectProductSetupHandlerUtilities.createProjectProductChild(stage.name, projectProduct.Id, currentStartDate, currentEndDate, new List<String>(), 0);
                child.CompletionRateStep__c = 100;

                if (projectProduct.RecordTypeId == fundModificationRecordTypeId) child.tech_teamvalidation__c = allTeamsValidated;
            }

            projectProductChildren.add(child);
            currentStartDate = currentEndDate;
        }

        // 💡 APPEL NOUVELLE MÉTHODE POUR LA LOGIQUE SHARECLASS CREATION
        if (projectProduct.RecordTypeId == shareClassCreationRecordTypeId) handleShareclassCreationTeamValidation(projectProductChildren, matrix);

        return projectProductChildren;
    }

    // FIX-20178: validation teams and their Share Class fields per stage come from the PMT matrix of the project (US-20194: according to its conditions)
    private void handleShareclassCreationTeamValidation(List<ProjectProductChild__c> projectProductChildren, PMTMatrix matrix) {
        // Pour chaque étape (enfant) du projet
        for (ProjectProductChild__c child : projectProductChildren) {
            Set<String> currentTeams = new Set<String>();

            // Récupérer les équipes déjà présentes
            if (child.TECH_TeamValidation__c != null) currentTeams.addAll(child.TECH_TeamValidation__c.split(';'));

            // Étape actuelle (Design et Proposal partagent le type DesignAndProposal)
            String currentStep = child.Tech_Childtype__c;
            if (currentStep == 'DesignAndProposal') currentStep = 'Proposal';

            if (matrix.getStage(currentStep) != null) {
                // Vérification équipe par équipe : sans champ Share Class à cette étape, l'équipe est ajoutée à la multipicklist
                for (PMTMatrix.Team team : matrix.getValidationTeams()) {
                    if (hasNoFieldsToValidate(matrix.getRule(team.name, currentStep), true)) currentTeams.add(team.key);
                }
            }

            // Mise à jour de la multipicklist uniquement si des équipes sont ajoutées
            if (!currentTeams.isEmpty()) child.TECH_TeamValidation__c = String.join(new List<String>(currentTeams), ';');
        }
    }

    private List<RoadToMarket__c> createRoadToMarkets(ProjectProduct__c projectProduct, String mainRoadToMarketId) {
        List<RoadToMarket__c> l_roadToMarket = new List<RoadToMarket__c>();

        // Récupération de tous les enregistrements de la custom metadata
        for (RoadToMarketTask__mdt roadToMarketMdt : [SELECT MasterLabel, Name__c, Description__c, Team__c, Contributors__c, TeamOrder__c
                                                      FROM RoadToMarketTask__mdt ORDER BY TeamOrder__c, MasterLabel]) {
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
    public void updateProjectProductStatus(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        for (Id projectId : newProjectProduct.keySet()) {
            ProjectProduct__c oldProject = oldProjectProduct.get(projectId);
            ProjectProduct__c newProject = newProjectProduct.get(projectId);

            if (oldProject.ProjectStatus__c != newProject.ProjectStatus__c) {
                newProject.Tech_DateChangementStatus__c = Date.today(); //met à jour la date du changement de statut
            }
        }
    }

    public void updateProjectProductName(Map<Id, ProjectProduct__c> newProjectProduct, Map<Id, ProjectProduct__c> oldProjectProduct) {
        for (Id projectId : newProjectProduct.keySet()) {
            ProjectProduct__c oldProject = oldProjectProduct.get(projectId);
            ProjectProduct__c newProject = newProjectProduct.get(projectId);

            if (oldProject.InternalShortName__c != newProject.InternalShortName__c) {
                List<String> nameList = newProject.Name.split('-');
                newProject.Name = nameList[0] + ' - ' + newProject.InternalShortName__c + ' - ' + nameList[2]; //met à jour la date du changement de statut
            }
        }
    }

    public void getOwnersTeam(List<ProjectProduct__c> projectProduct) {
        // FIX-20178: owners from the PMT matrix - the team's default owner (PMTTeam__mdt), then the owner rules (PMTOwnerRule__mdt, e.g. Legal by LegalForm__c)
        PMTMatrix matrix = PMTMatrix.get();
        Map<String, Schema.SObjectField> projectFields = Schema.SObjectType.ProjectProduct__c.fields.getMap();

        // Affectation des propriétaires d'équipe (champ owner = clé de l'équipe + '__c', ex. ProductStrategy__c)
        for (ProjectProduct__c oProjectProduct : projectProduct) {
            // US-20120: Scope (PS/IS) is determined by the creating user's custom permission, not VehicleType__c
            oProjectProduct.Scope__c = FeatureManagement.checkPermission('PRPIS') ? 'IS' : 'PS';

            // Teams that don't apply to the Scope (IS on a PS project, and vice versa) get no owner
            Map<String, Id> ownerIdByTeam = matrix.forScope(oProjectProduct.Scope__c).getOwnerIdByTeam(oProjectProduct);
            for (PMTMatrix.Team team : matrix.teams) {
                String ownerField = team.key + '__c';
                if (projectFields.containsKey(ownerField)) oProjectProduct.put(ownerField, ownerIdByTeam.get(team.name));
            }
        }
    }

    public void createTaskList(List<ProjectProduct__c> projectProduct) {
        List<ProjectTask__c> taskList = new List<ProjectTask__c>();
        Id ControlId = Schema.SObjectType.ProjectTask__c.getRecordTypeInfosByDeveloperName().get('ControlTask').getRecordTypeId();
        Id TodoId = Schema.SObjectType.ProjectTask__c.getRecordTypeInfosByDeveloperName().get('TodoTask').getRecordTypeId();
        for (ProjectProduct__c pp : projectProduct) {
            if (pp.RecordTypeId == fundCreationRecordTypeId || pp.RecordTypeId == fundModificationRecordTypeId) {
                for (Task_List__mdt task_mdt : Task_List__mdt.getAll().values()) {
                    // US-20120: Control PS / Control IS task lists are mutually exclusive per project scope
                    if (task_mdt.Team__c == 'Control PS' && pp.Scope__c == 'IS') continue;
                    if (task_mdt.Team__c == 'Control IS' && pp.Scope__c != 'IS') continue;

                    ProjectTask__c task = new ProjectTask__c();
                    task.Product__c = pp.Id;
                    task.Description__c = task_mdt.Description__c;
                    task.Action_Comment__c = task_mdt.Comment__c;
                    task.Team__c = task_mdt.Team__c;
                    task.Type__c = task_mdt.Task_Type__c;
                    task.Order__c = task_mdt.Order__c;
                    task.RecordTypeId = task_mdt.Task_Type__c == 'Control' ? ControlId : TodoId;
                    taskList.add(task);
                }
            }
        }
        if (!taskList.isEmpty()) insert taskList;
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
                    if (!tempProjectUserMap.containsKey(cleaned)) tempProjectUserMap.put(cleaned, new Set<Id>());
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
                if (activeUserIds.contains(userId)) activeMembers.add(userId);
            }

            if (!activeMembers.isEmpty()) projectNameWithOwnersTeam.put(groupName, activeMembers);
        }

        // Création des groupes
        if (!projectNameWithOwnersTeam.isEmpty()) {
            List<Id> groupsId = ChatterGroupService.createGroupWithMembers(projectNameWithOwnersTeam, 'Description');
            ChatterGroupService.updateGroupMemberNotifications(groupsId, 'P');
        }
    }

    // US-20194: runs resyncPhases once the change of a condition field is committed (projects with their values before the change).
    public without sharing class ResyncConditionalValuesJob implements Queueable {
        private Map<Id, ProjectProduct__c> oldProjectProducts;

        public ResyncConditionalValuesJob(Map<Id, ProjectProduct__c> oldProjectProducts) {
            this.oldProjectProducts = oldProjectProducts;
        }

        public void execute(QueueableContext context) {
            resyncPhases(oldProjectProducts);
        }
    }
}