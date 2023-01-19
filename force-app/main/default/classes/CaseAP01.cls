/**
 * Created by Saad on 02/05/2022.
 */

public with sharing class CaseAP01
{
    public void updateFeedback(List<Case> newCases)
    {
        Map<Id, Opportunity> opportunities = getRelatedOpportunities(newCases);

        for(Case aCase : newCases)
        {
            if(aCase.Coordinator_Feedback__c != opportunities.get(aCase.Opportunity__c)?.Due_Diligence_Feedback__c)
            {
                aCase.Coordinator_Feedback__c = opportunities.get(aCase.Opportunity__c)?.Due_Diligence_Feedback__c;
            }
            if(aCase.Opportunity_s_Result_Reason_Explanation__c !=  opportunities.get(aCase.Opportunity__c)?.Result_Reason_Explanation__c){

                aCase.Opportunity_s_Result_Reason_Explanation__c = opportunities.get(aCase.Opportunity__c)?.Result_Reason_Explanation__c;
            }
        }
    }

    private Map<Id, Opportunity> getRelatedOpportunities(List<Case> newCases)
    {
        Set<Id> opportunitiesIds = getOpportunitiesIds(newCases);

        return new Map<Id, Opportunity>([
                SELECT
                    Id,
                    Due_Diligence_Feedback__c, Result_Reason_Explanation__c
                FROM
                    Opportunity
                WHERE
                    Id IN : opportunitiesIds
        ]);
    }

    private Set<Id> getOpportunitiesIds(List<Case> newCases)
    {
        Set<Id> opportunitiesIds = new Set<Id>();

        for(Case aCase : newCases)
        {
            if(aCase.Opportunity__c != null)
            {
                opportunitiesIds.add(aCase.Opportunity__c);
            }
        }

        if(opportunitiesIds.size() > 0)
        {
            return  opportunitiesIds;
        }
        return null;
    }
}