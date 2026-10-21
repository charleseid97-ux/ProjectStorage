/** ──────────────────────────────────────
 * @description Trigger logic for ProjectShareclassChild__c (Share Class stages of a PMT project): filled fields count
 *                  against the stage's required Share Class fields (PMT matrix, FIX-20178; US-20194: according to the conditions
 *                  of the project and of the share class), parent Share Class updates, record lock, cloning from the parent Share Class and tax fields.
 * @lastModifiedBy Charles EID   [21-10-26]
 * @testClass Test_ProjectShareclassTrigger
 * @coverage 93%   [21-10-26]
 ────────────────────────────────────── */
public class ProjectShareclassChildHandler {

    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
    private static Boolean isRunning = false;

    public static void calculNbOfFields(List<ProjectShareclassChild__c> m_newProjectShareclassChild) {
        List<String> parentShareClass = new List<String>();
        Map<Id, String> parentToFields = new Map<Id, String>();
        Map<Id, String> parentToRT = new Map<Id, String>();
        Map<Id, Id> parentToProject = new Map<Id, Id>();
        for (ProjectShareclassChild__c proj : m_newProjectShareclassChild) {
            proj.NbofFilledFields__c = 0;
            parentShareClass.add(proj.ProjectShareclasses__c);
        }
        for (ProjectShareclass__c proj : [SELECT Id, ProjectProduct__c, Tech_FieldsToModify__c, Parent_Record_Type_Id__c
                                          FROM ProjectShareclass__c
                                          WHERE Id IN :parentShareClass]) {
            parentToFields.put(proj.Id, proj.Tech_FieldsToModify__c);
            parentToRT.put(proj.Id, proj.Parent_Record_Type_Id__c);
            parentToProject.put(proj.Id, proj.ProjectProduct__c);
        }
        Map<Id, ProjectProduct__c> projectById = PMTMatrix.loadProjects(new Set<Id>(parentToProject.values()));

        for (ProjectShareclassChild__c shareClass : m_newProjectShareclassChild) {
            String shareClassChildType = shareClass.TECH_Childtype__c;

            if (shareClass.TECH_Childtype__c == 'DesignAndProposal') shareClassChildType = 'Proposal';
            // FIX-20178 / US-20194: champs Share Class requis de l'étape, depuis la matrice PMT selon les conditions du projet et de la share class
            PMTMatrix matrix = PMTMatrix.get().forConditions(projectById.get(parentToProject.get(shareClass.ProjectShareclasses__c))).forShareClass(shareClass.ProjectShareclasses__c);
            List<String> stageFields = matrix.getRequiredFieldsByStage(false).get(shareClassChildType);
            if (stageFields == null || stageFields.isEmpty()) continue;

            List<String> fieldList = new List<String>();
            if (parentToRT.get(shareClass.ProjectShareclasses__c) == fundModificationRecordTypeId) {
                if (parentToFields.get(shareClass.ProjectShareclasses__c) != null) {
                    for (String str : parentToFields.get(shareClass.ProjectShareclasses__c).split(';')) {
                        if (stageFields.contains(str)) fieldList.add(str);
                    }
                }
            }
            else {
                fieldList.addAll(stageFields);
            }
            shareClass.NbofFilledFields__c = ProjectProductSetupHandlerUtilities.countFilledFields(shareClass, fieldList);
        }
    }

