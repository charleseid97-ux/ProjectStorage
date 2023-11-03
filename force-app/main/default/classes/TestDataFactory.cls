/**
 * @description       : 
 * @author            : Thanina YAYA
 * @last modified on  : 14-09-2023
 * @last modified by  : Thanina YAYA
**/
@isTest
public class TestDataFactory {
    public static Account getAccount() {
        return new Account(Name='Account For Test',
                          BusinessDevelopmentRegion__c='BP_FR',
                          BillingCountry='France',
                          BillingCity='Paris',
                          BillingStreet='12 place Vendome',
                          BillingPostalCode='75001');
    }
    
    public static Account_Plan__c getAccountPlan(Id accountId) {
        return new Account_Plan__c(Company__c=accountId);
    }
    
    public static CampaignMember getCampaignMember(Id linkedId, Id campaign) {
        CampaignMember cm = new CampaignMember(campaignId=campaign);
        if (Schema.Contact.SObjectType == linkedId.getSobjectType()) {
            cm.contactId = linkedId;
        }
        else {
            cm.LeadId = linkedId;
        }
        return cm;
    }
            
    public static Campaign getCampaign(String recordType) {
        Id recordTypeId = Schema.SObjectType.Campaign.getRecordTypeInfosByName().get(recordType).getRecordTypeId();
        Campaign c = new Campaign(RecordTypeId=recordTypeId,
                                 Name='Test Campaign on ' + DateTime.now(),
                                 Status='Email Sent',
                                 Description='Test Data for Campaign. RecordType: ' + recordType,
                                 Type_of_client__c='All',
                                 Start_Date_Time__c=DateTime.now().addDays(7));
        return c;
    }
    
    public static Contact getContact() {
        Contact c = new Contact(LastName='Last',
                               FirstName='First',
                               email='first.last@invalid.com');
        return c;
    }

    public static List<Preference_Center_Category__mdt> getPreferenceCenterCategory() {
        List<Preference_Center_Category__mdt> prefList = new List<Preference_Center_Category__mdt>();
        
        Preference_Center_Category__mdt prefComm = new Preference_Center_Category__mdt();
        prefComm.MasterLabel = 'Newsletter';
        prefComm.DeveloperName = 'Monthly_Newsletter';
        prefComm.Category__c = 'Communication Type';
        prefComm.Order__c = 0;
        prefList.add(prefComm);

        Preference_Center_Category__mdt prefPreference = new Preference_Center_Category__mdt();
        prefPreference.MasterLabel = 'Equities';
        prefPreference.DeveloperName = 'Equities';
        prefPreference.Category__c = 'Preference';
        prefPreference.Order__c = 0;
        prefPreference.Childs__c = 'Carmignac_Climate_Transition_CC__c:Carmignac Climate Transition (CC);Carmignac_Emergents_CE_PE_UKCE__c:Carmignac Emergents (CE/PE/UKCE)';
        prefList.add(prefPreference);

        Preference_Center_Category__mdt prefInterest = new Preference_Center_Category__mdt();
        prefInterest.MasterLabel = 'Corporate';
        prefInterest.DeveloperName = 'Corporate';
        prefInterest.Category__c = 'Interest';
        prefInterest.Order__c = 0;
        prefList.add(prefInterest);

        return prefList;
    }

    public static Legal_Entity__c getLegalEntity() {
        Legal_Entity__c le = new Legal_Entity__c(
            Name = 'Test'
        );

        return le;
    }
}