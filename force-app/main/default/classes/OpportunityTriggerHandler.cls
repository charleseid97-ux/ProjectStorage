public class OpportunityTriggerHandler {

    public static void handleBeforeInsert(List<Opportunity> newOpportunity) {
        
        //Create Sets and Lists
        Set<ID> OppAcc = New Set<id>();
        
        //Loop through inbound opps and add the accountid to the ID set
        For(Opportunity o : newOpportunity)
        {
            OppAcc.add(o.Accountid);
        }    
        
        Map<id, account> AccMap=new Map<id, account>();
        AccMap.putAll([select toLabel(BusinessDevelopmentRegion__c),BusinessDevelopmentRegion_TEXT__c from Account where id in :OppAcc]);    
        
        //Loop back through the same opps. Link the account through the map above, then match the 2 fields.
        For(Opportunity o : newOpportunity)
        {
            Account a = AccMap.get(o.AccountId);
            o.BusinessDevelopmentRegion__c = (a.BusinessDevelopmentRegion__c != null) ? a.BusinessDevelopmentRegion__c : null;
            o.BusinessDevelopmentRegionTEXT__c = (a.BusinessDevelopmentRegion_TEXT__c != null) ? a.BusinessDevelopmentRegion_TEXT__c : null;
        }
    }
    
}