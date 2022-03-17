trigger StrengthsWeaknessesTrigger on Strengths_and_Weaknesses__c (before insert) {
    for(Strengths_and_Weaknesses__c sw:trigger.new){
        if ( sw.Strength_Type__c != null )
            sw.Name =  'Strength '+sw.Strength_Type__c;  
        else if ( sw.Weakness_Type__c != null )
            sw.Name =  'Weakness '+sw.Weakness_Type__c; 
    }
}