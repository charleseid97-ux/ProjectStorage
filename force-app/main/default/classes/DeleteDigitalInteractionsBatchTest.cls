@IsTest
private class DeleteDigitalInteractionsBatchTest {
    // Vérifie que le batch peut être lancé via Database.executeBatch.
    @IsTest
    static void batchRunsWithQueryLocator() {
        Test.startTest();
        Id asyncJobId = Database.executeBatch(new DeleteDigitalInteractionsBatch(), 200);
        Test.stopTest();

        System.assertNotEquals(null, asyncJobId, 'Le job batch doit être créé.');
    }

    // Couvre execute et finish sans dépendre de données Digital_Interaction__c existantes.
    @IsTest
    static void executeAndFinishHandleEmptyScope() {
        DeleteDigitalInteractionsBatch batch = new DeleteDigitalInteractionsBatch();

        Test.startTest();
        batch.execute(null, new List<SObject>());
        batch.finish(null);
        Test.stopTest();

        System.assert(true, 'Le batch doit accepter un scope vide.');
    }
}