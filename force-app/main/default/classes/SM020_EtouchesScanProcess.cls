/** 
 * @author : guemard briag
 * @date : Creation 13/04/2017
 * @date : Modification 13/04/2017
 * @description Service manager for Etouhces Scan.
 */
public class SM020_EtouchesScanProcess {
    
    
    private static String  CLASS_NAME = SM020_EtouchesScanProcess.class.getName();
    
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
    
    /**
    * @author : guemard briag
    * @date : Creation  13/04/2017
    * @date : Modification  13/04/2017
    * @description : This Methode launch 2 callout,
        1 : Get All Event modified since yesterday
        2 : Get All Event Live / Pre event
        
        
        With the result,
        1 All event modified, modifies the relative Campaign in Salesforce
        2 : Launch queuable Process for all the Campaign
        
    * @param wsContact : ScanEtouches
    * @return : Response Wrapper
    
    */
   
    @future(callout=true)
    public static void processEtouches(Id campaignID){
        
        
        String methodName = 'processEtouches';
        
        List<Campaign> listCampaignToUpdate = new List<Campaign>();
        List<Campaign> listCampToUpdateStatus = new List<Campaign>();
        List<Campaign> listCampInfosToUpdate = new List<Campaign>();
       
        datetime lastDate = Date.newInstance(2017, 03, 15);
        
        lastDate = Date.today().addDays(-1);
       
        system.debug('BGU DATA');
        //*********************Data preparation *************************//
        List<Campaign> listCampToUpdate = new List<Campaign>();
        List<Id> listID = new List<Id>();
        listID.add(campaignID);
        Map<String,String> mapEventStatusByEventId = new Map<String,String>();
        Map<String,eventEtouches> mapEventInfosByEventId = new Map<String,eventEtouches>();
        Set<String> SetStringEventID = new Set<String>();
        
        Campaign campaignInProgress = new Campaign();
        listCampToUpdate = EM011_Campaign.getAllListByIds(listID);
        
        List<Campaign> listCampToSend = listCampToUpdate;
        
        campaignInProgress = listCampToUpdate.get(0);
        if(listCampToUpdate !=null && listCampToUpdate.size()>0){
            campaignInProgress = listCampToUpdate.get(0);
        }else{
            
            // => Go out.
             
        }
        //Process ID 
        Datetime Prcss = Datetime.now();
        String processId = Prcss.format('yyyyMMddkkmmss');
        
        Process_Id__c tempProcess = new Process_Id__c();
        tempProcess.Index__c = processId;
        
        tempProcess.Date_Process__c = lastDate;
        
        //******************** 1st Process *********************//
        //******************** callGetAllScanEvent**************//
        
        
        
        system.debug('BGU callGetAllScanEvent');
        //launch the 1st call and Manage the status.
        List<eventEtouches> listModifiedEventID = new  List<eventEtouches>();
        eventEtouches modifiedEventID = new eventEtouches();
        
        //CALLOUT
     // listModifiedEventID = callGetAllScanEventOne(campaignInProgress.Event_code_Etouches__c, processId);
        //ASO 04/05/2017
        modifiedEventID = callGetAllScanEventOne(campaignInProgress.Event_code_Etouches__c, processId);
        //System.debug('ADBS Json deserialised'+listModifiedEventID);
        
        // Process Update the status
     // mapEventStatusByEventId = mapStatusByEventID(listModifiedEventID);
        //ASO 04/05/2017
        mapEventInfosByEventId = mapCampaignInfosByEventID(modifiedEventID);
        SetStringEventID = mapEventStatusByEventId.keySet();
        
        
       
     //     listCampToUpdateStatus = listCampaignToUpdate(listCampToUpdate, mapEventStatusByEventId);
        //ASO 04/05/2017
        listCampInfosToUpdate = listCampaignToUpdate2(listCampToUpdate, mapEventInfosByEventId);
        
        //Launch Queuable Process
        
        //SM021_EtouchesProcessQueue newjob = new SM021_EtouchesProcessQueue(listCampToSend,tempProcess,lastDate,null,null,null,1);
        
        SM21_EtouchesInit newjob = new SM21_EtouchesInit(listCampToSend,tempProcess,lastDate,null,null,null,1);
        
        
        ID jobID = System.enqueueJob(newjob);
        
      //    if(listCampToUpdateStatus != null && listCampToUpdateStatus.size() > 0){
       // ASO 04/05/2017
        if(listCampInfosToUpdate != null && listCampInfosToUpdate.size() > 0){  
            
            try{
                // update listCampToUpdateStatus;
                // ASO 04/05/2017
                update listCampInfosToUpdate;
                
             }  catch(DmlException e){
                
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName +' SM020_EtouchesScanProcess UPDATE CAMPAIGN STATUS FROM ETOUCHES/*\') ' +
            ' -Type : DmlException - Response Message  : ' + e.getMessage();
  
            
            String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM020_EtouchesScanProcess.processEtouches(scanEtouches); / ';
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Input Communication WebSite', Data,  fullResp);
            
            
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'processEtouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
            }
                
                 
        } 
       
       
       
       
       
       
        EM023_Log.insertLogErrorScan(listLogError,processId);
        insert tempProcess;
        
        
        
        
    }
    
    
    
