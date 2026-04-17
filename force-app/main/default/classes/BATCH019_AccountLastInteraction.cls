/**
 * Created by Saad on 06/08/2022.
 */

public with sharing class BATCH019_AccountLastInteraction implements Schedulable, Database.Batchable<SObject>, Database.Stateful
{
    private static final String ACCOUNT_QUERY = '' +
            'SELECT ' +
            '   Id, Name, Last_Contact_involved__c,' +
            '   Last_interaction_with_contact__c, ' +
            '   (SELECT Last_Interaction__c, Name FROM Contacts WHERE ContactStatus__c = \'true\' ORDER BY Last_Interaction__c DESC LIMIT 1)' +
            ' FROM ' +
            '       Account';

    String query;

    public BATCH019_AccountLastInteraction()
    {
        query = ACCOUNT_QUERY;
    }

    public BATCH019_AccountLastInteraction(String aQuery)
    {
        query = aQuery;
    }

    public void execute(SchedulableContext SC)
    {
        BATCH019_AccountLastInteraction batch = new BATCH019_AccountLastInteraction(ACCOUNT_QUERY);
        Database.executeBatch(batch);
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
            if(anAccount.Contacts.size() > 0)
            {
                anAccount.Last_interaction_with_contact__c = anAccount.Contacts.get(0)?.Last_Interaction__c;
                anAccount.Last_Contact_involved__c = '' + anAccount.Contacts.get(0)?.Name + ' in ' + anAccount.Name;
                accountsToUpdate.add(anAccount);
            }
        }

        Database.update(accountsToUpdate, false);
    }

    public void finish(Database.BatchableContext BC) {}
}