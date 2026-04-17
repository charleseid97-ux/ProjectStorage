/** 
* @author : Youssef MISSAOUI / Adolphe SONKO 
* @date : Creation 02/05/2017
* @date : Modification 16/05/2017
* @description Service manager for Campaign creation and modification REST web service. The Service manages all the business rules.
-- Maintenance History:
--
-- Date         Name  Version  Remarks
-- -----------  ----  -------  --------------------------------------
-- 28-FEB-2019  JLC    1.0      Add TECH_ID_Attendee in the request object
----------------------------------------------------------------------
**********************************************************************
*/
public class SM025_EtouchesProcessSubscriber {
    private static String  CLASS_NAME = SM025_EtouchesProcessSubscriber.class.getName();
    
    public static WSResponseWrapper getSubscriber(WS008_EtouchesSubscriberProcess.EtouchesSubscriber wsSubscriber){
        
        String methodName = 'getSubscriber';
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [wsSubscriber] : ' + wsSubscriber);
        
        WSResponseWrapper response = new WSResponseWrapper();
        response.Status = WSResponseWrapper.WS_STATUS_ERROR;
        
        CampaignMember campMemberToReturn = new CampaignMember();
        
        if(!ObjectUtil.isEmpty(wsSubscriber.EtouchesSubscriberId))
        {
            List<CampaignMember> listCampaignMembers = EM018_SubscriberEtouches.getListBySubscriberIds(new Set<String>{wsSubscriber.EtouchesSubscriberId});
            
            if(listCampaignMembers != null && listCampaignMembers.size() > 0)
            {
                campMemberToReturn = listCampaignMembers.get(0);
                response.Status = WSResponseWrapper.WS_STATUS_SUCCESS;
                response.Message = 'Here the CampaignMember corresponding to this Etouches Subscriber Id : ' + wsSubscriber.EtouchesSubscriberId;
                response.Data = new list<CampaignMember>{campMemberToReturn};
                    }
            else
            {   
                response.Message = 'This Subscriber Code Etouches does not correspond to any CampaignMember in Salesforce';
            }
        }
        else
        {
            WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsUpdateSubscriber = new WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber();
            wsUpdateSubscriber.FirstName = wsSubscriber.FirstName;
            wsUpdateSubscriber.LastName = wsSubscriber.LastName;
            wsUpdateSubscriber.Email = wsSubscriber.Email;
            wsUpdateSubscriber.CampaignId = wsSubscriber.CampaignId;
            
            campMemberToReturn = EM018_SubscriberEtouches.getCMByUpdateAttendee(wsUpdateSubscriber);
            
            if(campMemberToReturn != null )
            {              
                response.Status = WSResponseWrapper.WS_STATUS_SUCCESS;
                response.Message = 'Here the CampaignMember corresponding to this Etouches Subscriber Id : ' + wsSubscriber.EtouchesSubscriberId;
                response.Data = new list<CampaignMember>{campMemberToReturn};
                    }
            else
            {   
                response.Message = 'This Subscriber Code Etouches does not correspond to any CampaignMember in Salesforce';
            }  
        }
        
        return response;
    }
    
