public class ProjectProductBatchController {

    private static final Set<String> EXCLUDED_FIELDS = new Set<String>{ 'Name' };

    // =========================
    // Sonar constants (no duplicated literals)
    // =========================
    private static final String NAME_PRIIPS_SC_INVESTMENT_OBJECTIVE = 'PRIIPs Share Class Investment Objective';
    private static final String NAME_PRIIPS_PERF_FEE_UCITS_KIID      = 'PRIIPs Performance fee UCITS KIID';
    private static final String NAME_PRIIPS_PERF_FEE_EPT_KID         = 'PRIIPs Performance fee EPT/KID';

    private static final String SUBTYPE_PERF_FEE_EPT_KID             = 'Performance_fee_EPT/KID';
    private static final String SUBTYPE_PERF_FEE_UCITS_KIID          = 'Performance_fee_UCITS_KIID';
    private static final String SUBTYPE_SC_INV_OBJ                   = 'Share_Class_Investment_Objective';

    private static final String LOG_UPSERT                           = '[UPSERT] ';
    private static final String LOG_UPSERTED_TYPE                     = '[UPSERTED] Type: ';
    private static final String LOG_ERROR                             = '[ERROR] ';
    private static final String LOG_UPSERTS_FAILED_SUFFIX             = ' upserts failed.';

    public static Boolean canProcessProjectProduct(ProjectProduct__c pp, List<String> debugInformation, List<String> errorMessages) {
        Boolean isValid = true;

        // Condition : Milestone "Launch Date" = Completed
        Boolean milestoneCompleted = false;
        if (pp.Milestones__r != null && !pp.Milestones__r.isEmpty()) {
            milestoneCompleted = (pp.Milestones__r[0].Status__c == 'Completed');
        }

        // Condition: Tous les Project_Product_Childs__r.Status__c = Completed
        // On requête dans la query avant le execute, si la liste est vide c'est que tout les records sont completed --> (SELECT Id, Status__c FROM Project_Product_Childs__r WHERE Status__c != 'Completed')
        Boolean allChildCompleted = true;
        if (pp.Project_Product_Childs__r != null && !pp.Project_Product_Childs__r.isEmpty()) {
            allChildCompleted = false;
        }

        if (!milestoneCompleted) {
            String msg = LOG_ERROR + 'ProjectProduct ' + pp.Id + ' Milestone "Launch Date" not Completed.';
            debugInformation.add(msg);
            errorMessages.add(msg);
            isValid = false;
        }

        if (!allChildCompleted) {
            System.debug('pp.Project_Product_Childs__r:' + pp.Project_Product_Childs__r);
            String msg = LOG_ERROR + 'ProjectProduct ' + pp.Id + ' has incomplete Project Product Childs.';
            debugInformation.add(msg);
            errorMessages.add(msg);
            isValid = false;
        }

        if (isValid) {
            debugInformation.add('[CHECK PASSED] ProjectProduct ' + pp.Id + ' ready for processing.');
        } else {
            debugInformation.add('[SKIP] ProjectProduct ' + pp.Id + ' will not be processed.');
        }

        return isValid;
    }

