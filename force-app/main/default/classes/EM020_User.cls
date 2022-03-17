/** 
* @author: Briag GUEMARD
* @date : Creation 28/02/2017
* @date : Modification 28/02/2017
* @description : this Class allow to manage User entity data preparation .
*/


public class EM020_User {
    
     private static String CLASS_NAME = 'EM020_User';
     
     
     public static List<User> getUserbyId (List<Id> UserIdList){
     	
     	 List<User> returnUser =  new List<User>();
     	
     	String methodName = 'getUserbyId';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[UserIdList] :' + UserIdList);
        
        returnUser = DM023_User.getListByIds(UserIdList);
     	
     	return returnUser;
     }
    
   
/** 
* @author: Adolphe SONKO
* @date : Création 04/05/2017
* @date : Modification 04/05/2017
* @description : Get a list of users by their Names
*/
     public static User getListByName(String listNames){
     	
     	User returnUser =  new User();
     	
     	String methodName = 'getListByName';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[listNames] :' + listNames);
        
        returnUser = DM023_User.getListByName(listNames);
     	
     	return returnUser;
     }
}