/** 
* @author: Briag GUEMARD
* @date : Creation 28/03/2017
* @date : Modification 28/03/2017
* @description : this Class allows to launch request on the Template_Etouches__c object
*/



public  class DM022_eTouchesTemplate {
    
      private static String CLASS_NAME = 'DM022_eTouchesTemplate';
    private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('Template_Etouches__c');
    
      public static List<Template_Etouches__c> getAllList(){
        
        String methodName = 'getAllList';    
        
        
        String soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM Template_Etouches__c';    
        List<Template_Etouches__c> listTemplate = new List<Template_Etouches__c>((List<Template_Etouches__c>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listTemplate);
        return listTemplate; 
    }
  
    
}