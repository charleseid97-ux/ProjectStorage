/** 
* @author: Briag GUEMARD
* @date : Creation 27/02/2017
* @date : Modification 27/02/2017
* @description : This Class allows to handle trigger events in campaign entity.
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 08-AVR-2019  JLC         1.1    #15844 prevent inactive campaign to be updated
* -- 12-JUL-2019  JLC         1.1    #17135 Implement queueable interface to be able to process campaign in batch
*
*/
public class SM014_CampaignTriggerHandler {

    /**

    private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
     private static String  CLASS_NAME = SM014_CampaignTriggerHandler.class.getName();

    public static void onAfterInsert(List<Campaign> campaigns) {
        String methodName = 'onAfterInsert';
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [campaigns] : ' + campaigns);

        List<Campaign> campaignsToSend = new List<Campaign>();

        for (Campaign c : campaigns) {
            // To Add for only interface user from Shcedule
            if (c.Etouches_invitation__c == True && c.Event_code_Etouches__c == null) {
                // Begin the callout process
                campaignsToSend.add(c);
            }

            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [campaign name] : ' + c.name);
        }

        if (campaignsToSend != null && campaignsToSend.size() > 0) {
            //callCreateAllCampaigneTouches(campaignsToSendId);
            System.enqueueJob(new CallCreateCampaignEtouchesAsync(campaignsToSend, 0, 14));
        }

        EM023_Log.insertLogError(listLogError);
    }*/

    /**
     *
     *
     * @param listcampaigns
     * @param oldMap

    public static void onAfterUpdate(List<Campaign> listcampaigns, Map<Id, Campaign> oldMap) {
        String methodName = 'onAfterUpdate';
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [campaigns] : ' + listcampaigns);
        //@author JLC Added for #15844
        Set<String> excludeStatus = new Set<String>{
                'Closed', 'Cancelled', 'Rejected', 'Archived'
        };
        List<Campaign> campaignToUpdate = new List<Campaign>();

        List<Campaign> campaignsToCreate = new List<Campaign>();

        for (Campaign camp : listcampaigns) {
            //check if campaign should be updated
            boolean isUpdateable = !excludeStatus.contains(camp.status);

            if (camp.Event_code_Etouches__c == oldMap.get(camp.Id).Event_code_Etouches__c && camp.Event_code_Etouches__c != null && isUpdateable) {
                campaignToUpdate.add(camp);
            }

            if (camp.Etouches_invitation__c == true && oldMap.get(camp.Id).Etouches_invitation__c == false && camp.Event_code_Etouches__c == null && isUpdateable) {
                campaignsToCreate.add(camp);
            }
        }
        //TODO check why an update is done each time a campaign member status is changed
        //Lauch update etouches Event and mailing list
        if (campaignToUpdate != null && campaignToUpdate.size() > 0) {
            //callUpdateEtouchesEventandMailinglist(campaignToUpdate);
            System.enqueueJob(new CallUpdateCampaignEtouchesAsync(campaignToUpdate, 0, 14));
        }

        //Lauch Creation etouches Event and mailing list
        if (campaignsToCreate != null && campaignsToCreate.size() > 0) {
            //callCreateAllCampaigneTouches(campaignIdsCreate);
            System.enqueueJob(new CallCreateCampaignEtouchesAsync(campaignsToCreate, 0, 14));
        }

        EM023_Log.insertLogError(listLogError);
    }*/
     
