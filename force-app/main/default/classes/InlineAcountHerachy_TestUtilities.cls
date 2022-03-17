/**
* Generate the enviroment for the Unit Tests
* @author Sebastian Muñoz - Force.com Labs
* @createddate 06/08/2010
*/

public with sharing class InlineAcountHerachy_TestUtilities{
	
	//Lists
	public List<User>		 	testUserList { get; set; }
 	public List<Account>	 	testAccList  { get; set; }
 	public List<Lead>		 	testLeadList { get; set; }
 	public List<Opportunity>  	testOppList  { get; set; }
 	public List<Contact>	 	testConList  { get; set; }
 	public List<Task>		 	testTaskList { get; set; }
	
	//Objects
	public User			testUser { get; set; }
 	public Account		testAcc  { get; set; }
 	public Lead			testLead { get; set; }
 	public Opportunity	testOpp  { get; set; }
 	public Contact		testCon  { get; set; }
 	public Task			testTask { get; set; }
 	
 	
  	/**
  	* Check over all object field if the loged User has right over Object
  	* @parms sObject , CRUD check ( isCreateable, isDeleteable, isUpdateable ) 
  	* @return Boolean
  	*/
  	public Boolean checkObjectCrud( String objName, Set<String> fieldsToCheck, String crudType ){  		
  		
  		// Get the global describe
        Schema.DescribeSObjectResult objectResult = Schema.getGlobalDescribe().get( objName ).getDescribe();

  		for( String fieldToCheck : objectResult.fields.getMap().keySet() ){	
  			
  			Schema.DescribeFieldResult current_field = objectResult.fields.getMap().get( fieldToCheck ).getDescribe();
  			
  			if( fieldsToCheck.contains( current_field.getName() ) ) {
  			
	  			if( 'create'.equalsIgnoreCase( crudType ) && !current_field.isCreateable()){
		  			return false;
		  		}
		  		else if( 'update'.equalsIgnoreCase( crudType ) && !current_field.isUpdateable() ){
		  			return false;
		  		}
  			}
  		}
  		
  		return true;
  	}
  	
  	/**
  	* Create Account's
  	* @params accountToCreate ( the total amount of account )
  	*/
  	public void createAccounts( Integer accountToCreate, Set<String> fieldsToCheck ){

  		List<Account> auxList = new List<Account>();
  		
  		for( Integer i = 1; i <= accountToCreate; i++ ){
  			Account accAux 				= new Account();
  			accAux.Name 				= this.createRandomWord(i);
  			//accAux.ShippingStreet 		= '1 Main St.';
  			//accAux.ShippingState		= 'France';
  			//accAux.ShippingPostalCode	= '12345';
  			//accAux.ShippingCountry		= 'France';
  			//accAux.ShippingCity			= 'Anytown';
  			//accAux.Description			= 'This is a test account';
  			//accAux.BillingStreet		= '1 Main St.';
  			//accAux.BillingState			= 'VA';
  			//accAux.BillingPostalCode	= '12345';
  			accAux.BillingCountry 		= 'France';
  			//accAux.BillingCity			= 'Anytown';
  			//accAux.AnnualRevenue		= 10000;
  			//accAux.ParentId				= null;
            accAux.LegalForm__c = 'SARL (Société Anonyme à Responsabilité Limitée)';
            accAux.BusinessDevelopmentRegion__c = 'BP_FR';
			auxList.add( accAux );
  		}
  		
  		if ( this.checkObjectCrud('Account', fieldsToCheck, 'create') ){
  			try{
  				insert auxList;
  			}
  			catch( Exception ex ){
 				System.assert( false ,'Pre deploy test failed, This may be because of custom validation rules in your Org. You can check ignore apex errors or temporarily deactivate your validation rules for Accounts and try again.');
 			}
 			this.testAccList = new List<Account>();
 			this.testAccList.addAll( auxList );
  		}
  		else{
  			System.Assert(false , 'You need right over Account Object');
  		}
  	}
  	
  	/**
    * Method for Update a Account
    * @param fieldsToCheck
    */
  	public void updateAccountList( Set<String> fieldsToCheck ){ 
  		
  		if ( this.checkObjectCrud('Account', fieldsToCheck, 'create') && !this.testAccList.isEmpty() ){
  			try{
  				update this.testAccList;
  			}
  			catch( Exception ex ){
 				System.assert( false ,'Pre deploy test failed, This may be because of custom validation rules in your Org. You can check ignore apex errors or temporarily deactivate your validation rules for Accounts and try again.');
 			}
  		}
  		else{
  			System.Assert(false , 'You need right over Account Object');
  		}
  	}
  	
  	/**
    * Random words are required for testing 
    * as you will likely run into any word I can insert
    * during a test class and produce false test results.
    */
    public String createRandomWord(Integer i){
      
        String ret = 'word' + String.valueOf(math.rint( math.random() * 100000 ));
      
        //String ret = createRandomWText() + String.valueOf(math.rint( math.random() * 100000 ) + math.rint( math.random() * 100000 ) ) + createRandomWText();
        
      return ret;
    }
    
    
    public String createRandomWText(){

      Double ret = math.rint( math.random() * 4 );
      Integer retInt = Integer.valueOf(ret);
      String retValue = 'Test';
        
      if(retInt == 0)
          retValue = 'mot';
      if(retInt == 1)
          retValue = 'word';    
      if(retInt == 2)
          retValue = 'Salesforce';     
      if(retInt == 2)
          retValue = 'Microsoft';    
      
      return retValue;
    }
    
    
    
}