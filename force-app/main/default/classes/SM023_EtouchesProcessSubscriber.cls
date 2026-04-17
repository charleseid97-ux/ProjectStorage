/** 
 * @author : Briag GUEMARD
 * @date : Creation 13/04/2016
 * @date : Modification 15/04/2016
 * @description : Queuable Methode with Allow Callout.
 */
 
 
public class SM023_EtouchesProcessSubscriber implements Queueable,  Database.AllowsCallouts {
    
    private static String  CLASS_NAME = SM023_EtouchesProcessSubscriber.class.getName();
    
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
    
    private Process_Id__c ProcessIdCurrent;
    private datetime lastDate;
    private Campaign CampaignInProgress;
    private Integer LoopX;
    private String methodName = 'SM023_EtouchesProcessSubscriber';
    private Map<String,String> mapMemberStatusBySubscriberId;
    private Map<String,String> mapMemberStatusBySubscriberIdTemp;
    private Map<String,String> mapEmailByAttendeeIdFinal;
    
    //SM023_EtouchesProcessSubscriber newjobS = new SM023_EtouchesProcessSubscriber(ProcessIdCurrent,lastDate,CampaignInProgress,mapMemberStatusBySubscriberId);
    
    /*********** Constructor *************/
    public SM023_EtouchesProcessSubscriber( Process_Id__c ProcessIdCurrentJob, datetime lastDateJob, Campaign CampaignInProgressJob,  Integer LoopJob, Map<String,String> mapMemberStatusBySubscriberIdJob, Map<String,String>mapEmailByAttendeeIdFinalJob ){
        
        this.ProcessIdCurrent = ProcessIdCurrentJob;
        this.lastDate = lastDateJob;
        this.CampaignInProgress = CampaignInProgressJob;
        this.loopX=LoopJob;
        this.mapMemberStatusBySubscriberId = mapMemberStatusBySubscriberIdJob;
        this.mapEmailByAttendeeIdFinal= mapEmailByAttendeeIdFinalJob;
    }
    
