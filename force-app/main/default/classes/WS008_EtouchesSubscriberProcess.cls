/** 
 * @author : Youssef Missaoui
 * @date : Creation 17/05/2017
 * @date : Modification 17/05/2017
 * @description : web service REST class to handle creation and modification of Campaign Members. Its exposed for the Etouches.
    -- Maintenance History:
    --
    -- Date         Name  Version  Remarks
    -- -----------  ----  -------  --------------------------------------
    -- 28-FEB-2019  JLC    1.0      Add TECH_ID_Attendee in the request object
    ----------------------------------------------------------------------
    **********************************************************************
 */
@RestResource(urlMapping='/EtouchesCampaignMember/*')
global class WS008_EtouchesSubscriberProcess {
    private static String  CLASS_NAME = WS008_EtouchesSubscriberProcess.class.getName();
    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
    
    /**
    * @author : Youssef Missaoui
    * @date : Creation 17/05/2017
    * @date : Modification 17/05/2017
    * @description : manages to retrieve Campaign member .
    * @param : EtouchesSubscriber etouchesSubscriber is the Etouches Subscriber.
    * @return : WSResponseWrapper the Webservice response containes the created or updated Contact/Lead.
    */
    @HttpPost
    global static WSResponseWrapper doPost(EtouchesSubscriber etouchesSubscriber){
        
        String methodName = 'doPost';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [etouchesSubscriber] : ' + etouchesSubscriber);
        
        WSResponseWrapper response = new WSResponseWrapper();

        Savepoint sp = Database.setSavepoint();
        
        try
        {
            response = SM025_EtouchesProcessSubscriber.getSubscriber(etouchesSubscriber);            
        } 
         /* We are only quering no DML is done so will never enter this code
        catch(DmlException e)
        {           
            Database.rollback(sp);
            response.Message = e.getMessage();
            response.Status = WSResponseWrapper.WS_STATUS_ERROR;
            response.TechnicalMessage = e.getStackTraceString();
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName + '  @RestResource(urlMapping=\'/EtouchesCampaignMember/*\') - Type : DML Excepttion - Response Message  : ' + e.getMessage() +
            ' / Response Status : ' + WSResponseWrapper.WS_STATUS_ERROR +
            ' / Response TechnicalMessage : ' + e.getStackTraceString();               
            
            String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM025_EtouchesProcessSubscriber.getSubscriber(etouchesSubscriber); / Subscriber Id : ' + etouchesSubscriber.EtouchesSubscriberId; 
                        
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName ='Input CampaignMember Etouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);          
            
        } */
        catch(Exception e)
        {
            Database.rollback(sp);
            response.Message = e.getMessage();
            response.Status = WSResponseWrapper.WS_STATUS_ERROR;
            response.TechnicalMessage = e.getStackTraceString();
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [Exception] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
                    
            
            String fullResp = '  @RestResource(urlMapping=\'/EtouchesCampaign/*\') - Response Message  : ' + e.getMessage() +
            ' / Response Status : ' + WSResponseWrapper.WS_STATUS_ERROR +
            ' / Response TechnicalMessage : ' + e.getStackTraceString();   
                        
            String Data;
            if(etouchesSubscriber == null){
                 Data =  'Class name :' + CLASS_NAME + '  Methodname : SM025_EtouchesProcessSubscriber.getSubscriber(etouchesSubscriber); / etouchesSubscriber : '+'null';
            }else{
                 Data =  'Class name :' + CLASS_NAME + '  Methodname : SM025_EtouchesProcessSubscriber.getSubscriber(etouchesSubscriber); / Subscriber Id : ' + etouchesSubscriber.EtouchesSubscriberId; 
            }                       
            
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName ='Input Subscriber Etouches';
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
    global static WSResponseWrapper doPut(EtouchesUpdateSubscriber updateSubscriber){
        
        String methodName = 'doPut';
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [updateSubscriber] : ' + updateSubscriber);
        
        WSResponseWrapper response = new WSResponseWrapper();

        Savepoint sp = Database.setSavepoint();
        
        try
        {
            response = SM025_EtouchesProcessSubscriber.updateCampaignMember(updateSubscriber);            
        } 
        catch(DmlException e)
        {           
            Database.rollback(sp);
            response.Message = e.getMessage();
            response.Status = WSResponseWrapper.WS_STATUS_ERROR;
            response.TechnicalMessage = e.getStackTraceString();
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName + '  @RestResource(urlMapping=\'/EtouchesCampaignMember/*\') - Type : DML Excepttion - Response Message  : ' + e.getMessage() +
            ' / Response Status : ' + WSResponseWrapper.WS_STATUS_ERROR +
            ' / Response TechnicalMessage : ' + e.getStackTraceString();               
            
            String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM025_EtouchesProcessSubscriber.updateCampaignMember(updateSubscriber); / Event SFId : ' + updateSubscriber.SubscriberSFId + 
            ' / Status : ' + updateSubscriber.Status;
            
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName ='Input Update Event Etouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);          
            
        } catch(Exception e)
        {
            Database.rollback(sp);
            response.Message = e.getMessage();
            response.Status = WSResponseWrapper.WS_STATUS_ERROR;
            response.TechnicalMessage = e.getStackTraceString();
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [Exception] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
                                
            String fullResp = '  @RestResource(urlMapping=\'/EtouchesCampaignMember/*\') - Response Message  : ' + e.getMessage() +
            ' / Response Status : ' + WSResponseWrapper.WS_STATUS_ERROR +
            ' / Response TechnicalMessage : ' + e.getStackTraceString();   
                        
            String Data;
            
            if(updateSubscriber == null)
            {
                 Data =  'Class name :' + CLASS_NAME + '  Methodname : SM025_EtouchesProcessSubscriber.updateCampaignMember(updateSubscriber); / updateSubscriber : '+'null';
            }
            else
            {
                 Data =  'Class name :' + CLASS_NAME + '  Methodname : SM025_EtouchesProcessSubscriber.updateCampaignMember(updateSubscriber); / SubscriberSFId : ' + updateSubscriber.SubscriberSFId;
            }                       
            
            EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
            newErro.dateCreate = Datetime.now();
            newErro.interfaceName ='Input Update CampaignMember Etouches';
            newErro.Data = Data;
            newErro.error = fullResp;
                    
            listLogError.add(newErro);            
            
        }           
        //String strWSResponse = JSON.serialize(response);
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, ' [response] : '+ response);
        
        return response;           
    }

     /**
    * @author : Youssef MISSAOUI
    * @date : Creation 17/05/2017
    * @date : Modification 17/05/2017
    * @description : This class model the etouches Campaign Member object used as Webservice parameter.
    */
     global class EtouchesSubscriber{
        global String EtouchesSubscriberId;
        global String FirstName;
        global String LastName;
        global String Email;
        global String CampaignId;
     }    
    
     global class EtouchesUpdateSubscriber{
         global String SubscriberSFId;
         global String Status;
         global String FirstName;
         global String LastName;
         global String Email;
         global String CampaignId;
         global String AddressLine1;
         global String City;
         global String Company;
         global String Country;
         global String JobTitle;
         global String MobilePhone;
         global String WorkPhone;
         global String Zip;
         global String ContactQuestion;
         global String RegistrationDate;
         global String LastEtouchesActionSynchronized;
         global boolean SubscriberOptinOptout;
         global String LastActionDate;
         global Boolean Responded;
         global String BounceMessage;
         global String BounceType;
         //Add field attendedId
         global String TECH_ID_Attendee;
     }
}