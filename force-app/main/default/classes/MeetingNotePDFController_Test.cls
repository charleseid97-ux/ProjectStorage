@isTest
public class MeetingNotePDFController_Test 
{
  @isTest static void test1()
    {
        //Insert test organization
        Account a = new Account(
                      Name='Test Account',
                                BillingStreet='Fake Street',
                                BillingCountry='United States'
                               );
        insert a;
        
        //insert test meeting note 
        Meeting_Note__c m = new Meeting_Note__c(
                              Name='Test Meeting Note',
                              Date__c=date.newInstance(2019,01,01)
                            );
        insert m;
        
        //attach the organization to the meeting note
        insert new Meeting_Link__c(
                        Name='Test Meeting Note Link',
                        Account__c = a.Id,
                        Meeting_Note__c =m.Id
                        );
        
        Test.setCurrentPage(Page.MeetingNotePDF);       
        // Add parameters to page URL
        ApexPages.currentPage().getParameters().put('id', m.Id);
    
        Test.startTest();
        MeetingNotePDFController controller = new MeetingNotePDFController();
        Test.stopTest();
        
        //Assert that the getters are returning values
        System.assertNotEquals(NULL,controller.getMeetingNote());
        System.assertNotEquals(NULL,controller.getMyDomainName());     
    }
}