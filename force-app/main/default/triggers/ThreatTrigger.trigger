trigger ThreatTrigger on Threat__c (before insert) {
    for(Threat__c t:trigger.new){
        if ( t.Threat_Type__c != null )
            t.Name =  'Threat '+t.Threat_Type__c;
    }
}