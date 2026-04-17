/** 
 * @author : Briag GUEMARD
 * @date : Creation 13/04/2016
 * @date : Modification 15/04/2016
 * @description : Queuable Methode with Allow Callout.
 */
 
 
public class SM022EtouchesProcess2 implements Queueable,  Database.AllowsCallouts {
    
    private static String  CLASS_NAME = SM022EtouchesProcess2.class.getName();
    
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();



    private List<Campaign> CampaignToManageLeft;
    private Process_Id__c ProcessIdCurrent;
    private datetime lastDate;
    private Campaign CampaignInProgress;
    private Map<String, String> mapEmailByAttendeeIdFinal; // => OLD BGUprivate List<String> ListAttendeLeft;
	private List<attendeeInfo__c> ListAttendeAlreadyScanned;
	private Integer LoopX;
    private String methodName = 'SM022_EtouchesProcessQueue';
    
    
    
    
    /*********** Constructor *************/
    public SM022EtouchesProcess2(List<Campaign> CampaignToManageLeftJob, Process_Id__c ProcessIdCurrentJob, datetime lastDateJob, Campaign CampaignInProgressJob, Map<String, String> mapEmailByAttendeeIdJob, List<attendeeInfo__c> ListAttendeAlreadyScannedJob, Integer LoopJob ){
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
        
        
        
        //List<Bounce_Etouches__c> listBounceToInsert = new  List<Bounce_Etouches__c>();
        
        List<Lead> listLeadToCreateFromAttendee = new List<Lead>();
        
        List<attendeeToFind> listAttendeesToFind = new List<attendeeToFind>();
        
        List<CampaignMember> listCMToCreateFromAttendee = new List<CampaignMember>();
        
        List<Process_Id__c> processToUpdate = new List<Process_Id__c>();
        
        
        
        String evId;
    
        
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
            
            if (Limits.getHeapSize() > 0.3 * Limits.getLimitHeapSize()){
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
                    
                	if (Limits.getCallouts() > 0.3 * Limits.getLimitCallouts()){
                
						limitReached = true;
						
					}
					
					if (Limits.getHeapSize() > 0.3 * Limits.getLimitHeapSize()){
            			HeapLimit = true;
            		}
                	
                   
            }
            
            
            
            
             //system.debug('BGU limitReached ' + limitReached);
            
            //TEST is limits reached 
            if(!EndofFile || !HeapLimit){
                
                
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
                
                SM022_EtouchesProcessQueue newjob = new SM022_EtouchesProcessQueue(CampaignToManageLeft,ProcessIdCurrent,lastDate,null,null,null);
                
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
        }
        
        
        
   		if(listLeadToCreateFromAttendee != null && listLeadToCreateFromAttendee.size() > 0){
            
             
               try{
               insert listLeadToCreateFromAttendee;
                
             }  catch(DmlException e){
            
            //ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName +' SM022_EtouchesProcessQueue  insert listLeadToCreateFromAttendee;/*\') ' +
            ' -Type : DmlException - Response Message  : ' + e.getMessage();
  
            
            String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM022_EtouchesProcessQueue / scanEtouches : ' + ProcessIdCurrent.Index__c;
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
            
            String fullResp = methodName +' SM022_EtouchesProcessQueue update listCMToUpdateFromAttendee;/*\') ' +
            ' -Type : DmlException - Response Message  : ' + e.getMessage();
  
            
            String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM022_EtouchesProcessQueue / scanEtouches : ' + ProcessIdCurrent.Index__c;
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
            
            String fullResp = methodName +' SM022_EtouchesProcessQueue insert listCMToCreateFromAttendee;/*\') ' +
            ' -Type : DmlException - Response Message  : ' + e.getMessage();
  
            
            String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM022_EtouchesProcessQueue / scanEtouches : ' + ProcessIdCurrent.Index__c;
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
            
            String fullResp = methodName +' SM022_EtouchesProcessQueue  update processToUpdate;/*\') ' +
            ' -Type : DmlException - Response Message  : ' + e.getMessage();
  
            
            String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM022_EtouchesProcessQueue / scanEtouches : ' + ProcessIdCurrent.Index__c;
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
    



    
}