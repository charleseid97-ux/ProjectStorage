public class CPGN_AddToCampaignLeadMass_VFCE {
/** 
* @author: Olivier Lemaire
* @date : Creation 2017/04/12
* @date : Modification 
* @description : Controller extension for custom mass add lead to campaign to let choose the campaign 
* 				 category to apply to the member
*/    
    ApexPages.StandardSetController setLead;

    //------------ Constructor ----------------------------------
    public CPGN_AddToCampaignLeadMass_VFCE(ApexPages.StandardSetController controller) {
        setLead = controller;
    }

    //------------ Misc utilities --------------
    public integer getSelectedListSize() {
        return setLead.getSelected().size();
    }

    //--------------- Collect Choice and members -------------------    

    //--------------- searchCampaign using filtered name (to popuplate Campaign list)-----
    //  n.b.: this one is called from onchange event on sCampaignNameFilter field. This way the 
    //        Campaign picklist is populated from the filter enter in first field.
    public list<Campaign> listCampaign = new list<Campaign>();
    public String sCampaignNameFilter   {get;set;}
    public PageReference searchCampaign() {
        listCampaign = [
            select id, name from Campaign where name like :sCampaignNameFilter + '%'  
            order by name
            LIMIT 999
        ];
        return null;
    }    
    //-------------- Campaign Picklist -----------
    //		first level in dependent PL Campaign/CategoryEvent/MemberStatus) 
    //		and in dependent PL Campaign/MemberStatus
    public string sCampaignId		{get;set;}

    public List<SelectOption> getListCampaignName()
    {
        List<SelectOption> options = new List<SelectOption>();

        // Campaign list is itself constrained by search filter sCampaignNameFilter
        options.add(new SelectOption('None','--- Select ---'));        
        for (Campaign oCampaign : listCampaign) {
            options.add(new SelectOption(oCampaign.Id, oCampaign.Name));
        }
        return options;
    } 
    
    //-------------- CategoryEvent Picklist (second level in dependent PL Campaign/CategoryEvent/MemberStatus) -------------
    public list<Category_Event__c> listCategoryEvent = new list<Category_Event__c>();
    public string sCategoryEventId	{get;set;}

    public List<SelectOption> getlistCategoryEvent()
    {
        List<SelectOption> options = new List<SelectOption>();
        listCategoryEvent = [
            select id, name from Category_Event__c where Campaign__c = :sCampaignId
            LIMIT 999
        ];

        options.add(new SelectOption('None','--- Select ---'));        
        for (Category_Event__c oCategoryEvent : listCategoryEvent) {
            options.add(new SelectOption(oCategoryEvent.Id, oCategoryEvent.Name));
        }
        
        return options;
    }   

    //-------------- CampaignMemberStatus Picklist (Other second level in dependent PL Campaign/MemberStatus) ------------
    public list<CampaignMemberStatus> listCampaignMemberStatus = new list<CampaignMemberStatus>();
    public string sCampaignMemberStatus	{get;set;}

    public List<SelectOption> getlistCampaignMemberStatus()
    {
        List<SelectOption> options = new List<SelectOption>();
        listCampaignMemberStatus = [
            select id, Label from CampaignMemberStatus where CampaignId = :sCampaignId
        ];

        options.add(new SelectOption('None','--- Select ---'));        
        for (CampaignMemberStatus oCampaignMemberStatus : listCampaignMemberStatus) {
            options.add(new SelectOption(oCampaignMemberStatus.Label, oCampaignMemberStatus.Label));
        }
        
        return options;
    }   

    //---------------- Confirm if existing status must be kept ---------------------------------
    public boolean bKeepExistingStatus {get;set;}
    
    //--------------- Add Selected Records to campaign ------------------------------------------
    //  Note: if record already a member and bKeepExistingStatus fagged then do not update status)-----
    public PageReference AddToCampaign() {
        
        transient list<CampaignMember> listCampaignMemberAdd = new list<CampaignMember>();
        transient list<CampaignMember> listCampaignMemberUpd = new list<CampaignMember>();
        transient map<Id,CampaignMember> mapExistingCampaignMember = new map<Id,CampaignMember>();
        
        //Find set of existing members, assuming 5K max on campaign
        list<CampaignMember> listExistingCampaignMember = new list<CampaignMember>([
            select id, leadId,status from CampaignMember where CampaignId = :sCampaignId and leadId in :setLead.getSelected()
            LIMIT 9999 
        ]);
        
        for (CampaignMember oCampaignMember : listExistingCampaignMember) {
            mapExistingCampaignMember.put(oCampaignMember.leadId,oCampaignMember);
        }
        
        
        //for each selected record
        for (sObject oSelectedRecord : setlead.getSelected()) {
            
            //prepare member to update or add
            CampaignMember oCampaignMember = new CampaignMember(
                 leadId 	= oSelectedRecord.Id
                ,campaignId = sCampaignId
            );
            
            boolean bMemberExist = false;
            //check if selected record already in member list
            if (mapExistingCampaignMember != null) {
                if (mapExistingCampaignMember.keyset().contains(oSelectedRecord.Id) ) {
                    bMemberExist =true;
                }  else { 
                    bMemberExist =false;
                }
            } else {
                    bMemberExist =false;
            }
            
	        oCampaignMember.Category_Event_lookup__c= sCategoryEventId;
            if (bMemberExist) {
                oCampaignMember.id 			= mapExistingCampaignMember.get(oSelectedRecord.id).id;
                if  (!bKeepExistingStatus) {
	                oCampaignMember.status	= sCampaignMemberStatus;
                }
                listCampaignMemberUpd.add(oCampaignMember);
            } else {
                oCampaignMember.status 		= sCampaignMemberStatus;
                listCampaignMemberAdd.add(oCampaignMember);
            }

            
        }
        

        update listCampaignMemberUpd;
        insert listCampaignMemberAdd;

        //Yuck, harcoding. But then Contact = 003 and Lead = 00Q should be immutable across orgs
        return new PageReference('/00Q/o');
    }    





    //-------------- Sample HardCoded Dependant pick list Campaign/Opty on Campaign ------------
    /*
    public String sCampaignName {get;set;}
    public String sOptyName     {get;set;}

    public List<SelectOption> getListCampaignName()
    {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('None','--- Select ---'));        
        options.add(new SelectOption('AAA','Campaign A Display'));
        options.add(new SelectOption('BBB','Campaign B Display'));
        return options;
    } 
    
    public List<SelectOption> getListOptyName()
    {
        List<SelectOption> options = new List<SelectOption>();
        if(sCampaignName == 'AAA')
        {       
            options.add(new SelectOption('Opty1','Opty1'));
            options.add(new SelectOption('Opty2','Opty2'));
        }
        else if(sCampaignName == 'BBB')
        {       
            options.add(new SelectOption('Opty3','Opty3'));
            options.add(new SelectOption('Opty4','Opty4'));
            options.add(new SelectOption('Opty5','Opty5'));
        }
        else
        {
            options.add(new SelectOption('None','--- Select ---'));
        }      
        return options;
    }   
     * */

}