    public static WSResponseWrapper updateCampaignMember(WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsSubscriber)
    {        
        String methodName = 'updateCampaignMember';
        ObjectUtil.debugLog(CLASS_NAME, methodName, ' [wsSubscriber] : ' + wsSubscriber);
        
        WSResponseWrapper response = new WSResponseWrapper();
        response.Status = WSResponseWrapper.WS_STATUS_ERROR;
        
        System.debug('## JLC ## Class SM025 // updateCampaignMember // DEBUT // wsSubscriber = ' + wsSubscriber);
        
        if(!ObjectUtil.isEmpty(wsSubscriber.TECH_ID_Attendee))
        {
            //0- Update existing CampainMember with wsSubscriber data : GetExisting CampaignMember and update it
            
            System.debug('## JLC ## Class SM025 // updateCampaignMember // TECH_ID_Attendee NOT NULL  // TECH_ID_Attendee = ' + wsSubscriber.TECH_ID_Attendee + ' / ' + wsSubscriber.Status);
            
            List<CampaignMember> cmList = EM015_CampaignMember.getListCampaignMemberByAttendeeID(new List<String>{wsSubscriber.TECH_ID_Attendee});
            if(cmList!=null && cmList.size()>0){
                updateCampaignMemberByAttendeeID(cmList,wsSubscriber,response);
            }
            else {
                CampaignMember cam = EM018_SubscriberEtouches.getCMByUpdateAttendee(wsSubscriber);
                if(cam !=null){
                    response = updateCampaignMemberByEmaiFirstNameLastName(cam,wsSubscriber,response);
                }
                else
                { 
                    //1- Check Contact : if exist create CampaignMember and relate it to Contact
                    Contact con = EM002_Contact.getContactByUpdateSubscriber(wsSubscriber);
                    
                    if(con!=null)
                    {
                        response = linkNewCampaignMemberToContact(con, response, wsSubscriber);
                    }
                    else
                    {
                        //2- If contact is null check Lead : if exist create CampaignMember and relate it to Contact
                        Lead lead = EM001_Lead.getLeadByUpdateSubscriber(wsSubscriber);
                        
                        if(lead!=null)
                        {
                            response = linkNewCampaignMemberToLead(lead, response, wsSubscriber);
                        }
                        else
                        {
                            Lead ld = createNewLead(wsSubscriber);
                            
                            response = linkNewCampaignMemberToLead(ld, response, wsSubscriber);
                        }
                    } 
                }
            }
        }
        else if(ObjectUtil.isEmpty(wsSubscriber.TECH_ID_Attendee))
        {
            System.debug('## JLC ## Class SM025 // updateCampaignMember // TECH_ID_Attendee IS NULL ');
            
            CampaignMember cam = EM018_SubscriberEtouches.getCMByUpdateAttendee(wsSubscriber);            
            
            if(cam !=null)
            {
                response = updateCampaignMemberByEmaiFirstNameLastName(cam,wsSubscriber,response);
            }
            else
            { 
                //1- Check Contact : if exist create CampaignMember and relate it to Contact
                Contact con = EM002_Contact.getContactByUpdateSubscriber(wsSubscriber);
                
                if(con!=null)
                {
                    response = linkNewCampaignMemberToContact(con, response, wsSubscriber);
                }
                else
                {
                    //2- If contact is null check Lead : if exist create CampaignMember and relate it to Contact
                    Lead lead = EM001_Lead.getLeadByUpdateSubscriber(wsSubscriber);
                    
                    if(lead!=null)
                    {
                        response = linkNewCampaignMemberToLead(lead, response, wsSubscriber);
                    }
                    else
                    {
                        Lead ld = createNewLead(wsSubscriber);
                        
                        response = linkNewCampaignMemberToLead(ld, response, wsSubscriber);
                    }
                } 
            }
        }       
        System.debug('## JLC ## Class SM025 // updateCampaignMember // TECH_ID_Attendee IS NULL // response = ' + response);
        return response;
    }  
    
