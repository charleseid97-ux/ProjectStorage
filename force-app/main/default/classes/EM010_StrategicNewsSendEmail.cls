/** 
* @author: Adolphe SONKO
* @date : Création 19/09/2016
* @date : Modification 19/09/2016
* @description : This Class controls the sending of email for Strategic News entity.
*/

public class EM010_StrategicNewsSendEmail {
    
     private static String CLASS_NAME = 'EM010_StrategicNewsSendEmail';
     private static final String EmailHeadofCountry = '_Head_of_CountryprofessionalClients@carmignac.com';
   //  private static final String EmailHeadofCountrytest = 'frederic.freyermuth.external@carmignac.com';
     private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('User');
    
    /**
       * @author : Adolphe SONKO
       * @date : Création 19/09/2016
       * @date : Modification 19/09/2016 
       * @description : This method aims at sending email only for  all owners of local accounts related to the GAM
       */ 
       public static void StrategicNews_EmailAlert1(Set<String> Company) {
           
    
             List <Id> targetObjectIds = new List <Id> ();
             List <User> targetObjects = new List <User> ();
             List <Id> targetFieldIds1 = new List <Id> ();
             List<Messaging.SingleEmailMessage> listmails = new List<Messaging.SingleEmailMessage>(); 

             integer i = 0;
           
             List<Account> listAccounts2 = getListOfAccounts(Company);
             for(Account a : listAccounts2)
             {
                    targetFieldIds1.add(a.OwnerId) ;
                        
                   //New instance of a single email message    
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                
                    // Who you are sending the email to
                    mail.setTargetObjectId(targetFieldIds1[i]);  
                    i++;
                    mail.setBccSender(false);                
                    mail.setUseSignature(false);     
                 // The email you want to send
                    mail.setPlainTextBody('A new Strategic News have been published on GAM you are related to. Please check your chatter notifications in Salesforce or go directly to GAM you are following for more information'); 
                 // Send by who
                    mail.setSenderDisplayName('Strategic News Alert');               
                    mail.setSaveAsActivity(false);
                	
                    listmails.add(mail);
		
             } 
            
           		if (Test.isRunningTest()){

            		system.debug('Strategic News Email Alert 1 Tested successfully');
            
                }else{
                    Messaging.sendEmail(listmails); 
                }
             
     }
    
    /**
      * @author : Adolphe SONKO
      * @date : Création 19/09/2016
      * @date : Modification 19/09/2016 
      * @description : This method aims at sending email only for HOC
      */
    //Only the Hoc
    public static void StrategicNews_EmailAlert2() {
		

        	 
            List<Messaging.SingleEmailMessage> listmails = new List<Messaging.SingleEmailMessage>(); 
           
           //New instance of a single email message        
           Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
           // Who you are sending the email to
           mail.setToAddresses(new String[] {EmailHeadofCountry}) ;          
           mail.setBccSender(false);        
           mail.setUseSignature(false);        
        //  The email you want to send
           mail.setPlainTextBody('A new Strategic News have been published on GAM you are related to as HOC. Please check your chatter notifications in Salesforce or go directly to GAM you are following for more information');      
        // Send by who
           mail.setSenderDisplayName('Strategic News Alert');    
           mail.setSaveAsActivity(false);
                
           listmails.add(mail);

        
            	if (Test.isRunningTest()){

            		system.debug('Strategic News Email Alert 2 Tested successfully');
            
                }else{
                    Messaging.sendEmail(listmails); 
                }

     }
    
    
        /**
      * @author : Adolphe SONKO
      * @date : Création 19/09/2016
      * @date : Modification 19/09/2016 
      * @description : This method aims at sending email to all the users part of the same Business Development Region as the company
      */
    //All the users part of the same Business Development Region as the company
    public static void StrategicNews_EmailAlert3(String Company) {
		

            List <Id> targetFieldIds2 = new List <Id> ();
            List <User> targetObjects2 = new List <User> ();
            
            // retrieve Business dev region of the company
            List <Account> listAccounts3 = getAccountsByIds(new Set<String> {Company});
            
            if(listAccounts3 != null && !ObjectUtil.isEmpty((listAccounts3.get(0)).BusinessDevelopmentRegion__c)){
                
                integer i = 0;         
                String BusDevRegion = (listAccounts3.get(0)).BusinessDevelopmentRegion__c;
    
    
                targetObjects2 = getListByBusDevRegion(BusDevRegion);
                
                //BGU OLD 30/12
                // targetObjects2 = getListByBusDevRegion(new Set<String> {BusDevRegion});
                 
                List<Messaging.SingleEmailMessage> listmails = new List<Messaging.SingleEmailMessage>(); 
                for(User us : targetObjects2) {
                    
                    targetFieldIds2.add(us.Id);
                    
                    //New instance of a single email message    
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    
                    // Who you are sending the email to
                    mail.setTargetObjectId(targetFieldIds2[i]);  
                    i++;
                    mail.setBccSender(false);                       
                    mail.setUseSignature(false); 
                    //  The email you want to send
                    mail.setPlainTextBody('A new Strategic News have been published on your Business Region.');    
                    // Send by who
                    mail.setSenderDisplayName('Strategic News Alert');                     
                    mail.setSaveAsActivity(false);
                    
             
                    listmails.add(mail);
                    

                }
                
                if (Test.isRunningTest()){

            		system.debug('Strategic News Email Alert 3 Tested successfully');
            
                }else{
                    Messaging.sendEmail(listmails); 
                }
                
            }      
        
     }
    
      /**
     * @author : Adolphe SONKO
     * @date : Création 14/09/2016
     * @date : Modification 14/09/2016 
     * @description : This method performs an SQL query on the account to repatriate its data from an ID list.
     * @param : Set<String> Company This parameter is a list of unique identifiers of user.
     * @return : List<Account> The returned item is a list of Accounts.
     */  
    public static List<Account> getListOfAccounts(Set<String> Company){
        
        String methodName = 'getListOfAccounts';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Company] :' + Company);
           
        List<Account> listAccounts = DM010_StrategicNews.getListOfAccounts(Company);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listAccounts);
        return listAccounts; 
    }

    /**
     * @author : Adolphe SONKO
     * @date : Création 14/09/2016
     * @date : Modification 14/09/2016 
     * @description : This method performs an SQL query on the account to repatriate its data from an ID list.
     * @param : Set<String> Company This parameter is a list of unique identifiers of user.
     * @return : List<Account> The returned item is a list of Accounts.
     */  
    public static List<Account> getAccountsByIds(Set<String> Company){
        
        String methodName = 'getAccountsByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Company] :' + Company);
           
        List<Account> listAccounts = DM010_StrategicNews.getAccountsByIds(Company);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listAccounts);
        return listAccounts; 
    }
    
    /**
     * @author : Adolphe SONKO
     * @date : Création 13/09/2016
     * @date : Modification 13/09/2016 
     * @description : This method performs an SQL query on the user to repatriate its data from an ID list.
     * @param : Set<String> BusDevRegion This parameter is the Business developer region.
     * @return : List<user> The returned item is a list of Users.
     */  
        //BGU OLD 30/12
        //public static List<User> getListByBusDevRegion(Set<String> BusDevRegion){
    
        public static List<User> getListByBusDevRegion(String BusDevRegion){
        
        String methodName = 'getListByBusDevRegion';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[BusDevRegion] :' + BusDevRegion);
           
         //BGU 31/12 bog fixed
        List<User> listUsers = DM010_StrategicNews.getListByBusDevRegion(BusDevRegion);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listUsers);
        return listUsers; 
    }
        
    
}