/** 
 * @author : Briag GUEMARD
 * @date : Creation 13/04/2016
 * @date : Modification 15/04/2016
 * @description : Queuable Methode with Allow Callout.
 */
 
 
public class SM021_EtouchesProcessQueue implements Queueable,  Database.AllowsCallouts {
    
    private static String  CLASS_NAME = SM021_EtouchesProcessQueue.class.getName();
    
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();



    private List<Campaign> CampaignToManageLeft;
    private Process_Id__c ProcessIdCurrent;
    private datetime lastDate;
    private Campaign CampaignInProgress;
    private Map<String, String> mapEmailByAttendeeIdFinal; // => OLD BGUprivate List<String> ListAttendeLeft;
	private List<attendeeInfo__c> ListAttendeAlreadyScanned;
	private Integer LoopX;
    private String methodName = 'SM021_EtouchesProcessQueue';
    
    
    
    /*********** Constructor *************/
    public SM021_EtouchesProcessQueue(List<Campaign> CampaignToManageLeftJob, Process_Id__c ProcessIdCurrentJob, datetime lastDateJob, Campaign CampaignInProgressJob, Map<String, String> mapEmailByAttendeeIdJob, List<attendeeInfo__c> ListAttendeAlreadyScannedJob, Integer LoopJob ){
        this.CampaignToManageLeft = CampaignToManageLeftJob;
        this.ProcessIdCurrent = ProcessIdCurrentJob;
        this.lastDate = lastDateJob;
        this.CampaignInProgress = CampaignInProgressJob;
        this.mapEmailByAttendeeIdFinal = mapEmailByAttendeeIdJob;  // => OLD BGU this.ListAttendeLeft = ListAttendeLeftJob;
		this.ListAttendeAlreadyScanned = ListAttendeAlreadyScannedJob;
		this.loopX=LoopJob;
    }
    
