public class ProjectProductBatchController {

    private static final Set<String> EXCLUDED_FIELDS = new Set<String>{ 'Name' };

    // Logs / labels réutilisés pour éviter les duplications Sonar
    private static final String LOG_UPSERT = '[UPSERT] ';
    private static final String LOG_UPSERTED_TYPE = '[UPSERTED] Type: ';
    private static final String LOG_ERROR = '[ERROR] ';
    private static final String LOG_UPSERT_FAILED_SUFFIX = ' upserts failed.';

    private static final String TYPE_PRIIPS = 'PRIIPs';

    private static final String PRIIPS_SC_INVESTMENT_OBJECTIVE = 'PRIIPs Share Class Investment Objective';
    private static final String PRIIPS_PERF_FEE_UCITS = 'PRIIPs Performance fee UCITS KIID';
    private static final String PRIIPS_PERF_FEE_EPT = 'PRIIPs Performance fee EPT/KID';

    private static final String SUBTYPE_SC_INVESTMENT_OBJECTIVE = 'Share_Class_Investment_Objective';
    private static final String SUBTYPE_PERF_FEE_UCITS = 'Performance_fee_UCITS_KIID';
    private static final String SUBTYPE_PERF_FEE_EPT = 'Performance_fee_EPT/KID';

    public static Boolean canProcessProjectProduct(
        ProjectProduct__c pp,
        List<String> debugInformation,
        List<String> errorMessages
    ) {
        Boolean isValid = true;

        Boolean milestoneCompleted = false;
        if (pp.Milestones__r != null && !pp.Milestones__r.isEmpty()) {
            milestoneCompleted = pp.Milestones__r[0].Status__c == 'Completed';
        }

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

    public static void createFundShareclass(
        List<ProjectProduct__c> listFundCreation,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
        debugInformation.add('[INIT] Fund/Shareclass creation - ' + listFundCreation.size() + ' ProjectProduct(s) to process.');
        Savepoint sp = Database.setSavepoint();

        try {
            Id fundRecordTypeId = Schema.SObjectType.Product__c
                .getRecordTypeInfosByDeveloperName()
                .get('Fund')
                .getRecordTypeId();

            List<ProjectProduct__c> listProjectProductWFields =
                ProjectProductBatchUtilities.getProjectProduct(listFundCreation);

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

            // Préparation des Product__c
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
                ProjectProductBatchUtilities.UpsertDebugResult result =
                    ProjectProductBatchUtilities.logUpsertResults(listNewProduct);

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

            Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c
                .getRecordTypeInfosByDeveloperName()
                .get('Narrative')
                .getRecordTypeId();

            // Préparation Share Classes, FMA et narratives Product
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
                    newSC.OngoingCostsExante__c = getOngoingCosts(sc);

                    listNewShareClass.add(newSC);
                    debugInformation.add('[PREPARE] Shareclass from ProjectShareclass ' + sc.Id + ' prepared.');
                }

                for (FundManagerAssignment__c fma : projectProduct.Fund_Manager_Assignments__r) {
                    fma.Product__c = productId;
                    fma.StartDate__c = projectProduct.EndDate__c;
                    listFundManagerAssignmentToUpdate.add(fma);
                    debugInformation.add('[PREPARE] Fund Manager Assignment linked to product ' + productId);
                }

                for (Narrative__c projectThirdParty : projectProduct.Narratives__r) {
                    projectThirdParty.Product__c = productId;
                    listNarrative.add(projectThirdParty);
                }

                listNarrative.addAll(ProjectProductBatchUtilities.createNarratives(
                    projectProduct,
                    narrativeRecordTypeId,
                    projectProduct.DomiciledIn__c == 'FR' ? 'French' : 'English',
                    productId,
                    'Product'
                ));
            }

            Map<Id, Id> mapProjSCIdToSCId = insertShareclasses(
                listNewShareClass,
                debugInformation,
                errorMessages,
                recordsFailed,
                insertedRecords
            );

            List<Narrative__c> priipsShareclassNarratives = new List<Narrative__c>();
            List<TaxData__c> taxDataToUpdate = new List<TaxData__c>();

            // Liaison TaxData + création narratives Shareclass
            for (ProjectProduct__c projectProduct : listProjectProductWFields) {
                Product__c insertedProduct = mapProjectByProductId.get(projectProduct.Id);

                if (insertedProduct == null) {
                    errorMessages.add(LOG_ERROR + 'Missing Product for ProjectProduct ' + projectProduct.Id);
                    recordsFailed[0]++;
                    continue;
                }

                prepareShareclassNarrativesAndTaxData(
                    projectProduct,
                    insertedProduct.Id,
                    narrativeRecordTypeId,
                    mapProjSCIdToSCId,
                    priipsShareclassNarratives,
                    taxDataToUpdate,
                    errorMessages,
                    recordsFailed
                );
            }

            // Création des narratives Risk depuis les templates Custom Metadata
            List<Narrative__c> riskNarratives =
                NarrativeTemplateService.buildRiskNarratives(insertedProducts.values());

            List<SObject> toUpsert = new List<SObject>();
            toUpsert.addAll(priipsShareclassNarratives);
            toUpsert.addAll(riskNarratives);
            toUpsert.addAll(listFundManagerAssignmentToUpdate);
            toUpsert.addAll(listNarrative);
            toUpsert.addAll(taxDataToUpdate);
            upsertAndLog(toUpsert, debugInformation, errorMessages, recordsFailed, insertedRecords);

            debugInformation.add('[END] Fund/Shareclass creation complete.');
        } catch (Exception e) {
            rollbackAndLog(sp, e, debugInformation, errorMessages, recordsFailed);
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

            Map<Id, String> mapInvObj = new Map<Id, String>();
            Map<Id, String> mapRisk = new Map<Id, String>();
            Map<Id, String> mapIntendedRetail = new Map<Id, String>();
            Map<Id, String> mapReasonForRHP = new Map<Id, String>();
            Map<Id, String> languageByProductId = new Map<Id, String>();

            Map<Id, String> scLangById = new Map<Id, String>();
            Map<Id, Id> productByScId = new Map<Id, Id>();
            Map<Id, String> mapSCInvObj = new Map<Id, String>();
            Map<Id, String> mapSCPerfUCITS = new Map<Id, String>();
            Map<Id, String> mapSCPerfEPT = new Map<Id, String>();

            // Traitement Product + Shareclass, extrait pour réduire la complexité Sonar
            for (ProjectProduct__c pp : listWithFields) {
                processProductModification(
                    pp,
                    productMap,
                    shareclassMap,
                    productsToUpdate,
                    shareclassesToUpdate,
                    mapInvObj,
                    mapRisk,
                    mapIntendedRetail,
                    mapReasonForRHP,
                    languageByProductId,
                    scLangById,
                    productByScId,
                    mapSCInvObj,
                    mapSCPerfUCITS,
                    mapSCPerfEPT,
                    errorMessages,
                    recordsFailed
                );
            }

            if (!productsToUpdate.isEmpty()) {
                update productsToUpdate;
                debugInformation.add('[UPDATE] Products updated: ' + productsToUpdate.size());

                // Création ou mise à jour des narratives Risk liées aux produits
                List<SObject> riskNarratives = new List<SObject>();
                riskNarratives.addAll(
                    NarrativeTemplateService.buildRiskNarratives(productsToUpdate)
                );

                upsertAndLog(
                    riskNarratives,
                    debugInformation,
                    errorMessages,
                    recordsFailed,
                    insertedRecords
                );
            }

            upsertProductNarratives(
                mapInvObj,
                mapRisk,
                mapIntendedRetail,
                mapReasonForRHP,
                languageByProductId,
                debugInformation
            );

            if (!shareclassesToUpdate.isEmpty()) {
                update shareclassesToUpdate;
                debugInformation.add('[UPDATE] Shareclasses updated: ' + shareclassesToUpdate.size());
            }

            upsertShareclassNarratives(
                mapSCInvObj,
                mapSCPerfUCITS,
                mapSCPerfEPT,
                productByScId,
                scLangById,
                debugInformation
            );

            debugInformation.add('[END] Fund/Shareclass modification complete.');
        } catch (Exception e) {
            rollbackAndLog(sp, e, debugInformation, errorMessages, recordsFailed);
        }
    }

    public static void createShareclasses(
        List<ProjectProduct__c> listShareclassCreation,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
        debugInformation.add('[INIT] Shareclass creation for ' + listShareclassCreation.size() + ' ProjectProduct(s).');
        Savepoint sp = Database.setSavepoint();

        try {
            List<Share_Class__c> listNewShareClass = new List<Share_Class__c>();
            List<ProjectProduct__c> projectProducts =
                ProjectProductBatchUtilities.getProjectProduct(listShareclassCreation);

            Map<Id, Product__c> productMap =
                ProjectProductBatchUtilities.getMapProductByProductId(projectProducts);

            for (ProjectProduct__c pp : projectProducts) {
                Product__c product = productMap.get(pp.Product__c);

                for (ProjectShareclass__c sc : pp.ProjectShareclasses__r) {
                    Share_Class__c newSC = ProjectProductBatchUtilities.getNewShareclass(sc, product.Id);
                    newSC.Name = sc.Share_Class_Name__c;
                    newSC.LaunchDate__c = pp.EndDate__c;
                    newSC.Status__c = 'Active';
                    newSC.OngoingCostsExante__c = getOngoingCosts(sc);
                    newSC.ProjectShareclass__c = sc.Id;

                    listNewShareClass.add(newSC);
                    debugInformation.add('[PREPARE] New Shareclass from ProjectShareclass: ' + sc.Id);
                }
            }

            Map<Id, Id> mapProjSCIdToSCId = insertShareclasses(
                listNewShareClass,
                debugInformation,
                errorMessages,
                recordsFailed,
                insertedRecords
            );

            Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c
                .getRecordTypeInfosByDeveloperName()
                .get('Narrative')
                .getRecordTypeId();

            List<TaxData__c> taxDataToUpdate = new List<TaxData__c>();
            List<Narrative__c> priipsShareclassNarratives = new List<Narrative__c>();

            // Liaison des TaxData aux objets créés
            for (ProjectProduct__c pp : projectProducts) {
                Product__c product = productMap.get(pp.Product__c);

                if (pp.Tax_Data__r != null) {
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

                addShareclassNarratives(
                    pp,
                    product.Id,
                    narrativeRecordTypeId,
                    mapProjSCIdToSCId,
                    priipsShareclassNarratives
                );
            }

            List<SObject> toUpsert = new List<SObject>();
            toUpsert.addAll(priipsShareclassNarratives);
            toUpsert.addAll(taxDataToUpdate);

            upsertAndLog(toUpsert, debugInformation, errorMessages, recordsFailed, insertedRecords);

            debugInformation.add('[END] Shareclass creation complete.');
        } catch (Exception e) {
            rollbackAndLog(sp, e, debugInformation, errorMessages, recordsFailed);
        }
    }

    // -----------------------------
    // Helpers - création / insertion
    // -----------------------------

    private static Decimal getOngoingCosts(ProjectShareclass__c sc) {
        Decimal mgmtFees = sc.EffectiveManagementFees__c != null ? sc.EffectiveManagementFees__c : 0;
        Decimal serviceFees = sc.EffectiveServiceFees__c != null ? sc.EffectiveServiceFees__c : 0;
        return mgmtFees + serviceFees;
    }

    private static Map<Id, Id> insertShareclasses(
        List<Share_Class__c> listNewShareClass,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
        Map<Id, Id> mapProjSCIdToSCId = new Map<Id, Id>();

        if (listNewShareClass.isEmpty()) {
            return mapProjSCIdToSCId;
        }

        ProjectProductBatchUtilities.UpsertDebugResult result =
            ProjectProductBatchUtilities.logUpsertResults(listNewShareClass);

        debugInformation.add(LOG_UPSERT + result.successRecords.size() + ' Shareclasses created.');

        for (SObject currentSObject : result.successRecords.values()) {
            Share_Class__c sc = (Share_Class__c) currentSObject;
            Id projScId = (Id) sc.get('ProjectShareclass__c');

            if (projScId != null) {
                mapProjSCIdToSCId.put(projScId, sc.Id);
            }

            insertedRecords.add(sc.Id);
            debugInformation.add('[SUCCESS] Shareclass inserted: ' + sc.Id + ' (from ProjectShareclass ' + projScId + ')');
        }

        for (String err : result.errorMap.values()) {
            errorMessages.add(LOG_ERROR + 'Shareclass insert failed: ' + err);
            recordsFailed[0]++;
            throw new DmlException(LOG_ERROR + 'Shareclass insert failed: ' + err);
        }

        return mapProjSCIdToSCId;
    }

    private static void prepareShareclassNarrativesAndTaxData(
        ProjectProduct__c projectProduct,
        Id productId,
        Id narrativeRecordTypeId,
        Map<Id, Id> mapProjSCIdToSCId,
        List<Narrative__c> priipsShareclassNarratives,
        List<TaxData__c> taxDataToUpdate,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        if (projectProduct.ProjectShareclasses__r != null) {
            addShareclassNarratives(
                projectProduct,
                productId,
                narrativeRecordTypeId,
                mapProjSCIdToSCId,
                priipsShareclassNarratives
            );
        }

        if (projectProduct.Tax_Data__r == null) {
            return;
        }

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

    // -----------------------------
    // Helpers - modification
    // -----------------------------

    private static void processProductModification(
        ProjectProduct__c pp,
        Map<Id, Product__c> productMap,
        Map<Id, Share_Class__c> shareclassMap,
        List<Product__c> productsToUpdate,
        List<Share_Class__c> shareclassesToUpdate,
        Map<Id, String> mapInvObj,
        Map<Id, String> mapRisk,
        Map<Id, String> mapIntendedRetail,
        Map<Id, String> mapReasonForRHP,
        Map<Id, String> languageByProductId,
        Map<Id, String> scLangById,
        Map<Id, Id> productByScId,
        Map<Id, String> mapSCInvObj,
        Map<Id, String> mapSCPerfUCITS,
        Map<Id, String> mapSCPerfEPT,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        Product__c product = productMap.get(pp.Product__c);
        Id prodId = pp.Product__c;
        String lang = pp.DomiciledIn__c == 'FR' ? 'French' : 'English';

        languageByProductId.put(prodId, lang);

        List<String> fieldsToModify = getFieldsToModify(pp.TECH_FieldsToModify__c);

        fillProductNarrativeMaps(
            pp,
            prodId,
            fieldsToModify,
            mapInvObj,
            mapRisk,
            mapIntendedRetail,
            mapReasonForRHP
        );

        applyProductFieldUpdates(product, pp, fieldsToModify, errorMessages, recordsFailed);
        productsToUpdate.add(product);

        for (ProjectShareclass__c sc : pp.ProjectShareclasses__r) {
            processShareclassModification(
                sc,
                pp,
                lang,
                prodId,
                shareclassMap,
                scLangById,
                productByScId,
                mapSCInvObj,
                mapSCPerfUCITS,
                mapSCPerfEPT,
                shareclassesToUpdate,
                errorMessages,
                recordsFailed
            );
        }
    }

    private static List<String> getFieldsToModify(String rawFields) {
        List<String> fieldsToModify = new List<String>();

        if (String.isBlank(rawFields)) {
            return fieldsToModify;
        }

        for (String fieldName : rawFields.split(';')) {
            if (!String.isBlank(fieldName)) {
                fieldsToModify.add(fieldName.trim());
            }
        }

        return fieldsToModify;
    }

    private static void fillProductNarrativeMaps(
        ProjectProduct__c pp,
        Id prodId,
        List<String> fieldsToModify,
        Map<Id, String> mapInvObj,
        Map<Id, String> mapRisk,
        Map<Id, String> mapIntendedRetail,
        Map<Id, String> mapReasonForRHP
    ) {
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
    }

    private static void applyProductFieldUpdates(
        Product__c product,
        ProjectProduct__c pp,
        List<String> fieldsToModify,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        for (String fieldName : fieldsToModify) {
            if (String.isBlank(fieldName) || EXCLUDED_FIELDS.contains(fieldName)) {
                continue;
            }

            try {
                product.put(fieldName, pp.get(fieldName));
            } catch (Exception e) {
                errorMessages.add(LOG_ERROR + 'Field skipped: ' + fieldName + ' → ' + e.getMessage());
                recordsFailed[0]++;
            }
        }
    }

    private static void processShareclassModification(
        ProjectShareclass__c sc,
        ProjectProduct__c pp,
        String lang,
        Id prodId,
        Map<Id, Share_Class__c> shareclassMap,
        Map<Id, String> scLangById,
        Map<Id, Id> productByScId,
        Map<Id, String> mapSCInvObj,
        Map<Id, String> mapSCPerfUCITS,
        Map<Id, String> mapSCPerfEPT,
        List<Share_Class__c> shareclassesToUpdate,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        if (String.isBlank(sc.TECH_ShareClass__c) || shareclassMap == null) {
            return;
        }

        Id shareClassId;
        try {
            shareClassId = Id.valueOf(sc.TECH_ShareClass__c);
        } catch (Exception e) {
            errorMessages.add(LOG_ERROR + 'Invalid Shareclass Id: ' + sc.TECH_ShareClass__c + ' → ' + e.getMessage());
            recordsFailed[0]++;
            return;
        }

        if (!shareclassMap.containsKey(shareClassId)) {
            return;
        }

        Share_Class__c scToUpdate = shareclassMap.get(shareClassId);
        Id scId = scToUpdate.Id;

        scLangById.put(scId, lang);
        productByScId.put(scId, prodId);

        Set<String> scFieldsToModify = new Set<String>(getFieldsToModify(sc.TECH_FieldsToModify__c));

        fillShareclassNarrativeMaps(sc, scId, scFieldsToModify, mapSCInvObj, mapSCPerfUCITS, mapSCPerfEPT);

        scToUpdate.ESMAApplicationStartDate__c = pp.EndDate__c;

        applyShareclassFieldUpdates(scToUpdate, sc, scFieldsToModify, errorMessages, recordsFailed);

        shareclassesToUpdate.add(scToUpdate);
    }

    private static void fillShareclassNarrativeMaps(
        ProjectShareclass__c sc,
        Id scId,
        Set<String> scFieldsToModify,
        Map<Id, String> mapSCInvObj,
        Map<Id, String> mapSCPerfUCITS,
        Map<Id, String> mapSCPerfEPT
    ) {
        if (scFieldsToModify.contains('ShareclassInvestmentObjective__c')
            && !String.isBlank(sc.ShareclassInvestmentObjective__c)) {
            mapSCInvObj.put(scId, sc.ShareclassInvestmentObjective__c);
        }

        if (scFieldsToModify.contains('PerformanceFeeUCITSKIID__c')
            && !String.isBlank(sc.PerformanceFeeUCITSKIID__c)) {
            mapSCPerfUCITS.put(scId, sc.PerformanceFeeUCITSKIID__c);
        }

        if (scFieldsToModify.contains('PerformanceFeeEPTKID__c')
            && !String.isBlank(sc.PerformanceFeeEPTKID__c)) {
            mapSCPerfEPT.put(scId, sc.PerformanceFeeEPTKID__c);
        }
    }

    private static void applyShareclassFieldUpdates(
        Share_Class__c scToUpdate,
        ProjectShareclass__c sc,
        Set<String> fieldsToModify,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        for (String fieldName : fieldsToModify) {
            try {
                scToUpdate.put(fieldName, sc.get(fieldName));
            } catch (Exception e) {
                errorMessages.add(LOG_ERROR + 'Shareclass field skipped: ' + fieldName + ' → ' + e.getMessage());
                recordsFailed[0]++;
            }
        }
    }

    // -----------------------------
    // Helpers - narratives
    // -----------------------------

    private static void addShareclassNarratives(
        ProjectProduct__c pp,
        Id productId,
        Id narrativeRecordTypeId,
        Map<Id, Id> mapProjSCIdToSCId,
        List<Narrative__c> priipsShareclassNarratives
    ) {
        String language = pp.DomiciledIn__c == 'FR' ? 'French' : 'English';

        for (ProjectShareclass__c psc : pp.ProjectShareclasses__r) {
            Id scId = mapProjSCIdToSCId.get(psc.Id);

            addSCNarrativeIfNotBlank(
                priipsShareclassNarratives,
                PRIIPS_SC_INVESTMENT_OBJECTIVE,
                narrativeRecordTypeId,
                TYPE_PRIIPS,
                SUBTYPE_SC_INVESTMENT_OBJECTIVE,
                language,
                productId,
                scId,
                psc.ShareclassInvestmentObjective__c,
                'Shareclass'
            );

            addSCNarrativeIfNotBlank(
                priipsShareclassNarratives,
                PRIIPS_PERF_FEE_UCITS,
                narrativeRecordTypeId,
                TYPE_PRIIPS,
                SUBTYPE_PERF_FEE_UCITS,
                language,
                productId,
                scId,
                psc.PerformanceFeeUCITSKIID__c,
                'Shareclass'
            );

            addSCNarrativeIfNotBlank(
                priipsShareclassNarratives,
                PRIIPS_PERF_FEE_EPT,
                narrativeRecordTypeId,
                TYPE_PRIIPS,
                SUBTYPE_PERF_FEE_EPT,
                language,
                productId,
                scId,
                psc.PerformanceFeeEPTKID__c,
                'Shareclass'
            );
        }
    }

    private static void addSCNarrativeIfNotBlank(
        List<Narrative__c> bucket,
        String nameValue,
        Id recordTypeId,
        String typeVal,
        String subtypeVal,
        String language,
        Id productId,
        Id shareClassId,
        String richText,
        String scope
    ) {
        if (String.isBlank(richText)) {
            return;
        }

        Narrative__c n = new Narrative__c();
        n.RecordTypeId = recordTypeId;
        n.Name = nameValue;
        n.Type__c = typeVal;
        n.SubType__c = subtypeVal;
        n.Language__c = language;
        n.ShareClass__c = shareClassId;
        n.Content__c = richText;
        n.Narrative_Scope__c = scope;
        n.StartDate__c = System.today();

        bucket.add(n);
    }

    private static void upsertProductNarratives(
        Map<Id, String> mapInvObj,
        Map<Id, String> mapRisk,
        Map<Id, String> mapIntendedRetail,
        Map<Id, String> mapReasonForRHP,
        Map<Id, String> languageByProductId,
        List<String> debugInformation
    ) {
        Set<Id> prodIdsForNarratives = new Set<Id>();
        prodIdsForNarratives.addAll(mapInvObj.keySet());
        prodIdsForNarratives.addAll(mapRisk.keySet());
        prodIdsForNarratives.addAll(mapIntendedRetail.keySet());
        prodIdsForNarratives.addAll(mapReasonForRHP.keySet());

        if (prodIdsForNarratives.isEmpty()) {
            return;
        }

        Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c
            .getRecordTypeInfosByDeveloperName()
            .get('Narrative')
            .getRecordTypeId();

        List<Narrative__c> existingNarratives = [
            SELECT Id, Product__c, Language__c, Type__c, SubType__c, Content__c
            FROM Narrative__c
            WHERE Product__c IN :prodIdsForNarratives
            AND (
                   (Type__c = 'Investment Objective' AND SubType__c = 'PRIIPS')
                OR (Type__c = 'Risk' AND SubType__c = 'Main Risk of the Fund')
                OR (Type__c = :TYPE_PRIIPS AND SubType__c = 'INTENDED_RETAIL_INVESTOR')
                OR (Type__c = :TYPE_PRIIPS AND SubType__c = 'REASON_FOR_PHP')
            )
        ];

        Map<String, Narrative__c> existingByKey = new Map<String, Narrative__c>();
        for (Narrative__c n : existingNarratives) {
            existingByKey.put(
                ProjectProductBatchUtilities.narrativeKey(n.Product__c, n.Language__c, n.Type__c, n.SubType__c),
                n
            );
        }

        List<Narrative__c> narrativesToUpsert = new List<Narrative__c>();

        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
            mapInvObj,
            languageByProductId,
            existingByKey,
            'Investment Objective',
            'PRIIPS',
            'Investment Objective PRIIPS',
            narrativeRecordTypeId,
            debugInformation
        ));

        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
            mapRisk,
            languageByProductId,
            existingByKey,
            'Risk',
            'Main Risk of the Fund',
            'Risk Main Risk of the Fund',
            narrativeRecordTypeId,
            debugInformation
        ));

        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
            mapIntendedRetail,
            languageByProductId,
            existingByKey,
            TYPE_PRIIPS,
            'INTENDED_RETAIL_INVESTOR',
            'PRIIPs Intended Retail Investor',
            narrativeRecordTypeId,
            debugInformation
        ));

        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
            mapReasonForRHP,
            languageByProductId,
            existingByKey,
            TYPE_PRIIPS,
            'REASON_FOR_PHP',
            'PRIIPs Reason For PHP',
            narrativeRecordTypeId,
            debugInformation
        ));

        if (!narrativesToUpsert.isEmpty()) {
            upsert narrativesToUpsert;
            debugInformation.add(LOG_UPSERT + 'Narratives upserted (single DML): ' + narrativesToUpsert.size());
        }
    }

    private static void upsertShareclassNarratives(
        Map<Id, String> mapSCInvObj,
        Map<Id, String> mapSCPerfUCITS,
        Map<Id, String> mapSCPerfEPT,
        Map<Id, Id> productByScId,
        Map<Id, String> scLangById,
        List<String> debugInformation
    ) {
        Set<Id> scIdsForNarratives = new Set<Id>();
        scIdsForNarratives.addAll(mapSCInvObj.keySet());
        scIdsForNarratives.addAll(mapSCPerfUCITS.keySet());
        scIdsForNarratives.addAll(mapSCPerfEPT.keySet());

        if (scIdsForNarratives.isEmpty()) {
            return;
        }

        Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c
            .getRecordTypeInfosByDeveloperName()
            .get('Narrative')
            .getRecordTypeId();

        List<Narrative__c> existingSCNarratives = [
            SELECT Id, ShareClass__c, Language__c, Type__c, SubType__c, Content__c, Product__c
            FROM Narrative__c
            WHERE ShareClass__c IN :scIdsForNarratives
            AND Type__c = :TYPE_PRIIPS
            AND SubType__c IN (:SUBTYPE_SC_INVESTMENT_OBJECTIVE, :SUBTYPE_PERF_FEE_UCITS, :SUBTYPE_PERF_FEE_EPT)
        ];

        Map<String, Narrative__c> existingByKey = new Map<String, Narrative__c>();
        for (Narrative__c n : existingSCNarratives) {
            existingByKey.put(
                ProjectProductBatchUtilities.scNarrativeKey(n.ShareClass__c, n.Language__c, n.Type__c, n.SubType__c),
                n
            );
        }

        List<Narrative__c> narrativesToUpsert = new List<Narrative__c>();

        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(
            mapSCInvObj,
            productByScId,
            scLangById,
            existingByKey,
            TYPE_PRIIPS,
            SUBTYPE_SC_INVESTMENT_OBJECTIVE,
            PRIIPS_SC_INVESTMENT_OBJECTIVE,
            narrativeRecordTypeId,
            debugInformation
        ));

        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(
            mapSCPerfUCITS,
            productByScId,
            scLangById,
            existingByKey,
            TYPE_PRIIPS,
            SUBTYPE_PERF_FEE_UCITS,
            PRIIPS_PERF_FEE_UCITS,
            narrativeRecordTypeId,
            debugInformation
        ));

        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(
            mapSCPerfEPT,
            productByScId,
            scLangById,
            existingByKey,
            TYPE_PRIIPS,
            SUBTYPE_PERF_FEE_EPT,
            PRIIPS_PERF_FEE_EPT,
            narrativeRecordTypeId,
            debugInformation
        ));

        if (!narrativesToUpsert.isEmpty()) {
            upsert narrativesToUpsert;
            debugInformation.add(LOG_UPSERT + '[SC] Narratives upserted (single DML): ' + narrativesToUpsert.size());
        }
    }

    // -----------------------------
    // Helpers - DML / rollback
    // -----------------------------

    private static void upsertAndLog(
        List<SObject> toUpsert,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
        if (toUpsert.isEmpty()) {
            return;
        }

        ProjectProductBatchUtilities.UpsertDebugResult result =
            ProjectProductBatchUtilities.logUpsertResults(toUpsert);

        debugInformation.add(LOG_UPSERT + result.successRecords.size() + ' records upserted.');

        for (SObject currentSObject : result.successRecords.values()) {
            String objectType = currentSObject.getSObjectType().getDescribe().getName();
            insertedRecords.add((String) currentSObject.get('Id'));
            debugInformation.add(LOG_UPSERTED_TYPE + objectType + ' (Id: ' + currentSObject.get('Id') + ')');
        }

        if (!result.errorMap.isEmpty()) {
            errorMessages.add(LOG_ERROR + result.errorMap.size() + LOG_UPSERT_FAILED_SUFFIX);

            for (String err : result.errorMap.values()) {
                errorMessages.add(err);
                recordsFailed[0]++;
            }

            throw new DmlException(LOG_ERROR + result.errorMap.size() + LOG_UPSERT_FAILED_SUFFIX);
        }
    }

    private static void rollbackAndLog(
        Savepoint sp,
        Exception e,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        Database.rollback(sp);
        errorMessages.add(LOG_ERROR + 'Exception: ' + e.getMessage());
        recordsFailed[0]++;
        debugInformation.add('----------------------------------');
        debugInformation.add('[ROLLBACK] ⚠️ Transaction rolled back. Previous logs invalid.');
        debugInformation.add('[ROLLBACK] Reason: ' + e.getMessage());
    }
}