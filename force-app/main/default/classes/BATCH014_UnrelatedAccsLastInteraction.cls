/**
 * Created by Saad LOZZI on 07/09/2021.
 */

public with sharing class BATCH014_UnrelatedAccsLastInteraction implements Database.Batchable<SObject>
{
    String query;

    public BATCH014_UnrelatedAccsLastInteraction(String aQuery)
    {
        query = aQuery;
    }

    public Database.QueryLocator start(Database.BatchableContext BC)
    {
        Database.QueryLocator queryLocator = Database.getQueryLocator(query);

        return queryLocator;
    }

    public void execute(Database.BatchableContext BC, List<Account> scope)
    {
        List<Account> accountsToUpdate = new List<Account>();

        for(Account anAccount : scope)
        {
            if(anAccount.Last_interaction_with_contact__c == null ||
                    anAccount.Last_interaction_with_contact__c < anAccount.CreatedDate)
            {
                anAccount.Last_interaction_with_contact__c = anAccount.CreatedDate;
                accountsToUpdate.add(anAccount);
            }
        }

        Database.update(accountsToUpdate, false);
    }

    public void finish(Database.BatchableContext BC){}
}