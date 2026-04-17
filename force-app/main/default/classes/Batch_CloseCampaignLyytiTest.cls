/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 30-12-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
@IsTest
private class Batch_CloseCampaignLyytiTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test campaigns
        List<Campaign> campaigns = new List<Campaign>();
        Date d =  Date.today().addDays(-1);
        String year = String.valueOf(d.year()); 
        String month = (d.month() < 10 ? '0' : '') + String.valueOf(d.month()); 
        String day = (d.day() < 10 ? '0' : '') + String.valueOf(d.day()); 
         
        // Campaign that should be processed (yesterday's date)
        Campaign campaignToClose = new Campaign(
            recordtypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events'),
                Status = 'Live',
                Name='TestCampaign',
                Sales_Team__c='FR',
                Type='Survey',
                Event_Local_Start_Time__c = '2024/05/09 12:00',
                Start_Date_Time__c= Datetime.now(),
                End_Date_Time__c= Date.today().addDays(1),
                LyytiId__c = '1704919',
                Tech_ParticipantType__c=61909330,
                Event_Local_End_Time__c = year + '/' + month + '/' + day + ' 23:59'
        );
        campaigns.add(campaignToClose);
                
        insert campaigns;

        List<CampaignMemberStatus> statuses = new List<CampaignMemberStatus>{ 
            new CampaignMemberStatus(CampaignId = campaignToClose.Id, Label = 'Invited', HasResponded = false, IsDefault = true), 
            new CampaignMemberStatus(CampaignId = campaignToClose.Id, Label = 'Cancelled', HasResponded = false, IsDefault = false), 
            new CampaignMemberStatus(CampaignId = campaignToClose.Id, Label = 'Attended', HasResponded = false, IsDefault = false), 
            new CampaignMemberStatus(CampaignId = campaignToClose.Id, Label = 'No Show', HasResponded = false, IsDefault = false), 
            new CampaignMemberStatus(CampaignId = campaignToClose.Id, Label = 'Confirmed', HasResponded = true, IsDefault = false) }; 
        insert statuses;

        Category_Event__c category = new Category_Event__c(Name='default', Campaign__c=campaignToClose.Id);
        insert category;
        
        
        
        // Create test campaign members
        List<CampaignMember> members = new List<CampaignMember>();
        
        Account acc = TestDataFactory.getAccount();
        insert acc;
        
        Contact con = TestDataFactory.getContact();
        con.AccountId = acc.Id;
        insert con;
        
        // Add members to the campaign that should be processed
        CampaignMember member1 = new CampaignMember(
            CampaignId = campaignToClose.Id,
            ContactId = con.Id,
            Status = 'Invited',
            Category_Event_lookup__c = category.Id,
            Cancelled__c = true
        );
        members.add(member1);
        
        insert members;
    }
    
    @IsTest
    static void testBatchExecution() {
        // Get the number of campaigns before running the batch
        Integer initialCampaignCount = [SELECT COUNT() FROM Campaign WHERE Status = 'Closed'];
        Integer initialMemberCount = [SELECT COUNT() FROM CampaignMember WHERE Status = 'Cancelled'];
        
        Test.startTest();
        
        // Run the batch
        BATCH_CloseCampaignLyyti batchJob = new BATCH_CloseCampaignLyyti();
        Database.executeBatch(batchJob);
        
        Test.stopTest();
        
        // Verify the results
        List<Campaign> processedCampaigns = [
            SELECT Id, Status, 
                   (SELECT Id, Status FROM CampaignMembers WHERE Cancelled__c = true)
            FROM Campaign 
            WHERE Event_Local_End_Time__c LIKE :(batchJob.formatDate(Date.today().addDays(-1)))+'%'
        ];
        
        // Assertions
        System.assertEquals(1, processedCampaigns.size(), 'Should have processed 1 campaign');
        System.assertEquals('Closed', processedCampaigns[0].Status, 'Campaign status should be Closed');
        
        // Verify campaign members
        List<CampaignMember> updatedMembers = [
            SELECT Id, Status 
            FROM CampaignMember 
            WHERE CampaignId = :processedCampaigns[0].Id
        ];
        
        System.assertEquals(1, updatedMembers.size(), 'Should have 1 campaign member');
        System.assertEquals('Cancelled', updatedMembers[0].Status, 'Member status should be Cancelled');
    }
    
    @IsTest
    static void testFormatDate() {
        BATCH_CloseCampaignLyyti batchJob = new BATCH_CloseCampaignLyyti();
        Date testDate = Date.newInstance(2023, 1, 5);
        
        Test.startTest();
        String formattedDate = batchJob.formatDate(testDate);
        Test.stopTest();
        
        System.assertEquals('2023/01/05', formattedDate, 'Date format should match expected pattern');
    }
}