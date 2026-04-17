/** 
* @author Briag Guemard
* @date Creation 11/04/2017
* @date Modification 11/04/2016
* @description : EM020_UserTest Unit Test Class 
*/
@isTest
private class EM020_UserTest {
    
    // BGU 11/04/2017 Not working
    static testMethod void getUserbyId() {

        // Test User creation 
        User u = TestFactory.getCarmignacUserTestApex();
        
        System.runAs(u){
            // Test Begin
            System.test.startTest(); 
            TestFactory.createCustomSettings();
            User user = TestFactory.getStandardCarmignacUser();
            
            List<Id> UserIdList = new  List<Id>();
            UserIdList.add(user.Id);
            // Methods Calls
            List<User> testList = EM020_User.getUserbyId(UserIdList);
            User testUser = EM020_User.getListByName('Briag Guemard');
            
            // Results verification
            System.assertEquals(testList.size(), 1);
            //     System.assertEquals(testUser.Id, u.Id);
            
            // Governer limits tests
            System.assert(Limits.getQueries() < 0.9 * Limits.getLimitQueries());
        }
        
        // Test End 
        System.test.stopTest();
        
        
        
    }
    
}