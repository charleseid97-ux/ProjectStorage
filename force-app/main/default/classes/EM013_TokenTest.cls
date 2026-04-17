/** 
* @author Adolphe SONKO
* @date Creation 08/04/2017
* @date Modification 08/04/2017
* @description : EM013_Token Test Unit Test Class 
*/

@isTest
public class EM013_TokenTest {
	public static final String NewToken = '1234569872';
    
    static testMethod void getTokenTest() {       
        
        
        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            // Data Preparation
            WebserviceParameters__c param = new WebserviceParameters__c(Name ='EtouchesAPI', accountid__c ='4740',Endpoint__c='https://qa.eiseverywhere.com/api/v2', key__c='e3ffd78336f06f924a3ffc00b8f43994c68f4aa7');
            insert param;
            EM013_Token.setToken(NewToken);
            EM013_Token.getToken();
           
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
    }
}