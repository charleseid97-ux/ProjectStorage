/**
 * @description       : 
 * @author            : Mira EID
 * @group             : 
 * @last modified on  : 09-02-2026
 * @last modified by  : Mira EID
**/
@IsTest
private class CaseWorkingHoursTest {

    @IsTest
    
    static void testStatusTransitionsAndDurations() {
        
        // Création d'un Case initial en statut New
        Case c = TestDataFactory.getCase();
        insert c;
        
        // --- Passage New → Work in progress ---
        Test.startTest();

        c.Status = 'Work in progress';
        update c;

        // Simuler un On Hold
        c = [SELECT Id, Status, On_Hold__c FROM Case WHERE Id = :c.Id];
        c.On_Hold__c = true;
        update c;

        // Fin du On Hold
        c = [SELECT Id, On_Hold__c FROM Case WHERE Id = :c.Id];
        c.On_Hold__c = false;
        update c;

        // --- Passage Work in progress → Preview ---
        c = [SELECT Id, Status FROM Case WHERE Id = :c.Id];
        c.Status = 'Preview';
        update c;

        // --- Passage Preview → Validated ---
        c = [SELECT Id, Status FROM Case WHERE Id = :c.Id];
        c.Status = 'Validated';
        update c;
        
        c = [SELECT Id, Status FROM Case WHERE Id = :c.Id];
        c.Status = 'Work in progress';
        update c;
        
         // --- Passage New → Validated ---
        c = [SELECT Id, Status FROM Case WHERE Id = :c.Id];
        c.Status = 'Validated';
        update c;
        
        Test.stopTest();

        // Vérifications finales
        Case result = [
            SELECT
                TECHNewDate__c,
                TECHWorkinProgressDate__c,
                TECHPreviewDate__c,
                ValidationDate__c,
                OnHoldDuration__c,
                NewtoWorkinProgressDuration__c,
                WorkinProgresstoPreviewDuration__c,
                PreviewtoValidationDuration__c
            FROM Case
            WHERE Id = :c.Id
        ];

       
        System.assert(
            result.NewtoWorkinProgressDuration__c >= 0,
            'Durée New → Work in progress invalide'
        );

        System.assert(
            result.WorkinProgresstoPreviewDuration__c >= 0,
            'Durée Work in progress → Preview invalide'
        );

        System.assert(
            result.PreviewtoValidationDuration__c >= 0,
            'Durée Preview → Validated invalide'
        );
    }
}