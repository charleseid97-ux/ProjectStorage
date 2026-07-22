/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 28-03-2024
 * @last modified by  : Thanina YAYA
**/
global with sharing class AgreementUtil {

    //Investor without Agreement
    final public static String INST_RECTYPE_DEVNAME = 'Institutional_Agreement';
    final public static String INV_WITHRECTYPE_DEVNAME = 'Investor_without_Agreement_Request';
    final public static String INV_WITH_FULL_RECTYPE_DEVNAME = 'Investor_without_Agreement_Request_Full';
    final public static String INST_RECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(INST_RECTYPE_DEVNAME).getRecordTypeId();
    final public static String INV_WITHRECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(INV_WITHRECTYPE_DEVNAME).getRecordTypeId();
    final public static String INV_WITH_FULL_RECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(INV_WITH_FULL_RECTYPE_DEVNAME).getRecordTypeId();

    //Sub-distributor via Platforms
    final public static String SUB_DIS_RECTYPE_DEVNAME = 'Sub_distributor_Agreement';
    final public static String SUB_DISRECTYPE_DEVNAME = 'Sub_distributor_Agreement_Request';
    final public static String SUB_DIS_REQ_FULL_RECTYPE_DEVNAME = 'Sub_distributor_Agreement_Request_Full';
    final public static String SUB_DIS_RECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(SUB_DIS_RECTYPE_DEVNAME).getRecordTypeId();
    final public static String SUB_DISRECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(SUB_DISRECTYPE_DEVNAME).getRecordTypeId();
    final public static String SUB_DIS_REQ_FULL_RECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(SUB_DIS_REQ_FULL_RECTYPE_DEVNAME).getRecordTypeId();

    //Intermediary Agreement
    final public static String AGR_RECTYPE_DEVNAME = 'Agreement';
    final public static String REQ_RECTYPE_DEVNAME = 'Request_Agreement';
    final public static String REQ_FULL_RECTYPE_DEVNAME = 'Request_Agreement_Full';
    final public static String AGR_RECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(AGR_RECTYPE_DEVNAME).getRecordTypeId();
    final public static String REQ_RECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(REQ_RECTYPE_DEVNAME).getRecordTypeId();
    final public static String REQ_FULL_RECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(REQ_FULL_RECTYPE_DEVNAME).getRecordTypeId();

    //IS Agreement
    final public static String IS_RECTYPE_DEVNAME = 'IS_Agreement';
    final public static String IS_RECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(IS_RECTYPE_DEVNAME).getRecordTypeId();

    //Technical Agreement
    final public static String TECH_RECTYPE_DEVNAME = 'Technical_Agreement';
    final public static String TECH_RECTYPE_ID = Schema.SObjectType.Convention__c.getRecordTypeInfosByDeveloperName().get(TECH_RECTYPE_DEVNAME).getRecordTypeId();

    //Several Record Types share the exact same Code_Type__c -> Role__c mapping, so in the Agreement_RoleMapping
    //label they're grouped under one representative Record Type's DeveloperName instead of repeating the same
    //lines for each Record Type. Keyed by RecordTypeId and valued by the matching DeveloperName constant above,
    //so no runtime describe is needed to resolve the group's DeveloperName.
    final public static Map<Id, String> ROLE_MAPPING_GROUP_BY_RECORDTYPE_DEVNAME = new Map<Id, String>{
        AGR_RECTYPE_ID              => AGR_RECTYPE_DEVNAME,
        REQ_RECTYPE_ID              => AGR_RECTYPE_DEVNAME,
        REQ_FULL_RECTYPE_ID         => AGR_RECTYPE_DEVNAME,
        SUB_DIS_RECTYPE_ID          => SUB_DIS_RECTYPE_DEVNAME,
        SUB_DISRECTYPE_ID           => SUB_DIS_RECTYPE_DEVNAME,
        SUB_DIS_REQ_FULL_RECTYPE_ID => SUB_DIS_RECTYPE_DEVNAME,
        IS_RECTYPE_ID               => IS_RECTYPE_DEVNAME,
        INST_RECTYPE_ID             => INST_RECTYPE_DEVNAME,
        INV_WITHRECTYPE_ID          => INST_RECTYPE_DEVNAME,
        INV_WITH_FULL_RECTYPE_ID    => INST_RECTYPE_DEVNAME,
        TECH_RECTYPE_ID             => TECH_RECTYPE_DEVNAME
    };

    //Company data validation
    public static void validateCompanySnapshot(Convention__c agg, Account c) {
        String errorMsg = '';
        if (c != null) {
            if (c.BillingStreet == null || c.BillingCity == null || c.BillingPostalCode == null || c.BillingCountry == null) {
                agg.Company__c.addError('The minimum requirement for Address fields are not entered on this Company. Please enter at least Street, City, Postal Code and Country');
            }
            if (c.Distributor_Type__c == null || c.Distributor_Type__c == '') {
                agg.Distributor_Type__c.addError('Please ensure the linked Company has a Distibutor Type');
            }
            if (c.Sub_Type__c == null || c.Sub_Type__c == '') {
                agg.Sub_Type__c.addError('Please ensure the linked Company has a Sub-Type');
            }
            if (c.In__c == null || c.In__c == '') {
                agg.Investment_Decision__c.addError('Please ensure the linked Company has an Investment Decision');
            }
            if (c.Final_Distribution__c == null || c.Final_Distribution__c == '') {
                agg.Final_Distribution__c.addError('Please ensure the linked Company has a Final Distribution');
            }
        } else {
            agg.Company__c.addError('No Company was found');
        }
    }

    //GRID mandatory when Group = 1 validation
    public static void validateGRID(Convention__c agr) {
        if (agr.Agreement_Group__c == 1 && agr.Grid__c == null) {
            agr.Grid__c.addError('A GRID is mandatory for the Agreement Code Type');
        }
    }

    public static void agreementCodeGeneration(Convention__c agr, Integer currentCodeTop, Integer currentCodeSub, Map<Id, Convention__c> masterAgreements, String thisRTName) {
        String codePrefix = '', codeSubPrefix = '';
        String agreementCode = '';
        Integer thisCodeTop = 0, thisCodeSub = 0;

        if (String.isEmpty(agr.MasterConvention__c) || agr.Code_Type__c == 'Technical') {
            codePrefix = (agr.Carmignac_Legal_Entity__c == 'CGL') ? 'L' : '';
            if (currentCodeTop == -1) {
                //possible optimisation needed
                AggregateResult[] groupedResults = [SELECT max(Code_Top_Level__c) max FROM Convention__c];
                if (Integer.valueOf(groupedResults[0].get('max')) != null) {
                    thisCodeTop = Integer.valueOf(groupedResults[0].get('max'));
                }
            }
            thisCodeTop = thisCodeTop + 1;
            agr.Code_Top_Level__c = thisCodeTop;
        } 
        else {
            thisCodeTop = Integer.valueOf(masterAgreements.get(agr.MasterConvention__c).Code_Top_Level__c);
            codePrefix = (masterAgreements.get(agr.MasterConvention__c).Carmignac_Legal_Entity__c == 'CGL') ? 'L' : '';
            agr.Code_Top_Level__c = thisCodeTop;
            if (currentCodeSub == -1) {
                //possible optimisation needed
                AggregateResult[] groupedResults = [SELECT max(Code_Sub_Level__c) max FROM Convention__c WHERE MasterConvention__c = :agr.MasterConvention__c];
                if (Integer.valueOf(groupedResults[0].get('max')) != null) {
                    thisCodeSub = Integer.valueOf(groupedResults[0].get('max'));
                }
            }
            thisCodeSub = thisCodeSub + 1;
            agr.Code_Sub_Level__c = thisCodeSub;
        }

        String codeTopLP = String.valueOf(thisCodeTop).leftPad(3, '0');
        String codeSubLP = String.valueOf(thisCodeSub).leftPad(3, '0');

        codeSubPrefix = (thisRTName == 'Request_Agreement' || thisRTName == 'Investor_without_Agreement_Request' || thisRTName == 'Sub_distributor_Agreement_Request') ? agr.Business_Region__c.subString(3, 5) : 'T';

        agreementCode = (thisCodeSub == 0) ? codePrefix + codeTopLP : codePrefix + codeTopLP + '_' + codeSubPrefix + codeSubLP;
        if (thisRTName.equals('Technical_Agreement')) {
            agreementCode += '_T';
        }
        agr.Name = agreementCode;
        agr.TECH_ConventionExternalID__c = agreementCode;
    }

    public static void agreementNameGeneration(Convention__c agr, Map<Id, Convention__c> masterAgreements, Account linkedAccount) {
        String agreementName = linkedAccount.Name;

        if (agr.Code_Type__c == 'Technical') {
            agreementName += '_TECH';
        }
        else {
            agreementName += '_';
            if (String.isNotBlank(agr.Business_Region__c) && agr.Business_Region__c.length() >= 4) {
            	agreementName += agr.Business_Region__c.subString(3, 5);
            }
        }

        agr.ConventionName__c = agreementName;
    }

    public static Map<Id, Account> getAllLinkedAccounts(List<Id> accountIds) {
        //all companies linked to the new agreements
        Map<Id, Account> companyMap = new Map<Id, Account>([SELECT Id, Name, Distributor_Type__c, Sub_Type__c, In__c, Investment_vehicle__c, Investment_Vehicle_Type__c, Final_Distribution__c, 
                                                                BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, Ultimate_Parent_Id__c, Ultimate_Parent_Name__c, Ultimate_Parent_Tier__c, 
                                                                BusinessDevelopmentRegion__c, All_Concerned_Business_Regions__c, OwnerId, Owner.Name, Team__c
                                                            FROM Account
                                                            WHERE Id IN:accountIds]);
        return companyMap;
    }

    //Create Company Snapshot for Agreememt
    //Agreement recordType is added as param, cauz we need to baypass some rules in case of IS Agreement
    public static void snapCompanyToAgreement(Convention__c a, Account tmpAcc) {
        //**Start setting company snapshot data
        String mainAddress = (tmpAcc.BillingStreet != null) ? tmpAcc.BillingStreet + '\n' : '' ;
        mainAddress = (tmpAcc.BillingCity != null) ? mainAddress + tmpAcc.BillingCity + '\n' : mainAddress + '' ;
        mainAddress = (tmpAcc.BillingState != null) ? mainAddress + tmpAcc.BillingState + '\n' : mainAddress + '' ;
        mainAddress = (tmpAcc.BillingPostalCode != null) ? mainAddress + tmpAcc.BillingPostalCode + '\n' : mainAddress + '' ;
        mainAddress = (tmpAcc.BillingCountry != null) ? mainAddress + tmpAcc.BillingCountry + '\n' : mainAddress + '' ;

        a.Distributor_Type__c = tmpAcc.Distributor_Type__c;
        a.Sub_Type__c = tmpAcc.Sub_Type__c;
        a.Investment_Decision__c = tmpAcc.In__c;
        a.Investment_Vehicle__c = tmpAcc.Investment_vehicle__c;
        a.Investment_Vehicle_Type__c = tmpAcc.Investment_Vehicle_Type__c;
        a.Final_Distribution__c = tmpAcc.Final_Distribution__c;
        a.Main_Address__c = mainAddress;
        //a.Company_Country__c = tmpAcc.BillingCountry;
        //a.Company_Name__c = tmpAcc.Name;
        a.Business_Region__c = tmpAcc.BusinessDevelopmentRegion__c;
        a.TECH_Business_Region__c = tmpAcc.BusinessDevelopmentRegion__c;
        a.TeamSharing__c = tmpAcc.Team__c;
        //a.Business_Developer__c = tmpAcc.Owner.Name;
        a.Ultimate_Parent__c = tmpAcc.Ultimate_Parent_Name__c;
        a.Ultimate_Tier_at_Group_level__c = tmpAcc.Ultimate_Parent_Tier__c;
        if(a.RecordTypeId != IS_RECTYPE_ID) a.OwnerId = tmpAcc.OwnerId;
        //**End setting company snapshot data
    }

    //Utility method for Map Key retrieval
    public static String getKeyFromValue(Map<String, String> hm, String value) {
        for (String o : hm.keySet()) {
            if (hm.get(o).equals(value)) {
                return o;
            }
        }
        return null;
    }
}