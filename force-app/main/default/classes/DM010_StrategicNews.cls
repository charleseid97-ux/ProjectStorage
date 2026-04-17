/**
* @author : Adolphe SONKO
* @date : Creation 13/09/2016
* @date : Modification 13/09/2016
* @description : This class models.
*/


public class DM010_StrategicNews {
    
    private static String CLASS_NAME = 'DM010_StrategicNews';
    private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('Account');
    private static final String ALL_FIELDS2 = ObjectUtil.constructFieldListForQueryFrom('User');

     /**
     * @author : Adolphe SONKO
     * @date : Création 14/09/2016
     * @date : Modification 14/09/2016 
     * @description : This method performs an SQL query on the user to repatriate its data from an ID list.
     * @param : Set<id> Users This parameter is a list of unique identifiers of user.
     * @return : List<user> The returned item is a list of Users.
     */  
    public static List<Account> getListOfAccounts(Set<String> Company){
        
        String methodName = 'getListOfAccounts';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Company] :' + Company);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Account Where GAM__c IN: Company';    
        List<Account> listAccounts = new List<Account>((List<Account>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listAccounts);
        return listAccounts; 
    }

    /**
     * @author : Adolphe SONKO
     * @date : Création 15/09/2016
     * @date : Modification 15/09/2016 
     * @description : This method performs an SQL query on the user to repatriate its data from an ID list.
     * @param : Set<id> Company This parameter is a list of unique identifiers of user.
     * @return : List<account> The returned item is a list of Users.
     */  
    public static List<Account> getAccountsByIds(Set<String> Company){
        
        String methodName = 'getAccountsByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Company] :' + Company);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Account Where Id IN: Company';    
        List<Account> listAccounts = new List<Account>((List<Account>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listAccounts);
        return listAccounts; 
    }
    
     /**
     * @author : Adolphe SONKO
     * @date : Création 13/09/2016
     * @date : Modification 13/09/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from an ID list.
     * @param : Set<String> BusDevRegion This parameter is the Business developer region.
     * @return : List<user> The returned item is a list of Users.
     */  
    
    //BGU OLD 30/12 
    //public static List<User> getListByBusDevRegion(Set<String> BusDevRegion){
   
    public static List<User> getListByBusDevRegion(String BusDevRegion){
        
        String methodName = 'getListByBusDevRegion';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[BusDevRegion] :' + BusDevRegion);
        


        //BGU OLD 30/12
        //String soqlQuery = 'SELECT ' + ALL_FIELDS2 + ' FROM User Where BusinessDevelopmentRegions__c INCLUDES (BusDevRegion)';  
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS2 + ' FROM User Where BusinessDevelopmentRegions__c INCLUDES ( \'' +BusDevRegion+'\')';    
        

        List<User> listUsers = new List<User>((List<User>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listUsers);
        return listUsers; 
    }
    			
    
}