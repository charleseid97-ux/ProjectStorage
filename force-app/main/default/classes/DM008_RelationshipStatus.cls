/**
* @author : Adolphe SONKO
* @date : Creation 13/09/2016
* @date : Modification 13/09/2016
* @description : This class models .
*/

public class DM008_RelationshipStatus {

    private static String CLASS_NAME = 'DM008_RelationshipStatus';
    private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('Account');
    private static final String ALL_FIELDS2 = ObjectUtil.constructFieldListForQueryFrom('User');
    
    /**
     * @author : Adolphe SONKO
     * @date : Création 15/09/2016
	 * @date : Modification 15/09/2016 
     * @description : This method performs an SQL query on the user to repatriate its data from an ID list.
     * @param : (Set<String> Company) This parameter is a list of unique identifiers of company.
     */  
    public static List<Account> getListOfAccounts(Set<String> Company){
        
        String methodName = 'getListOfAccounts';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Company] :' + Company);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Account where GAM__c IN: Company';    
        List<Account> listAccounts = new List<Account>((List<Account>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listAccounts);
        return listAccounts; 
    }

    
   /**
     * @author : Adolphe SONKO
     * @date : Création 13/09/2016
	 * @date : Modification 13/09/2016 
     * @description : This method performs an SQL query on the contact to repatriate its data from an ID list.
     * @param : Set<id> Users This parameter is a list of unique identifiers of user.
     * @return : List<user> The returned item is a list of Users.
     */  
/*    public static List<User> getListByIds(Set<Id> UserIds){
        
        String methodName = 'getListByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[UserIds] :' + UserIds);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS2 + ' FROM User WHERE Id IN: UserIds';    
        List<User> listUsers = new List<User>((List<User>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listUsers);
        return listUsers; 
    }    */
    
}