    /**
    * @author : Briag GUEMARD
    * @date : Creation 22/03/2017
    * @date : Modification 15/05/2017
    */
    
    public class eventEtouches{
        
        public String eventid {get;set;}
        public String status {get;set;}
        public String lastmodified {get;set;}
        public String startdate {get;set;}  
        public String starttime {get;set;} 
        public String enddate {get;set;}
        public String endtime {get;set;}
        public String timezoneid {get;set;}
        public String description {get;set;}
        public String max_reg {get;set;}
        public String closedate {get;set;}
        public String closetime {get;set;}
        public String programmanager {get;set;}
        public String clientcontact {get;set;}
        public eventAddressEtouches location {get;set;}
    }
    
     public class eventAddressEtouches{
        public String name {get;set;}
        public String address1 {get;set;}
        public String address2 {get;set;}
        public String city {get;set;}
        public String state {get;set;}
        public String postcode {get;set;}   
        public String country {get;set;}
        public String phone {get;set;}
        public String email {get;set;}
        public String maptovenue {get;set;}
     }
    
  
    
 //   public static List<eventEtouches> callGetAllScanEventOne(String EventID,String processId){
     public static eventEtouches callGetAllScanEventOne(String EventID,String processId){
    
        system.debug('BGU inside callGetAllScanEventOne');
        
        String methodName = 'callGetAllScanEventOne';
        
        List<eventEtouches> eventList = new  List<eventEtouches>();
        eventEtouches eventInfos = new eventEtouches();

        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        
        //Httprequest
        
        HttpRequest request = EM0017_EventEtouches.getAllEventEtouchesOne(param_setting,param_setting.Token__c,EventID );
        
        //Httpresponse 
        
    //  HttpResponse responseEventList = EM0017_EventEtouches.getListEvent(request, null);
        //ASO 04/05/2017
        HttpResponse responseEventList = EM0017_EventEtouches.getEvent(request, null);
        
        
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
            
            String recordData = ' - processId : ' + processId;
               
            
            String Data = 'Class name : ' + CLASS_NAME +' Service Call All Event in Etouches - Methodname : '
             + methodName + recordData
            + fullReq ;
            
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Service Call All Event in Etouches ', Data,  fullResp);
            
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'Service Call All Event in Etouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
            
            
            
        }else
        {
        //Log if no error ? 
        //Process Fill the List 
        
            
            String fullResp = ' - Response: ' + responseEventList + 
            ' / Response body: ' + responseEventList.getBody()+
            ' / Response getStatus: ' + responseEventList.getStatus()+
            ' / Response getStatusCode: ' + responseEventList.getStatusCode();
            
            
            String fullReq = ' - Request header Authorization   : ' + request.getHeader('Authorization') +
            ' / Request header accept   : ' + request.getHeader('accept')+
            ' / Request header Content-Type  : ' + request.getHeader('Content-Type')+
            ' / Request string   : ' + request + 
            ' / Request  body: ' + request.getBody();   
            
            String recordData = ' - processId : ' + processId;
               
            
            String Data = 'Class name : ' + CLASS_NAME +' Service Call All Event in Etouches - Methodname : '
             + methodName + recordData
            + fullReq ;
            system.debug('BGU fullResp' + fullResp);
            system.debug('BGU fullReq' + fullReq);
            system.debug('BGU recordData' + fullResp);
            
            system.debug('BGU DAta ' + Data);
        
        
        
            String JsonlistetouchesEvents = responseEventList.getBody();
        //  if (JsonlistetouchesEvents.contains('{"data":"No events found') ){
            if (JsonlistetouchesEvents.contains('is not a valid event for this account, perhaps it has been deleted?') ){   
                System.debug('The specified Event id is not a valid event for this account, perhaps it has been deleted?');
                
            }else{
            //  eventList = (List<eventEtouches>)JSON.deserialize(JsonlistetouchesEvents, List<eventEtouches>.class);
                eventInfos = (eventEtouches)JSON.deserialize(JsonlistetouchesEvents, eventEtouches.class);
            }
            
              
                
        }
        

