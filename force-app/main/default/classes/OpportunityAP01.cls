/**
 * Created by Saad on 02/05/2022.
 */

public with sharing class OpportunityAP01
{
    public void updateFeedback(Map<Id, Opportunity> newOpportunities)
    {
        Map<Id, List<Case>> casesByOpportunities = getCasesByOpportunity(newOpportunities.values());

        List<Case> casesToUpdate = new List<Case>();

        for (Id oppId : casesByOpportunities.keySet()) {
            for (Case aCase : casesByOpportunities.get(oppId)) {
                if (aCase.Coordinator_Feedback__c != aCase.Opportunity__r.Due_Diligence_Feedback__c || aCase.Opportunity_s_Result_Reason_Explanation__c != aCase.Opportunity__r.Result_Reason_Explanation__c) {
                    aCase.Coordinator_Feedback__c = aCase.Opportunity__r.Due_Diligence_Feedback__c;
                    aCase.Opportunity_s_Result_Reason_Explanation__c = aCase.Opportunity__r.Result_Reason_Explanation__c;
                    casesToUpdate.add(aCase);
                }
            }
        }
        update casesToUpdate;
    }

    public void updateFeedback(Map<Id, Opportunity> newOpportunities, Map<Id, Opportunity> oldOpportunities)
    {
        List<Opportunity> opportunities = filterOpportunities(newOpportunities, oldOpportunities);

        updateFeedback(new Map<Id, Opportunity>(opportunities));
    }

    private List<Opportunity> filterOpportunities(Map<Id, Opportunity> newOpportunities, Map<Id, Opportunity> oldOpportunities)
    {
        List<Opportunity> opportunities = new List<Opportunity>();

        for(Id opportunityId : newOpportunities.keySet())
        {
            if(newOpportunities.get(opportunityId).Due_Diligence_Feedback__c != oldOpportunities.get(opportunityId).Due_Diligence_Feedback__c ||
                     newOpportunities.get(opportunityId).Result_Reason_Explanation__c != oldOpportunities.get(opportunityId).Result_Reason_Explanation__c)
            {
                opportunities.add(newOpportunities.get(opportunityId));
            }
        }

        return opportunities;
    }

    private Map<Id, List<Case>> getCasesByOpportunity(List<Opportunity> newOpportunities)
    {
        Map<Id, List<Case>> casesByOpportunity = new Map<Id, List<Case>>();

        List<Case> relatedCases = [
                SELECT
                        Id,
                        Coordinator_Feedback__c,
                        Opportunity_s_Result_Reason_Explanation__c,
                        Opportunity__r.Due_Diligence_Feedback__c,
                        Opportunity__r.Result_Reason_Explanation__c
                FROM
                        Case
                WHERE
                        Opportunity__c IN : newOpportunities
        ];

        for(Case aCase : relatedCases)
        {
            if(casesByOpportunity.containsKey(aCase.Opportunity__c))
            {
                casesByOpportunity.get(aCase.Opportunity__c).add(aCase);
            }
            else
            {
                casesByOpportunity.put(aCase.Opportunity__c, new List<Case>{aCase});
            }
        }

        return casesByOpportunity;
    }

    public void updateFeedbackDate(Map<Id, Opportunity> newOpportunities, Map<Id, Opportunity> oldOpportunities)
    {
        for(Opportunity aOpportunity : newOpportunities.values())
        {
            if(aOpportunity.Due_Diligence_Feedback__c != oldOpportunities.get(aOpportunity.Id).Due_Diligence_Feedback__c)
            {
                aOpportunity.TECH_FeedbackDate__c = System.now();
            }
        }
    }
}