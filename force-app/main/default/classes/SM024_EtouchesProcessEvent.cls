/** 
 * @author : Adolphe SONKO
 * @date : Creation 02/05/2017
 * @date : Modification 02/05/2017
 * @description Service manager for Campaign creation and modification REST web service. The Service manages all the business rules.
 */
public class SM024_EtouchesProcessEvent {
    private static String  CLASS_NAME = SM024_EtouchesProcessEvent.class.getName();
	
    public static WSResponseWrapper getCampaign(WS007_EtouchesEventProcess.EtouchesEvent wsEvent){
        
        String methodName = 'getCampaign';
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [wsEvent] : ' + wsEvent);
        
        WSResponseWrapper response = new WSResponseWrapper();
        response.Status = WSResponseWrapper.WS_STATUS_ERROR;
		
        Campaign campToReturn = new Campaign();
        if(!ObjectUtil.isEmpty(wsEvent.EtouchesEventId)){
           List<Campaign> listCampaigns = EM011_Campaign.ListCampaign(new list<String>{wsEvent.EtouchesEventId});
           if(listCampaigns != null && listCampaigns.size() > 0){
            	campToReturn = listCampaigns.get(0);
             	response.Status = WSResponseWrapper.WS_STATUS_SUCCESS;
                response.Message = 'Here the Campaign corresponding to this Etouches Event Id : '+wsEvent.EtouchesEventId;
                response.Data = new list<Campaign>{campToReturn};
           }else{
                response.Message = 'This Event Code Etouches does not correspond to any Campaign in Salesforce';
           }
        }else{
            response.Message = 'The Event Code Etouches is mandatory in order to retrieve the corresponding Campaign in Salesforce';
        }
        
        return response;
    }
    
    
    public static WSResponseWrapper updateCampaign(WS007_EtouchesEventProcess.EtouchesEventUpdate wsEvent){
        
        String methodName = 'updateCampaign';
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [wsEvent] : ' + wsEvent);
        
        WSResponseWrapper response = new WSResponseWrapper();
        response.Status = WSResponseWrapper.WS_STATUS_ERROR;
		
        Campaign campToReturn = new Campaign();
        if(!ObjectUtil.isEmpty(wsEvent.EventSFId)){
           List<Campaign> listCampaigns = EM011_Campaign.getListByIds(new Set<Id>{wsEvent.EventSFId});
           if(listCampaigns != null && listCampaigns.size() > 0){
            	campToReturn = listCampaigns.get(0);
                if(!ObjectUtil.isEmpty(wsEvent.Status)){ campToReturn.Status = wsEvent.Status;}	
                if(!ObjectUtil.isEmpty(wsEvent.RegistrationCloseDate)){ 
                    
                campToReturn.Registration_Closed_Date__c = Datetime.valueOf(wsEvent.RegistrationCloseDate) ;}
                if(!ObjectUtil.isEmpty(wsEvent.Description)){ campToReturn.Etouches_Event_Description__c = wsEvent.Description;}
                if(!ObjectUtil.isEmpty(wsEvent.Max_regsitration)){ campToReturn.Maximum_registration__c = Integer.valueOf(wsEvent.Max_regsitration);}

             	response.Status = WSResponseWrapper.WS_STATUS_SUCCESS;
                response.Data = new list<Campaign>{campToReturn};
                response.Message = 'The Campaign Was Successfully updated ';    
                ObjectUtil.updateRecords(new List<Campaign> {campToReturn});
           }else{
                response.Message = 'There is no Campaign in Salesforce with this Id: '+wsEvent.EventSFId;
           }
        }else{
            response.Message = 'The Campaign Id is mandatory !';
        }
        
        return response;
    }
    
}