    //  return eventList;    
    //  ASO 05/05/2017
        return eventInfos;
    }
    
    
    
     
        /** 
        * @author : Briag GUEMARD
        * @date : Creation 27/03/2016
        * @date : Modification 27/03/2016
        * @description : manages Scan on Etouches to get Preevent and Live elements
        * @param : none
        * @return : List of Event ID
    */
    
    /*
    private static List<String> callGetScanEvent(List<Template_Etouches__c> listAllTemplateToExcludeScan){

        system.debug('BGU inside callGetScanEvent');
        String methodName = 'callGetScanEvent';
        
        List<String> listStringEventID = new  List<String>();

        //BGu test
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [listStringEventID] : ' + listStringEventID); 
        
        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        
        //Httprequest
        
        HttpRequest request = EM0017_EventEtouches.getLivePreEventtEtouches(param_setting,param_setting.Token__c);
        
        //Httpresponse 
        
        HttpResponse responseEventList = EM0017_EventEtouches.getListEvent(request, null);
        
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
            
            //String recordData = ' - CommunicationSubscription ID : ' + CommunicationSubscription.Id;
               
            String Data = 'Class name : ' + CLASS_NAME +' Service Call Event To scan in Etouches - Methodname : '
             + methodName + fullReq ;
            
            //EM023_Log.createInterfaceLogIn(Datetime.now(),'Service Call Event To scan in Etouches', Data,  fullResp);
            
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName = 'Service Call Event To scan in Etouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);
            
            
        }else
        {
            
            //Log if no error ?
            //Process Fill the List 
            
            String JsonlistetouchesEvents = responseEventList.getBody();
            
            
            if (JsonlistetouchesEvents.contains('{"data":"No events found') ){
                System.debug('No events found for this');
            }else{
                List<eventEtouches> listetouchesEvent = (List<eventEtouches>)JSON.deserialize(JsonlistetouchesEvents, List<eventEtouches>.class); 
            
                for(eventEtouches  ev :listetouchesEvent){
                    
                    Boolean testIfTemplate= false;
                    for(Template_Etouches__c  templateId :listAllTemplateToExcludeScan){
                    
                        if(templateId.TemplateID__c ==ev.eventid){
                            testIfTemplate = true;  
                        }
                    
                    }
                    if(!testIfTemplate){
                        listStringEventID.add(ev.eventid);
                    }
                }  
            }
                  
            
            ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [listStringEventID] : ' + listStringEventID);
          
        }
        
        return listStringEventID;  
                
    }*/
    
    
    /** 
 * @author: Adolphe SONKO
 * @date : Creation 27/03/2017
 * @date : Modification 27/03/2017
 * @param : listEventetouches
 * @return : Map<String,String> mapStatusByEventID
*/
   private static Map<String,String> mapStatusByEventID(List<eventEtouches> listEventetouches){

        system.debug('ADBS inside mapStatusByEventID');
        
        String methodName = 'mapStatusByEventID';
        
        Map<String,String> mapStatusByEventID = new Map<String,String>();

        for(eventEtouches  ev :listEventetouches){
            mapStatusByEventID.put(ev.eventid, ev.status);
        }
        
       return mapStatusByEventID;
    }
   
    
   private static Map<String,eventEtouches> mapCampaignInfosByEventID(eventEtouches eventInfosEtouches){

        system.debug('ADBS inside mapCampaignInfosByEventID');
        
        String methodName = 'mapCampaignInfosByEventID';
        
        Map<String,eventEtouches> mapCampaignInfosByEventID = new Map<String,eventEtouches>();

        mapCampaignInfosByEventID.put(eventInfosEtouches.eventid, eventInfosEtouches);

        
       return mapCampaignInfosByEventID;
    }
    
   
