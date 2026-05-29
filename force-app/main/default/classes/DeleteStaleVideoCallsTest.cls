@IsTest
public class DeleteStaleVideoCallsTest {

    // Test de la suppression des VideoCall éligibles
    @IsTest
    static void testBatchDeletesEligibleVideoCalls() {

        // Création d’un VideoCall non enregistré et sans note associée
        // Remplir les champs obligatoires identifiés sur VideoCall
        VideoCall vcToDelete = new VideoCall(
            Name = 'VC To Delete',
            VendorMeetingKey = 'vendor_key_del_1',
            IsRecorded = false
        );
        insert vcToDelete;

        // Création d’un VideoCall non enregistré avec une note associée
        // Remplir les champs obligatoires identifiés sur VideoCall
        VideoCall vcWithNote = new VideoCall(
            Name = 'VC With Note',
            VendorMeetingKey = 'vendor_key_note_1',
            IsRecorded = false
        );
        insert vcWithNote;

        // Création d’une Meeting Note liée au second VideoCall
        // Remplir les champs obligatoires identifiés sur Meeting_Note__c, y compris Date__c
        Meeting_Note__c note = new Meeting_Note__c(
            VideoCall__c = vcWithNote.Id,
            Date__c = Date.today().addDays(-1)
        );
        insert note;

        // Modification de la date de création pour rendre les VideoCall éligibles (> 3 heures)
        Test.setCreatedDate(vcToDelete.Id, System.now().addHours(-4));
        Test.setCreatedDate(vcWithNote.Id, System.now().addHours(-4));

        // Exécution du batch dans le contexte de test
        Test.startTest();
        Database.executeBatch(new DeleteStaleVideoCalls(), 200);
        Test.stopTest();

        // Vérification que le VideoCall sans note a été supprimé
        Integer deletedCount = [
            SELECT COUNT()
            FROM VideoCall
            WHERE Id = :vcToDelete.Id
        ];
        System.assertEquals(0, deletedCount);

        // Vérification que le VideoCall avec note n’a pas été supprimé
        Integer remainingCount = [
            SELECT COUNT()
            FROM VideoCall
            WHERE Id = :vcWithNote.Id
        ];
        System.assertEquals(1, remainingCount);
    }

    // Test de l’exécution via l’interface Schedulable
    @IsTest
    static void testSchedulableExecution() {

        // Expression CRON valide positionnée dans le futur
        String cronExp = '0 0 0 1 1 ? 2050';

        // Planification du batch dans un contexte de test
        Test.startTest();
        System.schedule(
            'DeleteStaleVideoCalls_Test_Job',
            cronExp,
            new DeleteStaleVideoCalls()
        );
        Test.stopTest();

        // Vérification qu’un job planifié a bien été créé
        List<CronTrigger> jobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'DeleteStaleVideoCalls_Test_Job'
        ];
        System.assertEquals(1, jobs.size());
    }
}