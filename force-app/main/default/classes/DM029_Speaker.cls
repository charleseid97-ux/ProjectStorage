/**
* @author : Adolphe SONKO
* @date : Creation 21/04/2016
* @date : Modification 21/04/2016
* @description : This class models.
*/
public class DM029_Speaker {
        private static String CLASS_NAME = 'DM029_Speaker';
    	private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('Speaker__c');
    	private static final String ALL_FIELDS2 = ObjectUtil.constructFieldListForQueryFrom('Campaign');
     	
    public static List<Campaign> getEventListsByScheduleId(List<String> List_ID_Schedule){
        
        String methodName = 'getEventListsByScheduleId';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[EventIDList] :' + List_ID_Schedule);
          
        String soqlQuery = 'SELECT '+ ALL_FIELDS2 +' FROM Campaign WHERE TECH_ID_Schedule__c IN: List_ID_Schedule';    
        
        List<Campaign> listCampaign = new List<Campaign>((List<Campaign>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listCampaign);
        return listCampaign; 
    }
    

}