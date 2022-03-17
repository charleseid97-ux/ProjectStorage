global class BATCH006_RecordType_BrightTALK  implements Database.Batchable<sObject> {
    global Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id, recordTypeId, recordType.Name 
                                         FROM Lead 
                                         WHERE (LeadSource = 'BrightTalk' OR LeadSource = 'BrightTALK Channel - 13003') AND IsConverted = FALSE]);
    }
    
    global void execute(Database.BatchableContext context, List<Lead> lLead) {
        
        // Map Record Type Lead 
        List<RecordType> lRecordType = new List<RecordType>([SELECT Id,Name FROM RecordType WHERE sObjectType='Lead']);
        Map<String, ID> mIdNameRT = new Map<String, ID>();
        for (RecordType rt : lRecordType) {
            mIdNameRT.put(rt.Name, rt.ID);
        }
        
        // Leads Update processing Record Type
        List<Lead> lLeadUpdate = new List<Lead>();
        for(Lead l: lLead) {
            if(l.recordType.Name != 'BrightTALK Lead' || l.recordType.Name != 'BrightTALK Channel - 13003'){
                l.recordTypeId = mIdNameRT.get('BrightTALK Lead');
                lLeadUpdate.add(l);
            }
        }
        
        try {
            // Update the Lead Record Type
            Database.update(lLeadUpdate,false); 
            
        } catch(Exception e) {
            System.debug('Lead Update Record Type - The following exception has occurred: ' + e);
        }
        
    }
    global void finish(Database.BatchableContext context) {
        
    }
}