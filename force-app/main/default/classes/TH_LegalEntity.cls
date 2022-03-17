/**
* @author Abderrahmane TRIA
* @date Creation 07/04/2020
* @group TriggerHandler
* @description Trigger Handler Legal Entity
*/
public class TH_LegalEntity  extends TH_TriggerHandler {
    private static final String CLASS_NAME = TH_LegalEntity.class.getName();
    
    public override void beforeInsert(){
        
        System.debug('### Start before trigger: ' +CLASS_NAME+ ' Event Name: beforeInsert');
        List<String> lLEIs = new List<String>();
        if( System.isBatch() ) return;
        for (Legal_Entity__c le : (List<Legal_Entity__c>)Trigger.new) { 
            //call the processRecords method and pass the values
            if (le.LEI__c != 'No LEI UME' && le.LEI__c != '')
                lLEIs.add(le.LEI__c);
        }
        String leis = string.join(lLEIs,',');
        CalloutLegalEntity.processRecords(leis);
        
        System.debug('### End before trigger: ' +CLASS_NAME+ ' Event Name: beforeInsert');
        
    }
}