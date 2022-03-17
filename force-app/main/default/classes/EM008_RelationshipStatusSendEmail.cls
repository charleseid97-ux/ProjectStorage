/** 
* @author: Adolphe SONKO
* @date : Création 19/09/2016
* @date : Modification 19/09/2016
* @description : This Class controls the sending of email for Relationship Status entity.
*/

public class EM008_RelationshipStatusSendEmail {

	  private static String CLASS_NAME = 'EM008_RelationshipStatusSendEmail';
      private static final String EmailHeadofCountry = '_Head_of_CountryprofessionalClients@carmignac.com';
   //  private static final String EmailHeadofCountrytest = 'adolphe.sonko.external@carmignac.com';
    
      /**
      * @author : Adolphe SONKO
      * @date : Création 19/09/2016
	  * @date : Modification 19/09/2016 
      * @description : This method aims at sending email only for HOC
      */ 
      public static void RelationshipStatus_EmailAlert1() {

           List<Messaging.SingleEmailMessage> listmails = new List<Messaging.SingleEmailMessage>(); 
          
           //New instance of a single email message       
           Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
           // Who you are sending the email to        
           mail.setToAddresses(new String[] {EmailHeadofCountry}) ;
           mail.setBccSender(false);        
           mail.setUseSignature(false);        
          // The email you want to send
           mail.setPlainTextBody('A Relationship Status has been updated on GAM or company related to a GAM you are related to as HOC. ');  
          // Send by who
           mail.setSenderDisplayName('Adolphe Sonko');       
           mail.setSaveAsActivity(false);
        
           listmails.add(mail);
          
       	   if(Test.isRunningTest()){

            system.debug('Relationship Status Email Alert 1 Tested successfully');
            
           }else {
           		Messaging.sendEmail(listmails);
           }
         
		   
      }

      /**
       * @author : Adolphe SONKO
       * @date : Création 19/09/2016
       * @date : Modification 19/09/2016 
       * @description : This method aims at sending email only for  all owners of local accounts related to the GAM
       */ 
       public static void RelationshipStatus_EmailAlert2(Set<String> Company) {

                 List <Id> targetObjectIds = new List <Id> ();
                 List <User> targetObjects = new List <User> ();
                 List <Id> targetFieldIds1 = new List <Id> ();
                 List <Id> targetFieldIds2 = new List <Id> ();
                 integer i = 0;
               
                List<Messaging.SingleEmailMessage> listmails = new List<Messaging.SingleEmailMessage>(); 
               
                List<Account> listAccounts2 = getListOfAccounts(Company);
                for(Account a : listAccounts2)
                {
                        targetFieldIds2.add(a.OwnerId) ;
                    
                        //New instance of a mass email message    
                        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    
                        // Who you are sending the email to
                        mail.setTargetObjectId(targetFieldIds2[i]);  
                        i++;
                        mail.setBccSender(false);               
                        mail.setUseSignature(false);                
                    //	The email you want to send
                        mail.setPlainTextBody('A Relationship Status has been updated on GAM or company related to a GAM you are related to as Owner. '); 
                    //  Send by who
                        mail.setSenderDisplayName('Adolphe Sonko');            
                        mail.setSaveAsActivity(false);
                        
                        listmails.add(mail);

                 }  
           
           	if(Test.isRunningTest()){

            	system.debug('Relationship Status Email Alert 2 Tested successfully');
            
        	} else {
               Messaging.sendEmail(listmails);
            }     
     }

    /**
     * @author : Adolphe SONKO
     * @date : Création 14/09/2016
	 * @date : Modification 14/09/2016 
     * @description : This method performs an SQL query on the user to repatriate its data from an ID list.
     * @param : Set<String> Company This parameter is a list of unique identifiers of company.
     * @return : List<account> The returned item is a list of Company.
     */  
    public static List<Account> getListOfAccounts(Set<String> Company){
        
        String methodName = 'getListOfAccounts';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Company] :' + Company);
        
        List<Account> listAccounts = DM008_RelationshipStatus.getListOfAccounts(Company);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listAccounts);
        return listAccounts; 
    }    
    
     /**
     * @author : Adolphe SONKO
     * @date : Création 13/09/2016
	 * @date : Modification 13/09/2016 
     * @description : This method performs an SQL query on the user to repatriate its data from an ID list.
     * @param : Set<id> UserIds This parameter is a list of unique identifiers of user.
     * @return : List<user> The returned item is a list of Users.
     */  
 /*   public static List<User> getListByIds(Set<Id> UserIds){
        
        String methodName = 'getListByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[UserIds] :' + UserIds);
           
        List<User> listUsers = DM008_RelationshipStatus.getListByIds(UserIds);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listUsers);
        return listUsers; 
    }  */
  

}