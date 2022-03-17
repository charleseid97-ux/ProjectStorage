global without sharing class AgreementUtil {

//Company data validation
    public static void validateCompanySnapshot(Convention__c agg, Account c) {
        String errorMsg = '';
        if (c != null) {
            if (c.BillingStreet == null || c.BillingCity == null || c.BillingPostalCode == null || c.BillingCountry == null)
                agg.Company__c.addError('The minimum requirement for Address fields are not entered on this Company. Please enter at least Street, City, Postal Code and Country');
            if (c.Distributor_Type__c == null || c.Distributor_Type__c == '')
                agg.Distributor_Type__c.addError('Please ensure the linked Company has a Distibutor Type');
            if (c.Sub_Type__c == null || c.Sub_Type__c == '')
                agg.Sub_Type__c.addError('Please ensure the linked Company has a Sub-Type');
            if (c.In__c == null || c.In__c == '')
                agg.Investment_Decision__c.addError('Please ensure the linked Company has an Investment Decision');
            if (c.Final_Distribution__c == null || c.Final_Distribution__c == '')
                agg.Final_Distribution__c.addError('Please ensure the linked Company has a Final Distribution');
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
                if (Integer.valueOf(groupedResults[0].get('max')) != null)
                    thisCodeTop = Integer.valueOf(groupedResults[0].get('max'));
            }
            thisCodeTop = thisCodeTop + 1;
            agr.Code_Top_Level__c = thisCodeTop;
        } else {
            thisCodeTop = Integer.valueOf(masterAgreements.get(agr.MasterConvention__c).Code_Top_Level__c);
            codePrefix = (masterAgreements.get(agr.MasterConvention__c).Carmignac_Legal_Entity__c == 'CGL') ? 'L' : '';
            agr.Code_Top_Level__c = thisCodeTop;
            if (currentCodeSub == -1) {
                //possible optimisation needed
                AggregateResult[] groupedResults = [SELECT max(Code_Sub_Level__c) max FROM Convention__c WHERE MasterConvention__c = :agr.MasterConvention__c];
                if (Integer.valueOf(groupedResults[0].get('max')) != null)
                    thisCodeSub = Integer.valueOf(groupedResults[0].get('max'));
            }
            thisCodeSub = thisCodeSub + 1;
            agr.Code_Sub_Level__c = thisCodeSub;
        }

        String codeTopLP = String.valueOf(thisCodeTop).leftPad(3, '0');
        String codeSubLP = String.valueOf(thisCodeSub).leftPad(3, '0');

        codeSubPrefix = (thisRTName == 'Request_Agreement' || thisRTName == 'Investor_without_Agreement_Request' || thisRTName == 'Sub_distributor_Agreement_Request') ? agr.Business_Region__c.subString(3, 5) : 'T';

        agreementCode = (thisCodeSub == 0) ? codePrefix + codeTopLP : codePrefix + codeTopLP + '_' + codeSubPrefix + codeSubLP;
        if (thisRTName.equals('Technical_Agreement')) agreementCode += '_T';
        agr.Name = agreementCode;
        agr.TECH_ConventionExternalID__c = agreementCode;
    }

    public static void agreementNameGeneration(Convention__c agr, Map<Id, Convention__c> masterAgreements, Account linkedAccount) {
        String agreementName = linkedAccount.Name;

        if (agr.Code_Type__c == 'Technical') agreementName += '_TECH'; else agreementName += '_' + agr.Business_Region__c.subString(3, 5);

        agr.ConventionName__c = agreementName;
    }

    public static Map<Id, Account> getAllLinkedAccounts(List<Id> accountIds) {
        //all companies linked to the new agreements
        Map<Id, Account> companyMap = new Map<Id, Account>([
                SELECT Id,
                        Name,
                        Distributor_Type__c,
                        Sub_Type__c,
                        In__c,
                        Investment_vehicle__c,
                        Investment_Vehicle_Type__c,
                        Final_Distribution__c,
                        BillingStreet,
                        BillingCity,
                        BillingState,
                        BillingPostalCode,
                        BillingCountry,
                        Ultimate_Parent_Id__c,
                        Ultimate_Parent_Name__c,
                        Ultimate_Parent_Tier__c,
                        BusinessDevelopmentRegion__c,
                        All_Concerned_Business_Regions__c,
                        OwnerId,
                        Owner.Name
                FROM Account
                WHERE Id IN:accountIds
        ]);

        return companyMap;
    }

