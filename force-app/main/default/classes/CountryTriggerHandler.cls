public with sharing class CountryTriggerHandler {

    // Prevents manual initialization of the system-managed Main Share Class flag.
    public static void handleBeforeInsert(List<Country__c> newShareClasses) {
        MainShareClassService.validateSystemManagedField(newShareClasses, null);
    }

    // Executes existing registration logic and recalculates impacted Main Share Classes.
    public static void handleAfterInsert(List<Country__c> newShareClasses) {
        CountryHandler.createBelgiumSimulatorTaxData(newShareClasses);
        CountryHandler.syncItalianTaxData(newShareClasses, null);
        MainShareClassService.recalculateAfterCountryInsert(newShareClasses);
    }

    // Prevents manual updates of the system-managed Main Share Class flag.
    public static void handleBeforeUpdate(List<Country__c> newShareClasses , Map<Id,Country__c> oldShareClassesMap){
        MainShareClassService.validateSystemManagedField(newShareClasses, oldShareClassesMap);
    }
    
    // Executes existing registration logic and recalculates changed Product + Country groups.
    public static void handleAfterUpdate(List<Country__c> newShareClasses , Map<Id,Country__c> oldShareClassesMap){
        CountryHandler.syncItalianTaxData(newShareClasses, oldShareClassesMap);
        MainShareClassService.recalculateAfterCountryUpdate(newShareClasses, oldShareClassesMap);

    }

    // Recalculates the remaining registrations after a Country Registration is deleted.
    public static void handleAfterDelete(List<Country__c> oldShareClasses) {
        MainShareClassService.recalculateAfterCountryDelete(oldShareClasses);
    }
}