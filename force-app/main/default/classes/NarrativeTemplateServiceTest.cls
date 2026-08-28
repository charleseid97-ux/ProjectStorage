@IsTest
private class NarrativeTemplateServiceTest {

    // Récupère un template actif correspondant à la Legal Form demandée
    private static NarrativeTemplate__mdt getTemplate(String legalForm) {
        for (NarrativeTemplate__mdt template :
            NarrativeTemplate__mdt.getAll().values()) {
            if (template.Type__c == 'PRIIPS'
                && template.Language__c == 'EN'
                && template.LegalForm__c == legalForm) {
                return template;
            }
        }

        System.assert(false, 'Aucun NarrativeTemplate__mdt trouvé pour ' + legalForm);
        return null;
    }

    // Crée un produit avec les données nécessaires à la génération de narrative
    private static Product__c createProduct(
        String legalForm,
        String selectedRisk
    ) {
        Product__c product = new Product__c();

        // Renseigne Name uniquement lorsqu'il n'est pas auto-numéroté
        if (!Product__c.Name.getDescribe().isAutoNumber()) {
            product.Name = 'Narrative Template Test';
        }

        product.LegalForm__c = legalForm;
        product.RiskNotConsideredinIndicator__c = selectedRisk;
        insert product;

        return product;
    }

    // Vérifie qu'une narrative FCP est construite depuis le Custom Metadata
    @IsTest
    static void buildRiskNarrativesCreatesFcpNarrative() {
        NarrativeTemplate__mdt template = getTemplate('FCP');
        Product__c product = createProduct(
            'FCP',
            template.Subtype__c
        );

        Test.startTest();
        List<Narrative__c> narratives =
            NarrativeTemplateService.buildRiskNarratives(
                new List<Product__c>{ product }
            );
        Test.stopTest();

        // Vérifie les informations issues du produit et du template
        System.assertEquals(1, narratives.size());

        Narrative__c narrative = narratives[0];
        System.assertEquals(null, narrative.Id);
        System.assertEquals(product.Id, narrative.Product__c);
        System.assertEquals(template.MasterLabel, narrative.Name);
        System.assertEquals(template.Type__c, narrative.Type__c);
        System.assertEquals(template.Subtype__c, narrative.SubType__c);
        System.assertEquals('English', narrative.Language__c);
        System.assertEquals(template.Content__c, narrative.Content__c);
        System.assertEquals('Product', narrative.Narrative_Scope__c);
        System.assertEquals(Date.today(), narrative.StartDate__c);
    }

    // Vérifie que SICAV utilise les templates configurés pour SICAV/ICAV
    @IsTest
    static void buildRiskNarrativesNormalizesSicavLegalForm() {
        NarrativeTemplate__mdt template = getTemplate('SICAV/ICAV');
        Product__c product = createProduct(
            'SICAV',
            template.Subtype__c
        );

        Test.startTest();
        List<Narrative__c> narratives =
            NarrativeTemplateService.buildRiskNarratives(
                new List<Product__c>{ product }
            );
        Test.stopTest();

        // Le template SICAV/ICAV doit être retrouvé avec Legal Form SICAV
        System.assertEquals(1, narratives.size());
        System.assertEquals(product.Id, narratives[0].Product__c);
        System.assertEquals(template.Subtype__c, narratives[0].SubType__c);
        System.assertEquals(template.Content__c, narratives[0].Content__c);
    }

    // Vérifie qu'une narrative existante est réutilisée au lieu d'être dupliquée
    @IsTest
    static void buildRiskNarrativesUpdatesExistingNarrative() {
        NarrativeTemplate__mdt template = getTemplate('FCP');
        Product__c product = createProduct(
            'FCP',
            template.Subtype__c
        );

        Id recordTypeId = Schema.SObjectType.Narrative__c
            .getRecordTypeInfosByDeveloperName()
            .get('Narrative')
            .getRecordTypeId();

        // Insère une narrative existante avec un contenu devenu obsolète
        Narrative__c existingNarrative = new Narrative__c(
            RecordTypeId = recordTypeId,
            Name = 'Existing Narrative',
            Product__c = product.Id,
            Type__c = 'PRIIPS',
            SubType__c = template.Subtype__c,
            Language__c = 'English',
            Content__c = 'Old content',
            Narrative_Scope__c = 'Product',
            StartDate__c = Date.today()
        );
        insert existingNarrative;

        Test.startTest();
        List<Narrative__c> narratives =
            NarrativeTemplateService.buildRiskNarratives(
                new List<Product__c>{ product }
            );
        Test.stopTest();

        // La narrative retournée doit conserver l'identifiant existant
        System.assertEquals(1, narratives.size());
        System.assertEquals(existingNarrative.Id, narratives[0].Id);
        System.assertEquals(template.Content__c, narratives[0].Content__c);
        System.assertEquals(template.MasterLabel, narratives[0].Name);
    }

    // Vérifie les entrées vides et les produits incomplets
    @IsTest
    static void buildRiskNarrativesIgnoresInvalidInputs() {
        Product__c incompleteProduct = new Product__c();

        Test.startTest();
        List<Narrative__c> nullResult =
            NarrativeTemplateService.buildRiskNarratives(null);
        List<Narrative__c> emptyResult =
            NarrativeTemplateService.buildRiskNarratives(
                new List<Product__c>()
            );
        List<Narrative__c> incompleteResult =
            NarrativeTemplateService.buildRiskNarratives(
                new List<Product__c>{ incompleteProduct }
            );
        Test.stopTest();

        // Aucune narrative ne doit être générée
        System.assertEquals(0, nullResult.size());
        System.assertEquals(0, emptyResult.size());
        System.assertEquals(0, incompleteResult.size());
    }
}