     /**
     * @auteur : Briag Guemard
     * @date : Creation 16/03/2017
     * @date : Modification 16/03/2017 
     * @description : 
     * @param : Campaign.
     * @return : -Non-

     
    //@future(callout=true) updated to use queueable
    public static void callCreateAllCampaigneTouches(List<Campaign> campaignsToSend){
    try
    { 
        String methodName = 'callCreateAllCampaigneTouches'; 
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [campaignsToSend] : ' + campaignsToSend);
        
        //List<Campaign> campaignsToSend = new List<Campaign>();
        List<Campaign> campaignsToUpdate = new List<Campaign>();                        
        List<Category_Event__c> cateogryEventToInsert = new List<Category_Event__c>();      
        
        //1st access of the method      
        //campaignsToSend = EM011_Campaign.getAllListByIds(listCampaignIdNew);
        
        List<Template_Etouches__c> templateList = new List<Template_Etouches__c>();
        
        //2nd access
        templateList= EM019_TemplateEtouches.getAllTemplateEtouches();
        
        List<Id> allCRMuser = new List<Id>();       
        List<User> alluser = new List<User>();
        
        //load user     callUpdateMailingList
        for(Campaign c : campaignsToSend){
            
            allCRMuser.add(c.OwnerId);
            if (c.CRM_User__c!= null){
                allCRMuser.add(c.CRM_User__c);
            }           
        }
    
        if (allCRMuser != null && allCRMuser.size()>0){
            alluser = EM020_User.getUserbyId(allCRMuser);
        }       
        
        // Loop of Callout for each Campaign
         for(Campaign c : campaignsToSend)
         {          
            User owner = new User();
            User CrmSales = new User();
            
            //Get 2 users.
            for (User user1 : alluser){
                
                if (c.OwnerId == user1.Id){
                    owner= user1;                   
                }
                if (c.CRM_User__c == user1.Id){
                    CrmSales= user1;
                }               
            }
            
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [Owner] : ' + owner);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [CrmSales] : ' + CrmSales);
            
            Campaign campToAdd = callCreateCampaignEvent(c,templateList,owner,CrmSales );
            
            campaignsToUpdate.add(campToAdd);    
            
            //List category for a Campaign
            List<Category_Event__c> cateogryEventTemp = new List<Category_Event__c>(); 
            
            //callCreateCategory            
            cateogryEventTemp = getAllCatgeroy(campToAdd);
            
            //Loop for the new
            for(Category_Event__c categ : cateogryEventTemp)
            {
                cateogryEventToInsert.add(categ);
            }
         } 
        
        // DML  2nd and 3rd. 
        // campaignsToUpdate
        if(campaignsToUpdate != null && campaignsToUpdate.size() > 0){
            update campaignsToUpdate;
        }       
        
        // cateogryEventToInsert
        if(cateogryEventToInsert != null && cateogryEventToInsert.size() > 0){
            insert cateogryEventToInsert;
        }       
     }
    catch (Exception e) 
    {
        EM023_Log.errorToLog newErroException = new EM023_Log.errorToLog();
        newErroException.dateCreate = Datetime.now();
        newErroException.interfaceName = 'callCreateAllCampaigneTouches Catch Exception';
        newErroException.Data = e.getMessage();
        newErroException.error = e.getStackTraceString();
        
        listLogError.add(newErroException);  
    }   
    
    EM023_Log.insertLogError(listLogError);     
    }*/

