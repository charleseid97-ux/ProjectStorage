public class ProjectShareclassChildHandler {
    static final Id fundModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();  
    
    public static void calculNbOfFields(List<ProjectShareclassChild__c> m_newProjectShareclassChild) {
        
        // List<String> fieldList = new List<String>();
        List<String> parentShareClass = new List<String>();
        Map<Id, String> parentToFields = new Map<Id, String>();
        Map<Id, String> parentToRT = new Map<Id, String>();
        for (ProjectShareclassChild__c proj : m_newProjectShareclassChild) {
            proj.NbofFilledFields__c  = 0;
            parentShareClass.add(proj.ProjectShareclasses__c);
        }
        List<ProductProjectSettings__c> settings = [SELECT Stage__c, Team__c, RequiredFieldsShareClass__c FROM ProductProjectSettings__c WHERE ProjectType__c = 'Creation' ];
        for(ProjectShareclass__c proj : [SELECT id,Tech_FieldsToModify__c,Parent_Record_Type_Id__c FROM ProjectShareclass__c WHERE id IN :parentShareClass]){
            parentToFields.put(proj.Id, proj.Tech_FieldsToModify__c);
            parentToRT.put(proj.Id, proj.Parent_Record_Type_Id__c);
        }
            for (ProjectShareclassChild__c shareClass : m_newProjectShareclassChild) {
                List<String> fieldList = new List<String>();

                for (ProductProjectSettings__c setting : settings) {

                String shareClassChildType = shareClass.TECH_Childtype__c;

                if(shareClass.TECH_Childtype__c =='DesignAndProposal'){
                    shareClassChildType = 'Proposal';
                }
                if(shareClassChildType == setting.Stage__c) {
                    if (setting.RequiredFieldsShareClass__c != null) {
                        if(parentToRT.get(shareClass.ProjectShareclasses__c) ==fundModificationRecordTypeId){

                            if(parentToFields.get(shareClass.ProjectShareclasses__c) != null){
                                for (String str : parentToFields.get(shareClass.ProjectShareclasses__c).split(';')) {
                                    if(setting.RequiredFieldsShareClass__c.split(';').contains(str)){
                                        fieldList.add(str);
                                    }
                                }
                            }

                        } else {
                            fieldList.addAll(setting.RequiredFieldsShareClass__c.split(';'));
                        }
                        System.debug('Stage : '+shareClassChildType+' have Field List: ' + fieldList);
                        shareClass.NbofFilledFields__c  = ProjectProductSetupHandlerUtilities.countFilledFields(shareClass,fieldList);

                    }
                }
            }
        }
    }
    
    public static void updateShareclassParent(Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild,
                                          Map<Id, ProjectShareclassChild__c> m_oldProjectShareclassChild) {
        
        if(ProjectShareclassTriggerHandler.isUpdatingNbOfGoals){
            return;
        }

        Set<Id> parentIds = new Set<Id>();
        
        for (ProjectShareclassChild__c newChild : m_newProjectShareclassChild.values()) {
            if (newChild.ProjectShareclasses__c != null) {
                parentIds.add(newChild.ProjectShareclasses__c);
            }
        }
    
        if (parentIds.isEmpty()) return;
    
        // Récupération des parents existants
        Map<Id, ProjectShareclass__c> parentRecords = new Map<Id, ProjectShareclass__c>(
            [SELECT Id FROM ProjectShareclass__c WHERE Id IN :parentIds]
        );
        if (parentRecords.isEmpty()) return;
    
        Set<String> excludedFields = new Set<String>{
            'id', 'createddate', 'createdbyid', 'lastmodifieddate',
            'lastmodifiedbyid', 'systemmodstamp', 'ownerid',
            'lastactivitydate', 'recordtypeid'
        };
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
    
                if (newValue != oldValue && (newValue == null || !newValue.equals(oldValue))) {
                    parentToUpdate.put(fieldName, newValue);
                }
            }
        }
    
        if (!parentsToUpdate.isEmpty()) {
            update parentsToUpdate.values();
        }
    }
 
    public static void lockRecordShareClassChild(Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild, Map<Id, ProjectShareclassChild__c> m_oldProjectShareclassChild) {
        List<ProjectShareclassChild__c> newList = new List<ProjectShareclassChild__c>(m_newProjectShareclassChild.values());
        List<ProjectShareclassChild__c> oldList = new List<ProjectShareclassChild__c>(m_oldProjectShareclassChild.values());
 
        if (!newList.isEmpty() && !oldList.isEmpty()) {
            ProjectChildTeamValidationController.lockRecordShareClassChild(newList[0], oldList[0]);
        }
    }
 
 
    public static void cloneParentShareclass(List<ProjectShareclassChild__c> newProjectShareclassChild) {
        Set<Id> shareClassesIds = new Set<Id>();
        for (ProjectShareclassChild__c target : newProjectShareclassChild) {
            if(target.ProjectShareclasses__c != null ){
                shareClassesIds.add(target.ProjectShareclasses__c);
            }
            
        }
    
        // Query all related Shareclass records
        if (!shareClassesIds.isEmpty()) {
            Map<Id, SObject> sourceRecords = new Map<Id, SObject>();
 
            try {
                for (SObject sc : Database.query('SELECT ' + RecordCloneHelper.getAllFieldNames('ProjectShareclass__c') + ' FROM ProjectShareclass__c WHERE Id IN :shareClassesIds')) {
                    sourceRecords.put((Id)sc.get('Id'), sc);
                }
            } catch (Exception e) {
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
                    } catch (Exception e) {
                        target.addError('Error cloning record: ' + e.getMessage());
                    }
                } else {
                    target.addError('No matching Parent record found for cloning.');
                }
            }
        }
    }

    private static Boolean isRunning = false;

    public static void updateTaxFields(
            Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild,
            Map<Id, ProjectShareclassChild__c> m_oldProjectShareclassChild
        ){
            if (isRunning) return;
            isRunning = true;

            try {
                String BE_TIS = 'BE TIS';
                String BE_ASSET_TEST = 'BE Asset Test';

                for (ProjectShareclassChild__c newRec : m_newProjectShareclassChild.values()) {

                    Set<String> valuesSet = new Set<String>();

                    if (!String.isBlank(newRec.TaxTransparency__c)) {
                        valuesSet.addAll(newRec.TaxTransparency__c.split(';'));
                    }

                    Boolean hasBeTis = valuesSet.contains(BE_TIS);
                    Boolean hasBeAssetTest = valuesSet.contains(BE_ASSET_TEST);
                    system.debug('hasBeTis: ' + hasBeTis + ', hasBeAssetTest: ' + hasBeAssetTest);
                    if (hasBeTis && !hasBeAssetTest) {
                        valuesSet.add(BE_ASSET_TEST);
                    } else if (hasBeAssetTest && !hasBeTis) {
                        valuesSet.add(BE_TIS);
                    }

                    newRec.TaxTransparency__c = String.join(new List<String>(valuesSet), ';');
                }

            } finally {
                isRunning = false;
            }
        }
    

    public static void validateBelgiumSimulatorOnProject(
        Map<Id, ProjectShareclassChild__c> m_newProjectShareclassChild,
        Map<Id, ProjectShareclassChild__c> m_oldProjectShareclassChild
    ) {
        if (m_newProjectShareclassChild == null || m_newProjectShareclassChild.isEmpty()) {
            return;
        }

        String BELGIUM_SIMULATOR = 'Belgium Simulator';
        String ACCUMULATING = 'Accumulating';
        String FCP = 'FCP';
        String BELGIUM = 'Belgium';

        for (ProjectShareclassChild__c rec : m_newProjectShareclassChild.values()) {
            Set<String> newTaxValues = new Set<String>();
            if (!String.isBlank(rec.TaxTransparency__c)) {
                for (String val : rec.TaxTransparency__c.split(';')) {
                    if (!String.isBlank(val)) {
                        newTaxValues.add(val.trim());
                    }
                }
            }

            Boolean shouldValidate = false;

            ProjectShareclassChild__c oldRec = m_oldProjectShareclassChild.get(rec.Id);

            Set<String> oldTaxValues = new Set<String>();
            if (!String.isBlank(oldRec.TaxTransparency__c)) {
                for (String val : oldRec.TaxTransparency__c.split(';')) {
                    if (!String.isBlank(val)) {
                        oldTaxValues.add(val.trim());
                    }
                }
            }

            shouldValidate =
                newTaxValues.contains(BELGIUM_SIMULATOR) &&
                !oldTaxValues.contains(BELGIUM_SIMULATOR);
            

            if (!shouldValidate) {
                continue;
            }

            Set<String> countryValues = new Set<String>();
            if (!String.isBlank(rec.CountryRegNeeded__c)) {
                for (String val : rec.CountryRegNeeded__c.split(';')) {
                    if (!String.isBlank(val)) {
                        countryValues.add(val.trim());
                    }
                }
            }

            Boolean isAccumulating = rec.DividendPolicy__c == ACCUMULATING;
            Boolean isFcp = rec.LegalForm__c == FCP;
            Boolean isRegisteredInBe = countryValues.contains(BELGIUM);

            if (!(isAccumulating && isFcp && isRegisteredInBe)) {
                rec.addError(
                    'Belgium Simulator can only be added for Acc share classes of FCP funds registered in Belgium.'
                );
            }
        }
    }
}