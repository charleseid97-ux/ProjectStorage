/** 
* @author Pape DIOUF
* @date Creation 02/09/2016
* @date Modification 05/09/2016
* @description : EM001_Lead Unit Test Class 
*/
@isTest
private class EM001_LeadTest {
    
    static testMethod void getListByIdsTest() {
        
        // Data Preparation
        Lead lead = TestFactory.getSimpleProSpaceLead();
        Insert lead;
        
        // Test User creation
        
        // Backup Line Not to Delete
        //User u = TestFactory.getStandardCarmignacUser();
        User u = [Select id from User where Id = :UserInfo.getUserId()];
        
        //insert u;
        
        // Test Begin
        System.test.startTest();       
        
        System.runAs(u){
            // Methods Calls
            List<Lead> found_leadList =  EM001_Lead.getListByIds(new Set<String>{lead.Id});
            List<Lead> No_leadList =  EM001_Lead.getListByIds(new Set<String>{'0064E000002WwK4'}); // Inexistant ID for Lead Entity
            
            // Results verification
            System.assertEquals(found_leadList.size(), 1);
            System.assertEquals(found_leadList.get(0).Id, lead.Id);
            System.assertEquals(No_leadList.size(), 0);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    
    static testMethod void getListByTechSunIds() {
        
        // Data Preparation
        Lead lead = TestFactory.getSimpleProSpaceLead();
        Insert lead;
        
        // Test User creation
        // Backup Line Not to Delete
        //User u = TestFactory.getStandardCarmignacUser();
        User u = [Select id from User where Id = :UserInfo.getUserId()];
        
        
        //insert u;
        
        // Test Begin
        System.test.startTest();       
        
        System.runAs(u){
            // Methods Calls
            // methdos : getListByTechSunIds
            
            Integer tempInt = Integer.valueof(lead.Technical_ID__c);
            
            List<Lead> found_leadList =  EM001_Lead.getListByTechSunIds(new Set<Integer>{tempInt});
            List<Lead> No_leadList =  EM001_Lead.getListByTechSunIds(new Set<Integer>{20023641}); // Inexistant Technical_ID__c for Lead Entity
            
            // Results verification
            System.assertEquals(found_leadList.size(), 1);
            System.assertEquals(found_leadList.get(0).Technical_ID__c, lead.Technical_ID__c);
            System.assertEquals(No_leadList.size(), 0);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    
    static testMethod void getListByPersoMail() {
        
        // Data Preparation
        Lead lead = TestFactory.getSimpleProSpaceLead();
        Insert lead;
        
        // Test User creation
        
        ///Backup Line Not to Delete
        // User u = TestFactory.getStandardCarmignacUser();
        //insert u;
        User u = [Select id from User where Id = :UserInfo.getUserId()];
        
        // Test Begin
        System.test.startTest();       
        
        System.runAs(u){
            // Methods Calls
            // methdos :getListByPersoMails
            
            
            
            List<Lead> found_leadList =  EM001_Lead.getListByPersoMails(new Set<String>{lead.PersonalEmail__c});
            List<Lead> No_leadList =  EM001_Lead.getListByPersoMails(new Set<String>{'doestnotexit@mail.test'}); // Inexistant Technical_ID__c for Lead Entity
            
            // Results verification
            System.assertEquals(found_leadList.size(), 1);
            System.assertEquals(found_leadList.get(0).PersonalEmail__c, lead.PersonalEmail__c);
            System.assertEquals(No_leadList.size(), 0);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    static testMethod void getListByProMail() {
        
        // Data Preparation
        Lead lead = TestFactory.getSimpleProSpaceLead();
        Insert lead;
        
        // Test User creation
        ///Backup Line Not to Delete 
        // User u = TestFactory.getStandardCarmignacUser();
        User u = [Select id from User where Id = :UserInfo.getUserId()];
        
        //insert u;
        
        // Test Begin
        System.test.startTest();       
        
        System.runAs(u){
            // Methods Calls
            // methdos :getListByProMails
            
            
            
            List<Lead> found_leadList =  EM001_Lead.getListByProMails(new Set<String>{lead.Email});
            List<Lead> No_leadList =  EM001_Lead.getListByProMails(new Set<String>{'doestnotexit@mail.test'}); // Inexistant Technical_ID__c for Lead Entity
            
            // Results verification
            System.assertEquals(found_leadList.size(), 1);
            System.assertEquals(found_leadList.get(0).Email, lead.Email);
            System.assertEquals(No_leadList.size(), 0);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    
    static testMethod void testGetListLeadFromEmail() {
        
        // Data Preparation
        
        
        Lead leadtest = TestFactory.getSimpleProSpaceLead();
        Insert leadtest;
        
        Lead leadtest2 = TestFactory.getSimpleProSpaceLead();
        Insert leadtest2;
        
        // Lead leadtest3 = TestFactory.getSimpleProSpaceLead();
        // Insert leadtest3;
        
        // Test User creation
        
        ///Backup Line Not to Delete 
        // User u = TestFactory.getStandardCarmignacUser();
        User u = [Select id from User where Id = :UserInfo.getUserId()];
        
        //insert u;
        
        // Test Begin
        System.test.startTest();       
        
        System.runAs(u){
            // Methods Calls
            // methdos :getListLeadsFromEmails
            
            List<String> listEmails = new List<String>();
            
            // List<String> listEmails2 = new List<String>();
            
            List<String> listEmails3 = new List<String>();
            
            listEmails.add(leadtest.Email);
            
            listEmails.add(leadtest2.Email);
            
            // listEmails2.add(leadtest3.Email);
            
            listEmails3.add('Testoldcarmignac@doesnotexits.com');
            
            list<Lead> testList1 = EM001_Lead.getListLeadsFromEmails(listEmails);
            
            // list<Lead> testList2 = EM001_Lead.getListLeadsFromEmails(listEmails2);
            
            list<Lead> testList3 = EM001_Lead.getListLeadsFromEmails(listEmails3);
            
            // Results verification
            
            System.assertEquals(testList1.size(), 2);
            // System.assertEquals(testList2.size(), 1);
            System.assertEquals(testList3.size(), 0);
            
            
            
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        
        // Test End 
        System.test.stopTest();
    }
    
    
    static testMethod void testSetProfil() {
        
        // Data Preparation
        
        Lead temp = TestFactory.getSimpLeadTestSetProfile();
        
        
        Insert temp;
        
        // Test User creation
        
        ///Backup Line Not to Delete 
        // User u = TestFactory.getStandardCarmignacUser();
        User u = [Select id from User where Id = :UserInfo.getUserId()];
        //insert u;
        
        // Test Begin
        System.test.startTest();       
        
        System.runAs(u){
            // Methods Calls
            // methdos :getListByPersoMails
            
            temp = EM001_Lead.setProfile(temp);
            
            
            // Results verification
            System.assertEquals(temp.WebsiteRole__c, EM001_Lead.WEBSITEROLE_PROSPACETEMP);
            System.assertEquals(temp.TrialStatus__c,  EM001_Lead.STATUS_WAITINGFORVALIDATION);
            System.assertEquals(temp.Status, EM001_Lead.STATUS_NEW);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
    
    static testMethod void  testgetTechnicalIDById(){
        
        
        // Data Preparation
        
        Lead temp = TestFactory.getSimpleProSpaceLead();
        
        
        Insert temp;
        
        // Test User creation
        
        ///Backup Line Not to Delete 
        // User u = TestFactory.getStandardCarmignacUser();
        User u = [Select id from User where Id = :UserInfo.getUserId()];
        //insert u;
        
        // Test Begin
        System.test.startTest();       
        
        System.runAs(u){
            // Methods Calls
            // methdos :getTechnicalIDById
            
            String tempTest = EM001_Lead.getTechnicalIDById(temp.Id);
            
            String goodvalue = String.valueof(temp.Technical_ID__c);
            
            // Results verification
            System.assertEquals(tempTest, goodvalue);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
    
}