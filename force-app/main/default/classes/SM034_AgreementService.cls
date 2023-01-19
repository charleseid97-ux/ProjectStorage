/**
 * Created by noorg on 18/06/2021.
 */

public without sharing class SM034_AgreementService {
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

            if(thisRecordTypeName == 'Request_Agreement' || thisRecordTypeName == 'Investor_without_Agreement_Request' || thisRecordTypeName == 'Technical_Agreement' || thisRecordTypeName == 'Sub_distributor_Agreement_Request') {
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

            if(thisRecordTypeName == 'Investor_without_Agreement_Request' || thisRecordTypeName == 'Technical_Agreement') {
                if(zeroGrid == null) {
                    zeroGrid = [SELECT Id, Name FROM Grid__c WHERE Name = '0%'];
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
            AgreementUtil.validateGRID(a);

            //Agreement code and increment generation
            AgreementUtil.agreementCodeGeneration(a, currentCodeTop, currentCodeSub, masterAgreements, thisRecordTypeName);
            currentCodeTop = Integer.valueOf(a.Code_Top_Level__c);
            currentCodeSub = Integer.valueOf(a.Code_Sub_Level__c);

            //Agreement name
            AgreementUtil.agreementNameGeneration(a, masterAgreements, tmpAcc);

            AgreementUtil.validateUniqueCode(a);
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
            if(thisRecordTypeName == 'Investor_without_Agreement_Request' || thisRecordTypeName == 'Technical_Agreement') {
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

        if(rebateContactsToInsert.size() > 0) insert rebateContactsToInsert;

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

        for(Convention__c agr : newItems){
            if(agr.Carmignac_Legal_Entity__c == 'CGL' && CGL != null) roles.add(new Agreement_Role__c(Role__c = 'Carmignac Entity', Agreement__c = agr.Id, Legal_Entity__c = CGL));
            else if(agr.Carmignac_Legal_Entity__c == 'CGF' && CGF != null) roles.add(new Agreement_Role__c(Role__c = 'Carmignac Entity', Agreement__c = agr.Id, Legal_Entity__c = CGF));
        }

        if(!roles.isEmpty()) insert roles;
    }


    /**
     * @author Noor
     * @date 17/01/2022
     * @description  Setting up the role if Legal Entity company match Agreement Company based on Code Type
     *               For Sub-distributor via Platforms master Agreement Company is Used
     *               The default role per code Type is stored in custom metadata Agreement_Role_Mapping__mdt
     * @param newItems new created agreement
     */
    public static void createDefaultLegalEntityAgreementRole(List<Convention__c> newItems){

        List<Agreement_Role__c> roles = new List<Agreement_Role__c>();
        Set<Id> companyIds = new Set<Id>();

        for(Convention__c agr : newItems) {
            companyIds.add(agr.Company__c);
            if(agr.MasterConvention__r.Company__c != null) companyIds.add(agr.MasterConvention__r.Company__c);
        }

        List<Convention__c> agreementsWithMaster = [SELECT Id,Code_Type__c,Company__c, MasterConvention__r.Company__c
                                                                FROM Convention__c WHERE Id IN : newItems];

        Map<Id, Legal_Entity__c> matchingLegalEntityByCompany = new Map<Id, Legal_Entity__c>();
        for(Legal_Entity__c le : [SELECT Company__c, Id, Name FROM Legal_Entity__c WHERE Company__c IN : companyIds]) {
            matchingLegalEntityByCompany.put(le.Company__c, le);
        }

        for(Convention__c agr : agreementsWithMaster) {

            if(agr.Code_Type__c.equalsIgnoreCase('Sub-distributor via Platforms') && matchingLegalEntityByCompany.containsKey(agr.MasterConvention__r.Company__c))
                roles.add(createRole(agr, matchingLegalEntityByCompany.get(agr.MasterConvention__r.Company__c).Id));

            else if(!agr.Code_Type__c.equalsIgnoreCase('Sub-distributor via Platforms')
                      && !agr.Code_Type__c.equalsIgnoreCase('Technical')
                        && matchingLegalEntityByCompany.containsKey(agr.Company__c))
                roles.add(createRole(agr, matchingLegalEntityByCompany.get(agr.Company__c).Id));
        }

        if(!roles.isEmpty()) insert roles;
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
    private static Agreement_Role__c createRole(Convention__c agr, Id legalEntityId) {

        return new Agreement_Role__c(Agreement__c = agr.Id, Legal_Entity__c = legalEntityId, Role__c = getMappingAgreementRole(agr.Code_Type__c), TECH_Agreement_CodeType__c= agr.Code_Type__c);
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

        if(agreementRoles.containsKey(codeType)) return agreementRoles.get(codeType);

        else return agreementRoles.get('Default');

    }

    public static void handleBeforeUpdate(List<Convention__c> newAgreements, map<id, Convention__c> oldAgreements) {

        List<Id> accountIds = new List<Id>();
        List<Id> gridIds = new List<Id>();

        Map<Id, Convention__c> mConvIds_withSubAgreements = new Map<Id, Convention__c>();

        for(Convention__c agr : newAgreements) {
            accountIds.add(agr.Company__c);
            gridIds.add(agr.Grid__c);

            Convention__c oldConv = oldAgreements.get(agr.Id);
            if(agr.Agreement_Type__c == 'Master') {
                if(agr.Primary_Rebate_Contact__c != oldConv.Primary_Rebate_Contact__c){
                    mConvIds_withSubAgreements.put(agr.Id, agr);
                }
            }

        }
        //all companies linked to the new agreements
        Map<Id, Account> companyMap = AgreementUtil.getAllLinkedAccounts(accountIds);
        Map<Id, Grid__c> gridMap = new Map<Id, Grid__c>([SELECT Id, Name FROM Grid__c WHERE Id IN: gridIds]);

        if(mConvIds_withSubAgreements.size() > 0){
            List<Convention__c> lConventionToUpdate = new List<Convention__c>([SELECT Primary_Rebate_Contact__c, Convention__c FROM Convention__c WHERE MasterConvention__c IN :mConvIds_withSubAgreements.keySet() AND Status__c != 'Terminated']);
            if(lConventionToUpdate.size() > 0){
                for(Convention__c Conv : lConventionToUpdate) {
                    Convention__c a = mConvIds_withSubAgreements.get(Conv.id);
                    for(id MasterId : mConvIds_withSubAgreements.keySet()){
                        Conv.Primary_Rebate_Contact__c = mConvIds_withSubAgreements.get(MasterId).Primary_Rebate_Contact__c;                    }
                }

            }
            update lConventionToUpdate;
        }

        List<Agreement_Grid_History__c> AGHToInsert = new List<Agreement_Grid_History__c>();
        for(Convention__c agr : newAgreements) {

            Account tmpAcc = companyMap.get(agr.Company__c);

            if(agr.Company__c != oldAgreements.get(agr.Id).Company__c) {
                AgreementUtil.validateCompanySnapshot(agr, tmpAcc);

                AgreementUtil.snapCompanyToAgreement(agr, tmpAcc);
            }

            if(agr.Amendment_Approval_Status__c == 'Approved' && agr.Grid_Request_Approved__c) {
                Agreement_Grid_History__c retAGH = AgreementUtil.createGridHistory(agr, gridMap.get(agr.Grid__c));
                if(retAGH != null) {
                    AGHToInsert.add(retAGH);

                    agr.Grid__c = agr.Grid_Request__c;
                    agr.Grid_Request__c = null;
                    agr.Grid_Start_Date__c = agr.Grid_Request_Start_Date__c;
                    agr.Grid_Request_Start_Date__c = null;
                    agr.Amendment_Approval_Status__c = '';
                    agr.Grid_Request_Approved__c = false;
                }
            }

            if(agr.Amendment_Approval_Status__c == 'Approved' && agr.Status__c != null)
                agr.Renewal_Request_End_Date__c = null;

            if(String.isEmpty(agr.Amendment_Approval_Status__c) == false && agr.Amendment_Approval_Status__c != 'Approval Rejected' && agr.Status__c == 'Rejected')
                agr.Status__c = 'In Negotiation';

            if(String.isEmpty(agr.Agreement_Termination_Status__c) == false && agr.Agreement_Termination_Status__c != 'Approval Rejected' && agr.Status__c == 'Rejected')
                agr.Status__c = 'In Negotiation';

            
            //if(agr.Amendment_Approval_Status__c != oldAgreements.get(agr.Id).Amendment_Approval_Status__c ||
            //        agr.Approval_Status__c != oldAgreements.get(agr.Id).Approval_Status__c )
            //    AgreementUtil.validateStepsApproval(agr, oldAgreements);
        }

        if(AGHToInsert.size() > 0)
            insert AGHToInsert;
    }

    public static void attachedKYD_DD(List<Convention__c> conventions) {

        Set<Id> legalEntitySet = getallLegalEntities(conventions);
        Map<Id, KYD_Due_Diligence_Oversight__c>getKYCCheckListMap = new Map<Id, KYD_Due_Diligence_Oversight__c>([SELECT Id, Active__c, LegalEntity__c
        FROM KYD_Due_Diligence_Oversight__c
        WHERE LegalEntity__c IN:legalEntitySet
        AND Active__c =true
        ORDER BY createdDate DESC LIMIT 1]);

        for(Convention__c agr : conventions) {
            for(KYD_Due_Diligence_Oversight__c chk: getKYCCheckListMap.values()){
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
        if (agreementRoles.size() > 0){
            list<Agreement_Role__c> rols = agreementRoles[0].Agreement_Roles__r;
            for (Agreement_Role__c r: rols){
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

        for(Convention__c agr : newItems.values())
            if(agr.RecordTypeId.equals(intermediaryAgreement) && agr.Status__c.equals('Terminated') && agr.Status__c != oldItems.get(agr.Id).Status__c)
                agreementsToUpdate.add(agr);

        if(!agreementsToUpdate.isEmpty()){
            List<Convention__c> childAgreement = new List<Convention__c>();

            for(Convention__c agr : [SELECT Id FROM Convention__c WHERE MasterConvention__c IN : agreementsToUpdate AND Status__c NOT IN ('Terminated', 'Pending Termination')]){
                agr.Status__c = 'Pending Termination';
                childAgreement.add(agr);
            }
            update childAgreement;
        }
    }


    public static void validateAgreementWhenApproved(Map<Id, Convention__c> newMap, Map<Id, Convention__c> oldMap) {
        //Validate only when request come from the agreement page
        if(newMap.size() == 1) validateStepsApproval(newMap.values()[0], oldMap.values()[0]);
    }

    public static void validateStepsApproval(Convention__c agr, Convention__c oldAgreement) {

        String approvalStep = getApprovalStepName(agr);

        switch on approvalStep {
            when 'Agreement Request IS Approval' {
                if(approvedAction(agr, oldAgreement, 'DCO Approval', 'HOC Approval')){
                    validateRequestISApprovalKYD(agr, oldAgreement);
                    validateRequestISApprovalRiskLevel(agr);
                }
            }
            when 'Agreement Request Compliance Approval' {
                if (approvedAction(agr, oldAgreement, 'Compliance Approval', 'DCO Approval')) validateRequestComplianceApproval(agr);
            }
            when 'Agreement Amendment Legal Approval' {
                if (!isAgreementRoleValidated(agr, oldAgreement)) agr.Name.addError(System.label.Validate_Agreement_Roles_Error_message);
            }
            when 'Agreement Renewal Legal Approval' {
                if (!isAgreementRoleValidated(agr, oldAgreement)) agr.Name.addError(System.label.Validate_Agreement_Roles_Error_message);
            }
            when 'Agreement Renewal with GRID Legal Approval' {
                if (!isAgreementRoleValidated(agr, oldAgreement)) agr.Name.addError(System.label.Validate_Agreement_Roles_Error_message);
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
        ProcessInstance[] pi = [SELECT Id,TargetObjectId, Status FROM ProcessInstance WHERE TargetObjectId = :agr.Id AND Status = 'Pending' ORDER BY CreatedDate DESC];

        ProcessInstanceNode[] pin ;
        if (!pi.isEmpty()) pin = [SELECT Id, NodeStatus, ProcessNodeName, ProcessInstanceId FROM ProcessInstanceNode WHERE ProcessInstanceId = :pi[0].Id AND NodeStatus = 'Pending'];

        if (pin != null && !pin.isEmpty()) approvalStep = pin[0].ProcessNodeName;

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
        if (agr.KYD_DD_Oversight_Status__c != 'Completed' &&
                agr.KYD_Due_Diligence_Oversight__c == oldAgr.KYD_Due_Diligence_Oversight__c)
            agr.KYD_DD_Oversight_Status__c .addError(System.Label.Due_Diligence_Error_Message);
    }

    /**
     * @author MNFR
     * @description Check if the Due Diligence field is not Updated and not Completed
     *              Check if the Preliminary_Risk_Assesment is Empty/null
     * @param agr agreement
     * @return An error message
     */
    public static void validateRequestISApprovalRiskLevel(Convention__c agr) {

        if (String.isBlank(agr.Preliminary_Risk_Assesment__c) &&
           agr.KYD_DD_Oversight_Status__c != 'Completed') agr.Preliminary_Risk_Assesment__c.addError(System.Label.Risk_level_Error_Message);
    }


    /**
     * @author MNFR
     * @description Check if compliance clearing is checked
     * @param agr agreement
     * @return An error message
     */
    public static void validateRequestComplianceApproval(Convention__c agr) {
        if (!agr.Compliance_Clearing__c) agr.Compliance_Clearing__c.addError(System.Label.Compliance_Clearing_Error_Message);
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

        for(Convention__c agr : newMap.values()){
            if(agr.Code_Type__c != oldMap.get(agr.Id).Code_Type__c) agrIds.add(agr.Id);
        }

        for(Agreement_Role__c role : [SELECT Id, Role__c, Agreement__r.Code_Type__c FROM Agreement_Role__c
                                        WHERE Agreement__c IN :agrIds AND Role__c != 'Carmignac Entity']){
            role.TECH_Agreement_CodeType__c = role.Agreement__r.Code_Type__c;
            role.Role__c = getMappingAgreementRole(role.Agreement__r.Code_Type__c);
            roleToUpdate.add(role);
        }

        if(!roleToUpdate.isEmpty()) update roleToUpdate;
    }

}