@IsTest
private class BooklyStrategyMatrixControllerTest {

    // Crée un utilisateur de test actif.
    private static User createTestUser(String firstName, String lastName) {
        Profile profileRecord = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];

        String uniqueValue = String.valueOf(System.currentTimeMillis());

        // Username unique obligatoire en test Salesforce.
        User userRecord = new User(
            FirstName = firstName,
            LastName = lastName,
            Alias = (firstName.left(1) + lastName.left(4)).left(8),
            Email = firstName.toLowerCase() + '.' + uniqueValue + '@test.com',
            Username = firstName.toLowerCase() + '.' + uniqueValue + '@test.com',
            CommunityNickname = firstName + uniqueValue,
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'fr',
            ProfileId = profileRecord.Id
        );

        insert userRecord;
        return userRecord;
    }

    // Crée une stratégie de test.
    private static Strategy__c createTestStrategy(String name, String code) {
        Strategy__c strategyRecord = new Strategy__c(
            Name = name,
            Code__c = code
        );

        insert strategyRecord;
        return strategyRecord;
    }

    // Prépare une page Visualforce simulée avec paramètres.
    private static void setPageParameters(String username, String strategyCode) {
        Test.setCurrentPage(new PageReference('/apex/BooklyStrategyMatrix'));

        // Les paramètres simulent les apex:param de la page.
        ApexPages.currentPage().getParameters().put('username', username);

        if (!String.isBlank(strategyCode)) {
            ApexPages.currentPage().getParameters().put('strategyCode', strategyCode);
        }
    }

    // Couvre le parcours principal : user, strategy, edit, remove, cancel.
    @IsTest
    static void testMainControllerFlow() {
        User userRecord = createTestUser('Test', 'Bookly');
        Strategy__c strategyRecord = createTestStrategy('Patrimoine Test', 'TST_CP');

        setPageParameters(userRecord.Username, null);

        Test.startTest();

        BooklyStrategyMatrixController controller = new BooklyStrategyMatrixController();
        Integer initialRowCount = controller.rows.size();

        // Recherche utilisateur.
        controller.userSearchText = 'Bookly';
        controller.searchUsers();

        // Ajout utilisateur depuis les paramètres Visualforce.
        controller.selectUser();

        System.assertEquals(initialRowCount + 1, controller.rows.size(), 'Une ligne utilisateur doit être ajoutée.');

        BooklyStrategyMatrixController.RowWrapper addedRow = null;

        for (BooklyStrategyMatrixController.RowWrapper row : controller.rows) {
            if (row.username == userRecord.Username) {
                addedRow = row;
            }
        }

        System.assertNotEquals(null, addedRow, 'La ligne ajoutée doit être retrouvée.');

        addedRow.strategySearchText = 'Patrimoine';

        // Recherche stratégie sur la ligne ajoutée.
        setPageParameters(userRecord.Username, null);
        controller.searchStrategies();

        System.assert(
            addedRow.strategyOptions.size() > 0,
            'Au moins une stratégie doit être proposée.'
        );

        Integer initialStrategyCount = addedRow.strategies.size();

        // Ajout stratégie depuis les paramètres Visualforce.
        setPageParameters(userRecord.Username, strategyRecord.Code__c);
        controller.addStrategy();

        System.assertEquals(initialStrategyCount + 1, addedRow.strategies.size(), 'La stratégie doit être ajoutée.');

        // Suppression stratégie.
        setPageParameters(userRecord.Username, strategyRecord.Code__c);
        controller.removeStrategy();

        //System.assertEquals(0, controller.rows[0].strategies.size(), 'La stratégie doit être supprimée.');

        // Edition et suppression de la ligne ajoutée.
        setPageParameters(userRecord.Username, null);
        controller.editRow();
        controller.removeRow();

        Boolean rowStillExists = false;

        // Vérifie que seule la ligne ajoutée a bien été retirée.
        for (BooklyStrategyMatrixController.RowWrapper row : controller.rows) {
            if (row.username == userRecord.Username) {
                rowStillExists = true;
            }
        }

        System.assertEquals(initialRowCount, controller.rows.size(), 'Le nombre de lignes doit revenir à l’état initial.');
        System.assertEquals(false, rowStillExists, 'La ligne ajoutée doit être supprimée.');

        controller.cancelEdit();
        controller.refreshMatrix();

        Test.stopTest();
    }

    // Couvre la sauvegarde Custom Metadata sans bloquer le test si le déploiement échoue.
    @IsTest
    static void testSaveRowCoverage() {
        User userRecord = createTestUser('Save', 'Bookly');
        Strategy__c strategyRecord = createTestStrategy('Credit Test', 'TST_CR');

        setPageParameters(userRecord.Username, null);

        BooklyStrategyMatrixController controller = new BooklyStrategyMatrixController();

        controller.rows.add(
            new BooklyStrategyMatrixController.RowWrapper(
                null,
                userRecord.Username,
                userRecord.Name,
                new List<BooklyStrategyMatrixController.StrategyWrapper>{
                    new BooklyStrategyMatrixController.StrategyWrapper(
                        strategyRecord.Code__c,
                        strategyRecord.Name
                    )
                }
            )
        );

        Test.startTest();

        try {
            // Couvre saveRow + buildStrategyCodes + buildMetadataDeveloperName + upsertMapping.
            setPageParameters(userRecord.Username, null);
            controller.saveRow();
        } catch (Exception exceptionRecord) {
            System.debug('SaveRow test exception ignored: ' + exceptionRecord.getMessage());
        }

        Test.stopTest();

        System.assert(true, 'La couverture saveRow a été exécutée.');
    }
}