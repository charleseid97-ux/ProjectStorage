/**
 * Created by Saad on 02/05/2022.
 */

public with sharing class CaseTriggerHandler
{
    public static void handleBeforeInsert(List<Case> newCases)
    {
        new CaseAP01().updateFeedback(newCases);
    }

    public static void handleBeforeUpdate(List<Case> newCases)
    {
        new CaseAP01().updateFeedback(newCases);
    }
}