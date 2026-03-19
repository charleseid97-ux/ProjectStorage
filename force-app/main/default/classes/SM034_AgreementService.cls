/**
* @description       : 
* @author            : admin_ngoolamnabee
* @last modified on  : 11-07-2024
* @last modified by  : Khadija EL GDAOUNI
**/

public without sharing class SM034_AgreementService {
    
    public static void handleRollupCalculate(Map<Id, Convention__c> newItems, Map<Id, Convention__c> oldRecordsMap) {
        Set<Id> accountIds = new Set<Id>();
        
        if (oldRecordsMap == null) {
            // Cas d'insertion
            for (Convention__c newAgreement : newItems.values()) {
                if (newAgreement.Company__c != null && (newAgreement.YTDNetFlows__c!= null || newAgreement.AUM_To_Date__c!= null)) {
                    accountIds.add(newAgreement.Company__c);
                }
            }
        } else {
            // Cas de mise à jour
            for (Convention__c newAgreement : newItems.values()) {
                Convention__c oldAgreement = oldRecordsMap.get(newAgreement.Id);
                
                if (isRelevantFieldChanged(newAgreement, oldAgreement)) {
                    if (newAgreement.Company__c != null) {
                        accountIds.add(newAgreement.Company__c);
                    }
                    if (oldAgreement.Company__c != null && newAgreement.Company__c != oldAgreement.Company__c) {
                        accountIds.add(oldAgreement.Company__c);
                    }
                }
            }
        }
        if(accountIds.size()>0){
            List<AggregateResult> results = [
                SELECT Company__c, SUM(YTDNetFlows__c) totalFlow, SUM(AUM_To_Date__c) totalAUM
                FROM Convention__c
                WHERE Company__c IN :accountIds
                GROUP BY Company__c
            ];
            List<Account> accountsToUpdate = new List<Account>();
            for (AggregateResult ar : results) {
                accountsToUpdate.add(new Account(
                    Id = (Id)ar.get('Company__c'),
                    YTDNetFlowsAgreement__c = (Decimal)ar.get('totalFlow'),
                    AUMToDateAgreement__c = (Decimal)ar.get('totalAUM')
                ));
            }
            
            if (!accountsToUpdate.isEmpty()) {
                update accountsToUpdate;
            }
        }
        
        
        
    }
    
    private static boolean isRelevantFieldChanged(Convention__c newAgreement, Convention__c oldAgreement) {
        return newAgreement.Company__c != oldAgreement.Company__c ||
            newAgreement.YTDNetFlows__c != oldAgreement.YTDNetFlows__c ||
            newAgreement.AUM_To_Date__c != oldAgreement.AUM_To_Date__c;
    }
    
    public static void handleBeforeInsert(List<Convention__c> newAgreements) {
        
        Map<String, String> BDRCRMEmails = new Map<String, String>();
        
        List<BDRCRMEmail__mdt> BDRCRMEmailList = [SELECT BusinessRegion__c,crmEmail__c FROM BDRCRMEmail__mdt];
        for (BDRCRMEmail__mdt BDRCRMEmailItem : BDRCRMEmailList ) {
            BDRCRMEmails.put(BDRCRMEmailItem.BusinessRegion__c, BDRCRMEmailItem.crmEmail__c);
        }
        
        Map<String, String> BDRHOCEmails = new Map<String, String>();
        
        List<BDRHOCEmail__mdt> BDRHOCEmailList = [SELECT BusinessRegion__c,hocEmail__c FROM BDRHOCEmail__mdt];
        for (BDRHOCEmail__mdt BDRHOCEmailItem : BDRHOCEmailList ) {
            BDRHOCEmails.put(BDRHOCEmailItem.BusinessRegion__c, BDRHOCEmailItem.hocEmail__c);
        }
        
        Grid__c zeroGrid = null;
        
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
        
        //get all current master agreements - to be used in code generation
        Map<Id, Convention__c> masterAgreements = new Map<Id, Convention__c>([SELECT Id, Code_Top_Level__c, Carmignac_Legal_Entity__c, conventionName__c FROM Convention__c WHERE Agreement_Type__c = 'Master']);
        Integer currentCodeTop = -1, currentCodeSub = -1;
        
        List<Id> accountIds = new List<Id>();
        
        for(Convention__c a : newAgreements) {
            accountIds.add(a.Company__c);
        }
        
        //all companies linked to the new agreements
        Map<Id, Account> companyMap = AgreementUtil.getAllLinkedAccounts(accountIds);
        
        for(Convention__c a : newAgreements) {
            
            String thisRecordTypeName = AgreementUtil.getKeyFromValue(agmRtMap, a.RecordTypeId);
            
            Account tmpAcc = companyMap.get(a.Company__c);
            
            if(a.RecordTypeId == AgreementUtil.REQ_RECTYPE_ID || a.RecordTypeId == AgreementUtil.INV_WITHRECTYPE_ID || a.RecordTypeId == AgreementUtil.TECH_RECTYPE_ID 
               || a.RecordTypeId == AgreementUtil.SUB_DISRECTYPE_ID || a.RecordTypeId == AgreementUtil.IS_RECTYPE_ID) {
                   AgreementUtil.validateCompanySnapshot(a, tmpAcc);
                   
                   AgreementUtil.snapCompanyToAgreement(a, tmpAcc);
                   
                   //Legal Entity = CG France if company BDR in France else CG Lux
                   //OVERRIDE Sub Agreement to Master Agreement Legal Entity
                   a.Carmignac_Legal_Entity__c = (a.MasterConvention__c != null) ? masterAgreements.get(a.MasterConvention__c).Carmignac_Legal_Entity__c : (tmpAcc.BusinessDevelopmentRegion__c == 'BP_FR') ? 'CGF' : 'CGL';
                   
                   //Set CRM Team Email based on the Business Development Region
                   a.CRM_Team_Email_Address__c = BDRCRMEmails.get(a.Business_Region__c);
                   //Set HOC Email based on the Business Development Region
                   a.HOC_Email_Address__c = BDRHOCEmails.get(a.Business_Region__c);
                   
                   //Set Grid Start Date to the Effective Date
                   a.Grid_Start_Date__c = a.EffectiveDate__c;
               }
            
            if(a.RecordTypeId == AgreementUtil.INV_WITHRECTYPE_ID || a.RecordTypeId == AgreementUtil.TECH_RECTYPE_ID) {
                if(zeroGrid == null) {
                    List<Grid__c> gridList = [SELECT Id, Name FROM Grid__c WHERE Name = '0%'];
                    if (gridList.size() > 0) {
                        zeroGrid = gridList[0];
                    }
                }
                
                if(zeroGrid != null) {
                    a.Grid__c = zeroGrid.Id;
                    a.Grid_Start_Date__c = system.today();
                    a.SignedDate__c = system.today();
                }
            }
            
            //Agreement Type based on MasterConvention being set
            //if(!thisRecordTypeName.equals('Technical_Agreement')) a.Agreement_Type__c = (a.MasterConvention__c == null) ? 'Master' : 'Standard';
            
            //Agreement Group based on Code Type
            a.Agreement_Group__c = (a.Code_Type__c == 'Institutional without Agreement' || a.Code_Type__c == 'Technical' || a.Code_Type__c == 'Reporting') ? 2 : 1;
            System.debug('//NGO a.Agreement_Type__c : ' + a);
            //commented by Nina 10-01
            if(!(a.RecordTypeId == AgreementUtil.IS_RECTYPE_ID)) {
                AgreementUtil.validateGRID(a);
                //Agreement code and increment generation
                AgreementUtil.agreementCodeGeneration(a, currentCodeTop, currentCodeSub, masterAgreements, thisRecordTypeName);
                currentCodeTop = Integer.valueOf(a.Code_Top_Level__c);
                currentCodeSub = Integer.valueOf(a.Code_Sub_Level__c);
                //Agreement name
                AgreementUtil.agreementNameGeneration(a, masterAgreements, tmpAcc);
                //AgreementUtil.validateUniqueCode(a); replaced by duplicate rule on agreement name
            }
            
            
        }
    }
    
    public static void createDefaultRebateContact(List<Convention__c> newAgreements) {
        
        Map<String, Id> agmRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Convention__c.SObjectType);
        List<Contact> defaultRebateContact = [SELECT Id, Name FROM Contact WHERE MOIS_Default_Contact__c = true];
        List<ConventionRelatedContact__c> rebateContactsToInsert = new List<ConventionRelatedContact__c>();
        
        //Map<Id, Convention__c> masterAgreements = new Map<Id, Convention__c>([SELECT Id, Code_Top_Level__c, Carmignac_Legal_Entity__c, conventionName__c, Company__c,
        //(SELECT Contact__c, Delivery_mode__c, Primary_Rebate_Contact__c, Role__c FROM ConventionRelatedContacts__r)
        //FROM Convention__c WHERE Agreement_Type__c = 'Master']);
        
        for(Convention__c agr : newAgreements) {
            String thisRecordTypeName = AgreementUtil.getKeyFromValue(agmRtMap, agr.RecordTypeId);
            if ((agr.RecordTypeId == AgreementUtil.INV_WITHRECTYPE_ID || agr.RecordTypeId == AgreementUtil.TECH_RECTYPE_ID) && defaultRebateContact.size() > 0) {
                rebateContactsToInsert.add(new ConventionRelatedContact__c(Convention__c = agr.Id,
                                                                           Contact__c = defaultRebateContact[0].Id,
                                                                           Delivery_mode__c = 'Email',
                                                                           Primary_Rebate_Contact__c = true,
                                                                           Role__c = 'Rebate/ IS Contact'));
            }
            //Code commented as there are no master agreement for Intermediary agreement even for standard Type
            /*else if (thisRecordTypeName == 'Request_Agreement' && agr.Agreement_Type__c == 'Standard') {
if(masterAgreements.get(agr.MasterConvention__c).ConventionRelatedContacts__r.size() > 0) {
for(ConventionRelatedContact__c rC : masterAgreements.get(agr.MasterConvention__c).ConventionRelatedContacts__r) {
rebateContactsToInsert.add(new ConventionRelatedContact__c(Convention__c = agr.Id,
Contact__c = rC.Contact__c,
Delivery_mode__c = rC.Delivery_mode__c,
Primary_Rebate_Contact__c = rC.Primary_Rebate_Contact__c,
Role__c = rC.Role__c));
}
}
}*/
        }
        
        if(rebateContactsToInsert.size() > 0) {
            insert rebateContactsToInsert;
        }
    }
    
    /**
* @author Noor
* @date 17/01/20212
* @description  Setting up the Carmignac Legal Entity Appointed Party Role
* @param newItems new created agreement
*/
    public static void createDefaultCarmignacAgreementRole(List<Convention__c> newItems){
        
        //Automated Role variables
        List<Agreement_Role__c> roles = new List<Agreement_Role__c>();
        
        Map<String, Global_Settings__mdt> settings = Utils.getGlobalSettings();
        
        Id CGL = settings.get('CARMIGNAC_GESTION_LUXEMBOURG').Value__c;
        Id CGF = settings.get('CARMIGNAC_GESTION').Value__c;
        
        for (Convention__c agr : newItems){
            if (agr.Carmignac_Legal_Entity__c == 'CGL' && CGL != null) {
                roles.add(new Agreement_Role__c(Role__c = 'Carmignac Entity', Agreement__c = agr.Id, Legal_Entity__c = CGL));
            }
            else if (agr.Carmignac_Legal_Entity__c == 'CGF' && CGF != null) {
                roles.add(new Agreement_Role__c(Role__c = 'Carmignac Entity', Agreement__c = agr.Id, Legal_Entity__c = CGF));
            }
        }
        
        if (!roles.isEmpty()) {
            insert roles;
        }
    }
    
    /*public static void createAgreementRoles(Map<Id, Convention__c> newItems) {

//Automated Role variables
List<Agreement_Role__c> roles = new List<Agreement_Role__c>();

Map<String, Global_Settings__mdt> settings = Utils.getGlobalSettings();
List<List<String>> autoAgreementRoleMapping = Utils.getAutoAgreementRoleMapping();

Id CGL = settings.get('CARMIGNAC_GESTION_LUXEMBOURG').Value__c;
Id CGF = settings.get('CARMIGNAC_GESTION').Value__c;

for (Convention__c agr : [SELECT Id, Code_Type__c, Company__r.LegalEntity__c, CurrencyIsoCode, Carmignac_Legal_Entity__c, RecordTypeId FROM Convention__c where id in :newItems.keySet()]) {

Agreement_Role__c agrRoleCarmignac = new Agreement_Role__c();
agrRoleCarmignac.Role__c = 'Carmignac Entity';
agrRoleCarmignac.Agreement__c = agr.Id;

if (agr.Carmignac_Legal_Entity__c == 'CGL' && CGL != null) {
agrRoleCarmignac.Legal_Entity__c = CGL;

}
else if (agr.Carmignac_Legal_Entity__c == 'CGF' && CGF != null) {
agrRoleCarmignac.Legal_Entity__c = CGF;
}

if (agrRoleCarmignac.Legal_Entity__c != null) {
roles.add(agrRoleCarmignac);
}

Agreement_Role__c agrRole = new Agreement_Role__c();
agrRole.Agreement__c = agr.Id;
agrRole.TECH_Agreement_CodeType__c = agr.Code_Type__c;
agrRole.CurrencyIsoCode = agr.CurrencyIsoCode;
agrRole.Legal_Entity__c = agr.Company__r.LegalEntity__c;

String recordTypeString = Schema.getGlobalDescribe().get('Convention__c').getDescribe().getRecordTypeInfosById().get(agr.RecordTypeId).getName();
for (List<String> mapping : autoAgreementRoleMapping) {
system.debug('Record Type String: ' + recordTypeString);
system.debug('Mapping code type: ' + mapping[1] + ' Mapping record type: ' + mapping[2] + ' Mapping role: ' + mapping[0]);
if (mapping[1].equals(agr.Code_Type__c) && mapping[2].equals(recordTypeString)) {
agrRole.Role__c = mapping[0];
break;
}
}

if (agrRole.Role__c != null && agrRole.Legal_Entity__c != agrRoleCarmignac.Legal_Entity__c && agrRole.Legal_Entity__c != null) {
roles.add(agrRole);
}
}

if (!roles.isEmpty()) {
insert roles;
}
}*/
    
    /**
* @author Noor
* @date 17/01/2022
* @description  Setting up the role if Legal Entity company match Agreement Company based on Code Type
*               For Sub-distributor via Platforms master Agreement Company is Used
*               The default role per code Type is stored in custom metadata Agreement_Role_Mapping__mdt
* 				Previously called on After Insert Agreement Trigger - Not used anymore since need has changed
* @param newItems new created agreement
*/
    public static void createDefaultLegalEntityAgreementRole(List<Convention__c> newItems){
        
        List<Agreement_Role__c> roles = new List<Agreement_Role__c>();
        Set<Id> companyIds = new Set<Id>();
        
        for (Convention__c agr : newItems) {
            companyIds.add(agr.Company__c);
            if (agr.MasterConvention__r.Company__c != null) {
                companyIds.add(agr.MasterConvention__r.Company__c);
            }
        }
        
        List<Convention__c> agreementsWithMaster = [SELECT Id, Code_Type__c, Company__c, MasterConvention__r.Company__c
                                                    FROM Convention__c WHERE Id IN : newItems];
        
        /*Map<Id, Legal_Entity__c> matchingLegalEntityByCompany = new Map<Id, Legal_Entity__c>();
for(Legal_Entity__c le : [SELECT Company__c, Id, Name FROM Legal_Entity__c WHERE Company__c IN : companyIds]) {
matchingLegalEntityByCompany.put(le.Company__c, le);
}*/
        Map<Id, Id> matchingLegalEntityByCompany = new Map<Id, Id>();
        for (Account acc : [SELECT Id, LegalEntity__c FROM Account where id in : companyIds AND LegalEntity__c != null]) {
            matchingLegalEntityByCompany.put(acc.Id, acc.LegalEntity__c);
        }
        
        for (Convention__c agr : agreementsWithMaster) {
            
            if (agr.Code_Type__c.equalsIgnoreCase('Sub-distributor via Platforms') && matchingLegalEntityByCompany.containsKey(agr.MasterConvention__r.Company__c)) {
                roles.add(createRole(agr, matchingLegalEntityByCompany.get(agr.MasterConvention__r.Company__c)));
            }
            else if (!agr.Code_Type__c.equalsIgnoreCase('Sub-distributor via Platforms')
                     && !agr.Code_Type__c.equalsIgnoreCase('Technical')
                     && matchingLegalEntityByCompany.containsKey(agr.Company__c)) {
                         roles.add(createRole(agr, matchingLegalEntityByCompany.get(agr.Company__c)));
                     }
        }
        
        if (!roles.isEmpty()) {
            insert roles;
        }
    }
    
    /**
* @author Noor
* @date 17/01/2022
* @description Create the role for agreement and Legal Entity
*
* @param agr
* @param legalEntityId
*
* @return
*/
    public static Agreement_Role__c createRole(Convention__c agr, Id legalEntityId) {
        Agreement_Role__c agrRole = new Agreement_Role__c();
        agrRole.Agreement__c = agr.Id;
        agrRole.Legal_Entity__c = legalEntityId;
        agrRole.Role__c = getMappingAgreementRole(agr.Code_Type__c);
        agrRole.TECH_Agreement_CodeType__c= agr.Code_Type__c;
        return agrRole;
    }
    
    /**
* @author Noor
* @date 17/01/2022
* @description Get the mapping between Code Type and Agreement role in Agreement_Role_Mapping__mdt
*
* @param codeType agreement CodeType
*
* @return  Agreement role, the default value is stored in Agreement_Role_Mapping__mdt
*/
    private static String getMappingAgreementRole(String codeType) {
        
        Map<String, String> agreementRoles = Utils.getAgreementRoleSettings();
        
        if (agreementRoles.containsKey(codeType)) {
            return agreementRoles.get(codeType);
        }
        
        else {
            return agreementRoles.get('Default');
        }
        
    }
    
    public static void handleBeforeUpdate(List<Convention__c> newAgreements, map<id, Convention__c> oldAgreements) {
        
        List<Id> accountIds = new List<Id>();
        List<Id> gridIds = new List<Id>();
        
        Map<Id, Convention__c> mConvIds_withSubAgreements = new Map<Id, Convention__c>();
        Map<Id, List<Convention__c>> accAgreement = new Map<Id, List<Convention__c>>();
        
        for(Convention__c agr : newAgreements) {
            accountIds.add(agr.Company__c);
            gridIds.add(agr.Grid__c);
            
            Convention__c oldConv = oldAgreements.get(agr.Id);
            if (checkIfApprovalProcess(agr.id, 'Started')) {
                if (accAgreement.containsKey(oldConv.Company__c)) {
                    accAgreement.get(agr.Company__c).add(agr);
                }
                else {
                    accAgreement.put(agr.Company__c, new List<Convention__c>{agr});
                }
            }
            else if (agr.Agreement_Type__c == 'Master') {
                if (agr.Primary_Rebate_Contact__c != oldConv.Primary_Rebate_Contact__c){
                    mConvIds_withSubAgreements.put(agr.Id, agr);
                }
            }
            
        }
        
        //Check if the records updated because of approval process have required fields
        if (accAgreement.size() > 0) {
            List<Account> accList = [SELECT id, LegalEntity__c FROM Account where id in: accAgreement.keySet()];
            for (Account acc : accList) {
                for (Convention__c agr : accAgreement.get(acc.id)) {
                    if (acc.LegalEntity__c == null) {
                        agr.Name.addError(System.Label.ApprovalProcessMandotoryFieldsAgreement);
                    }
                }
            }
            return;
        }
        //all companies linked to the new agreements
        Map<Id, Account> companyMap = AgreementUtil.getAllLinkedAccounts(accountIds);
        Map<Id, Grid__c> gridMap = new Map<Id, Grid__c>([SELECT Id, Name FROM Grid__c WHERE Id IN: gridIds]);
        
        if (mConvIds_withSubAgreements.size() > 0){
            List<Convention__c> lConventionToUpdate = new List<Convention__c>([SELECT Primary_Rebate_Contact__c, Convention__c FROM Convention__c WHERE MasterConvention__c IN :mConvIds_withSubAgreements.keySet() AND Status__c != 'Terminated']);
            if (lConventionToUpdate.size() > 0){
                for (Convention__c Conv : lConventionToUpdate) {
                    Convention__c a = mConvIds_withSubAgreements.get(Conv.id);
                    for (id MasterId : mConvIds_withSubAgreements.keySet()) {
                        Conv.Primary_Rebate_Contact__c = mConvIds_withSubAgreements.get(MasterId).Primary_Rebate_Contact__c;
                    }
                }
                
            }
            update lConventionToUpdate;
        }
        
        for (Convention__c agr : newAgreements) {

            Account tmpAcc = companyMap.get(agr.Company__c);
            Convention__c oldAgr = oldAgreements.get(agr.Id);

            if(agr.Company__c != oldAgr.Company__c) {
                AgreementUtil.validateCompanySnapshot(agr, tmpAcc);
                AgreementUtil.snapCompanyToAgreement(agr, tmpAcc);
            }
            
            if( (String.isNotEmpty(agr.Amendment_Approval_Status__c) && agr.Amendment_Approval_Status__c != 'Approval Rejected' && agr.Status__c == 'Rejected') ||
                (String.isNotEmpty(agr.Agreement_Termination_Status__c) && agr.Agreement_Termination_Status__c != 'Approval Rejected' && agr.Status__c == 'Rejected')) {
                agr.Status__c = 'In Negotiation';
            }
        }

        GridUtility.handleAgreementGridTransitions(newAgreements, oldAgreements); // ──── Grid__c + Agreement field swaps + AgreementGridTimeline__c lifecycle ────
    }
    
    public static boolean checkIfApprovalProcess(Id recordId, String statusString) {
        List<ProcessInstance> existingApprovals = [SELECT Id, TargetObjectId
                                                   FROM ProcessInstance
                                                   WHERE TargetObjectId=:recordId AND status=:statusString];
        return existingApprovals.size() > 0;
    }
    
    public static void attachedKYD_DD(List<Convention__c> conventions) {
        
        Set<Id> legalEntitySet = getallLegalEntities(conventions);
        Map<Id, KYD_Due_Diligence_Oversight__c>getKYCCheckListMap = new Map<Id, KYD_Due_Diligence_Oversight__c>([SELECT Id, Active__c, LegalEntity__c
                                                                                                                 FROM KYD_Due_Diligence_Oversight__c
                                                                                                                 WHERE LegalEntity__c IN:legalEntitySet AND Active__c =true
                                                                                                                 ORDER BY createdDate DESC LIMIT 1]);
        
        for (Convention__c agr : conventions) {
            for (KYD_Due_Diligence_Oversight__c chk: getKYCCheckListMap.values()) {
                agr.KYD_Due_Diligence_Oversight__c = chk.Id;
            }
        }
    }
    
    //Utility method to return all legal entities related to agreeement
    public static Set<Id>getallLegalEntities(List<Convention__c> agrList) {
        Set<Id>agRecordIdSet = new Set<Id>();
        Set<Id>legalEntitiesSet = new Set<Id>();
        
        for(Convention__c agr: agrList){
            agRecordIdSet.add(agr.Id);
        }
        
        Convention__c[] agreementRoles = [SELECT Id, (SELECT Id, Legal_Entity__c, Legal_Role_Validation__c
                                                      FROM Agreement_Roles__r WHERE Role__c!=:System.Label.CarmignacEntity)
                                          FROM Convention__c where Id IN: agRecordIdSet];
        if (agreementRoles.size() > 0) {
            list<Agreement_Role__c> rols = agreementRoles[0].Agreement_Roles__r;
            for (Agreement_Role__c r: rols) {
                legalEntitiesSet.add(r.Legal_Entity__c);
            }
        }
        return legalEntitiesSet;
    }
    
    /**
* @author Noor
* @date 03/12/2021
* @description  When a master agreement is terminated, update all his siblings to pending termination
* @param newItems
* @param oldItems
*/
    public static void updateChildAgreementWhenTerminated(Map<Id, Convention__c> newItems, Map<Id, Convention__c> oldItems) {
        
        List<Convention__c> agreementsToUpdate = new List<Convention__c>();
        
        Id intermediaryAgreement = UtilitiesSObject.getRecordTypeIdByDeveloperName(Convention__c.SObjectType, 'Agreement');
        
        for(Convention__c agr : newItems.values()) {
            if(agr.RecordTypeId.equals(intermediaryAgreement) && agr.Status__c.equals('Terminated') && agr.Status__c != oldItems.get(agr.Id).Status__c) {
                agreementsToUpdate.add(agr);
            }
        }
        
        if (!agreementsToUpdate.isEmpty()) {
            List<Convention__c> childAgreement = new List<Convention__c>();
            
            for (Convention__c agr : [SELECT Id FROM Convention__c WHERE MasterConvention__c IN : agreementsToUpdate AND Status__c NOT IN ('Terminated', 'Pending Termination')]){
                agr.Status__c = 'Pending Termination';
                childAgreement.add(agr);
            }
            update childAgreement;
        }
    }
    
    public static void validateAgreementWhenApproved(Map<Id, Convention__c> newMap, Map<Id, Convention__c> oldMap) {
        for (Convention__c c : newMap.values()) {
            validateStepsApproval(c, oldMap.get(c.id));
        }
    }
    
    public static void validateStepsApproval(Convention__c agr, Convention__c oldAgreement) {
        
        String approvalStep = getApprovalStepName(agr);
        
        switch on approvalStep {
            when 'Agreement Request IS Approval' {
                if (approvedAction(agr, oldAgreement, 'DCO Approval', 'HOC Approval')) {
                    validateRequestISApprovalKYD(agr, oldAgreement);
                    validateRequestISApprovalRiskLevel(agr);
                }
            }
            when 'Agreement Request Compliance Approval' {
                if (approvedAction(agr, oldAgreement, 'Compliance Approval', 'DCO Approval')) {
                    validateRequestComplianceApproval(agr);
                }
            }
            when 'Agreement Amendment Legal Approval' {
                if (!isAgreementRoleValidated(agr, oldAgreement)) {
                    agr.Name.addError(System.label.Validate_Agreement_Roles_Error_message);
                }
            }
            when 'Agreement Renewal Legal Approval' {
                if (!isAgreementRoleValidated(agr, oldAgreement)) {
                    agr.Name.addError(System.label.Validate_Agreement_Roles_Error_message);
                }
            }
            when 'Agreement Renewal with GRID Legal Approval' {
                if (!isAgreementRoleValidated(agr, oldAgreement)) {
                    agr.Name.addError(System.label.Validate_Agreement_Roles_Error_message);
                }
            }
            when else {
            }
        }
    }
    
    /**
* @author JLC
* @description Check if agreement has a pending approval process
* @param agr
*
* @return approval step name if exist else empty
*/
    public static String getApprovalStepName(Convention__c agr) {
        String approvalStep = '';
        ProcessInstance[] pi = [SELECT Id, TargetObjectId, Status FROM ProcessInstance WHERE TargetObjectId = :agr.Id AND Status = 'Pending' ORDER BY CreatedDate DESC];
        
        ProcessInstanceNode[] pin;
        if (!pi.isEmpty()) {
            pin = [SELECT Id, NodeStatus, ProcessNodeName, ProcessInstanceId FROM ProcessInstanceNode WHERE ProcessInstanceId = :pi[0].Id AND NodeStatus = 'Pending'];
        }
        
        if (pin != null && !pin.isEmpty()) {
            approvalStep = pin[0].ProcessNodeName;
        }
        
        return approvalStep;
    }
    
    public static boolean isAgreementRoleValidated(Convention__c agr, Convention__c oldAgr) {
        
        return agr.NumberOfUnvalidatedAgreementRole__c != oldAgr.NumberOfUnvalidatedAgreementRole__c || agr.NumberOfUnvalidatedAgreementRole__c == 0;
    }
    
    /**
* @author MNFR
* @description Check if the Due Diligence field is not Updated and not Completed
*              Check if the Preliminary_Risk_Assesment is Empty/null
* @param agr, oldAgr
* @return An error message
*/
    public static void validateRequestISApprovalKYD(Convention__c agr, Convention__c oldAgr) {
        if (agr.KYD_DD_Oversight_Status__c != 'Completed' && agr.KYD_Due_Diligence_Oversight__c == oldAgr.KYD_Due_Diligence_Oversight__c) {
            agr.KYD_DD_Oversight_Status__c .addError(System.Label.Due_Diligence_Error_Message);
        }
    }
    
    /**
* @author MNFR
* @description Check if the Due Diligence field is not Updated and not Completed
*              Check if the Preliminary_Risk_Assesment is Empty/null
* @param agr agreement
* @return An error message
*/
    public static void validateRequestISApprovalRiskLevel(Convention__c agr) {
        
        if (String.isBlank(agr.Preliminary_Risk_Assesment__c) && (String.isBlank(agr.KYD_Responsible__c) || agr.KYD_Responsible__c.toLowerCase() != 'reliance')) {
            agr.Preliminary_Risk_Assesment__c.addError(System.Label.Risk_level_Error_Message);
        }
    }
    
    
    /**
* @author MNFR
* @description Check if compliance clearing is checked
* @param agr agreement
* @return An error message
*/
    public static void validateRequestComplianceApproval(Convention__c agr) {
        if (!agr.Compliance_Clearing__c) {
            agr.Compliance_Clearing__c.addError(System.Label.Compliance_Clearing_Error_Message);
        }
    }
    
    public static Boolean approvedAction(Convention__c agr, Convention__c oldAgr, String actualStatus, String previousStatus) {
        return agr.Approval_Status__c == actualStatus && oldAgr.Approval_Status__c == previousStatus;
    }
    
    /**
* @author Noor
* @date 16/02/2022
* @description update the role on agreement role when the code type is changed on the agreement
* @param newMap map of updated agreements
* @param oldMap map of old values agreements
*/
    public static void updateAgreementRoleWhenCodeTypeChange(Map<Id, Convention__c> newMap, Map<Id, Convention__c> oldMap) {
        
        Set<Id> agrIds = new Set<Id>();
        List<Agreement_Role__c> roleToUpdate = new List<Agreement_Role__c>();
        
        for (Convention__c agr : newMap.values()){
            if(agr.Code_Type__c != oldMap.get(agr.Id).Code_Type__c) {
                agrIds.add(agr.Id);
            }
        }
        
        for (Agreement_Role__c role : [SELECT Id, Role__c, Agreement__r.Code_Type__c FROM Agreement_Role__c
                                       WHERE Agreement__c IN :agrIds AND Role__c != 'Carmignac Entity']){
                                           role.TECH_Agreement_CodeType__c = role.Agreement__r.Code_Type__c;
                                           role.Role__c = getMappingAgreementRole(role.Agreement__r.Code_Type__c);
                                           roleToUpdate.add(role);
                                       }
        
        if (!roleToUpdate.isEmpty()) {
            update roleToUpdate;
        }
    }
    
}