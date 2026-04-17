public class StrategicNewsCtrl {
    @AuraEnabled
    public static List < String > getselectOptions(sObject objObject, string fld) {
        return AccountUtil.getselectOptions(objObject, fld);
    }
    
    @AuraEnabled
    public static List<Id> getAccountList(String UPId) {
        UPId = UPId.substring(0, 15);
        List<Id> returnAccountIds = new List<Id>();
        Account UPAccount = [SELECT Id, Name FROM Account WHERE Id=:UPId];
        returnAccountIds.add(UPAccount.Id);
        for(Account a : [SELECT Id, Name FROM Account WHERE Ultimate_Parent_Id__c =: UPId AND Id <> : UPId ORDER BY Name]) {
            returnAccountIds.add(a.Id);
        }
        
        return returnAccountIds;
    }
    
    @AuraEnabled
    public static List<StrategicNews__c> getStrategicNewsList(String type, List<Id> accIds) {
        List<StrategicNews__c> SNs = new List<StrategicNews__c>();
        String SNQuery = 'SELECT Id, Type__c, Subtype__c, Name, Title__c, CreatedDate, Company__r.Name, StrategicNews__c  FROM StrategicNews__c WHERE Company__c IN: accIds ';
        SNQuery = SNQuery + (type == 'All' ? '' : 'AND Type__c =: type ');
        SNQuery = SNQuery + 'ORDER BY CreatedDate desc';
        List<StrategicNews__c> SNList = database.query(SNQuery);
        SNs.addAll(SNList);
        
        return SNs;
    }
    @AuraEnabled
    public static List<Id> getStrategicNews(List<Id> selectedSN) {    
        return selectedSN;
    } 
}