    public static void createFundShareclass(List<ProjectProduct__c> listFundCreation, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed, List<Id> insertedRecords) {
        debugInformation.add('[INIT] Fund/Shareclass creation - ' + listFundCreation.size() + ' ProjectProduct(s) to process.');
        Savepoint sp = Database.setSavepoint();
        try {
            Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
            List<ProjectProduct__c> listProjectProductWFields = ProjectProductBatchUtilities.getProjectProduct(listFundCreation);

            List<Share_Class__c> listNewShareClass = new List<Share_Class__c>();
            List<Product__c> listNewProduct = new List<Product__c>();
            List<FundManagerAssignment__c> listFundManagerAssignmentToUpdate = new List<FundManagerAssignment__c>();
            List<Narrative__c> listNarrative = new List<Narrative__c>();
            Map<Id, Product__c> mapProjectByProductId = new Map<Id, Product__c>();

            if (listProjectProductWFields == null || listProjectProductWFields.isEmpty()) {
                String msg = LOG_ERROR + 'No ProjectProduct enriched. Skipping creation.';
                errorMessages.add(msg);
                debugInformation.add(msg);
                recordsFailed[0]++;
                return;
            }

            for (ProjectProduct__c projectProduct : listProjectProductWFields) {
                Product__c newProduct = ProjectProductBatchUtilities.getNewProduct(projectProduct);
                newProduct.ParentProject__c = projectProduct.Id;
                newProduct.RecordTypeId = fundRecordTypeId;
                newProduct.LaunchDate__c = projectProduct.EndDate__c;
                newProduct.Name = projectProduct.InternalShortName__c;
                newProduct.Validity__c = true;
                listNewProduct.add(newProduct);
                mapProjectByProductId.put(projectProduct.Id, newProduct);

                debugInformation.add('[PREPARE] Product initialized for ProjectProduct ' + projectProduct.Id);
            }
            Map<Id, Product__c> insertedProducts = new Map<Id, Product__c>();
            if (!listNewProduct.isEmpty()) {
                ProjectProductBatchUtilities.UpsertDebugResult result = ProjectProductBatchUtilities.logUpsertResults(listNewProduct);
                for (SObject sObj : result.successRecords.values()) {
                    Product__c prod = (Product__c) sObj;
                    insertedProducts.put(prod.Id, prod);
                    insertedRecords.add(prod.Id);
                    debugInformation.add('[SUCCESS] Product inserted: ' + prod.Name + ' (Id: ' + prod.Id + ')');
                }
                for (String err : result.errorMap.values()) {
                    errorMessages.add(LOG_ERROR + 'Product insert failed: ' + err);
                    recordsFailed[0]++;
                    throw new DmlException(LOG_ERROR + 'Product insert failed: ' + err);
                }
            }

            Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName().get('Narrative').getRecordTypeId();

            for (ProjectProduct__c projectProduct : listProjectProductWFields) {
                Product__c insertedProduct = mapProjectByProductId.get(projectProduct.Id);
                if (insertedProduct == null || !insertedProducts.containsKey(insertedProduct.Id)) {
                    String msg = '[SKIP] Product creation failed for ProjectProduct ' + projectProduct.Id + ' → skipping related records.';
                    debugInformation.add(msg);
                    errorMessages.add(msg);
                    recordsFailed[0]++;
                    continue;
                }

                Id productId = insertedProduct.Id;

                for (ProjectShareclass__c sc : projectProduct.ProjectShareclasses__r) {
                    Share_Class__c newSC = ProjectProductBatchUtilities.getNewShareclass(sc, productId);
                    newSC.LaunchDate__c = projectProduct.EndDate__c;
                    newSC.Name = sc.Share_Class_Name__c;
                    newSC.ProjectShareclass__c = sc.Id;
                    Decimal mgmtFees = sc.EffectiveManagementFees__c != null ? sc.EffectiveManagementFees__c : 0;
                    Decimal serviceFees = sc.EffectiveServiceFees__c != null ? sc.EffectiveServiceFees__c : 0;

                    newSC.OngoingCostsExante__c = mgmtFees + serviceFees;
                    listNewShareClass.add(newSC);
                    debugInformation.add('[PREPARE] Shareclass from ProjectShareclass ' + sc.Id + ' prepared.');
                }

                for (FundManagerAssignment__c fma : projectProduct.Fund_Manager_Assignments__r) {
                    fma.Product__c = productId;
                    fma.StartDate__c = projectProduct.EndDate__c;
                    listFundManagerAssignmentToUpdate.add(fma);
                    debugInformation.add('[PREPARE] Fund Manager Assignment linked to product ' + productId);
                }

                // THIRD PARTIES
                for (Narrative__c projectThirdParty : projectProduct.Narratives__r) {
                    projectThirdParty.Product__c = productId;
                    listNarrative.add(projectThirdParty);
                }

                List<Narrative__c> autoNarratives = ProjectProductBatchUtilities.createNarratives(
                    projectProduct,
                    narrativeRecordTypeId,
                    projectProduct.DomiciledIn__c == 'FR' ? 'French' : 'English',
                    productId
                );
                listNarrative.addAll(autoNarratives);
            }

            Map<Id, Id> mapProjSCIdToSCId = new Map<Id, Id>(); // ProjectShareclass__c.Id -> Share_Class__c.Id

            if (!listNewShareClass.isEmpty()) {
                ProjectProductBatchUtilities.UpsertDebugResult scResult =
                    ProjectProductBatchUtilities.logUpsertResults(listNewShareClass);

                // succès : construire le mapping PSC -> SC
                for (SObject sObj : scResult.successRecords.values()) {
                    Share_Class__c sc = (Share_Class__c) sObj;
                    Id projScId = (Id) sc.get('ProjectShareclass__c');
                    if (projScId != null) {
                        mapProjSCIdToSCId.put(projScId, sc.Id);
                    }
                    insertedRecords.add(sc.Id);

                    debugInformation.add('[SUCCESS] Shareclass inserted: ' + sc.Id + ' (from ProjectShareclass ' + projScId + ')');
                }

                // erreurs : log + compteur
                for (String err : scResult.errorMap.values()) {
                    errorMessages.add(LOG_ERROR + 'Shareclass insert failed: ' + err);
                    recordsFailed[0]++;
                    throw new DmlException(LOG_ERROR + 'Shareclass insert failed: ' + err);
                }
            }

            List<Narrative__c> priipsShareclassNarratives = new List<Narrative__c>();
            List<TaxData__c> taxDataToUpdate = new List<TaxData__c>();

            for (ProjectProduct__c projectProduct : listProjectProductWFields) {
                Product__c insertedProduct = mapProjectByProductId.get(projectProduct.Id);

                if (insertedProduct == null) {
                    errorMessages.add(LOG_ERROR + 'Missing Product for ProjectProduct ' + projectProduct.Id);
                    recordsFailed[0]++;
                    continue;
                }

                Id productId = insertedProduct.Id;
                String language = (projectProduct.DomiciledIn__c == 'FR') ? 'French' : 'English';

                if (projectProduct.ProjectShareclasses__r == null) continue;

                for (ProjectShareclass__c psc : projectProduct.ProjectShareclasses__r) {
                    // retrouver l'Id de la Share_Class créée pour ce ProjectShareclass
                    Id scId = mapProjSCIdToSCId.get(psc.Id);
                    if (scId == null && psc.TECH_ShareClass__c != null) {
                        try { scId = Id.valueOf(psc.TECH_ShareClass__c); } catch (Exception e) {}
                    }
                    if (scId == null) {
                        errorMessages.add(LOG_ERROR + 'Missing Share_Class__c Id for ProjectShareclass ' + psc.Id);
                        recordsFailed[0]++;
                        continue;
                    }

                    // 1 Narrative par champ RTF non vide
                    addSCNarrativeIfNotBlank(
                        priipsShareclassNarratives, NAME_PRIIPS_SC_INVESTMENT_OBJECTIVE,
                        narrativeRecordTypeId, 'PRIIPs', SUBTYPE_SC_INV_OBJ,
                        language, productId, scId, psc.ShareclassInvestmentObjective__c
                    );
                    addSCNarrativeIfNotBlank(
                        priipsShareclassNarratives, NAME_PRIIPS_PERF_FEE_UCITS_KIID,
                        narrativeRecordTypeId, 'PRIIPs', SUBTYPE_PERF_FEE_UCITS_KIID,
                        language, productId, scId, psc.PerformanceFeeUCITSKIID__c
                    );
                    addSCNarrativeIfNotBlank(
                        priipsShareclassNarratives, NAME_PRIIPS_PERF_FEE_EPT_KID,
                        narrativeRecordTypeId, 'PRIIPs', SUBTYPE_PERF_FEE_EPT_KID,
                        language, productId, scId, psc.PerformanceFeeEPTKID__c
                    );
                }

                if (projectProduct.Tax_Data__r == null) continue;
                for (TaxData__c td : projectProduct.Tax_Data__r) {
                    if (td.Product__c == null) {
                        td.Product__c = productId;
                    }
                    if (td.ShareClass__c == null) {
                        td.ShareClass__c = mapProjSCIdToSCId.get(td.ProjectShareclass__c);
                    }
                    taxDataToUpdate.add(td);
                }
            }

            List<SObject> toUpsert = new List<SObject>();
            toUpsert.addAll(priipsShareclassNarratives);
            toUpsert.addAll(listFundManagerAssignmentToUpdate);
            toUpsert.addAll(listNarrative);
            toUpsert.addAll(taxDataToUpdate);

            if (!toUpsert.isEmpty()) {
                ProjectProductBatchUtilities.UpsertDebugResult result = ProjectProductBatchUtilities.logUpsertResults(toUpsert);
                debugInformation.add(LOG_UPSERT + result.successRecords.size() + ' records upserted.');
                for (SObject currentSObject : result.successRecords.values()) {
                    String objectType = currentSObject.getSObjectType().getDescribe().getName();
                    insertedRecords.add((String) currentSObject.get('Id'));

                    debugInformation.add(LOG_UPSERTED_TYPE + objectType + ' (Id: ' + currentSObject.get('Id') + ')');
                }
                if (!result.errorMap.isEmpty()) {
                    errorMessages.add(LOG_ERROR + result.errorMap.size() + LOG_UPSERTS_FAILED_SUFFIX);
                    for (String err : result.errorMap.values()) {
                        errorMessages.add(err);
                        recordsFailed[0]++;
                        throw new DmlException(LOG_ERROR + result.errorMap.size() + LOG_UPSERTS_FAILED_SUFFIX);
                    }
                }
            }

            debugInformation.add('[END] Fund/Shareclass creation complete.');
        } catch (Exception e) {
            Database.rollback(sp);
            errorMessages.add(LOG_ERROR + 'Exception: ' + e.getMessage());
            recordsFailed[0]++;
            debugInformation.add('----------------------------------');
            debugInformation.add('[ROLLBACK] ⚠️ Transaction rolled back. Previous logs invalid.');
            debugInformation.add('[ROLLBACK] Reason: ' + e.getMessage());
        }
    }

