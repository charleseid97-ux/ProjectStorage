/**
 * Created by Saad on 24/08/2021.
 */
@IsTest
public with sharing class BATCH013_LeadLastInteractionTest
{
    private static final String QUERY_LEAD = '' +
            'SELECT ' +
            '   Id, ' +
            '   CreatedDate, ' +
            '   Last_Interaction__c ' +
            ' FROM ' +
            '       Lead';

    private static final Datetime aDATETIME = Datetime.newInstance(2021, 06, 30, 19, 0, 0);

    @TestSetup
    private static void setup()
    {
        Id RecordTypeIdLead = Schema.SObjectType.Lead.getRecordTypeInfosByName().get('Website Lead').getRecordTypeId();
        Lead ld = TestFactory.getSimpleLead();
        ld.RecordTypeId = RecordTypeIdLead;
        ld.TECH_WebSiteID__c = '58263';
        insert ld;
        Test.setCreatedDate(ld.Id, DateTime.newInstance(2012,12,12));


        Campaign camp1 = new Campaign
                (
                        recordtypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events'),
                        Status = 'Live',
                        Name='TestCampaign',
                        Sales_Team__c='FR',
                        Type='Survey',
                        Event_Local_Start_Time__c = '2017/05/09 12:00',
                        Event_Local_End_Time__c = '2017/05/09 18:00',
                        Start_Date_Time__c= aDATETIME,
                        End_Date_Time__c= aDATETIME
                );

        insert camp1;

        CampaignMemberStatus cms1 = new CampaignMemberStatus(CampaignId = camp1.Id, HasResponded=false,
                Label = 'Attended', SortOrder = 3, isDefault = true);

        insert cms1;

        Category_Event__c categ = new Category_Event__c(
                Name = 'Category 1',
                Campaign__c = camp1.Id,
                Tech_Category_Event_ID_Etouches__c = '1234');

        insert categ;

        CampaignMember campMember = new CampaignMember(
                LeadId = ld.Id,
                CampaignId = camp1.Id,
                Status = 'Attended',
                Category_Event_lookup__c = categ.Id,
                TECH_ID_Subscriber__c = '752809');

        insert campMember;
    }

    @IsTest
    private static void testBehavior()
    {
        Test.startTest();
        BATCH013_LeadLastInteraction batch = new BATCH013_LeadLastInteraction(QUERY_LEAD);
        Database.executeBatch(batch);
        Test.stopTest();

        Datetime aLeadLastInteraction = [SELECT Id, Last_Interaction__c FROM Lead LIMIT 1].Last_Interaction__c;
        System.assertEquals(aDATETIME, aLeadLastInteraction);
    }
}