@isTest
public class CaseTriggerTest {
    @isTest static void testSetup() {
        Map<Id, Case> newMap = new Map<Id, Case>();
        CaseTriggerHandler cth = new CaseTriggerHandler();
        cth.BeforeDelete(newMap);
        cth.BeforeInsert(new List<Case>());
        cth.BeforeUpdate(newMap, newMap);
    }
    
    @isTest static void testCaseWithNDA() {
        NDA__c nda = new NDA__c();
        nda.Active__c = True;
        nda.Name = 'New NDA Test';
        nda.Status__c = 'Pending signature';
        insert nda;
        
        Account acc = new Account();
        acc.Name = 'New Account Test';
        acc.BusinessDevelopmentRegion__c = 'BP_FR';
        acc.BillingCountry = 'France';
        acc.LegalForm__c = 'Individual Person';
        insert acc;
        
        Case c = new Case();
        c.AccountId = acc.id;
        c.Type = 'Data Solution';
        c.Status = 'New';
        c.Origin = 'Email';
        c.Due_date__c = date.today().addDays(15);
        c.NDA__c = nda.id;
        insert c;
        
        //Add Share Class
        //Add case Product
        
        NDA__c secondNDA = new NDA__c();
        nda.Active__c = True;
        nda.Name = 'Second NDA';
        nda.Status__c = 'Pending signature';
        insert secondNDA;
        
        c.NDA__c = secondNDA.id;
        update c;
        
        delete c;
        
        //check company name on both nda
        //check nda product on both nda
    }
}