//Create Company Snapshot for Agreememt
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
        //a.Business_Developer__c = tmpAcc.Owner.Name;
        a.Ultimate_Parent__c = tmpAcc.Ultimate_Parent_Name__c;
        a.Ultimate_Tier_at_Group_level__c = tmpAcc.Ultimate_Parent_Tier__c;
        a.OwnerId = tmpAcc.OwnerId;
        //**End setting company snapshot data
    }

//Create GRID History records once a new GRID Amendment is Approved on an Agreement
    public static Agreement_Grid_History__c createGridHistory(Convention__c agr, Grid__c currentGrid) {
        Agreement_Grid_History__c newAGH = new Agreement_Grid_History__c(Name = agr.Name + ' - ' + currentGrid.Name,
                Agreement__c = agr.Id,
                Grid__c = agr.Grid__c,
                Grid_Start_Date__c = agr.Grid_Start_Date__c,
                Grid_End_Date__c = agr.Grid_Request_Start_Date__c);
        return newAGH;
    }

    public static void validateUniqueCode(Convention__c agr) {
        String thisAgrId = agr.Id;
        List<Convention__c> agrs = new List<Convention__c>([SELECT Id, Name FROM Convention__c WHERE Name = :agr.Name AND Id <> :thisAgrId]);
        if (agrs.size() > 0) {
            agr.Name.addError('This Agreement Code is not Unique. Please notify an Administrator.');
        }
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
/*
//Utility method for Validation step of Approval process
public static void validateStepsApproval_old(Convention__c agr, map<id, Convention__c> oldAgreements) {

    String approvalStep = getApprovalStepName(agr);
    System.debug('//NGO validateApprovalStepsWorkflow approvalStep : '+approvalStep);

    System.debug('validateStepsApproval '+agr);

    if (String.isNotBlank(approvalStep) ){

        System.debug('validateStepsApproval pin[0].ProcessNodeName '+approvalStep);
        System.debug('validateStepsApproval agr.KYD_DD_Oversight_Status__c '+agr.KYD_DD_Oversight_Status__c);
        System.debug('validateStepsApproval agr.Approval_Status__c '+agr.Approval_Status__c);
        System.debug('validateStepsApproval oldAgreements.get(agr.Id)..Approval_Status__c '+oldAgreements.get(agr.Id).Approval_Status__c);


        if (approvalStep != 'Agreement Request Compliance Approval') agr.IS_Approved__c = false;
        else if (agr.Preliminary_Risk_Assesment__c == 'High' || agr.Preliminary_Risk_Assesment__c == 'Medium') agr.IS_Approved__c = true;

        if (approvalStep== 'Agreement Request IS Approval') {
            if (agr.KYD_DD_Oversight_Status__c != 'Completed' && agr.KYD_Due_Diligence_Oversight__c == oldAgreements.get(agr.Id).KYD_Due_Diligence_Oversight__c
                    && agr.Approval_Status__c == 'DCO Approval' && oldAgreements.get(agr.Id).Approval_Status__c == 'HOC Approval'){
                agr.KYD_DD_Oversight_Status__c .addError('You must complete KYD Due Diligence Oversight before IS can approve');
            }

            if (agr.Preliminary_Risk_Assesment__c == '' || String.isEmpty(agr.Preliminary_Risk_Assesment__c))
                agr.Preliminary_Risk_Assesment__c.addError('You must select a Risk Level.');
        }

        if(approvalStep== 'Agreement Request Compliance Approval' && agr.Compliance_Clearing__c == false)
            agr.Compliance_Clearing__c.addError('You must tick a Compliance Clearing.');

        if((approvalStep == 'Agreement Amendment Legal Approval' ||
                approvalStep== 'Agreement Renewal Legal Approval' ||
                approvalStep == 'Agreement Renewal with GRID Legal Approval') && isAgreementRoleValidated(agr))
            agr.Name.addError('You must validate all Agreement Roles. ');

    }
}
*/

}