    private static WSResponseWrapper updateCampaignMemberByEmaiFirstNameLastName(CampaignMember cam, WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsSubscriber, WSResponseWrapper response){
        
        System.debug('## JLC ## Class SM025 // updateCampaignMember // TECH_ID_Attendee IS NULL // wsSubscriber = ' + wsSubscriber);
        System.debug('## JLC ## Class SM025 // updateCampaignMember // TECH_ID_Attendee IS NULL // cam = ' + cam.Name + ' CAM Id = ' + cam.Id  + ' CAM Statut = ' + cam.Status + ' TECH_ID_Attendee = ' + wsSubscriber.TECH_ID_Attendee);
        
        boolean updateCM = false;
        boolean differentRegistrationDate = String.isBlank(wsSubscriber.RegistrationDate) ? (cam.Registration_dated__c != null) : (cam.Registration_dated__c != Date.valueOf(wsSubscriber.RegistrationDate));
            boolean differentLastActionDate = String.isBlank(wsSubscriber.LastActionDate) ? (cam.Last_Action_Date__c != null) : (cam.Last_Action_Date__c != Date.valueOf(wsSubscriber.LastActionDate));
                
                if(cam.Status != wsSubscriber.Status 
                   || cam.Contact_question__c != wsSubscriber.ContactQuestion 
                   || differentRegistrationDate 
                   || differentLastActionDate 
                   || cam.Last_Etouches_action_synchronized__c != wsSubscriber.LastEtouchesActionSynchronized
                   || cam.Subscriber__c != wsSubscriber.SubscriberOptinOptout 
                   || cam.Bounce_Responded__c != wsSubscriber.Responded 
                   || cam.Bounce__c != wsSubscriber.BounceMessage 
                   || cam.Bounce_Type__c != wsSubscriber.BounceType
                   || cam.E_Address_Line_1__c != wsSubscriber.AddressLine1 
                   || cam.E_City__c != wsSubscriber.City 
                   || cam.E_Country__c != wsSubscriber.Country 
                   || cam.E_Company__c != wsSubscriber.Company 
                   || cam.E_Job_Title__c != wsSubscriber.JobTitle
                   || cam.E_Mobile_Phone__c != wsSubscriber.MobilePhone 
                   || cam.E_Work_Phone__c != wsSubscriber.WorkPhone 
                   || cam.E_Zip__c != wsSubscriber.Zip){
                       
                       System.debug('## JLC ## Class SM025 // updateCampaignMember TRUE ' + 'WsSUBSCRIBER STATUS= ' + wsSubscriber.Status + ' / CAM = ' + cam);  
                       
                       updateCM = true;
                       System.debug('## JLC ## Class SM025 // updateCampaignMember TRUE ' + 'WsSUBSCRIBER STATUS= ' + wsSubscriber.Status + ' / CAM STATUS = ' + cam.Status);  
                       cam.Status = wsSubscriber.Status;
                       cam.Contact_question__c = wsSubscriber.ContactQuestion;                    
                       cam.Registration_dated__c = String.isBlank(wsSubscriber.RegistrationDate) ? null : Date.valueOf(wsSubscriber.RegistrationDate); 
                       cam.Last_Action_Date__c = String.isBlank(wsSubscriber.LastActionDate) ? null : Date.valueOf(wsSubscriber.LastActionDate); 
                       cam.Last_Etouches_action_synchronized__c = wsSubscriber.LastEtouchesActionSynchronized;   
                       cam.Subscriber__c = wsSubscriber.SubscriberOptinOptout;   
                       cam.E_Address_Line_1__c = wsSubscriber.AddressLine1;
                       cam.E_City__c = wsSubscriber.City;
                       cam.E_Country__c = wsSubscriber.Country;
                       cam.E_Company__c = wsSubscriber.Company;
                       cam.E_Job_Title__c = wsSubscriber.JobTitle;
                       cam.E_Mobile_Phone__c = wsSubscriber.MobilePhone;
                       cam.E_Work_Phone__c = wsSubscriber.WorkPhone;
                       cam.E_Zip__c = wsSubscriber.Zip; 
                       if(wsSubscriber.Responded == true)
                       {
                           cam.Bounce_Responded__c = true;
                       }  
                       cam.Bounce__c = wsSubscriber.BounceMessage;   
                       cam.Bounce_Type__c = wsSubscriber.BounceType; 
                       cam.TECH_ID_Attendee__c = wsSubscriber.TECH_ID_Attendee;
                   }
        
        if(updateCM){
            System.debug('## JLC ## Class SM025 // updateCampaignMember updateCM = true');
            update cam;
        }               
        
        response.Status = WSResponseWrapper.WS_STATUS_SUCCESS;
        System.debug('## JLC ## Class SM025 // updateCampaignMember TRUE RESPONSE STATUT = ' + response.Status);
        System.debug('## JLC ## Class SM025 // updateCampaignMember TRUE RESPONSE = ' + response);
        response.Message = 'Here the CampaignMember updated from etouches data : ' + wsSubscriber;
        response.Data = new list<CampaignMember>{cam}; 
            
            return response;
    }
    
