@isTest(SeeAllData=true)
public   class ObjectUtilTest {
    
     static testMethod void ObjectUtilTest(){
			
		User u = TestFactory.getStandardCarmignacUser();
			//insert u;
			
       	Contact contact = new contact();
        List<Contact> listContact = new List<Contact>();
			
			//Test Begin
			System.test.startTest();       
			
			System.runAs(u){
				ObjectUtil.getTECH_WhichWebService_Values();
                ObjectUtil.isEmpty(1 == 1);
                ObjectUtil.isEmpty(contact);
                ObjectUtil.isEmpty('test');
                ObjectUtil.getPicklistValues('Contact', 'TECH_WhichWebService__c');
                ObjectUtil.getProfile();
                ObjectUtil.insertRecords(listContact);
                ObjectUtil.updateRecords(listContact);
                ObjectUtil.deleteRecords(listContact);
			}
				// Test End 
			System.test.stopTest();	
					
			
		 
		 //repeat the same for the rest of classes.
		} 
}