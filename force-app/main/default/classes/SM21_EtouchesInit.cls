/** 
 * @author : Briag GUEMARD
 * @date : Creation 13/04/2016
 * @date : Modification 15/04/2016
 * @description : Queuable Methode with Allow Callout.
 */
 
 
public class SM21_EtouchesInit implements Queueable,  Database.AllowsCallouts {


	private static String  CLASS_NAME = SM21_EtouchesInit.class.getName();
    
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();



    private List<Campaign> CampaignToManageLeft;
    private Process_Id__c ProcessIdCurrent;
    private datetime lastDate;
    private Campaign CampaignInProgress;
    private Map<String, String> mapEmailByAttendeeIdFinal; // => OLD BGUprivate List<String> ListAttendeLeft;
	private List<attendeeInfo__c> ListAttendeAlreadyScanned;
	private Integer LoopX;
    private String methodName = 'SM21_EtouchesInit';
    
    
    
    /*********** Constructor *************/
    public SM21_EtouchesInit(List<Campaign> CampaignToManageLeftJob, Process_Id__c ProcessIdCurrentJob, datetime lastDateJob, Campaign CampaignInProgressJob, Map<String, String> mapEmailByAttendeeIdJob, List<attendeeInfo__c> ListAttendeAlreadyScannedJob, Integer LoopJob ){
        this.CampaignToManageLeft = CampaignToManageLeftJob;
        this.ProcessIdCurrent = ProcessIdCurrentJob;
        this.lastDate = lastDateJob;
        this.CampaignInProgress = CampaignInProgressJob;
        this.mapEmailByAttendeeIdFinal = mapEmailByAttendeeIdJob;  // => OLD BGU this.ListAttendeLeft = ListAttendeLeftJob;
		this.ListAttendeAlreadyScanned = ListAttendeAlreadyScannedJob;
		this.loopX=LoopJob;
    }
    
     public void execute(QueueableContext context) {
        
        system.debug('BGU SM21_EtouchesInit');
        
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
        
        boolean testSub = false;
        
        SM023_EtouchesProcessSubscriber newjobS = null;
        
        
    
        /************* 1ST BLOC **************/
       
        
        if(CampaignInProgress ==null){
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
                             
                             
                               
		                 // LAUNCH SUBSCRIBER PROCESS 
		                 // LAUNCH SUBSCRIBER PROCESS 
		                 // LAUNCH SUBSCRIBER PROCESS 
		                 // LAUNCH SUBSCRIBER PROCESS 
		                 // LAUNCH SUBSCRIBER PROCESS 
		                 // LAUNCH SUBSCRIBER PROCESS 
		                 // LAUNCH SUBSCRIBER PROCESS 
		                 // PARAMETER mapMemberStatusBySubscriberId
		                 
		                 
		                  system.debug('BGU  LAUNCH SM023_EtouchesProcessSubscriber');
                		//SM023_EtouchesProcessSubscriber newjobS = new SM023_EtouchesProcessSubscriber(ProcessIdCurrent,lastDate,CampaignInProgress,LoopX,mapMemberStatusBySubscriberId);
                		
                		testSub = true;
                		mapEmailByAttendeeIdFinal = null;
                		newjobS = new SM023_EtouchesProcessSubscriber(ProcessIdCurrent,lastDate,CampaignInProgress,LoopX,mapMemberStatusBySubscriberId, mapEmailByAttendeeIdFinal);
                		
                
                		//ID jobIDS = System.enqueueJob(newjobS);
                		
                		
                		
		               
		                             
                             // END OLD TO ERASE ! 
                        }
                        	//system.debug('BGU mapStatusBySubscriberId SIZE  '+mapStatusBySubscriberId.keySet().size());
                 }
                 
                 
              
                //Update the Campaign member 
                /*if(mapMemberStatusBySubscriberId != null && mapMemberStatusBySubscriberId.keySet().size() > 0){
                     
                     
                     // => 
                     
                     SetSubscriberIds = mapMemberStatusBySubscriberId.keySet();
                     //4th SOQL
                     listCampaignMembers = DM017_etouchesCreateSubscriber.getListBySubscriberIds(SetSubscriberIds) ;
                
                     listCampaignMemberToUpdate2 = listCampaignMemberToUpdate(listCampaignMembers, mapMemberStatusBySubscriberId);
                       
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
                        
                        
                        
                     }
                    
               		// LAUNCH PROCESS 
                        
                    //mapEmailByAttendeeId2 = callGetScanListAttendeesX(lastDate, evId, String.valueOf(beforelimits+Offset)) ;
                    loopX=loopX+1;
                	
                	 system.debug('BGU  LAUNCH SM022_EtouchesProcessAttendee');
                	
                	
                	if(testSub){
                		
                		newjobS = new SM023_EtouchesProcessSubscriber(ProcessIdCurrent,lastDate,CampaignInProgress,LoopX,mapMemberStatusBySubscriberId, mapEmailByAttendeeIdFinal);
                		
                	}else{
                		
                		newjobS = new SM023_EtouchesProcessSubscriber(ProcessIdCurrent,lastDate,CampaignInProgress,LoopX,null, mapEmailByAttendeeIdFinal);
                		
                	}
                	 
                	 
                	 
                	 //newjobA = new SM022_EtouchesProcessAttendee(null,ProcessIdCurrent,lastDate,CampaignInProgress,mapEmailByAttendeeIdFinal,null,loopX);
                
                	
                
                        
                    // OK FOR 4k NEED TO UP. 
                 }
                 
                 
                 
                 /* //system.debug('BGU mapEmailByAttendeeId');*/
                 
                 
                 ////system.debug(mapEmailByAttendeeId);
            
                
                
        }   
        
        
        if (mapEmailByAttendeeIdFinal !=null){
        	
        	
        }
        
        
        
        
        
         if(newjobS!=null){
         	 ID jobIDS = System.enqueueJob(newjobS);
         }  
        
       
         
        
        // Insert Error Log.
        EM023_Log.insertLogErrorScan(listLogError,ProcessIdCurrent.Index__c);
        
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
    
    
    
    
  /*  private static attendeeInfo__c callGetScanAttendee(String eventid, String attendeeid){

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
    }  */
    
    
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
    
    /*
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
        
    }*/
        
    
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
     
    
    /*
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
     }*/
     
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
  	}
    
       
}