    private static void updateCampaignMemberByAttendeeID(List<CampaignMember> cmList, WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsSubscriber, WSResponseWrapper response){
        CampaignMember cm = cmList.get(0);
        System.debug('## JLC ## Class SM025 // updateCampaignMember // TECH_ID_Attendee NOT NULL  // CMLIST.GET(0) = ' + cm + ' / ' + cm.Status);
        
        boolean updateCM = false;
        boolean differentRegistrationDate = String.isBlank(wsSubscriber.RegistrationDate) ? (cm.Registration_dated__c != null) : (cm.Registration_dated__c != Date.valueOf(wsSubscriber.RegistrationDate));
            boolean differentLastActionDate = String.isBlank(wsSubscriber.LastActionDate) ? (cm.Last_Action_Date__c != null) : (cm.Last_Action_Date__c != Date.valueOf(wsSubscriber.LastActionDate));
                
                if(cm.Status != wsSubscriber.Status 
                   || cm.Contact_question__c != wsSubscriber.ContactQuestion 
                   || differentRegistrationDate 
                   || differentLastActionDate 
                   || cm.Last_Etouches_action_synchronized__c != wsSubscriber.LastEtouchesActionSynchronized
                   || cm.Subscriber__c != wsSubscriber.SubscriberOptinOptout 
                   || cm.Bounce_Responded__c != wsSubscriber.Responded 
                   || cm.Bounce__c != wsSubscriber.BounceMessage 
                   || cm.Bounce_Type__c != wsSubscriber.BounceType
                   || cm.E_Address_Line_1__c != wsSubscriber.AddressLine1 
                   || cm.E_City__c != wsSubscriber.City 
                   || cm.E_Country__c != wsSubscriber.Country 
                   || cm.E_Company__c != wsSubscriber.Company 
                   || cm.E_Job_Title__c != wsSubscriber.JobTitle
                   || cm.E_Mobile_Phone__c != wsSubscriber.MobilePhone 
                   || cm.E_Work_Phone__c != wsSubscriber.WorkPhone 
                   || cm.E_Zip__c != wsSubscriber.Zip){
                       
                       System.debug('## JLC ## Class SM025 // updateCampaignMember TRUE ' + 'WsSUBSCRIVER STATUS= ' + wsSubscriber.Status + ' CM = ' + cm);
                       
                       updateCM = true;
                       cm.Status = wsSubscriber.Status;
                       cm.Contact_question__c = wsSubscriber.ContactQuestion;                    
                       cm.Registration_dated__c = String.isBlank(wsSubscriber.RegistrationDate) ? null : Date.valueOf(wsSubscriber.RegistrationDate); 
                       cm.Last_Action_Date__c = String.isBlank(wsSubscriber.LastActionDate) ? null : Date.valueOf(wsSubscriber.LastActionDate); 
                       cm.Last_Etouches_action_synchronized__c = wsSubscriber.LastEtouchesActionSynchronized;   
                       cm.Subscriber__c = wsSubscriber.SubscriberOptinOptout;   
                       cm.E_Address_Line_1__c = wsSubscriber.AddressLine1;
                       cm.E_City__c = wsSubscriber.City;
                       cm.E_Country__c = wsSubscriber.Country;
                       cm.E_Company__c = wsSubscriber.Company;
                       cm.E_Job_Title__c = wsSubscriber.JobTitle;
                       cm.E_Mobile_Phone__c = wsSubscriber.MobilePhone;
                       cm.E_Work_Phone__c = wsSubscriber.WorkPhone;
                       cm.E_Zip__c = wsSubscriber.Zip; 
                       if(wsSubscriber.Responded == true)
                       {
                           cm.Bounce_Responded__c = true;
                       }  
                       cm.Bounce__c = wsSubscriber.BounceMessage;   
                       cm.Bounce_Type__c = wsSubscriber.BounceType; 
                       System.debug('## JLC ## Class SM025 // updateCampaignMember BEFORE THE UPDATE');
                       if(updateCM){
                           System.debug('## JLC ## Class SM025 // updateCampaignMember TRUE OK');
                           update cm;
                       } 
                       
                   }
        
        
        response.Status = WSResponseWrapper.WS_STATUS_SUCCESS;
        response.Message = 'Here the CampaignMember updated with the Id: ' + wsSubscriber.SubscriberSFId;
        response.Data = new list<CampaignMember>{cm}; 
            System.debug('## JLC ## Class SM025 // response.Data = ' + response.Data);
    }
    
