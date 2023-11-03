//Update the dynamic dashboards used for the HomePage
global with sharing class BATCH024_DynamicDashboardRefresh implements Database.Batchable<sObject>, Database.AllowsCallouts, schedulable {
    
    //The batch job starts
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT id FROM Dashboard WHERE FolderName=:'Public Sales Dashboards']);
    }

    //The scheduled batch job starts
    global void execute(System.SchedulableContext sc) {
        BATCH024_DynamicDashboardRefresh batch = new BATCH024_DynamicDashboardRefresh();
        Database.executeBatch(batch);
    }

    //The batch job executes and operated on one batch of records
    global void execute(Database.BatchableContext bc, List<Dashboard> scope) {
        for (Dashboard d : scope) {
            HttpRequest req = new HttpRequest();
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            req.setMethod('PUT');
            req.setEndpoint(URL.getSalesforceBaseUrl().toExternalForm() + '/services/data/v57.0/analytics/dashboards/' + d.id);        
            Http http = new Http();
            HttpResponse res = http.send(req);
        }
    }

    //The batch job finishes
    global void finish(Database.BatchableContext bc) {

    }
}