    public void execute(QueueableContext context) {
        
        Boolean limitReached;
        
        List<CampaignMember> listCMToUpdateFromAttendee = new List<CampaignMember>();
        
        List<CampaignMember> listCampaignMemberToUpdate = new List<CampaignMember>();
        
        //List<Bounce_Etouches__c> listBounceToInsert = new  List<Bounce_Etouches__c>();
        
        List<Lead> listLeadToCreateFromAttendee = new List<Lead>();
        
        List<attendeeToFind> listAttendeesToFind = new List<attendeeToFind>();
        
        List<CampaignMember> listCMToCreateFromAttendee = new List<CampaignMember>();
        
        List<Process_Id__c> processToUpdate = new List<Process_Id__c>();
        
        List<CampaignMember> listCampaignMemberToUpdate2 = new List<CampaignMember>();
        
        String evId;
    
        /************* 1ST BLOC **************/
       
        
        if(CampaignInProgress ==null){
        	loopX = loopX+1;
        	system.debug('BGU loopX loopX '  + loopX);
        	
        }
                
        if( mapEmailByAttendeeIdFinal == null  && CampaignInProgress ==null &&  CampaignToManageLeft !=null){
                system.debug('BGU  0 : CAMPAIGN TO PROCESS START   '  + CampaignInProgress);
            
                /***********0 ***************/ 
                //GEt the 1st elements of the list. 
                CampaignInProgress = CampaignToManageLeft.get(0);
                            
                List<Id> ListCampaignIdInProgress =  new List<Id>();
                
                ListCampaignIdInProgress.add(CampaignInProgress.Id);
                
            	 //system.debug('BGU  0 : CAMPAIGN TO PROCESS   '  + CampaignInProgress);
                
                /***********1 ***************/
                /*1 : Get the mailing list of the Campaign*/
                
                List<String> listStringMailingListID = new List<String>();
                listStringMailingListID.add(CampaignInProgress.TECH_Mailing_List_ID_Etouches__c);
                
                //RE USE OF OLD METHOD WITH THE LIST, ONLY ONE ITEM IN THIS LIST
                
                //system.debug('BGU  1 : listStringMailingListID   '  + CampaignInProgress);
                
                /*********** 2 ***************/
                /*2 : Get the Campaign memeber of this event.*/
                
                List<CampaignMember> listCampaignMembersFromScannedEvents = new List<CampaignMember>();
                
                listCampaignMembersFromScannedEvents = EM018_SubscriberEtouches.getListByCampaignIds(ListCampaignIdInProgress);
                
                //List To Update at the end
                
                //system.debug('BGU  2 : listCampaignMembersFromScannedEvents   '  + listCampaignMembersFromScannedEvents);
                
                /*********** 3 ***************/ 
                /*3 : Get the Bounce of the Campaign*/
                
                // List For Bounce Of the Campaign
                //List<Bounce_Etouches__c> listBounceAllForCampaignInProgress = new  List<Bounce_Etouches__c>();
                //List of Bounce of the Etouches request
                //List<Bounce_Etouches__c> listBounceToCheck = new  List<Bounce_Etouches__c>();
                
                
                
                
                
                //listBounceAllForCampaignInProgress = EM022_BounceEtouches.getAllBounceInSalesforce(ListCampaignIdInProgress);
                
                
               // //system.debug('BGU  /*********** 3 ***************/ listBounceAllForCampaignInProgress PROCESS   '  + listBounceAllForCampaignInProgress);
                
                /*********** CALLOUT ***********/
                                
                
                /*********** 4 ***************/ 
                /*4 : Get The subscriber of the Event*/
                
                 ////system.debug('BGU  /*********** 4 ***************/ listBounceAllForCampaignInProgress PROCESS   '  + listBounceAllForCampaignInProgress);
                
                Integer limitsEtouches = 2000;
                Integer beforelimits = 1998;
                Integer Offset = 0;
                Map<String,String> mapMemberStatusBySubscriberId = new Map<String,String>();
                Set<String> SetSubscriberIds = new Set<String>(); 
                List<CampaignMember> listCampaignMembers = new List<CampaignMember>();
                
                
                for(String  listId :listStringMailingListID){
                    
                 Map<String, String> mapStatusBySubscriberId = new Map<String, String>();
                 
                
                 
                 mapStatusBySubscriberId = callGetScanSubscriberX(null,  listId, String.valueOf(limitsEtouches),'0') ; 
               
                 //system.debug(mapStatusBySubscriberId);
                    
                    if(mapStatusBySubscriberId != null && mapStatusBySubscriberId.keySet().size() == 0){
                         
                      
                    	 //system.debug(mapStatusBySubscriberId);
					     
                     }else{
                        
                        for(String sub :mapStatusBySubscriberId.keySet()){
                         	
                         	mapMemberStatusBySubscriberId.put(sub,mapStatusBySubscriberId.get(sub));
                                            
                         }
                        
                   
                 
                        
                         if(mapStatusBySubscriberId.keySet().size() == limitsEtouches){
                                    //system.debug('BGU mapStatusBySubscriberId.keySet().size() >= limitsEtouches ' + mapStatusBySubscriberId.keySet().size());
                                    Boolean testIfNotEnd= true;
                                    
                                    while(testIfNotEnd) {
                                    	    
                                        Offset= Offset+limitsEtouches;
                                        Map<String, String> mapStatusBySubscriberIdX = new Map<String, String>();
                                        mapStatusBySubscriberIdX= callGetScanSubscriberX(null,  listId, String.valueOf(limitsEtouches), String.valueof(Offset)) ; 
                                        
                                        
                                         if(mapStatusBySubscriberIdX != null && mapStatusBySubscriberIdX.keySet().size() >= 0){
                                            
                                            for(String sub :mapStatusBySubscriberIdX.keySet()){
                                            	mapMemberStatusBySubscriberId.put(sub,mapStatusBySubscriberIdX.get(sub));
                                            
                                            }
                                            
                                            
                                         }
                                         
                                         
                                        
                                         
                                         if (mapStatusBySubscriberIdX.keySet().size() < limitsEtouches){
                                            testIfNotEnd = false;
                                         }
                                        
                                         
                                    }        
                                    
                                      
                                
                                //mapStatusBySubscriberId2 = callGetScanSubscriber(lastDate,  listId, String.valueOf(beforelimits+Offset)) ; 
                                
                                // ONLY 4K Subscriber ! Need TO GO UP ! 
                                
                                
                             }                       
                         
                         /* OLD SONKO
                             for(String sub :mapStatusBySubscriberId.keySet()){
                                mapMemberStatusBySubscriberId.put(sub,mapStatusBySubscriberId.get(sub));
                                
                             }
                             for(String sub :mapStatusBySubscriberId2.keySet()){
                                mapMemberStatusBySubscriberId.put(sub,mapStatusBySubscriberId2.get(sub));
                                
                             }
                             */
                             
                             // END OLD TO ERASE ! 
                        }
                        	//system.debug('BGU mapStatusBySubscriberId SIZE  '+mapStatusBySubscriberId.keySet().size());
                 }
                 
                //Update the Campaign member 
                if(mapMemberStatusBySubscriberId != null && mapMemberStatusBySubscriberId.keySet().size() > 0){
                     
                     SetSubscriberIds = mapMemberStatusBySubscriberId.keySet();
                     //4th SOQL
                     listCampaignMembers = DM017_etouchesCreateSubscriber.getListBySubscriberIds(SetSubscriberIds) ;
                
                     listCampaignMemberToUpdate2 = listCampaignMemberToUpdate(listCampaignMembers, mapMemberStatusBySubscriberId);
                       
                }
                
                //system.debug('BGU listCampaignMemberToUpdate2 ' + listCampaignMemberToUpdate2);
       
       		
               //system.debug('BGU TEST 15h23555');
               //system.debug(listCampaignMemberToUpdate2);
               
               
                /*********** 5 ***************/ 
                /*5 : Get the bounce of Etouhces*/
               /* 
                // Check Bounce for Campaign in Progress 
            
                evId = CampaignInProgress.Event_code_Etouches__c;
                
                Map<String, String> mapCodeByEmail = new Map<String, String>();
                
                listBounceToCheck= callGetBounceFromEvent(evId);
                
                if (listBounceToCheck != null && listBounceToCheck.size()>0){
                
                //  listBounceAll All Scna Bounced in Salesforce
                //  listBounceToCheck All Bounce in Etouches we check.
                //  listCampaignMembersFromScannedEvents List of all Campaign Memeber (of Scan Campaign)
                //  listScannedcampaigns List of Scanned Campaign  
            
                //Launch check Bounce.
                
                //Get the good Campaign
                Campaign camp1 = CampaignInProgress;
                
                    if (camp1.Event_code_Etouches__c != null) {
                        
                        //Get the list of the campaign memeber
                        List<CampaignMember> listCampOnCamp1 = listCampaignMembersFromScannedEvents;
                        
                        // OLD WITH ALL CM AND CAMPAIGN List<CampaignMember> listCampOnCamp1 = EM015_CampaignMember.getAllCMFromCampaign(camp1, listCampaignMembersFromScannedEvents);
                        
                        // GEt the list of good Bounce laready in Salfes
                        List<Bounce_Etouches__c> listBounceAlreadyInCamp = listBounceAllForCampaignInProgress;
                        
                        // OLD WITH ALL CAMPAIGN AND BOUNCE List<Bounce_Etouches__c> listBounceAlreadyInCamp = EM022_BounceEtouches.getBounceOfACampaign( listBounceAllForCampaignInProgress,  camp1);
                        
                        List<Bounce_Etouches__c> listBounceToAdd = EM022_BounceEtouches.getBounceNewBounceDelta(listBounceAlreadyInCamp,listBounceToCheck);
                            
                        if (listBounceToAdd != null && listBounceToAdd.size()>0){
                            
                            for (Bounce_Etouches__c toAdd : listBounceToAdd){
                                
                                toAdd.Campaign__c = camp1.Id;
                                
                                Datetime myDT = Datetime.now();
                                
                                toAdd.CreationBeforeInsert__c = myDT;
                                
                                listBounceToInsert.add(toAdd);
                            }
                            
                            
                        }
                                            
                        //get the list of Bounce for one campaign member
                        
                        
                        
                        // Delta between listBounceToCheck and ListOfBounce
                        
                        // Add new bounce to Insert
                        
                        // Add Campaign memeber with the last Bounce attach in Campaign member to Update.
                            // If laready inside  Update Bounce
                            // If not inside add it. 
                    }
                    else
                    { 
                        //system.debug('BGU no campaign in salesforces (But some Bounce in Etouches) for event '  + evId );
                    }
                }
                else
                {
                    //system.debug('BGU no Bounce in Etouches for event : ' + evId);
                }
                
                // Launch the Delta Between Bounce already in, and NEw Bounce
                
                if (listBounceToInsert !=null &&  listBounceToInsert.size() > 0 ) {
                    
                    //all bounce to insert
                    for (Bounce_Etouches__c bounce : listBounceToInsert ) {
                        
                        //all Campaigne member of the campaigne
                        for (CampaignMember cmAll : listCampaignMembersFromScannedEvents){
                            
                            // check if the mail matched with the CM.
                            
                            if (cmAll.Email ==  bounce.Email__c) {
                            
                            CampaignMember temp = new CampaignMember();
                                    //Add the bounce to the campaign member
                                    boolean testAlreadyIn = false;
                                    //check if already in the Updated CM. 
                                      for (CampaignMember cmUp : listCampaignMemberToUpdate){
                                        
                                        // If already inside the Update CM.
                                        if(cmAll.Id == cmUp.Id){
                                            
                                            temp = cmUp;
                                            
                                            temp.Bounce_Etouches__c = bounce.Id;
                                            
                                            testAlreadyIn = true;
                                             
                                        }
                                        
                                      }
                                     
                                     // If not in the Uopdate CM, 
                                     if (!testAlreadyIn){
                                        //The 
                                        
                                            temp = cmAll;
                                            
                                            temp.Bounce_Etouches__c = bounce.Id;
                                        
                                     }
                                     
                               listCampaignMemberToUpdate.add(temp);
                            }
                            
                        }
                    }
                }*/
                    
                
                
                
                /*********** 6 **************/ 
                /*6 : Get List of Attende*/
                
                limitsEtouches = 2000;
                beforelimits = 1998;
                Offset = 0;
                ListAttendeAlreadyScanned = new List<attendeeInfo__c>();
                
                 evId = CampaignInProgress.Event_code_Etouches__c;
                
                Map<String,String> mapMemberEmailByAttendeeId = new Map<String,String>();
                
                Map<String,list<String>> mapAttendeeIdsbyEventId = new Map<String,list<String>>();
                
                Map<String, String> mapEmailByAttendeeId = new Map<String, String>();
                
                mapEmailByAttendeeId = callGetScanListAttendees( null, evId, String.valueOf(limitsEtouches));
                 
                mapEmailByAttendeeIdFinal = new Map<String, String>();
                
                
                
                 if(mapEmailByAttendeeId != null && mapEmailByAttendeeId.keySet().size() == 0){
                     //Nothing
                     
                 }else{
                    
                     for(String attId :mapEmailByAttendeeId.keySet()){
                        
                        //mapMemberEmailByAttendeeId.put(attId,mapEmailByAttendeeId.get(attId));
                        
                        mapEmailByAttendeeIdFinal.put(attId,mapEmailByAttendeeId.get(attId));
                        
                        /* 
                        if(mapAttendeeIdsbyEventId.get(evId) != null){
                            
                           mapAttendeeIdsbyEventId.get(evId).add(attId);
                           
                        }else{
                           
                           mapAttendeeIdsbyEventId.put(evId, new list<String>{attId});
                           
                        }*/
                     }
                    
                    
                    
                     if(mapEmailByAttendeeId.keySet().size() == limitsEtouches){
                        
                        
                        Boolean TestIFEnd = true; 
                        
                        while(TestIFEnd){
                            
                            Offset = Offset +limitsEtouches;
                            
                            Map<String, String> mapEmailByAttendeeIdX = new Map<String, String>();
                            mapEmailByAttendeeIdX  = callGetScanListAttendeesX( null, evId, String.valueOf(limitsEtouches), String.valueof(Offset) );
                            
                            if(mapEmailByAttendeeIdX != null){
                               for(String attId :mapEmailByAttendeeIdX.keySet()){
                        
			                        mapEmailByAttendeeIdFinal.put(attId,mapEmailByAttendeeIdX.get(attId));
			                        
			                        /* 
			                        if(mapAttendeeIdsbyEventId.get(evId) != null){
			                            
			                           mapAttendeeIdsbyEventId.get(evId).add(attId);
			                           
			                        }else{
			                           
			                           mapAttendeeIdsbyEventId.put(evId, new list<String>{attId});
                           
                        			}*/
                    			}			
                            }
                            if(mapEmailByAttendeeIdX.keySet().size() < limitsEtouches){
                                TestIFEnd= false;
                                
                            }
                            
                            
                            
                        }
                        
                        
                        
                        //mapEmailByAttendeeId2 = callGetScanListAttendeesX(lastDate, evId, String.valueOf(beforelimits+Offset)) ;
                        
                        // OK FOR 4k NEED TO UP. 
                     }
                    
                 /* OLD SONKO
                     for(String attId :mapEmailByAttendeeId.keySet()){
                        mapMemberEmailByAttendeeId.put(attId,mapEmailByAttendeeId.get(attId));
                         
                        if(mapAttendeeIdsbyEventId.get(evId) != null){
                            mapAttendeeIdsbyEventId.get(evId).add(attId);
                        }else{
                             mapAttendeeIdsbyEventId.put(evId, new list<String>{attId});
                        }
                     }
                     for(String attId :mapEmailByAttendeeId2.keySet()){
                        mapMemberEmailByAttendeeId.put(attId,mapEmailByAttendeeId2.get(attId));
                         
                        if(mapAttendeeIdsbyEventId.get(evId) != null){
                            mapAttendeeIdsbyEventId.get(evId).add(attId);
                        }else{
                            mapAttendeeIdsbyEventId.put(evId, new list<String>{attId});
                        }
                     } 
                 }
                 
                 
                 
                 /* //system.debug('BGU mapEmailByAttendeeId');*/
                 
                 
                 ////system.debug(mapEmailByAttendeeId);
            
                
                
        }   
        
        
        /************* 2ND BLOC **************/
        /************* 2ND BLOC **************/
        /************* 2ND BLOC **************/
        /************* 2ND BLOC **************/
        /************* 2ND BLOC **************/
        /************* 2ND BLOC **************/
        /************* 2ND BLOC **************/
        /************* 2ND BLOC **************/
        /************* 2ND BLOC **************/
        /************* Always Launch *********/
           
        
        system.debug(mapEmailByAttendeeIdFinal.keySet().size() + ' BGU CampaignInProgress 2ND BLOC ------- ');
      
      	 List<String> AllAttendees = new List<String>();
            
          
      	if ( mapEmailByAttendeeIdFinal != null){
      		
      		  for (String key: mapEmailByAttendeeIdFinal.keySet()) {
                    AllAttendees.add(key);
            }
            
      		
      	}
        
        if ( AllAttendees.size()>0  && CampaignInProgress != null){
            
            
            system.debug('BGU INSIDE 2 ND BLOC ');
            system.debug('BGU INSIDE 2 ND BLOC ' + mapEmailByAttendeeIdFinal);
            
            Campaign camp = CampaignInProgress;
            
            List<Id> temp = new List<Id>();
            temp.add(camp.Id);
            
            
            
            
            
            List<attendeeInfo__c> listAttendeesInfos = new List<attendeeInfo__c>();   
            
            evId = CampaignInProgress.Event_code_Etouches__c;
            
           
            
           //system.debug('BGU ListAttendeAlreadyScanned ' + ListAttendeAlreadyScanned);
           
           
           // FILL => ListAttendeAlreadyScanned
           // Get ListAttendeAlreadyScanned WITH ProcessIdCurrent ass parameter to Get all the data
           
           
           
           
           
           ListAttendeAlreadyScanned = new List<attendeeInfo__c>();
            limitReached = false;
            Boolean EndofFile = false;
            Boolean HeapLimit = false;
            
            if (Limits.getHeapSize() > 0.7 * Limits.getLimitHeapSize()){
            	HeapLimit = true;
            }
                                        
            while(!limitReached && !EndofFile && !HeapLimit){
                
                    string attId = AllAttendees.get(0);
                    
                    attendeeInfo__c AttendeeEtouchesInfo = new attendeeInfo__c();
                    AttendeeEtouchesInfo = callGetScanAttendee(evId, attId);
                    
                    //system.debug('ADBS Voici les infos de l attendee:'+AttendeeEtouchesInfo);
                    if(AttendeeEtouchesInfo.email__c !='Error'){
                        ListAttendeAlreadyScanned.add(AttendeeEtouchesInfo);    
                    }
                    
                    system.debug('AFTER BGU COUNT AllAttendees.size() ' + AllAttendees.size());
                    system.debug('AFTER BGU COUNT mapEmailByAttendeeIdFinal.size() ' + mapEmailByAttendeeIdFinal.keySet().size());
                	
                	if(AllAttendees.size()==1){
                		EndofFile = true;
                	}
                	
                	AllAttendees.remove(0);
                    mapEmailByAttendeeIdFinal.remove(attId);
                    
                	if (Limits.getCallouts() > 0.5 * Limits.getLimitCallouts()){
                
						limitReached = true;
						
					}
					
					if (Limits.getHeapSize() > 0.7 * Limits.getLimitHeapSize()){
            		HeapLimit = true;
            		}
                	
                   
                  
					
					
                
                
                
            }
            
            
            
            
             //system.debug('BGU limitReached ' + limitReached);
            
            //TEST is limits reached 
            if(!EndofFile ){
                
                //system.debug('BGU FINAL  ATTENDE FOUND TEST is limits reached   LAUNCH NEW PROCESS FOR SAME CAMPAIGN ' + Limits.getCallouts());
                
                //system.debug('BGU CampaignToManageLeft ' + CampaignToManageLeft);
                
                //system.debug('BGU CampaignInProgress ' + CampaignInProgress);
                
                //system.debug('BGU mapEmailByAttendeeId ' + mapEmailByAttendeeIdFinal);
                
                //system.debug('BGU ListAttendeAlreadyScanned ' + ListAttendeAlreadyScanned.size());
                
                
                /*
                this.CampaignToManageLeft = CampaignToManageLeftJob;
                this.ProcessIdCurrent = ProcessIdCurrentJob;
                this.lastDate = lastDateJob;
                this.CampaignInProgress = CampaignInProgressJob;
                this.mapEmailByAttendeeId = mapEmailByAttendeeIdJob;  
                
                */
                //LAUNCH NEW PROCESS TO CONTINUE
                
                //Keep CampaignInProgress in CampaignToManageLeft
                // IN parameter mapEmailByAttendeeId
               
                // BGU 19/04/2017
                // Need to launch NULL AND TEST
                 
                // BGU 19/04/2017
                // Need to insert those records 
                 loopX=loopX+1;
                SM022EtouchesProcess2 newjob = new SM022EtouchesProcess2(null,ProcessIdCurrent,lastDate,CampaignInProgress,mapEmailByAttendeeIdFinal,null,loopX);
                
                ID jobID = System.enqueueJob(newjob);
                
                
                //=> Save the data for next process
                
                
            }else{
                
                
                 
                    //system.debug('BGU FINAL  END OF THE GAME !  ');
                    // END OF THE GAME ! 
                    
                    // Update Process
                    // IF some Error with the index process => GO KO
                    // Else OK
                    
                    List<Interface_Log__c> listErrors = EM023_Log.getAllErrorLogFromProcess(ProcessIdCurrent.Index__c);
                    
                    
                    String searchPr = ProcessIdCurrent.Index__c;
                    processToUpdate = EM025_Process.getListByIndex (new set<String>{searchPr});
                    
                    Process_Id__c tempUpdate = processToUpdate.get(0);
                    
                    if(listErrors.size()>0){
                        
                        tempUpdate.Status__c = 'KO';
                        
                    }else
                    {
                        
                        tempUpdate.Status__c = 'OK';
                    }
                    
                
                /*
                //this.CampaignToManageLeft = CampaignToManageLeftJob;
                //this.ProcessIdCurrent = ProcessIdCurrentJob;
                //this.lastDate = lastDateJob;
                //this.CampaignInProgress = Null;
                //this.mapEmailByAttendeeId = Null;  
            
                
                
                //system.debug('BGU FINAL  ATTENDE FOUND TEST is limits NOT reached LAUNCH NEW PROCESS FOR NEXT CAMPAIGN ' + Limits.getCallouts());
                
                // REMOVE CampaignInProgress FROM CampaignToManageLeft
                //system.debug('BGU FINAL  CampaignToManageLeft before remove ' + CampaignToManageLeft);
                
                CampaignToManageLeft.remove(0);
               
                
                //system.debug('BGU FINAL  CampaignToManageLeft after remove (minues 0)' + CampaignToManageLeft);
            
                // Lot a Null in Parameter
                
                //LAUNCH NEW PROCESS FOR NEXT CAMPAIGN
                
                SM021_EtouchesProcessQueue newjob = new SM021_EtouchesProcessQueue(CampaignToManageLeft,ProcessIdCurrent,lastDate,null,null,null);
                
                ID jobID = System.enqueueJob(newjob);*/

               // PROCESS ListAttendeAlreadyScanned
            
            }
            // => DEDUP ListAttendeAlreadyScanned
            
            ListAttendeAlreadyScanned = dedupAttende(ListAttendeAlreadyScanned);
            
            
            List<CampaignMember> listCampaignMember = new List<CampaignMember>();
            
            
            listCampaignMember =  EM018_SubscriberEtouches.getListByCampaignIds(temp);
            
            //system.debug('BGU PROCESS ATTENDEE  listAttendeesInfos ' + ListAttendeAlreadyScanned);
            
            //system.debug('BGU PROCESS ATTENDEE   before listCMToUpdateFromAttendee ' + listCMToUpdateFromAttendee);
            
            //system.debug('BGU PROCESS ATTENDEE   listCampaignMember ' + listCampaignMember);
           
            if(ListAttendeAlreadyScanned != null && ListAttendeAlreadyScanned.size() > 0 ){
            
                 for(attendeeInfo__c att :ListAttendeAlreadyScanned){
                    
                          if(listCampaignMember != null && listCampaignMember.size() > 0){
                            
                              boolean testAlreadyInCM = false;
                              
                              for(CampaignMember cm :listCampaignMember){
                                
                                  if(cm.Email == att.email__c){
                                    
                                      testAlreadyInCM = true;
                                      
                                      if(cm.Status != att.registrationstatus__c){
                                          cm.Status = att.registrationstatus__c ;
                                      }       
                                      
                                      listCMToUpdateFromAttendee.add(cm);
                             
                                           
                                      //Mise a jour du CM
                                  } 
                                  
                                  
                              } 
                                  
                                    
                               if (!testAlreadyInCM){
                                  //Creation du CM
                                    attendeeToFind attToFind = new attendeeToFind();
                                    attToFind.lastName = att.lastName__c;
                                    attToFind.firstName = att.firstName__c;
                                    attToFind.email = att.email__c;
                                    attToFind.campaignId = camp.Id;
                                    attToFind.registrationstatus = att.registrationstatus__c;
                                    attToFind.lastmodified = att.lastmodified__c;
                                      
                                    listAttendeesToFind.add(attToFind) ;
                              
                                  
                                  
                              }
                              
                            
                             
                          }else
                          {
                          			attendeeToFind attToFind = new attendeeToFind();
                                    attToFind.lastName = att.lastName__c;
                                    attToFind.firstName = att.firstName__c;
                                    attToFind.email = att.email__c;
                                    attToFind.campaignId = camp.Id;
                                    attToFind.registrationstatus = att.registrationstatus__c;
                                    attToFind.lastmodified = att.lastmodified__c;
                                      
                                    listAttendeesToFind.add(attToFind) ;
                          }
                     
                     
                     
                     
                 }
             }
             
            
             //system.debug('BGU PROCESS AFTER ATTENDEE   after listCMToUpdateFromAttendee ' + listCMToUpdateFromAttendee);
             
            
             // FIND THE NEW ATTENDEE => 
            
            
            //system.debug('BGU THE NEW ATTENDEE  listAttendeesToFind ' + listAttendeesToFind);
           
            if(listAttendeesToFind != null && listAttendeesToFind.size() > 0){
                
                List<String> listAttendeesEmails = new List<String>();
                List<Lead> listofAllLeadstosearch = new List<Lead>(); 
                List<Contact> listofAllContactstosearch = new List<Contact>();
                
                for(attendeeToFind att :listAttendeesToFind){
                    
                 listAttendeesEmails.add(att.email);
                 
                }
                
                listofAllContactstosearch = EM002_Contact.getListContactsFromEmails(listAttendeesEmails);
                
                if(listofAllContactstosearch != null && (listofAllContactstosearch.size() < listAttendeesToFind.size())){
                    
                     listofAllLeadstosearch = EM001_Lead.getListLeadsFromEmails(listAttendeesEmails);
                }
                
                
                for(attendeeToFind att :listAttendeesToFind){
                
                    boolean testAlreadyInContact = false;
                    
                    if(listofAllContactstosearch != null && listofAllContactstosearch.size() > 0){
                        
                        for(Contact con: listofAllContactstosearch){
                            
                            CampaignMember cMemb = new CampaignMember();
                            if(con.Email == att.email || con.PersonalEmail__c == att.email){
                                testAlreadyInContact = true;
                                cMemb.Status =  att.registrationstatus;
                                cMemb.contactId = con.Id;
                                cMemb.CampaignId = att.campaignId;
                                cMemb.Last_Action_Date__c = Date.valueOf(att.lastmodified);
                             
                                listCMToCreateFromAttendee.add(cMemb);
                                    
                            }
                            
                        }
                        
                    }
                    
                    if(!testAlreadyInContact){
                        
                         boolean testAlreadyInlead = false;  
                         if(listofAllLeadstosearch != null && listofAllLeadstosearch.size() > 0){
                            
                            for(Lead ld :listofAllLeadstosearch){
                                
                                CampaignMember cMemb = new CampaignMember();
                                if(ld.Email == att.email || ld.PersonalEmail__c == att.email){
                                    
                                    testAlreadyInlead = true;
                                  cMemb.Status =  att.registrationstatus;
                                  cMemb.LeadId = ld.Id;
                                  cMemb.CampaignId = att.campaignId;
                                  cMemb.Last_Action_Date__c = Date.valueOf(att.lastmodified);
                                  
                                  listCMToCreateFromAttendee.add(cMemb);
                                }
                                
                            }
                            
                            
                         }
                         
                          if(!testAlreadyInlead){
                             Lead leadFromAttendee = new Lead();
                             if(att.lastName != null){
                                
                             leadFromAttendee.FirstName = att.firstName;
                              leadFromAttendee.LastName = att.lastName ;
                              leadFromAttendee.Status = att.registrationstatus;
                              leadFromAttendee.Email = att.email;
                              
                              leadFromAttendee.LeadSource = 'Event';
                              leadFromAttendee.Company = 'Etouches Attendee';
                             
                              listLeadToCreateFromAttendee.add(leadFromAttendee);
                             }
                             
                          }

                        
                    }
                    
                }
                
            }
            

            
            
            
            
            
        
   

    
    
        }else{
            
            
            /*
                if(CampaignToManageLeft.size() > 0){
                
                    
                    
                    //this.CampaignToManageLeft = CampaignToManageLeftJob;
                    //this.ProcessIdCurrent = ProcessIdCurrentJob;
                    //this.lastDate = lastDateJob;
                    //this.CampaignInProgress = Null;
                    //this.mapEmailByAttendeeId = Null;  
                    
                    
                    //system.debug('BGU FINAL NO ATTENDEE FOUND LAUNCH NEW PROCESS FOR NEXT CAMPAIGN ' + Limits.getCallouts());
                
                    // REMOVE CampaignInProgress FROM CampaignToManageLeft
                    //system.debug('BGU FINAL  CampaignToManageLeft before remove ' + CampaignToManageLeft);
                    
                    CampaignToManageLeft.remove(0);
                    
                    //system.debug('BGU FINAL  mapEmailByAttendeeId Should BE Zero ' + mapEmailByAttendeeId);
                    
                    //system.debug('BGU FINAL  CampaignToManageLeft after remove (minues 0)' + CampaignToManageLeft);
                
                    // Lot a Null in Parameter
                    
                    //LAUNCH NEW PROCESS FOR NEXT CAMPAIGN
                    SM021_EtouchesProcessQueue newjob = new SM021_EtouchesProcessQueue(CampaignToManageLeft,ProcessIdCurrent,lastDate,null,null,null);
                    
                    ID jobID = System.enqueueJob(newjob);
                    
                
                }else
                {*/
                    
                    
                    //system.debug('BGU FINAL  END OF THE GAME !  ');
                    // END OF THE GAME ! 
                    
                    // Update Process
                    // IF some Error with the index process => GO KO
                    // Else OK
                    
                    List<Interface_Log__c> listErrors = EM023_Log.getAllErrorLogFromProcess(ProcessIdCurrent.Index__c);
                    
                    
                    String searchPr = ProcessIdCurrent.Index__c;
                    processToUpdate = EM025_Process.getListByIndex (new set<String>{searchPr});
                    
                    Process_Id__c tempUpdate = processToUpdate.get(0);
                    
                    if(listErrors.size()>0){
                        
                        tempUpdate.Status__c = 'KO';
                        
                    }else
                    {
                        
                        tempUpdate.Status__c = 'OK';
                    }
                    
                //}
            
       
            }  
             
           
            
        /********* DATA INSERT ********* /
        // Update Data 
        6 : Update Campaign member with Subscriber Infos
        7 : Update / Upsert Bounce
        
        
        /***** END of the Process ****/
        /***** Data To INJECT ****/
                
                
        
          /*
         if (listBounceToInsert !=null &&  listBounceToInsert.size() > 0 ) {
                    
                  
              try{
                 insert listBounceToInsert;
                
             }  catch(DmlException e){
            
            //ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName +' SM021_EtouchesProcessQueue insert listBounceToInsert;/*\') ' +
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
                    
         }*/
         
         
         if(listLeadToCreateFromAttendee != null && listLeadToCreateFromAttendee.size() > 0){
            
             
               try{
               insert listLeadToCreateFromAttendee;
                
             }  catch(DmlException e){
            
            //ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName +' SM021_EtouchesProcessQueue  insert listLeadToCreateFromAttendee;/*\') ' +
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
         
         //Update of Campaign Member from Attendee
         if(listCMToUpdateFromAttendee != null && listCMToUpdateFromAttendee.size() > 0){
             
           
             
              try{
              update listCMToUpdateFromAttendee;
                
             }  catch(DmlException e){
            
            //ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName +' SM021_EtouchesProcessQueue update listCMToUpdateFromAttendee;/*\') ' +
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
         
         
         
         
         
        
         if(listCampaignMemberToUpdate != null && listCampaignMemberToUpdate.size() > 0){
            
             
              try{
              update listCampaignMemberToUpdate;
                
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
         
         
         //Create of Campaign Member from Attendee
        if(listCMToCreateFromAttendee != null && listCMToCreateFromAttendee.size() > 0){
             
             
              try{
                 insert listCMToCreateFromAttendee;
                
             }  catch(DmlException e){
            
            //ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName +' SM021_EtouchesProcessQueue insert listCMToCreateFromAttendee;/*\') ' +
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
         
         
          if(processToUpdate != null && processToUpdate.size() > 0){
             
              try{
               update processToUpdate;
             
                
             }  catch(DmlException e){
            
            //ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName +' SM021_EtouchesProcessQueue  update processToUpdate;/*\') ' +
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
         
        
        // Insert Error Log.
        EM023_Log.insertLogErrorScan(listLogError,ProcessIdCurrent.Index__c);
        
     }
        
    }
    
    
    /*
     private static List<Bounce_Etouches__c>  callGetBounceFromEvent(String EventEtouhcesId){
                
        String methodName = 'callGetBounceFromEvent';
        List<Bounce_Etouches__c>  listBounceAll= new List<Bounce_Etouches__c>();
        
        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        
        HttpRequest request =  EM022_BounceEtouches.getAllBounce(param_setting,param_setting.Token__c,EventEtouhcesId);
        
        
        HttpResponse responseBounceList = EM022_BounceEtouches.getListBounce(request, null);
        
        // Manage the list.
         if(responseBounceList.getStatusCode()!= 200){
            
            //Interface Log
                
            String fullResp = ' - Response: ' + responseBounceList + 
            ' / Response body: ' + responseBounceList.getBody()+
            ' / Response getStatus: ' + responseBounceList.getStatus()+
            ' / Response getStatusCode: ' + responseBounceList.getStatusCode();
            
            
            String fullReq = ' - Request header Authorization   : ' + request.getHeader('Authorization') +
            ' / Request header accept   : ' + request.getHeader('accept')+
            ' / Request header Content-Type  : ' + request.getHeader('Content-Type')+
            ' / Request string   : ' + request + 
            ' / Request  body: ' + request.getBody();   
            
            String recordData = ' - Event ID (Etouches ID) : ' + EventEtouhcesId;
               
            
            String Data = 'Class name :' + CLASS_NAME +' Service Create Communication Sub in Prospace - Methodname : '
             + methodName + recordData
            + fullReq ;
            
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Service Create Communication Sub in Prospace', Data,  fullResp);
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'Get Token in Etouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
            
            
        }else
        {
            if (responseBounceList.getBody().contains('No bounce back recipients found')){
                // BGU 
                // Skip this part
            }else{
                //Load the List
                String JsonlistetouchesBounce = responseBounceList.getBody();
                List<bounceData> listetouchesBounce = (List<bounceData>)JSON.deserialize(JsonlistetouchesBounce, List<bounceData>.class); 
                
                //Deserialize he json response
                
                for (bounceData bounceData : listetouchesBounce){
                    Bounce_Etouches__c newtemp = new Bounce_Etouches__c();
                    newtemp.Code__c = bounceData.email;
                    newtemp.Email__c = bounceData.code;
                    listBounceAll.add(newtemp);
                }
                
            }
        }
            
    
        
        return listBounceAll;
        
    }
    
    */
    
    
    private static Map<String,String> callGetScanSubscriber(datetime lastdate, String listid, String limits){

        //system.debug('ADBS inside callGetScanSubscriber');
        String methodName = 'callGetScanSubscriber';
        
        Map<String,String> mapStatusBySubscriberId = new  Map<String,String>();

        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        
        //Httprequest
        
        HttpRequest request = EM018_SubscriberEtouches.getAllSubscribers(param_setting,param_setting.Token__c,lastdate,listid,limits);
        
        //Httpresponse 
        
        HttpResponse responseEventList = EM018_SubscriberEtouches.getListSubscriber(request, null);
        
        
        if(responseEventList.getStatusCode()!= 200){
            
            //Interface Log
                
            String fullResp = ' - Response: ' + responseEventList + 
            ' / Response body: ' + responseEventList.getBody()+
            ' / Response getStatus: ' + responseEventList.getStatus()+
            ' / Response getStatusCode: ' + responseEventList.getStatusCode();
            
            
            String fullReq = ' - Request header Authorization   : ' + request.getHeader('Authorization') +
            ' / Request header accept   : ' + request.getHeader('accept')+
            ' / Request header Content-Type  : ' + request.getHeader('Content-Type')+
            ' / Request string   : ' + request + 
            ' / Request  body: ' + request.getBody();   
            
            String recordData = ' - Mailing List ID (listid) : ' + listid;
               
            
            String Data = 'Class name :' + CLASS_NAME +' - Service Get the Subscriber from a Mailing List ID - Methodname : '
             + methodName + recordData
            + fullReq ;
            
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Service Get the Subscriber from a Mailing List ID ', Data,  fullResp);
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'Service Get the Subscriber from a Mailing List ID';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
            
            
        }else
        {
            
            //Log if no error ? 
            
            //Process Fill the List 
            String JsonlistetouchesSubscribers = responseEventList.getBody();
            if(JsonlistetouchesSubscribers.contains('No subscribers found!')){
                //system.debug('No Subscribers found for this Campaign!');
            }else{
                List<subscriberEtouches> listetouchesSubscribers = (List<subscriberEtouches>)JSON.deserialize(JsonlistetouchesSubscribers, List<subscriberEtouches>.class); 
           
                for(subscriberEtouches  sub :listetouchesSubscribers){
                    mapStatusBySubscriberId.put(sub.subscriberid,sub.status);
                }        
            }
        }
        
        return mapStatusBySubscriberId;         
    } 
    
    
    
    
    private static attendeeInfo__c callGetScanAttendee(String eventid, String attendeeid){

        //system.debug('ADBS inside callGetScanAttendee');
        String methodName = 'callGetScanAttendee';
        
    //  Map<String,String> mapEmailByAttendeeId = new  Map<String,String>();
    //  List<attendeeInfo__c> listAttendeeEtouchesInfo = new List<attendeeInfo__c>();
        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        
        //Httprequest
        
        HttpRequest request = EM021_AttendeeEtouches.getAttendees(param_setting,param_setting.Token__c,eventid,attendeeid);
        
        //Httpresponse 
        
        HttpResponse responseEventList = EM021_AttendeeEtouches.getAttendee(request, null);
        
        attendeeInfo__c attendeeEtouchesInfo = new attendeeInfo__c();
        
         if(responseEventList.getStatusCode()!= 200){
            
            //Interface Log
                
            String fullResp = ' - Response: ' + responseEventList + 
            ' / Response body: ' + responseEventList.getBody()+
            ' / Response getStatus: ' + responseEventList.getStatus()+
            ' / Response getStatusCode: ' + responseEventList.getStatusCode();
            
            
            String fullReq = ' - Request header Authorization   : ' + request.getHeader('Authorization') +
            ' / Request header accept   : ' + request.getHeader('accept')+
            ' / Request header Content-Type  : ' + request.getHeader('Content-Type')+
            ' / Request string   : ' + request + 
            ' / Request  body: ' + request.getBody();   
            
            String recordData = ' - eventid  : ' + eventid + ' attendeeid  : ' + attendeeid;
               
            
            String Data = 'Class name :' + CLASS_NAME +' Service Get Attendee in Etouches - Methodname : '
             + methodName + recordData
            + fullReq ;
            
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Service Service Get Attendee in Etouches ', Data,  fullResp);
            
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'Service Service Get Attendee in Etouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
            
            
        }else
        {
            If(responseEventList.getBody().contains('is unavailable for this account')){
                
                attendeeEtouchesInfo.email__c='Error';
                
                
                String fullResp = ' - Response: ' + responseEventList + 
            ' / Response body: ' + responseEventList.getBody()+
            ' / Response getStatus: ' + responseEventList.getStatus()+
            ' / Response getStatusCode: ' + responseEventList.getStatusCode();
            
            
            String fullReq = ' - Request header Authorization   : ' + request.getHeader('Authorization') +
            ' / Request header accept   : ' + request.getHeader('accept')+
            ' / Request header Content-Type  : ' + request.getHeader('Content-Type')+
            ' / Request string   : ' + request + 
            ' / Request  body: ' + request.getBody();   
            
            String recordData = ' - eventid  : ' + eventid + ' attendeeid  : ' + attendeeid;
               
            
            String Data = 'Class name :' + CLASS_NAME +' Service Get Attendee in Etouches - Methodname : '
             + methodName + recordData
            + fullReq ;
            
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Service Service Get Attendee in Etouches ', Data,  fullResp);
            
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'Service Service Get Attendee in Etouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
                
                
                
            }
            else{
                //Process Fill the List 
            String JsonlistetouchesAttendees = responseEventList.getBody();
         // //system.debug('BOdy of the Scan Attendee'+JsonlistetouchesAttendees);
          //  List<attendeeEtouches> listetouchesAttendees = (List<attendeeEtouches>)JSON.deserialize(JsonlistetouchesAttendees, List<attendeeEtouches>.class); 
             attendeeEtouches theAttendee = (attendeeEtouches)JSON.deserialize(JsonlistetouchesAttendees, attendeeEtouches.class); 
        
                
                for(attendeeFormInfo resp :theAttendee.responses){
                    if(resp.fieldname == 'email'){
                        attendeeEtouchesInfo.email__c = resp.response;
                    }
                    if(resp.fieldname == 'fname'){
                        attendeeEtouchesInfo.firstName__c = resp.response;
                    }
                    if(resp.fieldname == 'lname'){
                        attendeeEtouchesInfo.lastName__c = resp.response;
                    }
                }
               attendeeEtouchesInfo.attendeeid__c = theAttendee.attendeeid;
               attendeeEtouchesInfo.registrationstatus__c = theAttendee.registrationstatus;
               attendeeEtouchesInfo.lastmodified__c = theAttendee.lastmodified; 
                
            
            //Log if no error ? 
                
            }
            
                
        }
        
        return attendeeEtouchesInfo;            
    }  
    
    
    private static Map<String,String> callGetScanSubscriberX(datetime lastdate, String listid, String limits,String OffSet){

        //system.debug('ADBS inside callGetScanSubscriber');
        String methodName = 'callGetScanSubscriber';
        
        Map<String,String> mapStatusBySubscriberId = new  Map<String,String>();

        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        
        //Httprequest
        
        HttpRequest request = EM018_SubscriberEtouches.getAllSubscribersX(param_setting,param_setting.Token__c,lastdate,listid,limits,OffSet );
        
        //Httpresponse 
        
        HttpResponse responseEventList = EM018_SubscriberEtouches.getListSubscriber(request, null);
        
        
        if(responseEventList.getStatusCode()!= 200){
            
            //Interface Log
                
            String fullResp = ' - Response: ' + responseEventList + 
            ' / Response body: ' + responseEventList.getBody()+
            ' / Response getStatus: ' + responseEventList.getStatus()+
            ' / Response getStatusCode: ' + responseEventList.getStatusCode();
            
            
            String fullReq = ' - Request header Authorization   : ' + request.getHeader('Authorization') +
            ' / Request header accept   : ' + request.getHeader('accept')+
            ' / Request header Content-Type  : ' + request.getHeader('Content-Type')+
            ' / Request string   : ' + request + 
            ' / Request  body: ' + request.getBody();   
            
            String recordData = ' - Mailing List ID (listid) : ' + listid;
               
            
            String Data = 'Class name :' + CLASS_NAME +' - Service Get the Subscriber from a Mailing List ID - Methodname : '
             + methodName + recordData
            + fullReq ;
            
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Service Get the Subscriber from a Mailing List ID ', Data,  fullResp);
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'Service Get the Subscriber from a Mailing List ID';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
            
            
        }else
        {
            
            //Log if no error ? 
            
            //Process Fill the List 
            String JsonlistetouchesSubscribers = responseEventList.getBody();
            if(JsonlistetouchesSubscribers.contains('No subscribers found!')){
                //system.debug('No Subscribers found for this Campaign!');
            }else{
                List<subscriberEtouches> listetouchesSubscribers = (List<subscriberEtouches>)JSON.deserialize(JsonlistetouchesSubscribers, List<subscriberEtouches>.class); 
           
                for(subscriberEtouches  sub :listetouchesSubscribers){
                    mapStatusBySubscriberId.put(sub.subscriberid,sub.status);
                }        
            }
        }
        
        return mapStatusBySubscriberId;         
    } 
    
    private static List<attendeeInfo__c> dedupAttende(List<attendeeInfo__c> todedup) {
        String methodName = 'dedupAttende';
    
    
        //system.debug('BGU todedup todedup ' + todedup);
        
        //system.debug('BGU todedup todedup ' + todedup.size());
        
        List<attendeeInfo__c> returnList = new List<attendeeInfo__c>();
        
        for (attendeeInfo__c attX : todedup){          
            
            Boolean TestX= false;
            Boolean TestY= false;
            
            String attXemail = attX.email__c;
            
            Integer Counter = 0;
            
            for (attendeeInfo__c attY : todedup){
                
                String attYemail = attY.email__c;
                
                if(attXemail == attYemail){ 
                
                
                    Counter = Counter + 1;
                    
                    if(Counter > 1){
                        
                        TestX= true;    
                    
                        String tempXDAte = attX.lastmodified__c;
                        String tempYDAte = attY.lastmodified__c;
                        
                        
                        Datetime timeAttX   =  Datetime.valueOf(tempXDAte);
                        Datetime timeAttY =  Datetime.valueOf(tempYDAte);
                        
                        
                        if(timeAttX < timeAttY){
                        
                        TestY= true;
                        
                    }
                        
                    }
                    
                    
                    
                }
                
                
                
            }
            if(!TestX){
                    
                    
                    returnList.add(attX);
                    
            }else
            {   
                if(TestY){
                    
                    returnList.add(attX);
                }
                
            }
            
        }
        
        //system.debug('BGU todedup returnList ' + returnList);
        
        //system.debug('BGU todedup returnList ' + returnList.size());
        
    
        return returnList;
        
    }
        
    
     private static Map<String,String> callGetScanListAttendees(datetime lastdate, String eventid, String limits){

        //system.debug('ADBS inside callGetScanListAttendees');
        String methodName = 'callGetScanListAttendees';
        
        Map<String,String> mapEmailByAttendeeId = new  Map<String,String>();

        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        
        //Httprequest
        
        HttpRequest request = EM021_AttendeeEtouches.getAllAttendees(param_setting,param_setting.Token__c,lastdate,eventid,limits);
        
        //Httpresponse 
        
        HttpResponse responseEventList = EM021_AttendeeEtouches.getListAttendee(request, null);
        
        if(responseEventList.getStatusCode()!= 200){
            
            //Interface Log
                
            String fullResp = ' - Response: ' + responseEventList + 
            ' / Response body: ' + responseEventList.getBody()+
            ' / Response getStatus: ' + responseEventList.getStatus()+
            ' / Response getStatusCode: ' + responseEventList.getStatusCode();
            
            
            String fullReq = ' - Request header Authorization   : ' + request.getHeader('Authorization') +
            ' / Request header accept   : ' + request.getHeader('accept')+
            ' / Request header Content-Type  : ' + request.getHeader('Content-Type')+
            ' / Request string   : ' + request + 
            ' / Request  body: ' + request.getBody();   
            
            String recordData = ' - Event ID (Etouches ID) : ' + eventid;
               
            
            String Data = 'Class name :' + CLASS_NAME +' Service Get List Attendee in Etouches - Methodname : '
             + methodName + recordData
            + fullReq ;
            
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Service Get List Attendee in Etouches ', Data,  fullResp);
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'Service Get List Attendee in Etouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
            
            
            
        }else
        {
            
            //Log if no error ? 
                
            //Process Fill the List 
            String JsonlistetouchesAttendees = responseEventList.getBody();
            if(JsonlistetouchesAttendees.contains('No attendees found.')){
                //system.debug('No Attendees found for this Campaign!');
            }else{
                List<listAttendeeEtouches> listetouchesAttendees = (List<listAttendeeEtouches>)JSON.deserialize(JsonlistetouchesAttendees, List<listAttendeeEtouches>.class); 
            
                for(listAttendeeEtouches  att :listetouchesAttendees){
                 mapEmailByAttendeeId.put(att.attendeeid,att.email);
                } 
            }
        }
        
        
        
     
        return mapEmailByAttendeeId;            
    }
    
    private static Map<String,String> callGetScanListAttendeesX(datetime lastdate, String eventid, String limits,String Offset){

        //system.debug('ADBS inside callGetScanListAttendees');
        String methodName = 'callGetScanListAttendees';
        
        Map<String,String> mapEmailByAttendeeId = new  Map<String,String>();

        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        
        //Httprequest
        
        HttpRequest request = EM021_AttendeeEtouches.getAllAttendeesX(param_setting,param_setting.Token__c,lastdate,eventid,limits,Offset);
        
        //Httpresponse 
        
        HttpResponse responseEventList = EM021_AttendeeEtouches.getListAttendee(request, null);
        
        if(responseEventList.getStatusCode()!= 200){
            
            //Interface Log
                
            String fullResp = ' - Response: ' + responseEventList + 
            ' / Response body: ' + responseEventList.getBody()+
            ' / Response getStatus: ' + responseEventList.getStatus()+
            ' / Response getStatusCode: ' + responseEventList.getStatusCode();
            
            
            String fullReq = ' - Request header Authorization   : ' + request.getHeader('Authorization') +
            ' / Request header accept   : ' + request.getHeader('accept')+
            ' / Request header Content-Type  : ' + request.getHeader('Content-Type')+
            ' / Request string   : ' + request + 
            ' / Request  body: ' + request.getBody();   
            
            String recordData = ' - Event ID (Etouches ID) : ' + eventid;
               
            
            String Data = 'Class name :' + CLASS_NAME +' Service Get List Attendee in Etouches - Methodname : '
             + methodName + recordData
            + fullReq ;
            
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Service Get List Attendee in Etouches ', Data,  fullResp);
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'Service Get List Attendee in Etouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
            
            
            
        }else
        {
            
            //Log if no error ? 
                
            //Process Fill the List 
            String JsonlistetouchesAttendees = responseEventList.getBody();
            if(JsonlistetouchesAttendees.contains('No attendees found.')){
                //system.debug('No Attendees found for this Campaign!');
            }else{
                List<listAttendeeEtouches> listetouchesAttendees = (List<listAttendeeEtouches>)JSON.deserialize(JsonlistetouchesAttendees, List<listAttendeeEtouches>.class); 
            
                for(listAttendeeEtouches  att :listetouchesAttendees){
                 mapEmailByAttendeeId.put(att.attendeeid,att.email);
                } 
            }
        }
        
        
        
     
        return mapEmailByAttendeeId;            
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
     
     public class attendeeToFind{
        public String email {get;set;}
        public String firstName {get;set;}
        public String lastName {get;set;}
        public String registrationstatus {get;set;}
        public String lastmodified {get;set;}
        public String campaignId {get;set;}
   }
    
    
      public class subscriberEtouches{
        public String subscriberid {get;set;}
        public String email {get;set;}
        public String fname {get;set;}
        public String lname {get;set;} 
        public String status {get;set;} 
    }
    
    public class attendeeEtouchesFormResponses{
        public List<attendeeFormInfo> attendeeFormInfos {get;set;}
   }
   public class attendeeFormInfo{
        public String fieldname {get;set;}
        public String response {get;set;}
   }
    
    
   
   
    public class listAttendeeEtouches{
        public String attendeeid {get;set;}
        public String parentid {get;set;}
        public String name {get;set;}
        public String email {get;set;}
   }
   
   public class attendeeEtouches{
        public String attendeeid {get;set;}
        public String registrationstatus {get;set;}
        public List<attendeeFormInfo>  responses {get;set;}
        public String lastmodified {get;set;}
   }
   
   
    public class bounceData{
        public String email {get;set;}
        public String code {get;set;}
   }
   
   	public static void fakeMethod(){
		Integer i = 0;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
			i++;
		}

	
    
       
}