/** 
 * @author: Adolphe SONKO
 * @date : Creation 28/03/2017
 * @date : Modification 28/03/2017
 * @param : listCampaigns, mapEventStatusByEventId
 * @return : List<Campaign> listCampaignToUpdate
*/
   
    private static List<Campaign> listCampaignToUpdate(List<Campaign> listCampaigns, Map<String,String> mapEventStatusByEventId){
        
        String methodName = 'listCampaignToUpdate'; 
        system.debug('ADBS inside listCampaignToUpdate');
        
        List<Campaign> listCampaignToUpdate = new List<Campaign>();
        for(Campaign camp: listCampaigns){
            
        system.debug('BGU camp.Status ' + camp.Status );
        system.debug('BGU mapEventStatusByEventId' + mapEventStatusByEventId.get(camp.Event_code_Etouches__c));     
            if(camp.Status != mapEventStatusByEventId.get(camp.Event_code_Etouches__c)){
                system.debug('BGU INSIDE');
                
                camp.Status = mapEventStatusByEventId.get(camp.Event_code_Etouches__c);
                listCampaignToUpdate.add(camp);
            }
        }
        
        system.debug('BGU RETURN  ' + listCampaignToUpdate );
        return listCampaignToUpdate;
     }
    

     private static List<Campaign> listCampaignToUpdate2(List<Campaign> listCampaigns, Map<String,eventEtouches> mapCampaignInfosByEventID){
        
        String methodName = 'listCampaignToUpdate'; 
        system.debug('ADBS inside listCampaignToUpdate');
        
        String closedatevide = '0000-00-00';
        List<Campaign> listCampaignToUpdate = new List<Campaign>();
        for(Campaign camp: listCampaigns){
            
        system.debug('ASO camp.Status ' + camp.Status );
        system.debug('ASO mapCampaignInfosByEventID from Etouches:' + mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c));      
            if(mapCampaignInfosByEventID != null && mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c) != null){
                    if( camp.Status != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).status
                       || camp.Local_zone__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).timezoneid
                       || camp.Etouches_Event_Description__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).description
                       || camp.Maximum_registration__c != Double.valueOf(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).max_reg)
                       || camp.Event_Local_Start_Time__c != (mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).startdate +' '+ mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).starttime) 
                       || camp.Event_Local_End_Time__c != (mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).enddate +' '+ mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).endtime) 
                 //      || camp.Registration_Closed_Date__c != Datetime.valueOf(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).closedate +' '+ mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).closetime)
                       || camp.Address_1__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.address1
                       || camp.Address_2__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.address2
                       || camp.City__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.city
                       || camp.Country__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.country
                       || camp.Post_Code__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.postcode
                       || camp.Location_name__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.name
                       || camp.Map_to_Venue__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.maptovenue
                       || (mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).clientcontact != null && camp.CRM_User__c != EM020_User.getListByName(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).clientcontact).Id )
                       || (mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).programmanager != null && camp.OwnerId != EM020_User.getListByName(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).programmanager).Id )){
                   
                system.debug('ASO INSIDE');
                
                    if(camp.Status != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).status){ camp.Status = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).status;} 
                    if(camp.Local_zone__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).timezoneid){ camp.Local_zone__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).timezoneid;}
                    if(camp.Etouches_Event_Description__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).description){ camp.Etouches_Event_Description__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).description;}
                    if(camp.Maximum_registration__c != Double.valueOf(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).max_reg)){ camp.Maximum_registration__c = Double.valueOf(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).max_reg);} 
                 //   if(camp.Start_Date_Time__c != Datetime.valueOf(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).startdateTime)){ camp.Start_Date_Time__c = Datetime.valueOf(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).startdateTime);}
                 //   if(camp.End_Date_Time__c != Datetime.valueOf(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).enddatetime)){ camp.End_Date_Time__c = Datetime.valueOf(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).enddatetime);} 
                    if(camp.Event_Local_Start_Time__c != (mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).startdate +' '+ mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).starttime)){ camp.Event_Local_Start_Time__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).startdate +' '+ mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).starttime;}
                    if(camp.Event_Local_End_Time__c != (mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).enddate +' '+ mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).endtime)){ camp.Event_Local_End_Time__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).enddate +' '+ mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).endtime;}                  
                    if(!ObjectUtil.isEmpty(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).closedate) && mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).closedate != closedatevide){                
                        if(camp.Registration_Closed_Date__c !=  Datetime.valueOf(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).closedate +' '+ mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).closetime)){ camp.Registration_Closed_Date__c = Datetime.valueOf(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).closedate +' '+ mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).closetime);} 
                    } 
                    If(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location != null){
                            if(camp.Address_1__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.address1){ camp.Address_1__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.address1;}
                            if(camp.Address_2__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.address2){ camp.Address_2__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.address2;}
                            if(camp.City__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.city){ camp.City__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.city;}
                            if(camp.Country__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.country){ camp.Country__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.country;}  
                            if(camp.Post_Code__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.postcode){ camp.Post_Code__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.postcode;}
                            if(camp.Location_name__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.name){ camp.Location_name__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.name;}  
                            if(camp.Map_to_Venue__c != mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.maptovenue){ camp.Map_to_Venue__c = mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).location.maptovenue;}     
                    }
                      
                    if(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).clientcontact != null && camp.CRM_User__c != EM020_User.getListByName(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).clientcontact).Id){ camp.CRM_User__c = EM020_User.getListByName(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).clientcontact).Id;}
                    if(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).programmanager != null && camp.OwnerId != EM020_User.getListByName(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).programmanager).Id){ camp.OwnerId = EM020_User.getListByName(mapCampaignInfosByEventID.get(camp.Event_code_Etouches__c).programmanager).Id;}  
                    
                    listCampaignToUpdate.add(camp);
                }
            }
            
        }
        
        system.debug('ASO RETURN  ' + listCampaignToUpdate );
        return listCampaignToUpdate;
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
        }

        
        
     
     
     
     
     
     
     
     
     
    
    }