/** 
* @author: Briag GUEMARD
* @date : Création 14/04/2017
* @date : Modification 14/04/2017
* @description : this Class allow to manage Process Object  entity data preparation .
*/
public class EM025_Process {

	private static String CLASS_NAME = 'EM025_Process';
	public static List<Process_Id__c> getListByIndex(Set<String> processId){
		
		String methodName = 'getListByIndex';    
        
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[processId] :' + processId);
        
        
        List<Process_Id__c> returnlist = DM025_Process.getListByIndex(processId);
        
         
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + returnlist);
        
        return returnlist;
        
	}
	
	
	
	
	
	

}