    private static WSResponseWrapper linkNewCampaignMemberToContact(Contact con, WSResponseWrapper response, WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsSubscriber){
        System.debug('## JLC ## Class SM025 // updateCampaignMember // CONTACT FOUND = ' + con + 'CONTACT NAME = ' + con.Name + ' CONTACT EVENT EMAIL = ' + con.Event_Email__c);
        
        CampaignMember camMember = new CampaignMember();         
        camMember.Status = wsSubscriber.Status;
        camMember.ContactId = con.Id;
        camMember.CampaignId = wsSubscriber.CampaignId;
        camMember.Contact_question__c = wsSubscriber.ContactQuestion;
        camMember.Registration_dated__c = String.isBlank(wsSubscriber.RegistrationDate) ? null : Date.valueOf(wsSubscriber.RegistrationDate); 
        camMember.Last_Action_Date__c = String.isBlank(wsSubscriber.LastActionDate) ? null : Date.valueOf(wsSubscriber.LastActionDate); 
        camMember.Last_Etouches_action_synchronized__c = wsSubscriber.LastEtouchesActionSynchronized;   
        camMember.Subscriber__c = wsSubscriber.SubscriberOptinOptout; 
        camMember.E_Address_Line_1__c = wsSubscriber.AddressLine1;
        camMember.E_City__c = wsSubscriber.City;
        camMember.E_Country__c = wsSubscriber.Country;
        camMember.E_Company__c = wsSubscriber.Company;
        camMember.E_Job_Title__c = wsSubscriber.JobTitle;
        camMember.E_Mobile_Phone__c = wsSubscriber.MobilePhone;
        camMember.E_Work_Phone__c = wsSubscriber.WorkPhone;
        camMember.E_Zip__c = wsSubscriber.Zip; 
        if(wsSubscriber.Responded == true)
        {
            camMember.Bounce_Responded__c = true;
        }  
        camMember.Bounce__c = wsSubscriber.BounceMessage;   
        camMember.Bounce_Type__c = wsSubscriber.BounceType; 
        camMember.TECH_ID_Attendee__c = wsSubscriber.TECH_ID_Attendee;
        
        System.debug('## JLC ## Class SM025 // updateCampaignMember // NEW CAMPAIN MEMBER FROM CON = ' + camMember + 'camMember NAME = ' + camMember.Name + ' camMember EVENT EMAIL = ' + camMember.Event_Email__c);
        
        //Database.insert(camMember, false);
        insert camMember;
        
        response.Status = WSResponseWrapper.WS_STATUS_SUCCESS;
        response.Message = 'Here the CampaignMember created from the Contact found with Etouches data: ' + wsSubscriber;
        response.Data = new list<CampaignMember>{camMember};  
            
            return response;
    }
    
    private static WSResponseWrapper linkNewCampaignMemberToLead (Lead lead, WSResponseWrapper response, WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsSubscriber){
        System.debug('## JLC ## Class SM025 // updateCampaignMember // LEAD FOUND = ' + lead);
        
        CampaignMember camMember = new CampaignMember();                    
        camMember.Status = wsSubscriber.Status;
        camMember.LeadId = lead.Id;
        camMember.CampaignId = wsSubscriber.CampaignId;
        camMember.Contact_question__c = wsSubscriber.ContactQuestion;
        camMember.Registration_dated__c = String.isBlank(wsSubscriber.RegistrationDate) ? null : Date.valueOf(wsSubscriber.RegistrationDate); 
        camMember.Last_Action_Date__c = String.isBlank(wsSubscriber.LastActionDate) ? null : Date.valueOf(wsSubscriber.LastActionDate); 
        camMember.Last_Etouches_action_synchronized__c = wsSubscriber.LastEtouchesActionSynchronized;   
        camMember.Subscriber__c = wsSubscriber.SubscriberOptinOptout;
        camMember.E_Address_Line_1__c = wsSubscriber.AddressLine1;
        camMember.E_City__c = wsSubscriber.City;
        camMember.E_Country__c = wsSubscriber.Country;
        camMember.E_Company__c = wsSubscriber.Company;
        camMember.E_Job_Title__c = wsSubscriber.JobTitle;
        camMember.E_Mobile_Phone__c = wsSubscriber.MobilePhone;
        camMember.E_Work_Phone__c = wsSubscriber.WorkPhone;
        camMember.E_Zip__c = wsSubscriber.Zip;
        if(wsSubscriber.Responded == true){camMember.Bounce_Responded__c = true;}  
        camMember.Bounce__c = wsSubscriber.BounceMessage;   
        camMember.Bounce_Type__c = wsSubscriber.BounceType; 
        camMember.TECH_ID_Attendee__c = wsSubscriber.TECH_ID_Attendee;
        insert camMember; 
        
        response.Status = WSResponseWrapper.WS_STATUS_SUCCESS;
        response.Message = 'Here the CampaignMember created from the Lead found with Etouches data: ' + wsSubscriber;
        response.Data = new list<CampaignMember>{camMember};
            
            return response;
    }
    
