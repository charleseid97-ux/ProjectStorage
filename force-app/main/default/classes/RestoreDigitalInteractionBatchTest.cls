@IsTest
private class RestoreDigitalInteractionBatchTest {

    // Vérifie la logique d'undelete sans dépendre des champs obligatoires de Digital_Interaction__c.
    @IsTest
    static void restoresDeletedRecordsWhenExecuteIsCalled() {
        Account acc = new Account(Name = 'RestoreDigitalInteractionBatchTest');
        insert acc;
        delete acc;

        Account deletedAcc = [
            SELECT Id, IsDeleted
            FROM Account
            WHERE Id = :acc.Id
            ALL ROWS
        ];
        System.assertEquals(true, deletedAcc.IsDeleted, 'Le record de test doit être supprimé avant l\'undelete.');

        RestoreDigitalInteractionBatch batch = new RestoreDigitalInteractionBatch();

        Test.startTest();
        batch.execute(null, new List<SObject>{ deletedAcc });
        Test.stopTest();

        Account restoredAcc = [
            SELECT Id, IsDeleted
            FROM Account
            WHERE Id = :acc.Id
            ALL ROWS
        ];
        System.assertEquals(false, restoredAcc.IsDeleted, 'Le record de test doit être restauré.');
        System.assertEquals(1, batch.successCount, 'Le compteur succès doit être incrémenté.');
        System.assertEquals(0, batch.errorCount, 'Aucune erreur ne doit être comptée.');
    }

    // Vérifie que le batch démarre correctement avec la QueryLocator cible.
    @IsTest
    static void batchCanBeStarted() {
        Test.startTest();
        Id jobId = Database.executeBatch(new RestoreDigitalInteractionBatch(), 200);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Le job batch doit être créé.');
    }
}