    public void execute(QueueableContext context){
    	
    	SM022_EtouchesProcessAttendee newjobA = null;
    	
    	system.debug('BGU SM023_EtouchesProcessSubscriber');
    	
    	if(mapMemberStatusBySubscriberId!= null && mapMemberStatusBySubscriberId.keySet().size()>0){
    		
    		//Process 	
    		Integer counter = 0;
    		Boolean testEndOffile = false;
    		Boolean testFiveHundredRecord = false;
    		
    		mapMemberStatusBySubscriberIdTemp = new Map<String,String>();
    		
    		List<String> tempProcess = new List<String>();

	
    		for (String key: mapMemberStatusBySubscriberId.keySet()) {
                    tempProcess.add(key);
            }
            
            
            
    		
    		system.debug('BGU counter INIT ' + counter);
    		
    		while (!testFiveHundredRecord && !testEndOffile ){
    			system.debug('BGU while START ' + counter);
    			
    			
    			mapMemberStatusBySubscriberIdTemp.put(tempProcess.get(0),mapMemberStatusBySubscriberId.get(tempProcess.get(0)));
    			
    			system.debug('BGU mapMemberStatusBySubscriberIdTemp' + mapMemberStatusBySubscriberIdTemp);
    			
    			mapMemberStatusBySubscriberId.remove(tempProcess.get(0));
    			
    			tempProcess.remove(0);
    			
    			system.debug('BGU tempProcess' + tempProcess);
    			
    			system.debug('BGU mapMemberStatusBySubscriberId' + mapMemberStatusBySubscriberId);
    			
    			counter= counter +1;
    			
    			system.debug('BGU counter -1  ' + counter);
    			
    			if (counter >500){
    				testFiveHundredRecord = true;
    			}
    			
    			system.debug('BGU counter -1 AFTER TEST END   ' + counter);
    			
    			system.debug('BGU testFiveHundredRecord AFTER TEST  ' + testFiveHundredRecord);
    			
    			if (tempProcess.size() < 1 ){
    				testEndOffile = true;
    			}
    			
    			system.debug('BGU testEndOffile AFTER TEST  ' + testEndOffile);
    			
    		}
    		
    		if(testFiveHundredRecord){
    			
    			    
                		SM023_EtouchesProcessSubscriber newjobS = new SM023_EtouchesProcessSubscriber(ProcessIdCurrent,lastDate,CampaignInProgress,LoopX,mapMemberStatusBySubscriberId, mapEmailByAttendeeIdFinal);
                
                		ID jobIDS = System.enqueueJob(newjobS);
    			
    			
    		}else{
    			
    			if(testEndOffile){
    				
    				if (mapEmailByAttendeeIdFinal !=null){
    					//SM022
    					newjobA = new SM022_EtouchesProcessAttendee(null,ProcessIdCurrent,lastDate,CampaignInProgress,mapEmailByAttendeeIdFinal,null,loopX);
    					
    				}
    				
    				//END OF THE GAME
    				
    			}
    			
    		}
    		
    		 Set<String> SetSubscriberIds = new Set<String>(); 
             List<CampaignMember> listCampaignMembers = New List<CampaignMember>();
             List<CampaignMember> listCampaignMemberToUpdate2 = New List<CampaignMember>();
    		
    		// PROCESS CAMPAIGN MEMBER 
    		// WITH mapMemberStatusBySubscriberIdTemp
    		if(mapMemberStatusBySubscriberIdTemp != null && mapMemberStatusBySubscriberIdTemp.keySet().size() > 0){
                     
                      
                    SetSubscriberIds = mapMemberStatusBySubscriberIdTemp.keySet();
                     //4th SOQL
                     listCampaignMembers = DM017_etouchesCreateSubscriber.getListBySubscriberIds(SetSubscriberIds) ;
                
                     listCampaignMemberToUpdate2 = listCampaignMemberToUpdate(listCampaignMembers, mapMemberStatusBySubscriberId);
                       
                   
             }
             
            
            if(listCampaignMemberToUpdate2 != null && listCampaignMemberToUpdate2.size() > 0){
            
             
              try{
              update listCampaignMemberToUpdate2;
                
             }  catch(DmlException e){
            
            //ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName +' SM021_EtouchesProcessQueue update listCampaignMemberToUpdate;/*\') ' +
            ' -Type : DmlException - Response Message  : ' + e.getMessage();
  
            
            String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM021_EtouchesProcessQueue / scanEtouches : ' + ProcessIdCurrent.Index__c;
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Input Communication WebSite', Data,  fullResp);
            
            
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'processEtouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
            }
             
             
         }  
             
    		
    		
    		
    	}else{
    		
    		if (mapEmailByAttendeeIdFinal !=null){
    					//SM022
    					
    					newjobA = new SM022_EtouchesProcessAttendee(null,ProcessIdCurrent,lastDate,CampaignInProgress,mapEmailByAttendeeIdFinal,null,loopX);
    					
    		}
    		
    		//END OF THE GAME
    	}
    	
    	if(newjobA!=null){
    		
    		ID jobIDA = System.enqueueJob(newjobA);
    	}
    	
    	
    	
    	
    	
    }


private static List<CampaignMember> listCampaignMemberToUpdate(List<CampaignMember> listCampaignMembers, Map<String,String> mapMemberStatusBySubscriberId){
        
        String methodName = 'listCampaignMemberToUpdate'; 
        //system.debug('ADBS inside listCampaignMemberToUpdate');
        
        List<CampaignMember> listCampaignMemberToUpdate = new List<CampaignMember>();
        for(CampaignMember cMemb: listCampaignMembers){
            
            // BGU => UNSUBSCRIBED.
            
            if(cMemb.Status != mapMemberStatusBySubscriberId.get(cMemb.TECH_ID_Subscriber__c)){
                if(mapMemberStatusBySubscriberId.get(cMemb.TECH_ID_Subscriber__c) != 'Subscribed' && cMemb.Subscriber__c == false){
                    cMemb.Subscriber__c = true;
                    listCampaignMemberToUpdate.add(cMemb);
                }else{
                    
                }             
                
            }
        }

        return listCampaignMemberToUpdate;
     }

    
}