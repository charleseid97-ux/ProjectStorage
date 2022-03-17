/*************************************************************************************************************************
Class Name      :   MeetingNoteUtil
Class Desc.     :   Utility Class  used for Meeting_Note__c
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
Oct-2015         Alpha FMC       0.01            Initial build of class                           Client               None
Feb-2017         Alpha FMC       0.02            Added in support for denormalised fields         Client
***************************************************************************************************************************/

public with sharing class MeetingNoteUtil
{

    // Private Variables
    private set<String> contactIds= new set<String>();
    private set<String> accountIds = new set<String>();
    private String objectName;
    private set<String> allLinkIds = new set<String>();
    private map<String,Account> accountIdToAccount;
    private map<String,Contact> contactIdToContact;
    private map<String,Opportunity> opportunityIdToOpportunity;
    private map<String,Campaign> campaignIdToCampaign;
    private map<String,Product__c> productIdToProduct;

    //Public Variables, this will be populated by the class and access by the MeetingNoteExt
    public Meeting_Note__c MeetingNote = new Meeting_Note__c();
    public list<Meeting_Link__c> ExternalContacts = new list<Meeting_Link__c>();
    public list<Meeting_Link__c> Products = new list<Meeting_Link__c>();
    public list<Meeting_Link__c> Accounts = new list<Meeting_Link__c>();
    public list<Meeting_Link__c> InternalContacts = new list<Meeting_Link__c>();
    public list<Meeting_Link__c> Opportunities = new list<Meeting_Link__c>();
    public list<Meeting_Link__c> Campaigns = new list<Meeting_Link__c>();


	public list<Meeting_Link__c> AllMeetingLinks{

		get{

			list<Meeting_Link__c> allLinks = new list<Meeting_Link__c>();

			allLinks.addAll(ExternalContacts);
			allLinks.addAll(Products);
			allLinks.addAll(Accounts);
			allLinks.addAll(InternalContacts);
			allLinks.addAll(Opportunities);
			allLinks.addAll(Campaigns);
			return allLinks;
		}
	}
    //Config Variables
    private static map<String,map<String,String>> configMap
    {
        get
        {
            if(configMap == null)
            {
                //map for task
                map<String,String> taskMap = new map<String,String>
                {
                    'Id' => null
                    , 'OwnerId' => 'Employee__c'
                    , 'WhoId' => 'Contact__c'
                    , 'WhatId' => null
                    , 'Subject' => 'Name'
                    , 'Description__c' => 'Note__c'
                    , 'ActivityDate'=> 'Date__c'
                };

                //map for task and events
                map<String,String> eventMap = new map<String,String>
                {
                    'Id' => null
                    , 'OwnerId' => 'Employee__c'
                    , 'WhoId' => 'Contact__c'
                    , 'WhatId' => null
                    , 'Subject' => 'Name'
                    , 'Description__c' => 'Note__c'
                    , 'ActivityDate'=> 'Date__c'
                    , 'Campaign_Event__c' => 'Campaign__c'
                    , 'Meeting_Note__c' => 'Id'
                };

                //map for contact
                map<String,String> contactMap = new map<String,String>
                {
                    'Id' => 'Contact__c'
                    , 'AccountId' => 'Account__c'
                    , 'OwnerId' => 'Employee__c'
                };

                //map for product
                map<String,String> productMap = new map<String,String>
                {
                    'Id' => 'Product__c'
                };
                //map for opportunity
                map<String,String> opportunityMap = new map<String,String>
                {
                    'Id' => 'Opportunity__c'
                };
                //map for campaign
                map<String,String> campaignMap = new map<String,String>
                {
                    'Id' => 'Campaign__c'
                };

                //map for account
                map<String,String> accountMap = new map<String,String>
                {
                    'Id' => 'Account__c'
                    , 'OwnerId' => 'Employee__c'
                };

                //Populate the object map
                configMap = new map<String,map<String,String>>
                {
                    'Task' => taskMap
                    , 'Event' => eventMap
                    , 'Contact' => contactMap
                    , 'Product__c' => productMap
                    , 'Opportunity' => opportunityMap
                    , 'Campaign' => campaignMap
                    , 'Account' => accountMap
                };
            }
            return configMap;
        }
        set;
    }

    /**
    * Constructor - takes in an Id from Event, Task, Account, Contact, Opporturtunity
    * or Product and builds up the dynamic query based on the configMap
    * @param  SObject - the Object of the id passed to the constructor
    * @return None
    */
    public MeetingNoteUtil(String activityId)
    {
        // Building up the query
        String queryStructure = 'SELECT {0} FROM {1} WHERE Id = \'\'{2}\'\'';
        objectName = Id.valueOf(activityId).getSObjectType().getDescribe().getName();
        //objectName = getObjectName(activityId);
        list<String> selectFields = new list<String>(configMap.get(objectName).keySet());
        String allFieldsQuery = string.format(queryStructure, new list<string>{string.join(selectFields,','),objectName,activityId});
        processInputObject(allFieldsQuery);
    }

    //Get Meeting Note id from Task/Event
    public static string idFromActivity(Id activityId)
    {
        Id meetingId;
        if(activityId != null)
        {
            if(String.valueOf(activityId).startsWith('00U'))
            {
                Event tmpEvent = [SELECT Meeting_Note__c FROM Event WHERE Id=:activityId];
                if(tmpEvent.Meeting_Note__c !=null)
                {
                    meetingId = tmpEvent.Meeting_Note__c;
                }
            }
            if(String.valueOf(activityId).startsWith('00T'))
            {
                Task tmpTask = [SELECT Meeting_Note__c FROM Task WHERE Id=:activityId];
                if(tmpTask.Meeting_Note__c !=null)
                {
                    meetingId = tmpTask.Meeting_Note__c;
                }
            }
        }
        return meetingId;
    }

    //Update the task/event with Meeting note
	public static void UpdateMeetingNoteActivity(Id activityId, Id meetingNoteId, Meeting_Note__c mn, List<Meeting_Link__c> cLinks, List<Meeting_Link__c> oLinks)
    {
        if(activityId != null)
        {
            if(String.valueOf(activityId).startsWith('00U'))
            {
                Event tmpEvent = [SELECT Id, Meeting_Note__c FROM Event WHERE Id=:activityId];
                if(tmpEvent !=null)
                {
                    tmpEvent.Meeting_Note__c = meetingNoteId;
                    update tmpEvent;
                }
            } else if(String.valueOf(activityId).startsWith('00T'))
            {
                Task tmpTask = [SELECT Id, Meeting_Note__c FROM Task WHERE Id=:activityId];
                if(tmpTask.Meeting_Note__c !=null)
                {
                    tmpTask.Meeting_Note__c = meetingNoteId;
                    update tmpTask;
                }
            } else {
                //here we will create a calendar entry if none exists
                Datetime current = System.now();
                Date currDate = mn.Date__c;
                Time currTime = current.time();
                Datetime startDate = datetime.newinstance(currDate,currTime);
                Datetime endDate = datetime.newinstance(currDate,currTime).addMinutes(15);

                Event e = new Event();
                e.StartDateTime = startDate;
                e.EndDateTime = endDate;
                e.Subject = mn.Name;
                
                if(String.valueOf(activityId).startsWith('003')) {
                    e.WhoId = activityId;
                } else {
                    e.WhatId = activityId;
                }

                if(oLinks.size() > 0){
                    e.whatId = oLinks[0].Opportunity__c;
                }

                if(mn.Meeting_Type__c.contains('call')) {
                    e.Type='Call';
                } else {
                    e.Type='Individual meeting';
                }
                e.Meeting_Note__c = meetingNoteId;
                insert e;
                
                if(!String.valueOf(activityId).startsWith('003')) {
                    List<EventRelation> ers = new List<EventRelation>();
                    
                    for(Meeting_Link__c ml : cLinks) {
                        EventRelation er = new EventRelation();
                        er.EventId = e.Id;
                        er.IsInvitee = true;
                        er.IsParent=true;
                        er.IsWhat = false;
                        er.RelationId = ml.Contact__c;
                        ers.add(er);
                    }
                    
                    insert ers;
                }
            }
        }
    }

    //Queries out the relevant SObject based on the Id passed to the constructor
    private void processInputObject(String query)
    {
        //Get the Object and add in to allLinksId
        SObject sObj = DataBase.Query(query);
        String activityId = (String) sObj.Id;
        allLinkIds.add(activityId);

        //Now check what object it came from Event/Task in which case we want all Event/Task Relations
        if (activityId.startsWith('00U') || activityId.startsWith('00T'))
        {
            getMeetingFromEventOrTask(sObj);
        }

        //Pass on fields to Call_Report__c
         populateMeetingNoteandLinks(sObj);


    }

    /**
    * Queries out all task/event relations and adds this to the set of allLinksIds
    * @param  SObject - the Object of the id passed to the constructor
    * @return None
    */
    private void getMeetingFromEventOrTask(SObject sObj)
    {
        list<SObject> activityRelations;
        if (String.valueOf(sObj.Id).startsWith('00T'))
        {
            activityRelations = [SELECT Id, AccountId, TaskId, IsWhat, RelationId
                                    FROM TaskRelation WHERE TaskId= :sObj.Id];
        }
        else if (String.valueOf(sObj.Id).startsWith('00U'))
        {
            activityRelations = [SELECT Id, AccountId, EventId, IsInvitee, IsParent
                                    , IsWhat, RelationId, Status FROM EventRelation WHERE EventId= :sObj.Id];
        }

        //Now loop through the activityRelations and add to allLinksId
        for(SObject so : activityRelations)
        {
            String rId = String.valueOf(so.get('RelationId'));
            allLinkIds.add(rId);
        }
    }

    /**
    * Uses the config Map to dynamically populate values on the Meeting Note, and add values to allLinksIds
    * @param  SObject - the Object of the id passed to the constructor
    * @return None
    */
    private void populateMeetingNoteandLinks(SObject sObj)
    {
        //Looping through all the values in the configMap for the revelant object
        for(String aField: configMap.get(objectName).keySet() )
        {
            //system.debug('This is : '+ aField);
            //system.debug('This will be mapped to: '+ configMap.get(objectName).get(aField));

            //get the FieldType
            String fieldType = getFieldType(objectName, aField);

            // Only interested in Strings and Dates for fields on the call report
            if(fieldType == 'STRING')
            {
                System.debug('BP String ' + configMap.get(objectName).get(aField) + ' - ' + sObj.get(aField));
                MeetingNote.put(configMap.get(objectName).get(aField),(String) sObj.get(aField));
            }

            else if(fieldType == 'DATE')
            {
                System.debug('BP Date ' + configMap.get(objectName).get(aField) + ' - ' + (Date) sObj.get(aField));
                MeetingNote.put(configMap.get(objectName).get(aField),(Date) sObj.get(aField));
            }

            //If it is an Id, add to the list of all relevant Ids
            else if(fieldType == 'ID')
            {
                String id = String.valueOf(sObj.get(aField));

                if(id != null && id.startsWith('701')) {
                    Campaign c = [SELECT Type FROM Campaign WHERE Id =: id];
	                MeetingNote.Meeting_Type__c = 'Event (Schedule)';
                    MeetingNote.Purpose__c = c.Type;
                }

                allLinkIds.add(id);
            }
        }
        //Before we are ready to create links, we need to populate our variables in createMeetingLink
        populateVariablesFromAllLinks();

        // Now loop we can loop through and create links for all
        for(String linkId : allLinkIds)
        {
            createMeetingLink(linkId);
        }
    }

    /**
    * Populates the properties of the class based on the content of the set allLinksIds
    * @param  None
    * @return None
    */
    private void populateVariablesFromAllLinks()
    {
        //Query out all contacts including contacts linked to relevant Users
        contactIdToContact = new map<String,Contact>([SELECT Id, Name, User__c, RecordType.DeveloperName
                                        , AccountId , Account.Name, JobTitle__c, Title, MailingCity, Phone, Email
                                        , Account.OwnerId, Account.RecordTypeId, Account.Type, Account.Client_Tier__c
                                        , Account.BillingCity
                                    FROM Contact
                                    WHERE (Id IN :allLinkIds OR (user__c IN :allLinkIds AND user__c != null))]);

        for(Contact c : contactIdToContact.values())
        {

            //if(c.AccountId != null) accountIdToAccount.put((String) c.AccountId , new Account(Id = c.AccountId, Name = c.Account.Name));
            //check if it is an internal contact and add in to allLinksId
            if( c.RecordType.DeveloperName == 'Internal_Carmignac_Contact')
            {
                if(c.user__c != null) allLinkIds.add((string) c.id);
            }
            //Else it's an external contact and we should add in the accounts to allLinksId
            else allLinkIds.add((string) c.accountid);
        }

        //now query out all accounts
        accountIdToAccount = new map<String,Account>([SELECT Id, Name, OwnerId, RecordTypeId
        											, Client_Tier__c, BillingCity, Type
        											FROM Account
        											WHERE Id IN :allLinkIds]);
        //and the Opportunity
        opportunityIdToOpportunity = new map<String,Opportunity>([SELECT Id, Name, AccountId, Account.Name, Amount
        																, StageName, CloseDate
        																FROM Opportunity WHERE Id IN : allLinkIds]);
        //and the Campaign
        campaignIdToCampaign = new map<String,Campaign>([SELECT Id, Name, Event_Type__c
                                                         FROM Campaign WHERE Id IN : allLinkIds]);
        
        //and the Product/Solution
        productIdToProduct = new map<String,Product__c>([SELECT Id, Name, RecordTypeId
        												FROM Product__c WHERE Id IN :allLinkIds]);
    }

    /**
    * Function to get the field type of any object API in the Schema
    * @param Object name and field name to get field type of
    * @return String - the field type
    */
    private static string getFieldType(String objName, String fieldName)
    {
        return String.valueOf(Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().get(fieldName).getDescribe().getSoapType());
    }

    /**
    * Function to get the Object name of any ID passed through
    * @param  String - Id to be processed
    * @return String - Object name associated to the Id
    */
    /*
    private static string getObjectName(String sId)
    {
        Id id = (Id) sId;
        return String.valueOf(id.getSObjectType().getDescribe().getName());
    }
	*/
    /**
    * createMeetingLink determins whether the input id string is an Account, Product__c, Opportunity,
    * User, Employee Contact, or External Contact
    * @param String - the Id to create a note for
    */
    private void createMeetingLink(String linkId)
    {
        //Firstly, get rid of null values
        if(linkId == null) linkId = 'INVALID';

        else
        {
            //For all of this method we need to make sure that each element only is added once
            //Check if it's an account
            if(linkId.startsWith('001') && !accountIds.contains(linkId))
            {
                Meeting_Link__c org = new Meeting_Link__c(Account__c = linkId );
                //added in for rendering  in VF and the de-normalised fields in controller
                org.Account__r = accountIdToAccount.get(linkId);
                //add to list
                Accounts.add(org);
                accountIds.add(linkId);
            }

            //Check if it's a Product, we will only ever have 1 product so no need to check for uniqueness.

            /*else if(UtilitiesSObject.findObjectName(linkId) == 'Product__c')
                Products.add(new Meeting_Link__c(Product__c = linkId,
                                                 Product__r = productIdToProduct.get(linkId)
                                                )
                            );
        	*/
            else if(Id.valueOf(linkId).getSObjectType().getDescribe().getName() == 'Product__c')
                Products.add(new Meeting_Link__c(Product__c = linkId,
                                                 Product__r = productIdToProduct.get(linkId)
                                                )
                            );

            //Check if it is an Opportunity, we will only ever have 1 opportunity so no need to check for uniqueness
            else if(linkId.startsWith('006')) Opportunities.add(new Meeting_Link__c(Opportunity__c = linkId
            																		, Opportunity__r = opportunityIdToOpportunity.get(linkId)));

            //Check if it is a Campaign, we will only ever have 1 Campaign so no need to check for uniqueness
            else if(linkId.startsWith('701')) Campaigns.add(new Meeting_Link__c(Campaign__c = linkId
            																		, Campaign__r = campaignIdToCampaign.get(linkId)));

            //check if it is a contact or employee and that is has not already been added
            else if(linkId.startsWith('003') && !contactIds.contains(linkId))
            {

                //Check if it is an employee
                if(contactIdToContact.get(linkId).RecordType.DeveloperName == 'Internal_Carmignac_Contact')
                {
                    Meeting_Link__c intCont = new Meeting_Link__c(Employee__c = linkId);
                    intCont.Employee__r = contactIdToContact.get(linkId);
                    InternalContacts.add(intCont);
                    contactIds.add(linkId);
                }
                //else check is an external contact, we only want employees and employees, i.e. no internal/external group contacts
                else if (contactIdToContact.get(linkId).RecordType.DeveloperName == 'Contact_DistributionContact' || contactIdToContact.get(linkId).RecordType.DeveloperName == 'Contact_SupportContact' || contactIdToContact.get(linkId).RecordType.DeveloperName == 'Contact_ThirdPartyContact')
                {
                    Meeting_Link__c extAtt = new Meeting_Link__c(Contact__c = linkId);
                    extAtt.Contact__r = contactIdToContact.get(linkId);
                    ExternalContacts.add(extAtt);
                    contactIds.add(linkId);
                }
            }
        }
    }
}