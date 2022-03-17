public class OpportunityCtrl {
    @AuraEnabled
    public static Opportunity opportunityParties(id oppId)
    { 
        Opportunity result = new Opportunity();
        
        result = [SELECT Id,
                  Name, 
                  CloseDate,
                  IsClosed,
                  Description,
                  IS_Team_Comment__c,
                  IS_Team_Stance__c,
                  Solution_Validation__c,
                  (SELECT Id, Name,
                   Company__c,
                   Company__r.Name
                   FROM Opportunity_Interested_Partners__r)
                  FROM Opportunity
                  WHERE Id = :oppId];
            
        return result;
    }
    
    @AuraEnabled
    public static Opportunity convertOpportunity(Opportunity opp, String oIPId) {
        Map<String, Id> oppRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Opportunity.SObjectType);
        
        Opportunity_Interested_Partner__c oIP = [SELECT Company__c, Company__r.Name FROM Opportunity_Interested_Partner__c WHERE Id =: oIPId];
        Opportunity newOpp = new Opportunity(Name = opp.Name + ' - ' + oIP.Company__r.Name,
                                             AccountId = oIP.Company__c,
                                             Amount = opp.Amount,
                                             CloseDate = opp.CloseDate,
                                             Description = opp.Description,
                                             IS_Team_Comment__c = opp.IS_Team_Comment__c,
                                             IS_Team_Stance__c = opp.IS_Team_Stance__c,
                                             Solution_Validation__c = opp.Solution_Validation__c,
                                             StageName = 'Partner Interest Confirmed',
                                             RecordTypeId = oppRtMap.get('x5Investment_Solution_Opportunity')
                                            );
        insert newOpp;
        
        Set<Id> mNoteIds = new Set<Id>();
        for(Meeting_Link__c ml : [SELECT Meeting_Note__c, Name, Id FROM Meeting_Link__c WHERE Opportunity__c =: opp.Id ]) {
            mNoteIds.add(ml.Meeting_Note__c);
        }
        
        List<Meeting_Note__c> mNotes = [SELECT Name, 
                                        (SELECT Name, Date__c, Opportunity__c, Account__c, Meeting_Note__c 
                                         FROM Meeting_Links__r
                                         WHERE Account__c <> null OR Opportunity__c <> null) 
                                        FROM Meeting_Note__c WHERE Id IN: mNoteIds];
        List<Meeting_Link__c> newMLinks = new List<Meeting_Link__c>();

        System.debug('BP 1 ' +  mNotes.size());

        for(Meeting_Note__c mn : mNotes) {
	        System.debug('BP 2 ' +  mn.Meeting_Links__r.size());
            for(Meeting_Link__c ml : mn.Meeting_Links__r) {
                if(ml.Account__c == oIP.Company__c) {
			        System.debug('BP 3 yes');
                    newMLinks.add(new Meeting_Link__c(Name = ml.Name, Meeting_Note__c = ml.Meeting_Note__c, Opportunity__c = newOpp.Id));
                }
            }
        }
        System.debug('BP 4 ' +  newMLinks);
        
        insert newMLinks;

        delete oIP;
        
        return newOpp;
    }
}