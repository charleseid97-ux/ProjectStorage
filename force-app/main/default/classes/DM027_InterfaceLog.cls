/** 
* @author: Briag GUEMARD
* @date : Creation 17/04/2017
* @date : Modification 17/04/2017
* @description : this Class allow to manage Log entity data preparation .
*/

public class DM027_InterfaceLog {
    
    private static String CLASS_NAME = 'DM027_InterfaceLog';
    private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('Interface_Log__c');
    
   
    public static List<Interface_Log__c> getListByProcessId(Set<String> ProcessID){
        
        String methodName = 'getListByProcessId';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[ProcessID] :' + ProcessID);
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Interface_Log__c WHERE 	Process_Id__c IN: ProcessID';    
        List<Interface_Log__c> listCResul= new List<Interface_Log__c>((List<Interface_Log__c>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCResul);
        return listCResul; 
    }
   
    
}