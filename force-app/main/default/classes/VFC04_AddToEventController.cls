/*
----------------------------------------------------------------------
-- - Name          : VFC04_AddToEventController
-- - Author        : JL Consulting
-- - Description   : Controller used by
                     1. AddToEvent (lightning component)
--                   2. VFP01_AddToEventController.vfp (Muti select button for Contact)
--                   2. VFP04_AddToEventLeadController.vfp (Muti select button for Lead)
-- Maintenance History:
--
-- Date         Name  Version  Remarks
-- -----------  ----  -------  --------------------------------------
-- 23-NOV-2018  JLC    1.0      Initial version
----------------------------------------------------------------------
**********************************************************************
*/
public class VFC04_AddToEventController {
    
    ApexPages.StandardSetController setSelectedValues;
    
    public String sContactIds {get; set;}

    /*
    * Constructor for both VFP01_AddToEventController and VFP04_AddToEventLeadController
    * Visualforce page
    */
    public VFC04_AddToEventController(ApexPages.StandardSetController controller){
        System.debug('//NGO controller : '+controller);
        setSelectedValues = controller;
    }
    
    /*
    *  Get list of Contacts or Leads to be displayed on the AddToEvent screen 
    */
    @AuraEnabled
    public static List<SObject> initializeMembers(String recordId, String sobjecttype){
        
        System.debug('//NGO initializeContacts : '+recordId);
        System.debug('//NGO initializeContacts : '+sobjecttype);
        String sQuery ;
        //List < sObject > lstOfRecords = Database.query(sQuery);
        
        List<SObject> results = new List<SObject>();
        if(String.isNotBlank(recordId)){
            if(recordId.indexOf(',') > 0){
                String[] splitIds = recordId.split(',');
                //results = [select Id, Name, Salutation from Contact where Id in :splitIds];
                sQuery =  'select id, Name, Salutation from ' +sobjecttype + ' where Id in :splitIds';
            }else{
                sQuery =  'select id, Name, Salutation from ' +sobjecttype + ' where Id = :recordId';
            }
 
        }
        System.debug('//NGO sQuery : '+sQuery);
        results = Database.query(sQuery);
        return results;
    }
    
    /*
    *  Initialize the Category Event picklist by fetching the Category Event 
    *  associated with the selected Campaign
    */
    @AuraEnabled
    public static List<Category_Event__c> initializePicklist(Id sCampaignId){
        System.debug('//NGO sCampaignId : '+sCampaignId);       
        List<Category_Event__c> events = [select Id, Name from Category_Event__c where Campaign__c = :sCampaignId
            LIMIT 999];
        return events;
    }
    
    /*
    *  Initialize the Member Status picklist by fetching the CampaignMemberStatus
    *  associated with the selected Campaign
    */
    @AuraEnabled
    public static List<String> initializePicklistMember(Id sCampaignId){
        System.debug('//NGO sCampaignId : '+sCampaignId);
        List<String> options = new List<String>();        
        //List<CampaignMemberStatus> metadatas = [select id, Label from CampaignMemberStatus where CampaignId = :sCampaignId order by Label asc];
        List<CampaignMemberStatus> metadatas = [select id, Label from CampaignMemberStatus where CampaignId = :sCampaignId and (Label = 'Invited' OR Label = 'Confirmed')];
                
        for(CampaignMemberStatus mdt : metadatas){            
            if(!options.contains(mdt.Label)){
                options.add(mdt.Label);
            }
        }
        if(options.size()==0){
            options.add('Invited');
            options.add('Confirmed');
        }
        
        return options;
    }
    
