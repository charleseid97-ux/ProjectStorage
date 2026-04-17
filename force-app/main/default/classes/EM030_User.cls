/**
* @author Abderrahmane TRIA
* @date Creation 08/04/2020
* @group Entity Manager
* @description EM of User object
*/
public without sharing class EM030_User {
    
    private static final String CLASS_NAME       = EM030_User.class.getName();
    private static final DM030_User dataManager  = new DM030_User();
    
        /**
    * @author Abderrahmane TRIA
	* @date Creation 08/04/2020
    * @description get users records from specified user ids
    * @param usersIds set of user ids
    * @return user map by id
    */
    public static Map<Id, User> getUsers(Set<Id> usersIds) {
        System.debug('### Start class: ' +CLASS_NAME+ ' Method Name: getUsers');
        System.debug('### End class: ' +CLASS_NAME);
        return dataManager.getUsers(usersIds);
    }
    
        /**
    * @author Abderrahmane TRIA
	* @date Creation 08/04/2020
    * @description get users records from specified user ids
    * @param usersIds set of user ids
    * @return user map by id
    */
    public static String getLangageLabel(String userId){
        return dataManager.getLangageLabel(userId); 
    }
   
}