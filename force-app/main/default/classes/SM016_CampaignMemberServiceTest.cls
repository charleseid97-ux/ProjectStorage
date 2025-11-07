@IsTest
public class SM016_CampaignMemberServiceTest {
    @testSetup static void setup() {
        Campaign c = new Campaign(Name='Test Campaign',
                                 Status='New',
                                 Type='Survey',
                                 Description='Test Campaign for class SM016_CampaignMemberServiceTest',
                                 Type_of_client__c='Retail',
                                 Start_Date_Time__c=datetime.now());
        insert c;
        
        Lead leadCampaign = new Lead(FirstName='Sarah',
                                    LastName='Sample',
                                    Company='Test Company',
                                    LeadSource='Web',
                                    Status='New',
                                    Email='test@example.com');
        insert leadCampaign;
        
        CampaignMember firstCM = new CampaignMember(LeadId=leadCampaign.Id,
                                                   CampaignId=c.ID,
                                                   status='Connected');
        insert firstCM;
    }
    
    @IsTest
    static void testUpdateEventOptOut() {
        Campaign c = [SELECT id FROM Campaign LIMIT 1];
        CampaignMember cm = [SElECT id,Subscriber__c, LeadID FROM CampaignMember where campaignId =: c.Id LIMIT 1];
        if (cm != null) {
            cm.Subscriber__c = !cm.Subscriber__c;
            update cm;
            Lead l = [SELECT id, Event_Opt_Out__c FROM Lead where id =: cm.LeadId];
            assert.areEqual(cm.Subscriber__c, l.Event_Opt_Out__c);
        }
    }
}