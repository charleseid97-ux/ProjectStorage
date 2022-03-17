/** 
 * @author : Adolphe SONKO
 * @date : Creation 02/05/2017
 * @date : Modification 02/05/2017
 * @description : web service REST class to handle creation and modification of Campaigns. Its exposed for the Etouches.
 */
@RestResource(urlMapping='/EtouchesCampaign/*')
global class WS007_EtouchesEventProcess {
	
    private static String  CLASS_NAME = WS007_EtouchesEventProcess.class.getName();
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();

    
   /**
    * @author : Adolphe SONKO
    * @date : Creation 02/05/2017
    * @date : Modification 02/05/2017
    * @description : manages to retrieve Campaign .
    * @param : EtouchesEvent etouchesEvent is the Etouches Event.
    * @return : WSResponseWrapper the Webservice response containes the created or updated Contact/Lead.
    */
    @HttpPost
	global static WSResponseWrapper doPost(EtouchesEvent etouchesEvent){
        
        String methodName = 'doPost';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [etouchesEvent] : ' + etouchesEvent);
		
        WSResponseWrapper response = new WSResponseWrapper();

        Savepoint sp = Database.setSavepoint();
        
        try{
            response = SM024_EtouchesProcessEvent.getCampaign(etouchesEvent);
            
        } catch(DmlException e){
        	
            Database.rollback(sp);
            response.Message = e.getMessage();
            response.Status = WSResponseWrapper.WS_STATUS_ERROR;
            response.TechnicalMessage = e.getStackTraceString();
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName + '  @RestResource(urlMapping=\'/EtouchesCampaign/*\') - Type : DML Excepttion - Response Message  : ' + e.getMessage() +
        	' / Response Status : ' + WSResponseWrapper.WS_STATUS_ERROR +
        	' / Response TechnicalMessage : ' + e.getStackTraceString();           	   
        	
        	String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM024_EtouchesProcessEvent.getCampaign(etouchesEvent); / Event Id : ' + etouchesEvent.EtouchesEventId; 
        	
        	
        	EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
        	newErro.dateCreate = Datetime.now();
        	newErro.interfaceName ='Input Campaign Etouches';
        	newErro.Data = Data;
        	newErro.error = fullResp;
		        	
        	listLogError.add(newErro);
        	
            
        } catch(Exception e){
            Database.rollback(sp);
            response.Message = e.getMessage();
            response.Status = WSResponseWrapper.WS_STATUS_ERROR;
            response.TechnicalMessage = e.getStackTraceString();
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [Exception] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
                  	
        	
        	String fullResp = '  @RestResource(urlMapping=\'/EtouchesCampaign/*\') - Response Message  : ' + e.getMessage() +
        	' / Response Status : ' + WSResponseWrapper.WS_STATUS_ERROR +
        	' / Response TechnicalMessage : ' + e.getStackTraceString();   
        				
            String Data;
            if(etouchesEvent == null){
                 Data =  'Class name :' + CLASS_NAME + '  Methodname : SM024_EtouchesProcessEvent.getCampaign(etouchesEvent); / etouchesEvent : '+'null';
            }else{
                 Data =  'Class name :' + CLASS_NAME + '  Methodname : SM024_EtouchesProcessEvent.getCampaign(etouchesEvent); / Event Id : ' + etouchesEvent.EtouchesEventId; 
            }
        	        	
     		
        	EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
        	newErro.dateCreate = Datetime.now();
        	newErro.interfaceName ='Input Event Etouches';
        	newErro.Data = Data;
        	newErro.error = fullResp;
		        	
        	listLogError.add(newErro);
            
            
        }
       	
        //String strWSResponse = JSON.serialize(response);
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, ' [response] : '+ response);
        
        return response;
           
    }
    
    
       /**
    * @author : Adolphe SONKO
    * @date : Creation 02/05/2017
    * @date : Modification 02/05/2017
    * @description : manages to retrieve Campaign .
    * @param : EtouchesEvent etouchesEvent is the Etouches Event.
    * @return : WSResponseWrapper the Webservice response containes the created or updated Contact/Lead.
    */
    @HttpPut
	global static WSResponseWrapper doPut(EtouchesEventUpdate etouchesupdateEvent){
        
        String methodName = 'doPut';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [etouchesupdateEvent] : ' + etouchesupdateEvent);
		
        WSResponseWrapper response = new WSResponseWrapper();

        Savepoint sp = Database.setSavepoint();
        
        try{
            response = SM024_EtouchesProcessEvent.updateCampaign(etouchesupdateEvent);
            
        } catch(DmlException e){
        	
            Database.rollback(sp);
            response.Message = e.getMessage();
            response.Status = WSResponseWrapper.WS_STATUS_ERROR;
            response.TechnicalMessage = e.getStackTraceString();
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName + '  @RestResource(urlMapping=\'/EtouchesCampaign/*\') - Type : DML Excepttion - Response Message  : ' + e.getMessage() +
        	' / Response Status : ' + WSResponseWrapper.WS_STATUS_ERROR +
        	' / Response TechnicalMessage : ' + e.getStackTraceString();           	   
        	
        	String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM024_EtouchesProcessEvent.updateCampaign(etouchesupdateEvent); / Event SFId : ' + etouchesupdateEvent.EventSFId + 
       // 	' / Owner : ' + etouchesupdateEvent.Owner +
        	' / Status : ' + etouchesupdateEvent.Status +
       /* 	' / CRM USER : '+ etouchesupdateEvent.CRM_USER_SFId +
        	' / SalesTeam : '+ etouchesupdateEvent.SalesTeam +
       // 	' / EventCategory : '+etouchesupdateEvent.EventCategory +
			' / Company Name : '+etouchesupdateEvent.CompanySFId +
       //  	' / Event Type : '+etouchesupdateEvent.EventType +
         	' / Name : '+etouchesupdateEvent.Name +
            ' / StartDateTime : '+etouchesupdateEvent.StartDateTime +
            ' / EndDateTime : '+etouchesupdateEvent.EndDateTime +  */
            ' / Registration Close Date : '+etouchesupdateEvent.RegistrationCloseDate +
       //     ' / Local Zone : '+etouchesupdateEvent.LocalZone +
       //     ' / Commercial Strategy : '+etouchesupdateEvent.CommercialStrategy +
       //     ' / Targeted Attendees : '+etouchesupdateEvent.TargetedAttendees +
            ' / Description : '+etouchesupdateEvent.Description +
            ' / Description : '+etouchesupdateEvent.Max_regsitration ;
         /*   ' / B2B2C Event : '+etouchesupdateEvent.B2B2C_Event +
            ' / Carmignac Office : '+etouchesupdateEvent.CarmignacOffice +
            ' / Carmignac Office Location : '+etouchesupdateEvent.CarmignacOfficeLocation +
            ' / Location Name : '+etouchesupdateEvent.LocationName +
         	' / Address1 : '+etouchesupdateEvent.Address1 +
         	' / Address2 : '+etouchesupdateEvent.Address2 +
         	' / City : '+etouchesupdateEvent.City +
         	' / Country : '+etouchesupdateEvent.Country +
         	' / PostalCode : '+etouchesupdateEvent.PostalCode +
            ' / Map to venue : '+etouchesupdateEvent.Maptovenue +
            ' / eTouches Invitation : '+etouchesupdateEvent.eTouchesInvitation ; */
        	
        	EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
        	newErro.dateCreate = Datetime.now();
        	newErro.interfaceName ='Input Update Event Etouches';
        	newErro.Data = Data;
        	newErro.error = fullResp;
		        	
        	listLogError.add(newErro);
        	
            
        } catch(Exception e){
            Database.rollback(sp);
            response.Message = e.getMessage();
            response.Status = WSResponseWrapper.WS_STATUS_ERROR;
            response.TechnicalMessage = e.getStackTraceString();
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [Exception] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
                  	
        	
        	String fullResp = '  @RestResource(urlMapping=\'/EtouchesCampaign/*\') - Response Message  : ' + e.getMessage() +
        	' / Response Status : ' + WSResponseWrapper.WS_STATUS_ERROR +
        	' / Response TechnicalMessage : ' + e.getStackTraceString();   
        				
            String Data;
            if(etouchesupdateEvent == null){
                 Data =  'Class name :' + CLASS_NAME + '  Methodname : SM024_EtouchesProcessEvent.updateCampaign(etouchesupdateEvent); / etouchesupdateEvent : '+'null';
            }else{
                 Data =  'Class name :' + CLASS_NAME + '  Methodname : SM024_EtouchesProcessEvent.updateCampaign(etouchesupdateEvent); / Event SFId : ' + etouchesupdateEvent.EventSFId + 
        //	' / Owner : ' + etouchesupdateEvent.Owner +
        	' / Status : ' + etouchesupdateEvent.Status +
        /*	' / CRM USER : '+ etouchesupdateEvent.CRM_USER_SFId +
        	' / SalesTeam : '+ etouchesupdateEvent.SalesTeam +
       // 	' / EventCategory : '+etouchesupdateEvent.EventCategory +
			' / Company Name : '+etouchesupdateEvent.CompanySFId +
       //  	' / Event Type : '+etouchesupdateEvent.EventType +
         	' / Name : '+etouchesupdateEvent.Name + 
            ' / StartDateTime : '+etouchesupdateEvent.StartDateTime +
            ' / EndDateTime : '+etouchesupdateEvent.EndDateTime +*/
            ' / Registration Close Date : '+etouchesupdateEvent.RegistrationCloseDate +
           /*  ' / Local Zone : '+etouchesupdateEvent.LocalZone +
       //     ' / Commercial Strategy : '+etouchesupdateEvent.CommercialStrategy +
       //     ' / Targeted Attendees : '+etouchesupdateEvent.TargetedAttendees +  */
            ' / Description : '+etouchesupdateEvent.Description +
            ' / Maximum regsitration : '+etouchesupdateEvent.Max_regsitration ;
        /*    ' / B2B2C Event : '+etouchesupdateEvent.B2B2C_Event +
            ' / Carmignac Office : '+etouchesupdateEvent.CarmignacOffice +
            ' / Carmignac Office Location : '+etouchesupdateEvent.CarmignacOfficeLocation +
            ' / Location Name : '+etouchesupdateEvent.LocationName +
         	' / Address1 : '+etouchesupdateEvent.Address1 +
         	' / Address2 : '+etouchesupdateEvent.Address2 +
         	' / City : '+etouchesupdateEvent.City +
         	' / Country : '+etouchesupdateEvent.Country +
         	' / PostalCode : '+etouchesupdateEvent.PostalCode +
            ' / Map to venue : '+etouchesupdateEvent.Maptovenue +
            ' / eTouches Invitation : '+etouchesupdateEvent.eTouchesInvitation ;  */
            }
        	        	
     		
        	EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
        	newErro.dateCreate = Datetime.now();
        	newErro.interfaceName ='Input Update Event Etouches';
        	newErro.Data = Data;
        	newErro.error = fullResp;
		        	
        	listLogError.add(newErro);
            
            
        }
       	
        //String strWSResponse = JSON.serialize(response);
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, ' [response] : '+ response);
        
        return response;
           
    }
    
    
     /**
    * @author : Adolphe SONKO
    * @date : Creation 02/05/2017
    * @date : Modification 02/05/2017
    * @description : This class model the etouches Campaign object used as Webservice parameter.
    */
     global class EtouchesEvent{
        global String EtouchesEventId;
 	 }
    
  /**
    * @author : Adolphe SONKO
    * @date : Creation 02/05/2017
    * @date : Modification 02/05/2017
    * @description : This class model the etouches Campaign object used as Webservice parameter.
    */
    global class EtouchesEventUpdate{
        global Id EventSFId;
        global String Status;
        global String RegistrationCloseDate;
        global String Description;
        global String Max_regsitration;
    }
    
}