    /* Add Selected Records to campaign 
     * if record already a member and bKeepExistingStatus fagged then do not update status)
     */
    @AuraEnabled
    public static boolean addToCampaign(Id iCampaignId, Id iCategory,String sMemberStatus, List<SObject> contactsOrLeads, String sobjecttype) {
         try {
        //Mettre true par defaut pour bKeepExistingStatus
        boolean bKeepExistingStatus = false;
        System.debug('//JLC addToCampaign iCampaignId : '+ iCampaignId);
        System.debug('//JLC addToCampaign iCategory : '+ iCategory);
        System.debug('//JLC addToCampaign sMemberStatus: '+ sMemberStatus);
        System.debug('//JLC addToCampaign bKeepExistingStatus: '+ bKeepExistingStatus);
        System.debug('//JLC addToCampaign lContacts: '+ contactsOrLeads);
        List<Id> contactsOrLeadsIds = new List<Id>();
        for(SObject obj : contactsOrLeads){
            contactsOrLeadsIds.add(obj.Id);
        }
        
        transient list<CampaignMember> listCampaignMemberAdd = new list<CampaignMember>();
        transient list<CampaignMember> listCampaignMemberUpd = new list<CampaignMember>();
        transient map<Id,CampaignMember> mapExistingCampaignMember = new map<Id,CampaignMember>();
        
        //Find set of existing members, assuming 5K max on campaign
        list<CampaignMember> listExistingCampaignMember = new list<CampaignMember>([
            select id, LeadOrContactId, status from CampaignMember where CampaignId = :iCampaignId and LeadOrContactId in :contactsOrLeadsIds LIMIT 9999 
        ]);
        
        for (CampaignMember oCampaignMember : listExistingCampaignMember) {
            mapExistingCampaignMember.put(oCampaignMember.LeadOrContactId,oCampaignMember);
        }
        
        
        //for each selected record
        for (sObject oSelectedRecord : contactsOrLeads) {
            //prepare member to update or add
            CampaignMember oCampaignMember = new CampaignMember();
            if(sobjecttype.equalsIgnoreCase('Contact')){
                oCampaignMember.ContactId   = oSelectedRecord.Id;
            }else{
                oCampaignMember.LeadId  = oSelectedRecord.Id;
            }
            
            oCampaignMember.campaignId = iCampaignId;
            boolean bMemberExist = false;
            //check if selected record already in member list           
            if (mapExistingCampaignMember.size() > 0){
                if (mapExistingCampaignMember.keyset().contains(oSelectedRecord.Id) ) {
                    bMemberExist =true;
                }  else { 
                    bMemberExist =false;
                }
            } else {
                    bMemberExist =false;
            }
            
            oCampaignMember.Category_Event_lookup__c = iCategory;
            if (bMemberExist) {
                oCampaignMember.id          = mapExistingCampaignMember.get(oSelectedRecord.id).id;
                if  (!bKeepExistingStatus) {
                    oCampaignMember.status  = sMemberStatus;
                }
                listCampaignMemberUpd.add(oCampaignMember);
            } else {
                oCampaignMember.status      = sMemberStatus;
                listCampaignMemberAdd.add(oCampaignMember);
            }

            
        }
        
        
        System.debug('//JLC avant insert et update listCampaignMemberUpd =  '+ listCampaignMemberUpd);
        System.debug('//JLC avant insert et update listCampaignMemberAdd =  '+ listCampaignMemberAdd);
        update listCampaignMemberUpd;
        insert listCampaignMemberAdd;

        return true;
             } catch (DmlException e) {
                // Renvoie le message exact (inclut celui de la VR)
                // e.getDmlMessage(0) est souvent plus précis que e.getMessage()
                throw new AuraHandledException(e.getDmlMessage(0));
            } catch (Exception e) {
                throw new AuraHandledException(e.getMessage());
            }
    }    
    
    /*
     * Get the selected records from the list and convert to a String of IDs seperated by comma
     */
    public PageReference getSelectedValues(){
        // Apex code for handling records from a List View goes here
        List<SObject> selectedListViewRecords = (List<SObject>) setSelectedValues.getSelected();               
                   
        if(selectedListViewRecords.size()>0){                                
            list<string> conIds = new list<string>();  
            
            for(SObject objet : selectedListViewRecords){
                conIds.add(objet.Id); 
            }
            sContactIds = conIds.size()>0 ? String.join(conIds, ',') : '';
            
        }
        system.debug('//JLC selectedListViewRecords '+selectedListViewRecords.size() );
        return null;
    }
}