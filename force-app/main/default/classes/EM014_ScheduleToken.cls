/** 
* @author: Briag Guemard
* @date : Creation 06/03/2017
* @date : Modification 06/03/2017
* @description : This Class allows to schedule Etouches Token.
*/

global class EM014_ScheduleToken implements Schedulable {
    
    
    	private static String CLASS_NAME = 'EM014_ScheduleToken';
   	
    	global void execute(SchedulableContext SC){
    	
    	//SchedulableContext SC
    	//RecurringScheduleJob.startJob();   
    	
    	
    	
    		Datetime myDT = Datetime.now();
    		myDT = myDT.addMinutes(10);
    	
	        String day = string.valueOf(myDT.day() );
	        String month = string.valueOf(myDT.month());
	        String hour = string.valueOf(myDT.hour());
	        String minute = string.valueOf(myDT.minute());
	        String second = string.valueOf(myDT.second());
	        String year = string.valueOf(myDT.year());
	        
	        String strJobName = 'EM014_ScheduleToken-' + second + '_' + minute + '_' + hour + '_' + day + '_' + month + '_' + year;
	        String strSchedule = '0 ' + minute + ' ' + hour + ' ' + day + ' ' + month + ' ?' + ' ' + year;
	             
	        EM012_eTouchesAuthWS.getToken();
	        
	        String jobID = System.schedule(strJobName, strSchedule, new EM014_ScheduleToken());
	   		   			   		
			//List<CronTrigger> sobjList = Database.query('SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE \'EM014%\' and Id <> :jobID');
	   		
	   		DM014_eTouches_Token.getTriggerIdAndKillTheOldOne(jobID);
    	
    	}
    	
}