    private static Lead createNewLead (WS008_EtouchesSubscriberProcess.EtouchesUpdateSubscriber wsSubscriber){
        Campaign cp = EM011_Campaign.getCampaignByID(wsSubscriber.CampaignId);
        String queueName;
        String businessRegion;
        
        System.debug('Class SM025 // updateCampaignMember // LEAD NOT FOUND');
        
        //3- Create Lead 
        Lead ld = new Lead();              
        ld.Email = wsSubscriber.Email;
        ld.FirstName = wsSubscriber.FirstName;
        ld.LastName = wsSubscriber.LastName;
        ld.Street = wsSubscriber.AddressLine1;
        ld.City = wsSubscriber.City;                        
        ld.Country = wsSubscriber.Country;
        ld.Business_Card_Title__c = wsSubscriber.JobTitle;
        ld.MobilePhone = wsSubscriber.MobilePhone;
        ld.DirectPhone__c  = wsSubscriber.WorkPhone;
        ld.PostalCode = wsSubscriber.Zip; 
        ld.HasOptedOutOfEmail = wsSubscriber.SubscriberOptinOptout; //evol etouches optout 16012018
        ld.Status = 'New';
        ld.LeadSource = 'Event';
        
        if(cp !=null){
            
            Map<String, String> mapQueueBusinessRegion = new Map<String,String>();
            
            for(Queue_Business_Region__mdt queueBr: [SELECT Business_region__c, Queue__c from Queue_Business_Region__mdt]){
                mapQueueBusinessRegion.put(queueBr.Business_region__c, queueBr.Queue__c);
            }
            System.debug('Class SM025 // updateCampaignMember // LEAD NOT FOUND // MapQueueBr = ' + mapQueueBusinessRegion);
            
            businessRegion = cp.owner.BusinessDevelopmentRegions__c;
            
            System.debug('Class SM025 // updateCampaignMember // LEAD NOT FOUND // businessRegion = ' + businessRegion);
            
            if(businessRegion != null && businessRegion != ''){
                List<String> listQueueValues = businessRegion.split(';');
                queueName = mapQueueBusinessRegion.get(listQueueValues.get(0).trim());
                System.debug('Class SM025 // updateCampaignMember // LEAD NOT FOUND // listQueueValues.get(0).trim() = ' + listQueueValues.get(0).trim());
                System.debug('Class SM025 // updateCampaignMember // LEAD NOT FOUND // queueName = ' + queueName);
            }else{
                queueName = 'Event queue';
                System.debug('Class SM025 // updateCampaignMember // LEAD NOT FOUND // queueName = ' + queueName);
            }
            
            List<QueueSobject> listIdQueue = new List<QueueSobject>([SELECT queue.id from QueueSobject where queue.Name =:queueName]);
            System.debug('Class SM025 // updateCampaignMember // LEAD NOT FOUND // listIdQueue.get(0) = ' + listIdQueue.get(0).queueid);
            if(listIdQueue.get(0) != null){
                ld.OwnerId = listIdQueue.get(0).queueid;
            }
            
            ld.SourceComments__c = cp.Name;
        }
        
        if(!ObjectUtil.isEmpty(wsSubscriber.Company)){
            ld.Company = wsSubscriber.Company;
        }
        else
        {
            ld.Company = 'Default Company';
        }
        
        insert ld;
        
        return ld;
    }
}