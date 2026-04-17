/**
 * @author Abderrahmane TRIA
 * @date Creation 08/04/2020
 * @description DM of User object
 * @group Data Manager
 */
public with sharing class DM030_User {
    private static final String CLASS_NAME = DM030_User.class.getName();
    
   /**
    * @author Abderrahmane TRIA
	* @date Creation 08/04/2020
    * @description get users records from specified user ids
    * @param usersIds set of user ids
    * @return user map by id
    */
    public Map<Id, User> getUsers(Set<Id> usersIds) {
        System.debug('### Start class: ' +CLASS_NAME+ ' Method Name: getUsers');
        System.debug('### End class: ' +CLASS_NAME);
        return new Map<Id, User>(
            [
                SELECT Id, FirstName, LastName, Phone, Name, Email, ProfileId,LanguageLocaleKey,
                Profile.Name, Title, BypassApexTriggers__c
                FROM User
                WHERE id IN :usersIds
            ]
        );
    }
    
       /**
    * @author Abderrahmane TRIA
	* @date Creation 08/04/2020
    * @description Get Label of user's Language
    * @param userId : Salesforce Id of the user
    * @return : Label of user's Language
    */
    public String getLangageLabel(String userId){
        User usr =  [SELECT toLabel(LanguageLocaleKey) FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return usr.LanguageLocaleKey;
    }
}