/** ──────────────────────────────────────
 * @description Trigger logic for Milestone__c on PMT projects: link to the matching stage, SPC Final block, project
 *                  launch date, owner reassignment when SPC Final is completed on a modification project, and ESG
 *                  phase validation.
 *              At SPC Final, the teams owning the modified fields get their owner from the PMT matrix (PMTMatrix,
 *                  FIX-20178: default owner then owner rules), the other teams are emptied, the Scope team keeps its owner.
 * @lastModifiedBy Charles EID   [09-10-26]
 * @testClass Test_MilestoneTrigger
 * @coverage 99%   [09-10-26]
 ────────────────────────────────────── */
public class MilestoneHandler {

    // Constants to avoid duplicated literals (fix Sonar CODE_SMELL)
    private static final String SPC_FINAL = 'SPC Final';
    private static final String STATUS_COMPLETED = 'Completed';

    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
    static final Id fundCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();  

    public static void linkStepToMilestone (Milestone__c  milestone){
        List<ProjectProductChild__c> steps = [SELECT Id, Name, StartDate__c, EndDate__c, ProjectProductParent__c FROM ProjectProductChild__c WHERE ProjectProductParent__c = :milestone.Project_product__c];
        for(ProjectProductChild__c step: steps){
            if(step.StartDate__c <= milestone.StartDate__c && step.EndDate__c >= milestone.StartDate__c) {
                milestone.Project_Product_Child__c = step.id;
            }
        }
    }

    public static void blockSPCFinal(Map<Id, Milestone__c> newMilestones, Map<Id, Milestone__c> oldMilestones){
        Set<Id> setProjectProductId = new Set<Id>();
        for (Milestone__c milestone : newMilestones.values()) {
            if (milestone.Name == SPC_FINAL && milestone.Status__c != oldMilestones.get(milestone.Id).Status__c && milestone.Status__c == STATUS_COMPLETED) {
                setProjectProductId.add(milestone.Project_Product__c);
            }
        }
        
        if (setProjectProductId.isEmpty()) return;
        
        Map<Id, ProjectProduct__c> ppById = new Map<Id, ProjectProduct__c>([SELECT Id, LettreRequise__c FROM ProjectProduct__c WHERE Id IN :setProjectProductId AND RecordTypeId =: fundModificationRecordTypeId]); // 2) Charger les ProjectProduct + construire une map

        // 3) Bloquer les milestones non conformes
        for (Milestone__c milestone : newMilestones.values()) {
            Milestone__c oldMs = oldMilestones.get(milestone.Id);

            Boolean isSpcFinalToCompleted = milestone.Name == SPC_FINAL && milestone.Project_Product__c != null && milestone.Status__c == STATUS_COMPLETED && oldMs != null && milestone.Status__c != oldMs.Status__c;
            if (!isSpcFinalToCompleted) continue;

            ProjectProduct__c pp = ppById.get(milestone.Project_Product__c);
            if (pp != null && String.isBlank(String.valueOf(pp.LettreRequise__c))) { // Si PP introuvable ou LettreRequise__c non renseigné => blocage
                milestone.addError(System.Label.PMT_SPCFinalNoticeRequired);
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
            if (milestone.Name == SPC_FINAL && milestone.Status__c != oldMilestones.get(milestone.Id).Status__c && milestone.Status__c == STATUS_COMPLETED) {
                setProjectProductId.add(milestone.Project_Product__c);
            }
        }
        String fieldsToModifyProduct = '';
        String fieldsToModifySC = '';
        PMTMatrix matrix = PMTMatrix.get(); // FIX-20178: teams owning the modified fields and their owners come from the PMT matrix (default owner, then owner rules such as Legal by LegalForm__c)
        Map<String, Schema.SObjectField> projectFields = Schema.SObjectType.ProjectProduct__c.fields.getMap();
        Set<String> ownerRuleFields = matrix.getOwnerRuleFields();
        String ownerRuleFieldList = ownerRuleFields.isEmpty() ? '' : ', ' + String.join(new List<String>(ownerRuleFields), ', ');
        List<ProjectProduct__c> pp = Database.query('SELECT Id, TECH_FieldsToModify__c, Scope__c' + ownerRuleFieldList + ', (SELECT Id, TECH_FieldsToModify__c FROM ProjectShareclasses__r)'
                                                    + ' FROM ProjectProduct__c WHERE Id IN :setProjectProductId AND RecordTypeId = :fundModificationRecordTypeId');

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
            // Teams owning a modified field (exact match), in the PMT matrix restricted to the project's Scope
            PMTMatrix scopedMatrix = matrix.forScope(ProjectProductSetupHandlerUtilities.normalizeScope(projectProduct.Scope__c));
            Set<String> teamsWithModifiedFields = new Set<String>();
            for(String field : fieldsToModifyProduct.split(';')) {
                for(PMTMatrix.FieldRule rule : scopedMatrix.rules) {
                    if(rule.getAllFund().contains(field)) teamsWithModifiedFields.add(rule.team);
                }
            }
            if(!String.isEmpty(fieldsToModifySC)){
                for(String field : fieldsToModifySC.split(';')) {
                    for(PMTMatrix.FieldRule rule : scopedMatrix.rules) {
                        if(rule.getAllShareClass().contains(field)) teamsWithModifiedFields.add(rule.team);
                    }
                }
            }
            fieldsToModifyProduct = '';
            fieldsToModifySC = '';

            // A team owning a modified field gets its owner, the other teams are emptied. The Scope teams (Product Strategy / IS, PMTTeam__mdt.Scope__c) lead the project and keep their owner.
            Map<String, Id> ownerIdByTeam = scopedMatrix.getOwnerIdByTeam(projectProduct);
            for (PMTMatrix.Team team : matrix.teams) {
                String ownerField = team.key + '__c';
                if (String.isNotBlank(team.scope) || !projectFields.containsKey(ownerField)) continue;
                projectProduct.put(ownerField, teamsWithModifiedFields.contains(team.name) ? ownerIdByTeam.get(team.name) : null);
            }
            listProjectProductToUpdate.add(projectProduct);
        }

        if(listProjectProductToUpdate.size()>0){
            update listProjectProductToUpdate;
        }
    }

    public static void validatePhasesESG(Map<Id, Milestone__c> newMilestones, Map<Id, Milestone__c> oldMilestones){
        Set<Id> projectIds = new Set<Id>();
        for (Milestone__c milestone : newMilestones.values()) {
            if(milestone.Name == SPC_FINAL && milestone.Status__c != oldMilestones.get(milestone.Id).Status__c && milestone.Status__c == STATUS_COMPLETED) {
                projectIds.add(milestone.Project_Product__c);
            }
        }
        List<ProjectProductChild__c> children = [SELECT Id, ProjectProductParent__c, TECH_TeamValidation__c 
                                                 FROM ProjectProductChild__c 
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