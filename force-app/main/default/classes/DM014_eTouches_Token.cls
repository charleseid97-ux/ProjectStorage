/** 
* @author: Briag GUEMARD
* @date : Creation 06/03/2017
* @date : Modification 06/03/2017
* @description : this Class allows to prepare data for the token Job
*/

public class DM014_eTouches_Token{
	
	private static String CLASS_NAME = 'DM014_eTouches_Token';
	
	public static void getTriggerIdAndKillTheOldOne(String jobID)
	{
		
		List<CronTrigger> sobjList = Database.query('SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE \'EM014%\' and Id <> :jobID');
	   	
	   	Id cronid = sobjList.get(0).Id;
	   	
	   	System.abortJob(cronid);
	}
	
	
}