    /** 
    * @author: Adolphe SONKO
    * @date : Creation 21/03/2017
    * @date : Modification 21/03/2017
    * @description : This method allows to call the event and mailling list updates .

    //@future(callout=true) updated to use queueable
    public static void callUpdateEtouchesEventandMailinglist(List<Campaign> campaigns){
    try
    {
        String methodName = 'callUpdateEtouchesEventandMailinglist'; 
        
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [campaigns] : ' + campaigns);
        
        //List<Campaign> campaigns = new List<Campaign>();
                
        //campaigns = EM011_Campaign.getAllListByIds(listCampaignIds);
        
        List<Id> allCRMuser = new List<Id>();       
        List<User> alluser = new List<User>();
        
        //load user     
        for(Campaign c : campaigns)
        {           
            allCRMuser.add(c.OwnerId);
            if (c.CRM_User__c!= null){
                allCRMuser.add(c.CRM_User__c);
            }           
        }
    
        if (allCRMuser != null && allCRMuser.size()>0){
            alluser = EM020_User.getUserbyId(allCRMuser);
        }
        
        for(Campaign camp: campaigns){
            
            User owner = new User();
            User CrmSales = new User();
            
            //Get 2 users.
            for (User user1 : alluser){
                
                if (camp.OwnerId == user1.Id){
                    owner= user1;                   
                }
                if (camp.CRM_User__c == user1.Id){
                    CrmSales= user1;
                }               
            }
                        
            callUpdateEvent(camp,camp.Event_code_Etouches__c,owner,CRMSales);
            
            // To add User and onwer
            callUpdateMailingList(camp);
        }
    }   
    catch (Exception e) 
    {
        EM023_Log.errorToLog newErroException = new EM023_Log.errorToLog();
        newErroException.dateCreate = Datetime.now();
        newErroException.interfaceName = 'callUpdateEtouchesEventandMailinglist Catch Exception';
        newErroException.Data = e.getMessage();
        newErroException.error = e.getStackTraceString();
        
        listLogError.add(newErroException);  
    }   
        
    EM023_Log.insertLogError(listLogError);             
    }
    
    private static Campaign callCreateCampaignEvent(Campaign CampToEvent,List<Template_Etouches__c> templateList,  User Owner1,  User CRMSales ){
    
        String methodName = 'callCreateCampaignEvent'; 
        
        Campaign campaignRetrun = new Campaign(Id = CampToEvent.Id);
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [Campaign] : ' + CampToEvent);
        
        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [param_setting] : ' + param_setting);
        
        String token = EM029_EtouchesToken.getNewToken();
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [Token] : ' + token);
        try 
        {
            if (token != null)
            {           
                String template = getTemplate(CampToEvent,templateList);            
                String folderId = getFolder(CampToEvent,templateList);
                
                ObjectUtil.debugLog(CLASS_NAME, methodName, ' [template] : ' + template);
                    
                //Request to Etouches Clone         
                HttpRequest request = EM011_Campaign.getCreatePutCLONE(param_setting,token,template,folderId,CampToEvent.Name);
                ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.getCreatePutCLONE <= request] : ' + request);
                
                //Send request to eTouches Put Clone                
                HttpResponse responseEventID = EM011_Campaign.cloneEvent(request, null);
                 
                ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.cloneEvent <= response] : ' + responseEventID);
                ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.cloneEvent <= response body] : ' + responseEventID.getBody());
                ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.cloneEvent <= response getStatus] : ' + responseEventID.getStatus());
                ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.cloneEvent <= response getStatusCode] : ' + responseEventID.getStatusCode());
                
                    String recordData = 'Campaign Id : ' + CampToEvent.Id;
                
                    if  (responseEventID.getStatusCode() == 200)
                    {
                        if( responseEventID.getBody().contains('<error>'))
                        {  
                            EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(responseEventID,request,recordData,CLASS_NAME,methodName);
                            listLogError.add(newErro); 
                        }
                        else
                        {
                            //1- Update Event
                            String  Etouches_Event_ID = EtouchesXML.getEventID(responseEventID);                    
                            campaignRetrun.Event_code_Etouches__c = Etouches_Event_ID;                  
                            callUpdateEvent(CampToEvent,Etouches_Event_ID,Owner1,CRMSales);
                        
                            //2- Launch create mailing list
                            httpResponse responseMailingList = callCreateMailinglist(CampToEvent, token, Etouches_Event_ID);            
                            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [responseMailingList] : ' + responseMailingList);
                        
                            if(responseMailingList.getStatusCode() == 200)
                            {
                                if(responseMailingList.getBody().contains('<error>'))
                                {
                                    EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(responseEventID,request,recordData,CLASS_NAME,methodName);
                                    listLogError.add(newErro);                        
                                    ObjectUtil.debugLog(CLASS_NAME, methodName, 'callCreateMailinglist -Error ');   
                                }
                                else
                                {
                                    String Etouches_Mailinglist_ID = EtouchesXML.getMailinglistID(responseMailingList); 
                                    ObjectUtil.debugLog(CLASS_NAME, methodName, ' [Etouches_Mailinglist_ID] : ' + Etouches_Mailinglist_ID);
                                    campaignRetrun.TECH_Mailing_List_ID_Etouches__c =Etouches_Mailinglist_ID;                       
                                    ObjectUtil.debugLog(CLASS_NAME, methodName, ' [campaignRetrun] : ' + campaignRetrun);
                                }                                               
                            }
                            else 
                            {                                       
                              EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(responseEventID,request,recordData,CLASS_NAME,methodName);
                              listLogError.add(newErro);                        
                              ObjectUtil.debugLog(CLASS_NAME, methodName, 'callCreateMailinglist -Error '); 
                            }   
                        }               
                    }
                    else
                    {                   
                        EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(responseEventID,request,recordData,CLASS_NAME,methodName);
                        listLogError.add(newErro); 
                    }           
            }
            else
            {                   
                ObjectUtil.debugLog(CLASS_NAME, methodName, ' Token is null, Error.');
            }
            
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [campaignRetrun] : ' + campaignRetrun);   
        }
        catch (Exception e) 
        {
            EM023_Log.errorToLog newErroException = new EM023_Log.errorToLog();
            newErroException.dateCreate = Datetime.now();
            newErroException.interfaceName = 'callCreateCampaignEvent Catch Exception';
            newErroException.Data = e.getMessage();
            newErroException.error = e.getStackTraceString();
            
            listLogError.add(newErroException);  
        }   
                    
        return campaignRetrun;      
    }
    
    private static List<Category_Event__c> getAllCatgeroy(Campaign CampToEvent){
        
        String methodName='getAllCatgeroy';
         
        List<Category_Event__c> categToInster = new List<Category_Event__c>();      
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [Campaign] : ' + CampToEvent);
        
        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [param_setting] : ' + param_setting);
          
        String authToken= EM029_EtouchesToken.getNewToken();  
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [Token] : ' + authToken);
                
        //Launch create of list category 
        httpResponse responseCategory = callCreateListCategory(CampToEvent, authToken, CampToEvent.Event_code_Etouches__c);
        
        String recordData = 'Campaign Id : ' + CampToEvent.Id;
        
        if(responseCategory.getStatusCode() == 200){            
            if(responseCategory.getBody().contains('<error>'))
            {                   
                EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(responseCategory,null,recordData,CLASS_NAME,methodName);
                listLogError.add(newErro); 
                ObjectUtil.debugLog(CLASS_NAME, methodName, 'The category list was not created');
            }
            else
            {
                ObjectUtil.debugLog(CLASS_NAME, methodName, 'The category list was succesfully created'); 
            }       
        }
        else
        { 
            EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(responseCategory,null,recordData,CLASS_NAME,methodName);
            listLogError.add(newErro);
            ObjectUtil.debugLog(CLASS_NAME, methodName, 'The category list was not created'); 
        }
        
        categToInster = EM016_Category.getListCategoryToInsert(responseCategory,CampToEvent);       
        return categToInster;       
      }
    
    private static void callUpdateEvent(Campaign campaignToUpdate, String etouchesEvent, User owner1, User CrmSales){
        try
        {
            String methodName='callUpdateEvent';        
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [campaign] : ' + campaignToUpdate); 
            
            WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [param_setting] : ' + campaignToUpdate); 
            
            String authToken= EM029_EtouchesToken.getNewToken(); 
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [eTouchesToken] : ' + campaignToUpdate); 
             
            // Update the Campaign to Etouches  
            HttpRequest request = EM011_Campaign.getPutUpateEvent(param_setting,authToken,campaignToUpdate, etouchesEvent,owner1,CrmSales);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.getPutUpateEvent <= request] : ' + campaignToUpdate);
                        
            HttpResponse response = EM011_Campaign.upateEvent(request, null);  
            
            String recordData = 'Campaign Id : ' + campaignToUpdate.Id; 
            
            if(response.getStatusCode() == 200){            
                if(response.getBody().contains('<error>'))
                {   
                    EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response,request,recordData,CLASS_NAME,methodName);
                    listLogError.add(newErro);
                    ObjectUtil.debugLog(CLASS_NAME, methodName, 'The compaign was not updated - Error'); 
                }else{
                    ObjectUtil.debugLog(CLASS_NAME, methodName, 'The compaign was succesfully updated'); 
                }
            }
            else
            {   
                EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response,request,recordData,CLASS_NAME,methodName);
                listLogError.add(newErro);
            } 
            
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.upateEvent <= response] : ' + response);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.upateEvent <= response body] : ' + response.getBody());
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.upateEvent <= response getStatus] : ' + response.getStatus());
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.upateEvent <= response getStatusCode] : ' + response.getStatusCode());
        }
        catch (Exception e) 
        {
            EM023_Log.errorToLog newErroException = new EM023_Log.errorToLog();
            newErroException.dateCreate = Datetime.now();
            newErroException.interfaceName = 'callUpdateEvent Catch Exception';
            newErroException.Data = e.getMessage();
            newErroException.error = e.getStackTraceString();
            
            listLogError.add(newErroException);  
        }   
    }
     
    private static void callUpdateMailingList(Campaign updatedCampaign){
        try
        {
            String methodName='callUpdateMailingList';      
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [updatedCampaign] : ' + updatedCampaign);
            
            WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [param_setting] : ' + param_setting); 
            
            String authToken= EM029_EtouchesToken.getNewToken(); 
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [eTouchesToken] : ' + authToken);  
                    
            // Update the Mailing list to Etouches      
            HttpRequest request = EM011_Campaign.getPutUpdateMailingList(param_setting,authToken,updatedCampaign);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.getPutUpdateMailingList <= request] : ' + request);
                
            HttpResponse response = EM011_Campaign.updateMailinglist(request, null);        
            
            String recordData = 'Campaign Id : ' + updatedCampaign.Id;  
            
            if(response.getStatusCode() == 200){            
                if(response.getBody().contains('<error>')){
                        EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response,request,recordData,CLASS_NAME,methodName);
                        listLogError.add(newErro);  
                        ObjectUtil.debugLog(CLASS_NAME, methodName, 'The mailing list was not updated - Error');
                    }
                    else
                    {
                        ObjectUtil.debugLog(CLASS_NAME, methodName, 'The mailing list was succesfully updated');
                    }
            }
            else
            {   
                EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response,request,recordData,CLASS_NAME,methodName);
                listLogError.add(newErro);
                ObjectUtil.debugLog(CLASS_NAME, methodName, 'The mailing list was not updated - Error');
            }
            
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.updateMailinglist <= response] : ' + response);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.updateMailinglist <= response body] : ' + response.getBody());
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.updateMailinglist <= response getStatus] : ' + response.getStatus());
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.updateMailinglist <= response getStatusCode] : ' + response.getStatusCode());
        }
        catch (Exception e) 
        {
            EM023_Log.errorToLog newErroException = new EM023_Log.errorToLog();
            newErroException.dateCreate = Datetime.now();
            newErroException.interfaceName = 'callUpdateMailingList Catch Exception';
            newErroException.Data = e.getMessage();
            newErroException.error = e.getStackTraceString();
            
            listLogError.add(newErroException);  
        }   
      }     


    private static void callCloneEvent(Id campaignId, String authToken){ 
        try
        {
            String methodName ='callCloneEvent';
            
            WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [param_setting] : ' + param_setting);  
            
            Campaign campaign = EM011_Campaign.getListByIds(new Set<Id>{campaignId}).get(0);
            
            String template;        
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [template] : ' + template);  
            
            //Request to Etouches
            HttpRequest request = EM011_Campaign.getCreatePutCLONE(param_setting,authToken,template,'43156',campaign.Name);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.getCreatePutCLONE <= request] : ' + request);
            
            //Send request to eTouches          
            HttpResponse responseEventID = EM011_Campaign.cloneEvent(request, null);
                    
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.cloneEvent <= response] : ' + responseEventID);
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.cloneEvent <= response body] : ' + responseEventID.getBody());
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.cloneEvent <= response getStatus] : ' + responseEventID.getStatus());
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.cloneEvent <= response getStatusCode] : ' + responseEventID.getStatusCode());
            
            String recordData = 'EM011_Campaign.cloneEvent ';     
            
            //MAJ Campaign wiht Etouche Event ID        
            if  (responseEventID.getStatusCode() == 200)
            {   
                    if(responseEventID.getBody().contains('<error>')){
                        EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(responseEventID,request,recordData,CLASS_NAME,methodName);
                        listLogError.add(newErro);            
                        ObjectUtil.debugLog(CLASS_NAME, methodName, ' Clone Event Error');
                    }else{
                        ObjectUtil.debugLog(CLASS_NAME, methodName, ' Clone Event Success');
                    }
                
                    // Update after Clone. Send all data to Etouches.               
                    
                    //Get ID from response              
                    String  Etouches_Event_ID = EtouchesXML.getEventID(responseEventID);                                
                
                    //Launch create mailing list
                    httpResponse responseMailingList = callCreateMailinglist(campaign, authToken, Etouches_Event_ID);           
                    
                    //Launch create of list category 
                    httpResponse responseCategory = callCreateListCategory(campaign, authToken, Etouches_Event_ID);
                                    
                    EM016_Category.insertCategoryEvent(campaign, responseCategory);             
                    
                    //Update of campaign mailing list ID field  
                    EM011_Campaign.updateEtouhcheData(campaign,Etouches_Event_ID,responseMailingList);
            }
            else
            {            
                EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(responseEventID,request,recordData,CLASS_NAME,methodName);
                listLogError.add(newErro);            
                ObjectUtil.debugLog(CLASS_NAME, methodName, ' Clone Event Error');
            }
        }
        catch (Exception e) 
        {
            EM023_Log.errorToLog newErroException = new EM023_Log.errorToLog();
            newErroException.dateCreate = Datetime.now();
            newErroException.interfaceName = 'callCloneEvent Catch Exception';
            newErroException.Data = e.getMessage();
            newErroException.error = e.getStackTraceString();
            
            listLogError.add(newErroException);  
        }   
    }
        
    private static HttpResponse callCreateMailinglist(Campaign campaign, String authToken, String EtouchesEventID){
        
        String methodName ='callCreateMailinglist';
        
        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [param_setting] : ' + param_setting);  
        
        //Request to Etouches
        HttpRequest request = EM011_Campaign.getPostCreateMailingList(param_setting,authToken,EtouchesEventID,campaign);
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.getPostCreateMailingList <= request] : ' + request);
        
        //Send request to eTouches          
        HttpResponse response = EM011_Campaign.createMailinglist(request, null);
                
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.createMailinglist <= response] : ' + response);
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.createMailinglist <= response body] : ' + response.getBody());
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.createMailinglist <= response getStatus] : ' + response.getStatus());
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM011_Campaign.createMailinglist <= response getStatusCode] : ' + response.getStatusCode());

        String recordData = 'Campaign Id : ' + campaign.Id; 
        
        if  (response.getStatusCode() == 200)
        {
            if(response.getBody().contains('<error>')){
                EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response,request,recordData,CLASS_NAME,methodName);
                listLogError.add(newErro); 
                ObjectUtil.debugLog(CLASS_NAME, methodName, 'The mailing list was not created');
            }else
            {
                ObjectUtil.debugLog(CLASS_NAME, methodName, 'The mailing list was created successfully'); 
            }                               
        }
        else
        {            
            EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response,request,recordData,CLASS_NAME,methodName);
            listLogError.add(newErro); 
            ObjectUtil.debugLog(CLASS_NAME, methodName, 'The mailing list was not created');
        } 
        
        return response;
    }    
          
    private static HttpResponse callCreateListCategory(Campaign campaign, String authToken, String EtouchesEventID){   
        String methodName ='callCreateListCategory';
        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName(EM012_eTouchesAuthWS.SETTING_NAME);
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [param_setting] : ' + param_setting);

        //Request to Etouches
        HttpRequest request = EM016_Category.getAllCategoryEvent(param_setting,authToken,EtouchesEventID,campaign);
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM016_Category.getAllCategoryEvent <= request] : ' + request);
                
        //Send request to eTouches          
        HttpResponse response = EM016_Category.createAllCategory(request, null);
                
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM016_Category.createAllCategory <= response] : ' + response);
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM016_Category.createAllCategory <= response body] : ' + response.getBody());
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM016_Category.createAllCategory <= response getStatus] : ' + response.getStatus());
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [EM016_Category.createAllCategory <= response getStatusCode] : ' + response.getStatusCode());

        String recordData = 'Campaign Id : ' + campaign.Id; 
        
        if  (response.getStatusCode() == 200)
        {
            if(response.getBody().contains('<error>')){
                EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response,request,recordData,CLASS_NAME,methodName);
                listLogError.add(newErro);            
                ObjectUtil.debugLog(CLASS_NAME, methodName, 'The category list was not created'); 
            }
            else
            {
                ObjectUtil.debugLog(CLASS_NAME, methodName, 'The category list was created successfully');
            }           
        }
        else
        {            
            EM023_Log.errorToLog newErro = ObjectUtil.GetErrorToLog(response,request,recordData,CLASS_NAME,methodName);
            listLogError.add(newErro);            
            ObjectUtil.debugLog(CLASS_NAME, methodName, 'The category list was not created'); 
        }   
        return response;
    }  
    
    private static string getTemplate(Campaign c, List<Template_Etouches__c> templateList){
        String template;
        
        for (Template_Etouches__c temp : templateList){         
            if (temp.Sales_Team__c == c.Sales_Team__c && temp.Type__c == c.Type )
            {
                template= temp.TemplateID__c;               
            }           
        }
        
        return template;        
    }    
    
    private static string getFolder(Campaign c, List<Template_Etouches__c> templateList ){
        String folderID;        
        
        for (Template_Etouches__c temp : templateList){
            
            if (temp.Sales_Team__c == c.Sales_Team__c && temp.Type__c == c.Type )
            {               
                folderID= temp.FolderID__c;             
            }           
        } 
        
        return folderID;        
    }

    */
}