    public static void updateFundShareclassModification(
        List<ProjectProduct__c> listMods,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
        debugInformation.add('[INIT] Fund/Shareclass modification - ' + listMods.size() + ' ProjectProduct(s) to process.');
        Savepoint sp = Database.setSavepoint();

        try {
            List<Product__c> productsToUpdate = new List<Product__c>();
            List<Share_Class__c> shareclassesToUpdate = new List<Share_Class__c>();

            List<ProjectProduct__c> listWithFields = ProjectProductBatchUtilities.getProjectProduct(listMods);
            Map<Id, Product__c> productMap = ProjectProductBatchUtilities.getMapProductByProductId(listWithFields);
            Map<Id, Share_Class__c> shareclassMap = ProjectProductBatchUtilities.getMapShareClassByShareclassId(listWithFields);

            if (productMap == null) {
                errorMessages.add(LOG_ERROR + 'mapProductByProductId is null.');
                recordsFailed[0]++;
                return;
            }

            // --- Préparations pour les synchronisations de narratives ---
            Map<Id, String> mapInvObj = new Map<Id, String>();
            Map<Id, String> mapRisk = new Map<Id, String>();
            Map<Id, String> mapIntendedRetail = new Map<Id, String>();
            Map<Id, String> mapReasonForRHP = new Map<Id, String>();
            Map<Id, String> languageByProductId = new Map<Id, String>(); // ProductId -> Language ('French'|'English')

            // =====================
            // SHARECLASS NARRATIVES (PRIIPs) - single SOQL + single UPSERT
            // =====================
            Map<Id, String> scLangById = new Map<Id, String>(); // ShareClassId -> Language
            Map<Id, Id> productByScId = new Map<Id, Id>(); // ShareClassId -> ProductId (reporting)

            Map<Id, String> mapSCInvObj = new Map<Id, String>(); // ShareClassId -> content
            Map<Id, String> mapSCPerfUCITS = new Map<Id, String>();
            Map<Id, String> mapSCPerfEPT = new Map<Id, String>();

            for (ProjectProduct__c pp : listWithFields) {
                Product__c product = productMap.get(pp.Product__c);

                Id prodId = pp.Product__c;
                String lang = (pp.DomiciledIn__c == 'FR') ? 'French' : 'English';
                languageByProductId.put(prodId, lang);

                List<String> fieldsToModify = new List<String>();
                if (!String.isBlank(pp.TECH_FieldsToModify__c)) {
                    for (String f : pp.TECH_FieldsToModify__c.split(';')) {
                        if (f != null) fieldsToModify.add(f.trim());
                    }
                }

                if (fieldsToModify.contains('InvestmentObjective__c')) {
                    mapInvObj.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'InvestmentObjective__c'));
                }
                if (fieldsToModify.contains('RiskAssociated__c')) {
                    mapRisk.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'RiskAssociated__c'));
                }
                if (fieldsToModify.contains('IntentedRetailInvestor__c')) {
                    mapIntendedRetail.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'IntentedRetailInvestor__c'));
                }
                if (fieldsToModify.contains('ReasonForRHP__c')) {
                    mapReasonForRHP.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'ReasonForRHP__c'));
                }

                // Appliquer les modifications sur le Product (comme avant)
                for (String field : fieldsToModify) {
                    if (String.isBlank(field) || EXCLUDED_FIELDS.contains(field)) continue;
                    try {
                        product.put(field, pp.get(field));
                    } catch (Exception e) {
                        errorMessages.add(LOG_ERROR + 'Field skipped: ' + field + ' → ' + e.getMessage());
                        recordsFailed[0]++;
                    }
                }
                productsToUpdate.add(product);

                for (ProjectShareclass__c sc : pp.ProjectShareclasses__r) {
                    if (sc.TECH_ShareClass__c != null && shareclassMap.containsKey(Id.valueOf(sc.TECH_ShareClass__c))) {
                        Share_Class__c scToUpdate = shareclassMap.get(Id.valueOf(sc.TECH_ShareClass__c));

                        Id scId = scToUpdate.Id;

                        scLangById.put(scId, lang);
                        productByScId.put(scId, prodId);

                        Set<String> scFieldsToModify = new Set<String>();
                        if (!String.isBlank(sc.TECH_FieldsToModify__c)) {
                            for (String f : sc.TECH_FieldsToModify__c.split(';')) {
                                if (!String.isBlank(f)) scFieldsToModify.add(f.trim());
                            }
                        }
                        // 1) ShareClassInvestmentObjective__c
                        if (scFieldsToModify.contains('ShareclassInvestmentObjective__c') && !String.isBlank(sc.ShareclassInvestmentObjective__c)) {
                            mapSCInvObj.put(scId, sc.ShareclassInvestmentObjective__c);
                        }

                        // 2) PerformanceFeeUCITSKIID__c
                        if (scFieldsToModify.contains('PerformanceFeeUCITSKIID__c') && !String.isBlank(sc.PerformanceFeeUCITSKIID__c)) {
                            mapSCPerfUCITS.put(scId, sc.PerformanceFeeUCITSKIID__c);
                        }

                        // 3) PerformanceFeeEPTKID__c
                        if (scFieldsToModify.contains('PerformanceFeeEPTKID__c') && !String.isBlank(sc.PerformanceFeeEPTKID__c)) {
                            mapSCPerfEPT.put(scId, sc.PerformanceFeeEPTKID__c);
                        }

                        scToUpdate.ESMAApplicationStartDate__c = pp.EndDate__c;
                        if (!String.isEmpty(sc.TECH_FieldsToModify__c)) {
                            for (String field : sc.TECH_FieldsToModify__c.split(';')) {
                                try {
                                    scToUpdate.put(field, sc.get(field));
                                } catch (Exception e) {
                                    errorMessages.add(LOG_ERROR + 'Shareclass field skipped: ' + field + ' → ' + e.getMessage());
                                    recordsFailed[0]++;
                                }
                            }
                        }
                        shareclassesToUpdate.add(scToUpdate);
                    }
                }
            }

            // --- DML: Products ---
            if (!productsToUpdate.isEmpty()) {
                update productsToUpdate;
                debugInformation.add('[UPDATE] Products updated: ' + productsToUpdate.size());
            }

            // 2) Union des ProductIds à considérer
            Set<Id> prodIdsForNarratives = new Set<Id>();
            prodIdsForNarratives.addAll(mapInvObj.keySet());
            prodIdsForNarratives.addAll(mapRisk.keySet());
            prodIdsForNarratives.addAll(mapIntendedRetail.keySet());
            prodIdsForNarratives.addAll(mapReasonForRHP.keySet());

            if (!prodIdsForNarratives.isEmpty()) {
                // 3) RecordType Narrative
                Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c
                    .getRecordTypeInfosByDeveloperName().get('Narrative')
                    .getRecordTypeId();

                // 4) 1 seule query pour les 4 couples Type/SubType
                List<Narrative__c> existingNarratives = [
                    SELECT Id, Product__c, Language__c, Type__c, SubType__c, Content__c
                    FROM Narrative__c
                    WHERE Product__c IN :prodIdsForNarratives
                    AND (
                        (Type__c = 'Investment Objective' AND SubType__c = 'PRIIPS')
                        OR (Type__c = 'Risk'               AND SubType__c = 'Main Risk of the Fund')
                        OR (Type__c = 'PRIIPs'             AND SubType__c = 'INTENDED_RETAIL_INVESTOR')
                        OR (Type__c = 'PRIIPs'             AND SubType__c = 'REASON_FOR_PHP')
                    )
                ];

                // 5) Index existing par Product|Lang|Type|SubType
                Map<String, Narrative__c> existingByKey = new Map<String, Narrative__c>();
                for (Narrative__c n : existingNarratives) {
                    String key = ProjectProductBatchUtilities.narrativeKey(n.Product__c, n.Language__c, n.Type__c, n.SubType__c);
                    existingByKey.put(key, n);
                }

                // 6) Construire une SEULE liste globale à upsert
                List<Narrative__c> narrativesToUpsert = new List<Narrative__c>();

                narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
                    mapInvObj, languageByProductId, existingByKey,
                    'Investment Objective', 'PRIIPS', 'Investment Objective PRIIPS',
                    narrativeRecordTypeId, debugInformation
                ));

                narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
                    mapRisk, languageByProductId, existingByKey,
                    'Risk', 'Main Risk of the Fund', 'Risk Main Risk of the Fund',
                    narrativeRecordTypeId, debugInformation
                ));

                narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
                    mapIntendedRetail, languageByProductId, existingByKey,
                    'PRIIPs', 'INTENDED_RETAIL_INVESTOR', 'PRIIPs Intended Retail Investor',
                    narrativeRecordTypeId, debugInformation
                ));

                narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
                    mapReasonForRHP, languageByProductId, existingByKey,
                    'PRIIPs', 'REASON_FOR_PHP', 'PRIIPs Reason For PHP',
                    narrativeRecordTypeId, debugInformation
                ));

                // 7) 1 seul DML
                if (!narrativesToUpsert.isEmpty()) {
                    upsert narrativesToUpsert;
                    debugInformation.add(LOG_UPSERT + 'Narratives upserted (single DML): ' + narrativesToUpsert.size());
                }
            }

            // --- DML: Shareclasses ---
            if (!shareclassesToUpdate.isEmpty()) {
                update shareclassesToUpdate;
                debugInformation.add('[UPDATE] Shareclasses updated: ' + shareclassesToUpdate.size());
            }

            // Union des ShareClassIds concernés
            Set<Id> scIdsForNarratives = new Set<Id>();
            scIdsForNarratives.addAll(mapSCInvObj.keySet());
            scIdsForNarratives.addAll(mapSCPerfUCITS.keySet());
            scIdsForNarratives.addAll(mapSCPerfEPT.keySet());

            if (!scIdsForNarratives.isEmpty()) {
                Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c
                    .getRecordTypeInfosByDeveloperName().get('Narrative')
                    .getRecordTypeId();

                // 1 SOQL pour les 3 couples Type/SubType (PRIIPs)
                List<Narrative__c> existingSCNarratives = [
                    SELECT Id, ShareClass__c, Language__c, Type__c, SubType__c, Content__c, Product__c
                    FROM Narrative__c
                    WHERE ShareClass__c IN :scIdsForNarratives
                    AND Type__c = 'PRIIPs'
                    AND SubType__c IN ('Share_Class_Investment_Objective', 'Performance_fee_UCITS_KIID', 'Performance_fee_EPT/KID')
                ];

                Map<String, Narrative__c> existingByKey = new Map<String, Narrative__c>();
                for (Narrative__c n : existingSCNarratives) {
                    String key = ProjectProductBatchUtilities.scNarrativeKey(n.ShareClass__c, n.Language__c, n.Type__c, n.SubType__c);
                    existingByKey.put(key, n);
                }

                List<Narrative__c> narrativesToUpsert = new List<Narrative__c>();

                narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(
                    mapSCInvObj, productByScId, scLangById, existingByKey,
                    'PRIIPs', SUBTYPE_SC_INV_OBJ, NAME_PRIIPS_SC_INVESTMENT_OBJECTIVE,
                    narrativeRecordTypeId, debugInformation
                ));

                narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(
                    mapSCPerfUCITS, productByScId, scLangById, existingByKey,
                    'PRIIPs', SUBTYPE_PERF_FEE_UCITS_KIID, NAME_PRIIPS_PERF_FEE_UCITS_KIID,
                    narrativeRecordTypeId, debugInformation
                ));

                narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(
                    mapSCPerfEPT, productByScId, scLangById, existingByKey,
                    'PRIIPs', SUBTYPE_PERF_FEE_EPT_KID, NAME_PRIIPS_PERF_FEE_EPT_KID,
                    narrativeRecordTypeId, debugInformation
                ));

                if (!narrativesToUpsert.isEmpty()) {
                    upsert narrativesToUpsert; // ✅ 1 seul DML
                    debugInformation.add(LOG_UPSERT + '[SC] Narratives upserted (single DML): ' + narrativesToUpsert.size());
                }
            }

            debugInformation.add('[END] Fund/Shareclass modification complete.');

        } catch (Exception e) {
            Database.rollback(sp);
            errorMessages.add(LOG_ERROR + 'Exception: ' + e.getMessage());
            recordsFailed[0]++;
            debugInformation.add('----------------------------------');
            debugInformation.add('[ROLLBACK] ⚠️ Transaction rolled back. Previous logs invalid.');
            debugInformation.add('[ROLLBACK] Reason: ' + e.getMessage());
        }
    }

    public static void createShareclasses(List<ProjectProduct__c> listShareclassCreation, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed, List<Id> insertedRecords) {
        debugInformation.add('[INIT] Shareclass creation for ' + listShareclassCreation.size() + ' ProjectProduct(s).');
        Savepoint sp = Database.setSavepoint();
        try {

            List<Share_Class__c> listNewShareClass = new List<Share_Class__c>();
            List<ProjectProduct__c> projectProducts = ProjectProductBatchUtilities.getProjectProduct(listShareclassCreation);
            Map<Id, Product__c> productMap = ProjectProductBatchUtilities.getMapProductByProductId(projectProducts);

            for (ProjectProduct__c pp : projectProducts) {
                Product__c product = productMap.get(pp.Product__c);
                for (ProjectShareclass__c sc : pp.ProjectShareclasses__r) {
                    Share_Class__c newSC = ProjectProductBatchUtilities.getNewShareclass(sc, product.Id);
                    newSC.Name = sc.Share_Class_Name__c;
                    newSC.LaunchDate__c = pp.EndDate__c;
                    newSC.Status__c = 'Active';
                    newSC.OngoingCostsExante__c = sc.EffectiveManagementFees__c + sc.EffectiveServiceFees__c;
                    newSC.ProjectShareclass__c = sc.Id;
                    listNewShareClass.add(newSC);
                    debugInformation.add('[PREPARE] New Shareclass from ProjectShareclass: ' + sc.Id);
                }
            }
            Map<Id, Id> mapProjSCIdToSCId = new Map<Id, Id>();
            Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c
                .getRecordTypeInfosByDeveloperName().get('Narrative')
                .getRecordTypeId();

            if (!listNewShareClass.isEmpty()) {
                ProjectProductBatchUtilities.UpsertDebugResult result = ProjectProductBatchUtilities.logUpsertResults(listNewShareClass);
                debugInformation.add(LOG_UPSERT + result.successRecords.size() + ' Shareclasses created.');
                for (SObject currentSObject : result.successRecords.values()) {
                    Share_Class__c sc = (Share_Class__c) currentSObject;
                    Id projScId = (Id) sc.get('ProjectShareclass__c');
                    if (projScId != null) {
                        mapProjSCIdToSCId.put(projScId, sc.Id);
                    }

                    String objectType = currentSObject.getSObjectType().getDescribe().getName();
                    debugInformation.add(LOG_UPSERTED_TYPE + objectType + ' (Id: ' + currentSObject.get('Id') + ')');
                    insertedRecords.add((String) currentSObject.get('Id'));
                }
                for (String err : result.errorMap.values()) {
                    errorMessages.add(LOG_ERROR + 'Shareclass insert failed: ' + err);
                    recordsFailed[0]++;
                    throw new DmlException('Shareclass insert failed: ' + err);
                }
            }

            List<TaxData__c> taxDataToUpdate = new List<TaxData__c>();

            for (ProjectProduct__c pp : projectProducts) {
                Product__c product = productMap.get(pp.Product__c);

                if (pp.Tax_Data__r == null) continue;
                for (TaxData__c td : pp.Tax_Data__r) {
                    if (td.Product__c == null) {
                        td.Product__c = product.Id;
                    }
                    if (td.ShareClass__c == null) {
                        td.ShareClass__c = mapProjSCIdToSCId.get(td.ProjectShareclass__c);
                    }
                    taxDataToUpdate.add(td);
                }
            }

            List<Narrative__c> priipsShareclassNarratives = new List<Narrative__c>();

            for (ProjectProduct__c pp : projectProducts) {
                Product__c product = productMap.get(pp.Product__c);
                Id productId = product.Id;
                String language = (pp.DomiciledIn__c == 'FR') ? 'French' : 'English';

                for (ProjectShareclass__c psc : pp.ProjectShareclasses__r) {
                    // retrouver l'Id de la Share_Class créée pour ce ProjectShareclass
                    Id scId = mapProjSCIdToSCId.get(psc.Id);

                    addSCNarrativeIfNotBlank(
                        priipsShareclassNarratives, NAME_PRIIPS_SC_INVESTMENT_OBJECTIVE,
                        narrativeRecordTypeId, 'PRIIPs', SUBTYPE_SC_INV_OBJ,
                        language, productId, scId, psc.ShareclassInvestmentObjective__c
                    );
                    addSCNarrativeIfNotBlank(
                        priipsShareclassNarratives, NAME_PRIIPS_PERF_FEE_UCITS_KIID,
                        narrativeRecordTypeId, 'PRIIPs', SUBTYPE_PERF_FEE_UCITS_KIID,
                        language, productId, scId, psc.PerformanceFeeUCITSKIID__c
                    );
                    addSCNarrativeIfNotBlank(
                        priipsShareclassNarratives, NAME_PRIIPS_PERF_FEE_EPT_KID,
                        narrativeRecordTypeId, 'PRIIPs', SUBTYPE_PERF_FEE_EPT_KID,
                        language, productId, scId, psc.PerformanceFeeEPTKID__c
                    );
                }
            }

            List<SObject> toUpsert = new List<SObject>();
            toUpsert.addAll(priipsShareclassNarratives);
            toUpsert.addAll(taxDataToUpdate);

            if (!toUpsert.isEmpty()) {
                ProjectProductBatchUtilities.UpsertDebugResult result = ProjectProductBatchUtilities.logUpsertResults(toUpsert);
                debugInformation.add(LOG_UPSERT + result.successRecords.size() + ' records upserted.');
                for (SObject currentSObject : result.successRecords.values()) {
                    String objectType = currentSObject.getSObjectType().getDescribe().getName();
                    insertedRecords.add((String) currentSObject.get('Id'));

                    debugInformation.add(LOG_UPSERTED_TYPE + objectType + ' (Id: ' + currentSObject.get('Id') + ')');
                }
                if (!result.errorMap.isEmpty()) {
                    errorMessages.add(LOG_ERROR + result.errorMap.size() + LOG_UPSERTS_FAILED_SUFFIX);
                    for (String err : result.errorMap.values()) {
                        errorMessages.add(err);
                        recordsFailed[0]++;
                        throw new DmlException(LOG_ERROR + result.errorMap.size() + LOG_UPSERTS_FAILED_SUFFIX);
                    }
                }
            }

            debugInformation.add('[END] Shareclass creation complete.');
        } catch (Exception e) {
            Database.rollback(sp);
            errorMessages.add(LOG_ERROR + 'Exception: ' + e.getMessage());
            recordsFailed[0]++;
            debugInformation.add('----------------------------------');
            debugInformation.add('[ROLLBACK] ⚠️ Transaction rolled back. Previous logs invalid.');
            debugInformation.add('[ROLLBACK] Reason: ' + e.getMessage());
        }
    }

    private static void addSCNarrativeIfNotBlank(
        List<Narrative__c> bucket,
        String Name,
        Id recordTypeId,
        String typeVal,
        String subtypeVal,
        String language,
        Id productId,
        Id shareClassId,
        String richText
    ) {
        if (String.isBlank(richText)) return;

        Narrative__c n = new Narrative__c();
        n.RecordTypeId  = recordTypeId;
        n.Name          = Name;
        n.Type__c       = typeVal;      // 'PRIIPs'
        n.SubType__c    = subtypeVal;   // ex: 'Performance fee UCITS KIID'
        n.Language__c   = language;
        // n.Product__c  = productId;    // utile pour le reporting
        n.ShareClass__c = shareClassId; // lien vers la SC créée
        n.Content__c    = richText;
        n.StartDate__c  = System.today();
        bucket.add(n);
    }
}
