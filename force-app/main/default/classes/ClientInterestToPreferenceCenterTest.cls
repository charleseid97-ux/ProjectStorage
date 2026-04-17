@isTest
public class ClientInterestToPreferenceCenterTest {
    @TestSetup
    static void makeData(){
     
        Strategy__c strat = new Strategy__c();
        strat.Name = 'ALM ES CI';
        strat.AssetClass__c='Equity';
        strat.SubAssetClass__c='Global';
        strat.Code__c = 'CAELS';
        insert strat;
        
        Meeting_Note__c mn = new Meeting_Note__c();
        mn.Date__c = Date.today();
        insert mn;

        Contact cntct = new Contact(FirstName = 'FirstName3', LastName = 'LastName3', Email = 'Email3@domain.com', Phone = '0111111111', Source__c = '-',WebsiteCountry__c='FR');
        insert cntct;
        
        Event e = new Event();
        e.Meeting_Note__c = mn.Id;
        e.DurationInMinutes = 10;
        e.ActivityDateTime = Datetime.now();
        insert e;

        EventRelation er = new EventRelation();
        er.RelationId = cntct.Id;
        er.EventId = e.Id;
        er.IsInvitee = false;
        er.IsParent = true;
        er.IsWhat= false;
        insert er;
    }

    @isTest
    static void testUpdateinsertClientInterest() {
        Meeting_Note__c meeting = [SELECT Id FROM Meeting_Note__c limit 1];
        Strategy__c strat = [SELECT Id FROM Strategy__c limit 1];
         
        Test.startTest();

        ClientInterest__c ci = new ClientInterest__c();
        ci.Strategy__c = strat.Id;
        ci.MeetingNote__c = meeting.Id;
        ci.Interest__c = 5;
        insert ci;
        Test.stopTest();

        System.assertEquals(True, [SELECT Carmignac_Alt_European_Long_Short_CAELS__c FROM Contact limit 1].Carmignac_Alt_European_Long_Short_CAELS__c);
        
        ci.Interest__c = 1;
        update ci;
        System.assertEquals(False, [SELECT Carmignac_Alt_European_Long_Short_CAELS__c FROM Contact limit 1].Carmignac_Alt_European_Long_Short_CAELS__c);
        delete ci;

    }
}