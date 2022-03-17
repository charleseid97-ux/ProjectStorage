public class GAMHomepageCtrl {
	@AuraEnabled
    public static GAM_Homepage__c returnGAMHP(String HPId) {
        return [SELECT Name, Id, Company__c FROM GAM_Homepage__c WHERE Id =: HPId];
    }
    
	@AuraEnabled
    public static Account returnGAMAccount(String HPId) {
        GAM_Homepage__c GHP = [SELECT Company__c FROM GAM_Homepage__c WHERE Id =: HPId];
        return queryAccount('SELECT Id, TECH_CompanyTechSUNID__c, Name, Client_Tier__c, AUMToDate__c, Owner.Name FROM Account WHERE Id = \'' + GHP.Company__c + '\'');
    }
    
	@AuraEnabled
    public static StrategicNews__c returnGAMStrategicNews(String accId) {
        Account UP = [SELECT Id FROM Account WHERE Id =: accId];
        String upId = UP.Id;
        upId = upId.substring(0,15);
        return [SELECT Name, Id, type__c, title__c, ShortSubjectDescription__c, LongTitle__c, Company__c, Company__r.Name, Company__r.Ultimate_Parent_ID__c, CreatedBy.FirstName, CreatedBy.LastName, LastModifiedDate FROM StrategicNews__c WHERE Company__c IN (SELECT Id FROM Account WHERE Ultimate_Parent_ID__c =: upId) ORDER BY LastModifiedDate Desc LIMIT 1];
    }
    
    @AuraEnabled
    public static Account_Plan__c returnLatestAccPlan(String accId) {
        Account_Plan__c accPlan = [SELECT Name, Id FROM Account_Plan__c WHERE Company__c =: accId ORDER BY CreatedDate DESC LIMIT 1];
        return accPlan;
    }

    @AuraEnabled
    public static String getKeyContactFileId(String accId) {
        ContentDocumentLink keyContact = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId =: accId AND ContentDocument.title LIKE '%key%contact%' AND LinkedEntity.Type='Account'];
        return keyContact.ContentDocumentId;
    }
    
    @AuraEnabled
    public static String returnGAMHomepage(String accId) {
        Account UPAcc = [SELECT Ultimate_Parent_ID__c FROM Account WHERE Id =: accId];
        GAM_Homepage__c GAMHP = [SELECT Id FROM GAM_Homepage__c WHERE Company__c =: UPAcc.Ultimate_Parent_ID__c LIMIT 1];
        return GAMHP.Id;
    }
    
    @AuraEnabled
    public static String getOrganigramFileId(String accId) {
        ContentDocumentLink organigram = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId =: accId AND ContentDocument.title LIKE '%Organigram%' AND LinkedEntity.Type='Account'];
        return organigram.ContentDocumentId;
    }
    
    @AuraEnabled
    public static String getFullClientBuyListFileId(String accId) {
        ContentDocumentLink buyList = [SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId =: accId AND ContentDocument.title LIKE '%Full%List%' AND LinkedEntity.Type='Account'];
        return buyList.ContentDocumentId;
    }
    
    @AuraEnabled
    public static String getTieringFileId(String accId) {
        String statResourceId = [select Id from StaticResource where Name = 'AccountTierOverview' LIMIT 1].Id;
        return statResourceId;
    }
    
    private static Account queryAccount(String soqlQuery) {
        Account acc = Database.query(soqlQuery);
        return acc;
    }
    
    @AuraEnabled
    public static Id returnBuyListReport(String reportName) {
        Report buyListReport = [select Id from Report where Name =: reportName LIMIT 1];
        return buyListReport.Id;
    }

    @AuraEnabled
    public static List<GAM_Homepage__c> getGAMHomepagesT0() {
        List<GAM_Homepage__c> homepages = [SELECT Name, Company__r.Name, Company__r.Client_Tier__c, Id FROM GAM_Homepage__c WHERE Company__r.Client_Tier__c = 'Titanium (Tier 0)' ORDER BY Name];
        for(GAM_Homepage__c ghp : homepages) {
            String tmpName = ghp.Company__r.Name;
            String str = '';
            String[] splitString = tmpName.split(' ');
            for(String s: splitString) {
               str = str+s;
            }
            ghp.Company__r.Name = str;
        }
        return homepages;
    }
    
    @AuraEnabled
    public static List<GAM_Homepage__c> getGAMHomepagesT1() {
        List<GAM_Homepage__c> homepages = [SELECT Name, Company__r.Name, Company__r.Client_Tier__c, Id FROM GAM_Homepage__c WHERE Company__r.Client_Tier__c <> 'Titanium (Tier 0)' ORDER BY Name];
        for(GAM_Homepage__c ghp : homepages) {
            String tmpName = ghp.Company__r.Name;
            String str = '';
            String[] splitString = tmpName.split(' ');
            for(String s: splitString) {
               str = str+s;
            }
            ghp.Company__r.Name = str;
        }
        return homepages;
    }
    
}