    public static void updateShareclassParent(Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild, Map<Id, ProjectShareclassChild__c> m_oldProjectShareclassChild) {
        if (ProjectShareclassTriggerHandler.isUpdatingNbOfGoals) return;

        Set<Id> parentIds = new Set<Id>();
        for (ProjectShareclassChild__c newChild : m_newProjectShareclassChild.values()) {
            if (newChild.ProjectShareclasses__c != null) parentIds.add(newChild.ProjectShareclasses__c);
        }

        if (parentIds.isEmpty()) return;

        // Récupération des parents existants
        Map<Id, ProjectShareclass__c> parentRecords = new Map<Id, ProjectShareclass__c>([SELECT Id FROM ProjectShareclass__c WHERE Id IN :parentIds]);
        if (parentRecords.isEmpty()) return;

        Set<String> excludedFields = new Set<String>{'id', 'createddate', 'createdbyid', 'lastmodifieddate', 'lastmodifiedbyid', 'systemmodstamp', 'ownerid', 'lastactivitydate', 'recordtypeid'};
        Map<String, Schema.SObjectField> childFields = ProjectShareclassChild__c.SObjectType.getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> parentFields = ProjectShareclass__c.SObjectType.getDescribe().fields.getMap();

        Map<Id, ProjectShareclass__c> parentsToUpdate = new Map<Id, ProjectShareclass__c>();

        for (Id childId : m_newProjectShareclassChild.keySet()) {
            ProjectShareclassChild__c newChild = m_newProjectShareclassChild.get(childId);
            ProjectShareclassChild__c oldChild = m_oldProjectShareclassChild.get(childId);
            Id parentId = newChild.ProjectShareclasses__c;

            if (!parentRecords.containsKey(parentId)) continue;

            if (!parentsToUpdate.containsKey(parentId)) {
                ProjectShareclass__c parentClone = parentRecords.get(parentId).clone(false, true, false, false);
                parentClone.Id = parentId; // Réassignation correcte de l'Id
                parentsToUpdate.put(parentId, parentClone);
            }

            ProjectShareclass__c parentToUpdate = parentsToUpdate.get(parentId);

            for (String fieldName : childFields.keySet()) {
                if (excludedFields.contains(fieldName) || !parentFields.containsKey(fieldName)) continue;

                Object newValue = newChild.get(fieldName);
                Object oldValue = (oldChild != null) ? oldChild.get(fieldName) : null;

                if (newValue != oldValue && (newValue == null || !newValue.equals(oldValue))) parentToUpdate.put(fieldName, newValue);
            }
        }

        if (!parentsToUpdate.isEmpty()) update parentsToUpdate.values();
    }

    public static void lockRecordShareClassChild(Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild, Map<Id, ProjectShareclassChild__c> m_oldProjectShareclassChild) {
        List<ProjectShareclassChild__c> newList = new List<ProjectShareclassChild__c>(m_newProjectShareclassChild.values());
        List<ProjectShareclassChild__c> oldList = new List<ProjectShareclassChild__c>(m_oldProjectShareclassChild.values());

        if (!newList.isEmpty() && !oldList.isEmpty()) ProjectChildTeamValidationController.lockRecordShareClassChild(newList[0], oldList[0]);
    }

    public static void cloneParentShareclass(List<ProjectShareclassChild__c> newProjectShareclassChild) {
        Set<Id> shareClassesIds = new Set<Id>();
        for (ProjectShareclassChild__c target : newProjectShareclassChild) {
            if (target.ProjectShareclasses__c != null) shareClassesIds.add(target.ProjectShareclasses__c);
        }

        // Query all related Shareclass records
        if (!shareClassesIds.isEmpty()) {
            Map<Id, SObject> sourceRecords = new Map<Id, SObject>();

            try {
                for (SObject sc : Database.query('SELECT ' + RecordCloneHelper.getAllFieldNames('ProjectShareclass__c') + ' FROM ProjectShareclass__c WHERE Id IN :shareClassesIds')) {
                    sourceRecords.put((Id)sc.get('Id'), sc);
                }
            }
            catch (Exception e) {
                for (ProjectShareclassChild__c target : newProjectShareclassChild) {
                    target.addError('Error querying source records: ' + e.getMessage());
                }
                return; // Stop further processing
            }

            // Clone fields
            for (ProjectShareclassChild__c target : newProjectShareclassChild) {
                if (sourceRecords.containsKey(target.ProjectShareclasses__c)) {
                    try {
                        RecordCloneHelper.cloneRecordFields(sourceRecords.get(target.ProjectShareclasses__c), target);
                    }
                    catch (Exception e) {
                        target.addError('Error cloning record: ' + e.getMessage());
                    }
                }
                else {
                    target.addError('No matching Parent record found for cloning.');
                }
            }
        }
    }

    public static void updateTaxFields(Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild, Map<Id, ProjectShareclassChild__c> m_oldProjectShareclassChild) {
        if (isRunning) return;
        isRunning = true;

        try {
            String BE_TIS = 'BE TIS';
            String BE_ASSET_TEST = 'BE Asset Test';

            for (ProjectShareclassChild__c newRec : m_newProjectShareclassChild.values()) {
                Set<String> valuesSet = new Set<String>();
                if (!String.isBlank(newRec.TaxTransparency__c)) valuesSet.addAll(newRec.TaxTransparency__c.split(';'));

                // Preserve only the Tax Transparency values explicitly selected by the user
                Boolean hasBeTis = valuesSet.contains(BE_TIS);
                Boolean hasBeAssetTest = valuesSet.contains(BE_ASSET_TEST);

                newRec.TaxTransparency__c = String.join(new List<String>(valuesSet), ';'); // Save the current selection without automatically adding the other Belgium value
            }
        }
        finally {
            isRunning = false;
        }
    }
}