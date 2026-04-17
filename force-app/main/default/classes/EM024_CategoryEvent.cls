/** 
* @author: Briag GUEMARD
* @date : Création 14/04/2017
* @date : Modification 14/04/2017
* @description : this Class allow to manage Category Event  entity data preparation .
*/
public class EM024_CategoryEvent {
  
  
  	private static String CLASS_NAME = 'EM024_CategoryEvent';

	 public static Category_Event__c getRecordsByIds(Set<Id> CategoryId){
        
        String methodName = 'getRecordsByIds';    
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Category_Event__ID] :' + CategoryId);
        
        Category_Event__c tempReturn =   DM026_CategoryEvent.get1ListById(CategoryId);
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + tempReturn);
        
        return tempReturn; 
    }    
}