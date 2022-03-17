/**
* @author Abderrahmane TRIA
* @date Creation 28/05/2020
* @group BATCH
* @description BATCH to update Lead created by BrightTALK
*/
global class BATCH005_Lead_BrightTALK implements Database.Batchable<AggregateResult> {
    
    // The batch job starts
    global Iterable<AggregateResult> start(Database.BatchableContext bc){
        String BrightTalk = 'BrightTalk';
        String BrightTALKChannel = 'BrightTALK Channel - 13003';
        String query = 'SELECT Email ea, count(Id) cnt FROM Lead WHERE ( LeadSource = \'' + String.escapeSingleQuotes(BrightTalk)+'\' OR LeadSource = \'' + String.escapeSingleQuotes(BrightTALKChannel)+'\' ) AND IsConverted = FALSE GROUP BY Email HAVING count(Id)>1';
        return new AggregateResultIterable(query);
    }
    
    // The batch job executes and operates on one batch of records 
    global void execute(Database.BatchableContext bc, List<sObject> scope){ 
        
        List<String> lstEmaiLeads = new List<String>();
        for( sObject sObj : scope ) {
            AggregateResult ar = (AggregateResult)sObj;
            lstEmaiLeads.add(String.valueOf(ar.get('ea')));
        }
        
        // Leads processing
        Map<String,List<Lead>> mapLeads = new Map<String,List<Lead>>();
        
        for( Lead l : [SELECT Id, Email, Industry, Address1__c, Address2__c, City__c, ClientDeliveryEmail__c, Company, Country, Connection_History__c, LastModifiedDate
                       FROM Lead 
                       WHERE Email IN:lstEmaiLeads
                       ORDER BY LastModifiedDate desc] ) {
                           if( !mapLeads.containsKey( l.Email ) )
                               mapLeads.put( l.Email, new List<Lead>() );
                           
                           mapLeads.get( l.Email ).add( l );
                       }
        
        List<Lead> lstLeadsToRemove = new List<Lead>();
        List<Lead> lstMasterLeadDupes = new List<Lead>();
        
        for( String email : mapLeads.keySet() ) {
            
            List<Lead> lstLeadR = mapLeads.get( email );
            Lead masterLead = new Lead();
            
            masterLead = lstLeadR[0];
            
            if( lstLeadR.contains( masterLead ) ){
                Integer index = lstLeadR.indexOf(masterLead);
                lstLeadR.remove(index);
            }
            
            for( Lead l: lstLeadR ){
                if ( masterLead.Industry == null || masterLead.Industry == '' || masterLead.Industry == '--none--')
                    masterLead.Industry = l.Industry;
                if ( masterLead.Address1__c == null || masterLead.Address1__c == '')
                    masterLead.Address1__c = l.Address1__c;
                if ( masterLead.Address2__c == null || masterLead.Address2__c == '')
                    masterLead.Address2__c = l.Address2__c;
                if ( masterLead.City__c == null || masterLead.City__c == '')
                    masterLead.City__c = l.City__c;
                if ( masterLead.ClientDeliveryEmail__c == null || masterLead.ClientDeliveryEmail__c == '')
                    masterLead.ClientDeliveryEmail__c = l.ClientDeliveryEmail__c;
                if ( masterLead.Company == null || masterLead.Company == '')
                    masterLead.Company = l.Company;
                if ( masterLead.Country == null || masterLead.Country == '')
                    masterLead.Country = l.Country;
                
                if ( l.LastModifiedDate != null && masterLead.Connection_History__c == null )
                    masterLead.Connection_History__c =  string.valueof(l.LastModifiedDate);
                
                lstMasterLeadDupes.add ( masterLead );
                
                lstLeadsToRemove.add ( l );                
            }
        }
        
        // Contacts processing
        List<String> lstEmailContact = new List<String>();
        for (contact c :[SELECT id,PersonalEmail__c FROM Contact WHERE PersonalEmail__c != null ]){
            lstEmailContact.add(c.PersonalEmail__c);
        }
        
        for (Lead l :[SELECT id,Email 
                      FROM Lead 
                      WHERE ( LeadSource = 'BrightTalk' OR LeadSource = 'BrightTALK Channel - 13003' ) AND Email IN:lstEmailContact AND IsConverted = FALSE ]){
                          
                          lstLeadsToRemove.add ( l );
                      } 
        
        List<String> lstEmailLeads = new List<String>();
        Map<ID, String> mapIdEmailLeads = new Map<ID, String>();
        Map<ID, Lead> mapIdLeads = new Map<ID, Lead>();
        Set<ID> lstIdLeads = new Set<ID>();
        for( Lead l : [SELECT Id, Email 
                       FROM Lead 
                       WHERE ( LeadSource = 'BrightTalk' OR LeadSource = 'BrightTALK Channel - 13003' ) AND IsConverted = FALSE] ) {
                           
                           lstEmailLeads.add( l.Email );
                           mapIdEmailLeads.put( l.ID, l.Email );
                           mapIdLeads.put( l.ID, l );
                           if ( l.ID != null )
                               lstIdLeads.add( l.ID );
                       }
        
        Map<String, ID> mapEmailContact = new Map<String, ID>();
        for( Contact c : [SELECT Id, Name, PersonalEmail__c, Email, CreatedDate 
                          FROM Contact 
                          WHERE PersonalEmail__c IN:lstEmailLeads AND Email != NULL] ) {
                              if ( c.PersonalEmail__c != null )
                                  mapEmailContact.put( c.PersonalEmail__c, c.ID );            
                          }
        
        List<BrightTALK__Webcast_Activity__c> lstBTA = new List<BrightTALK__Webcast_Activity__c>();
        List<String> lEmailLeads = new List<String>();
        for( BrightTALK__Webcast_Activity__c BTA : [SELECT BrightTALK__Contact__c,BrightTALK__Lead__c 
                                                    FROM BrightTALK__Webcast_Activity__c
                                                    WHERE BrightTALK__Contact__c = null AND BrightTALK__Lead__c IN: lstIdLeads] ) {
                                                        if( mapIdEmailLeads.containsKey( BTA.BrightTALK__Lead__c )) {
                                                            if( mapEmailContact.containsKey( mapIdEmailLeads.get( BTA.BrightTALK__Lead__c ) )) {
                                                                BTA.BrightTALK__Contact__c  =  mapEmailContact.get( mapIdEmailLeads.get( BTA.BrightTALK__Lead__c ) );
                                                                lstBTA.add( BTA );
                                                                lstLeadsToRemove.add ( mapIdLeads.get( BTA.BrightTALK__Lead__c ) );
                                                            }
                                                        }
                                                    }
        // List of master to update
        List<Lead> lstLeadsToUpdate = new List<Lead>(new Set<Lead>(lstMasterLeadDupes));
        try {
            // BrightTALK Webcast Activity Database
            Database.update( lstBTA, false );
            Database.update( lstLeadsToUpdate, false );
            Database.delete( lstLeadsToRemove, false );
            
        } catch(Exception e) {
            System.debug('BrightTALK Webcast Activity - The following exception has occurred: ' + e);
        }
    }
    // The batch job finishes
    global void finish( Database.BatchableContext bc ){ 
        // execute any post-processing operations      
    }
}