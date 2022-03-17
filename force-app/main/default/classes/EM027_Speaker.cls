/**
* @author : Adolphe SONKO
* @date : Creation 21/04/2016
* @date : Modification 21/04/2016
* @description : This class models.
*/
public class EM027_Speaker {
	private static String CLASS_NAME = 'EM027_Speaker';
    
     public static List<Campaign> getEventListsByScheduleId(List<String> List_ID_Schedule){

    	 String methodName = 'getEventListsByScheduleId';
    	 
    	 ObjectUtil.debugLogBegin(CLASS_NAME, methodName , '[List_ID_Schedule] :' + List_ID_Schedule);
    	 
    	List<Campaign> ListEvent = new List<Campaign>();
    	
    	ListEvent = DM029_Speaker.getEventListsByScheduleId(List_ID_Schedule) ;
    	
    	return ListEvent;
    }
    
}