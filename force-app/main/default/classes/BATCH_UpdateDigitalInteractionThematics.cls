/**
* @author Abderrahmane TRIA
* @date Creation 23/04/2020
* @date Update 24/06/2020
* @group BATCH
* @description BATCH to Update Digital Interaction.
*/
global class BATCH_UpdateDigitalInteractionThematics implements 
Database.Batchable<sObject>, Database.Stateful {
    
    // instance member to retain state across transactions
    global Integer recordsProcessed = 0;
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT URL__c, Thematic__c FROM Digital_Interaction__c WHERE Thematic__c = \'N/A\' OR Thematic__c = null'
            // AND type__c in (\'QuarterlyReport\' , \'FlashNote\' , \'Video\' , \'FundsFocus\' , \'CarmignacNote\' , \'ProSpace\')' 
        );
    }
    global void execute(Database.BatchableContext bc, List<Digital_Interaction__c> scope){
        List<Digital_Interaction__c> dis = new List<Digital_Interaction__c>();
        List<Thematic__mdt> lstThematic = [SELECT Thematic__c,Thematic_values__c FROM Thematic__mdt]; 
        
        for (Digital_Interaction__c di : scope ) {
            di.Thematic__c = getThematicFromURL(di.URL__c, lstThematic);
            dis.add(di);
        }
        
        update(dis);
    }
    static String getThematicFromURL(String URL,List<Thematic__mdt> lstThematic) {
        
        List<String> lstURL = URL.split('/');
        
        Map<String, String> mapThematics = new Map<String, String>();
        
        for (Thematic__mdt Item : lstThematic ) {
            mapThematics.put(Item.Thematic__c, Item.Thematic_values__c);
        }
        
        for (String thematic : mapThematics.keySet()) {
            List<String> lstValuesThematic = mapThematics.get(thematic).split(';');
            if(containsAny(lstURL, lstValuesThematic))
                return thematic;
            
        }
        return 'N/A';
    }
    
    public static boolean containsAny(List<String> lstURL, List<String> values) {
        for (String i : values) {
            for ( String j : lstURL)
                if (j.contains(i))
                return true;
        }
        return false;
    }    
    global void finish(Database.BatchableContext bc){
        
    }    
}