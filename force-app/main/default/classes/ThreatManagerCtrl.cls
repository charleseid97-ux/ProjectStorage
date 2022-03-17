global without sharing class ThreatManagerCtrl {
    
    @AuraEnabled
    global static Threat__c loadThreat(String objectId) {
        Threat__c threat = [SELECT Name, Threat__c, Threat_Type__c, Account_Plan__c FROM Threat__c WHERE Id =: objectId];
        return threat;
    }
    
   @AuraEnabled
   global static Threat__c saveThreat(String parentRecordId, String currentObjectId, String threatText, String threatType){
       Threat__c threat = new Threat__c();
       if(currentObjectId != null) {
           system.debug('%%1');
           threat = [SELECT Name, Threat__c, Threat_Type__c, Account_Plan__c FROM Threat__c WHERE Id =: currentObjectId];
       } else {
           system.debug('%%2');
           threat.Account_Plan__c = parentRecordId;
       }
       threat.Threat__c = threatText;
       threat.Threat_Type__c = threatType;
		system.debug('%%' +parentRecordId + ' - ' + currentObjectId + ' - ' + threatText + ' - ' + threatType);
       try {
           upsert threat;
       } catch (Exception e) {
           throw new AuraHandledException(e.getMessage());
       }
       return threat;
   }
    
    @AuraEnabled
    public static List < String > getselectOptions(sObject objObject, string fld) {
		return AccountUtil.getselectOptions(objObject, fld);
	}
    
}