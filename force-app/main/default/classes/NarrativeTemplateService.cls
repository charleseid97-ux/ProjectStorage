public without sharing class NarrativeTemplateService {

    private static final String TYPE_PRIIPS = 'PRIIPS';
    private static final String LANGUAGE_EN = 'EN';
    private static final String NARRATIVE_LANGUAGE_EN = 'English';
    private static final String NARRATIVE_SCOPE_PRODUCT = 'Product';

    // Crée ou met à jour les narratives PRIIPS correspondant aux risques des produits
    public static List<Narrative__c> buildRiskNarratives(List<Product__c> products) {
        List<Narrative__c> narrativesToUpsert = new List<Narrative__c>();

        if (products == null || products.isEmpty()) {
            return narrativesToUpsert;
        }

        // Prépare les templates indexés par Legal Form et Subtype
        Map<String, NarrativeTemplate__mdt> templatesByKey = getTemplatesByKey();
        Set<Id> productIds = new Set<Id>();

        for (Product__c product : products) {
            if (product.Id != null) {
                productIds.add(product.Id);
            }
        }

        // Charge les narratives existantes pour éviter les doublons
        Map<String, Narrative__c> existingNarrativesByKey =
            getExistingNarrativesByKey(productIds);

        Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c
            .getRecordTypeInfosByDeveloperName()
            .get('Narrative')
            .getRecordTypeId();

        // Construit une narrative par risque sélectionné sur chaque produit
        for (Product__c product : products) {
            if (product.Id == null
                || String.isBlank(product.LegalForm__c)
                || String.isBlank(product.RiskNotConsideredinIndicator__c)) {
                continue;
            }

            String legalForm = normalizeLegalForm(product.LegalForm__c);
            List<String> selectedRisks =
                product.RiskNotConsideredinIndicator__c.split(';');

            // Recherche le template correspondant à chaque risque sélectionné
            for (String selectedRisk : selectedRisks) {
                String subtype = selectedRisk.trim();
                String templateKey = buildTemplateKey(legalForm, subtype);
                NarrativeTemplate__mdt template = templatesByKey.get(templateKey);

                if (template == null) {
                    continue;
                }

                // Réutilise la narrative existante ou initialise une nouvelle narrative
                String narrativeKey = buildNarrativeKey(product.Id, subtype);
                Narrative__c narrative = existingNarrativesByKey.get(narrativeKey);

                if (narrative == null) {
                    narrative = new Narrative__c();
                    narrative.RecordTypeId = narrativeRecordTypeId;
                    narrative.Product__c = product.Id;
                    narrative.StartDate__c = System.today();
                }

                // Alimente les champs depuis le Custom Metadata
                narrative.Name = template.MasterLabel;
                narrative.Type__c = template.Type__c;
                narrative.SubType__c = template.Subtype__c;
                narrative.Language__c = NARRATIVE_LANGUAGE_EN;
                narrative.Content__c = template.Content__c;
                narrative.Narrative_Scope__c = NARRATIVE_SCOPE_PRODUCT;

                narrativesToUpsert.add(narrative);
            }
        }

        return narrativesToUpsert;
    }

    // Indexe les Custom Metadata PRIIPS anglais par Legal Form et Subtype
    private static Map<String, NarrativeTemplate__mdt> getTemplatesByKey() {
        Map<String, NarrativeTemplate__mdt> templatesByKey =
            new Map<String, NarrativeTemplate__mdt>();

        for (NarrativeTemplate__mdt template :
            NarrativeTemplate__mdt.getAll().values()) {
            if (template.Type__c != TYPE_PRIIPS
                || template.Language__c != LANGUAGE_EN) {
                continue;
            }

            String legalForm = normalizeLegalForm(template.LegalForm__c);
            String key = buildTemplateKey(legalForm, template.Subtype__c);
            templatesByKey.put(key, template);
        }

        return templatesByKey;
    }

    // Charge les narratives PRIIPS existantes pour les produits traités
    private static Map<String, Narrative__c> getExistingNarrativesByKey(
        Set<Id> productIds
    ) {
        Map<String, Narrative__c> narrativesByKey =
            new Map<String, Narrative__c>();

        if (productIds.isEmpty()) {
            return narrativesByKey;
        }

        // Limite la recherche aux subtypes gérés par les templates
        Set<String> templateSubtypes = new Set<String>();
        for (NarrativeTemplate__mdt template :
            NarrativeTemplate__mdt.getAll().values()) {
            if (template.Type__c == TYPE_PRIIPS
                && template.Language__c == LANGUAGE_EN) {
                templateSubtypes.add(template.Subtype__c);
            }
        }

        // Indexe les narratives existantes par produit et subtype
        for (Narrative__c narrative : [
            SELECT Id, Product__c, SubType__c
            FROM Narrative__c
            WHERE Product__c IN :productIds
            AND Type__c = :TYPE_PRIIPS
            AND SubType__c IN :templateSubtypes
        ]) {
            String key = buildNarrativeKey(
                narrative.Product__c,
                narrative.SubType__c
            );
            narrativesByKey.put(key, narrative);
        }

        return narrativesByKey;
    }

    // Normalise SICAV et ICAV vers la valeur utilisée dans le Custom Metadata
    private static String normalizeLegalForm(String legalForm) {
        if (String.isBlank(legalForm)) {
            return null;
        }

        String normalizedLegalForm = legalForm.trim();

        if (normalizedLegalForm == 'SICAV'
            || normalizedLegalForm == 'ICAV'
            || normalizedLegalForm == 'SICAV/ICAV') {
            return 'SICAV/ICAV';
        }

        return normalizedLegalForm;
    }

    // Construit la clé de recherche d'un template
    private static String buildTemplateKey(
        String legalForm,
        String subtype
    ) {
        return legalForm + '|' + subtype.trim().toLowerCase();
    }

    // Construit la clé d'unicité d'une narrative produit
    private static String buildNarrativeKey(
        Id productId,
        String subtype
    ) {
        return String.valueOf(productId)
            + '|'
            + subtype.trim().toLowerCase();
    }
}