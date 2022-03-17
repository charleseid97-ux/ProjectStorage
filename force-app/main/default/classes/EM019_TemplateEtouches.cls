/** 
* @author: Briag GUEMARD
* @date : Creation 28/03/2017
* @date : Modification 28/03/2017
* @description : this Class allow to manage Template etouches request for send to Etouches
*/

public class EM019_TemplateEtouches {
    
    private static String CLASS_NAME = 'EM019_TemplateEtouches';
    
     public static List<Template_Etouches__c>  getAllTemplateEtouches(){
        
        String methodName = 'getAllTemplateEtouches';
        
        List<Template_Etouches__c> temp = new List<Template_Etouches__c>();        
                
        temp =   DM022_eTouchesTemplate.getAllList();
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, '[List<Template_Etouches__c>] :' + temp);
                      
        return temp ;    
    }
}