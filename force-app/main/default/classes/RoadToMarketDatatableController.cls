public with sharing class RoadToMarketDatatableController {
 
    @AuraEnabled(cacheable=true)
    public static List<RoadToMarket__c> getTasks(Id parentId, String teamFilter) {
        String query = 'SELECT Id, Name, Team__c, Description__c, Contributors__c, Deadline__c, Status__c, Criticity__c, TECH_TeamOrder__c, RoadToMarket__c ' +
                       'FROM RoadToMarket__c WHERE RoadToMarket__c = :parentId';
        if (String.isNotBlank(teamFilter)) {
            query += ' AND Team__c = :teamFilter';
        }
        query += ' ORDER BY TECH_TeamOrder__c';
        return Database.query(query);
    }
 
    @AuraEnabled(cacheable=true)
    public static List<String> getTeamPicklistValues() {
        List<String> values = new List<String>();
        Schema.DescribeFieldResult fieldResult = RoadToMarket__c.Team__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            values.add(entry.getValue());
        }
        return values;
    }
 
    @AuraEnabled(cacheable=true)
    public static List<String> getStatusPicklistValues() {
        List<String> values = new List<String>();
        Schema.DescribeFieldResult fieldResult = RoadToMarket__c.Status__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            values.add(entry.getValue());
        }
        return values;
    }
 
    @AuraEnabled
    public static List<RoadToMarket__c> updateTasks(List<RoadToMarket__c> updatedRecords) {
        update updatedRecords;
        return [
            SELECT Id, Name, Team__c, Description__c, Contributors__c, Deadline__c, Status__c, Criticity__c, TECH_TeamOrder__c, RoadToMarket__c
            FROM RoadToMarket__c
            WHERE Id IN :updatedRecords
        ];
    }
 
    @AuraEnabled
    public static void deleteTask(Id recordId) {
        delete [SELECT Id FROM RoadToMarket__c WHERE Id = :recordId];
    }
}