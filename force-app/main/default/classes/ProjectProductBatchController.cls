// =========================
// ProjectProductBatchController.cls
// Fixes requested:
// - constants for "Exception: " and "Shareclass insert failed: "
// - refactor methods to reduce Cognitive Complexity (createFundShareclass + updateFundShareclassModification + createShareclasses)
//   -> move main logic into private helpers (Sonar counts complexity per method)
// =========================
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

    // NEW constants requested by Sonar
    private static final String LOG_EXCEPTION_PREFIX                  = 'Exception: ';
    private static final String ERR_SHARECLASS_INSERT_FAILED          = 'Shareclass insert failed: ';

    public static Boolean canProcessProjectProduct(ProjectProduct__c pp, List<String> debugInformation, List<String> errorMessages) {
        Boolean isValid = true;

        Boolean milestoneCompleted = false;
        if (pp.Milestones__r != null && !pp.Milestones__r.isEmpty()) {
            milestoneCompleted = (pp.Milestones__r[0].Status__c == 'Completed');
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

    // -------------------------
    // createFundShareclass (refactored wrapper)
    // -------------------------
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
            createFundShareclassInternal(listFundCreation, debugInformation, errorMessages, recordsFailed, insertedRecords);
            debugInformation.add('[END] Fund/Shareclass creation complete.');
        } catch (Exception e) {
            rollbackAndLog(sp, e, debugInformation, errorMessages, recordsFailed);
        }
    }

    // -------------------------
    // updateFundShareclassModification (refactored wrapper)
    // -------------------------
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
            updateFundShareclassModificationInternal(listMods, debugInformation, errorMessages, recordsFailed, insertedRecords);
            debugInformation.add('[END] Fund/Shareclass modification complete.');
        } catch (Exception e) {
            rollbackAndLog(sp, e, debugInformation, errorMessages, recordsFailed);
        }
    }

    // -------------------------
    // createShareclasses (refactored wrapper)
    // -------------------------
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
            createShareclassesInternal(listShareclassCreation, debugInformation, errorMessages, recordsFailed, insertedRecords);
            debugInformation.add('[END] Shareclass creation complete.');
        } catch (Exception e) {
            rollbackAndLog(sp, e, debugInformation, errorMessages, recordsFailed);
        }
    }

    // ============================================================
    // ===================== INTERNAL METHODS ======================
    // ============================================================

    private static void createFundShareclassInternal(
        List<ProjectProduct__c> listFundCreation,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
        Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
        List<ProjectProduct__c> listProjectProductWFields = ProjectProductBatchUtilities.getProjectProduct(listFundCreation);

        if (listProjectProductWFields == null || listProjectProductWFields.isEmpty()) {
            String msg = LOG_ERROR + 'No ProjectProduct enriched. Skipping creation.';
            errorMessages.add(msg);
            debugInformation.add(msg);
            recordsFailed[0]++;
            return;
        }

        CreateFundContext ctx = initFundCreationContext(listProjectProductWFields, fundRecordTypeId, debugInformation);

        // 1) Insert products
        ctx.insertedProductsById = upsertProductsForFundCreation(ctx, debugInformation, errorMessages, recordsFailed, insertedRecords);

        // 2) Prepare related records (SC, FMA, Narratives)
        prepareFundCreationRelatedRecords(ctx, debugInformation, errorMessages, recordsFailed);

        // 3) Insert shareclasses + mapping
        ctx.mapProjSCIdToSCId = upsertShareclassesForFundCreation(ctx, debugInformation, errorMessages, recordsFailed, insertedRecords);

        // 4) Prepare PRIIPs SC narratives + TaxData update + upsert all
        preparePriipsNarrativesAndTaxData(ctx, debugInformation, errorMessages, recordsFailed);

        upsertAllForFundCreation(ctx, debugInformation, errorMessages, recordsFailed, insertedRecords);
    }

    private static void updateFundShareclassModificationInternal(
        List<ProjectProduct__c> listMods,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
        // NOTE: logic unchanged, moved to helpers to reduce cognitive complexity
        List<ProjectProduct__c> listWithFields = ProjectProductBatchUtilities.getProjectProduct(listMods);
        Map<Id, Product__c> productMap = ProjectProductBatchUtilities.getMapProductByProductId(listWithFields);
        Map<Id, Share_Class__c> shareclassMap = ProjectProductBatchUtilities.getMapShareClassByShareclassId(listWithFields);

        if (productMap == null) {
            errorMessages.add(LOG_ERROR + 'mapProductByProductId is null.');
            recordsFailed[0]++;
            return;
        }

        ModifContext ctx = initModifContext(listWithFields, productMap, shareclassMap);

        fillModifContext(ctx, debugInformation, errorMessages, recordsFailed);

        updateProductsIfNeeded(ctx.productsToUpdate, debugInformation);

        upsertProductNarrativesIfNeeded(ctx, debugInformation);

        updateShareclassesIfNeeded(ctx.shareclassesToUpdate, debugInformation);

        upsertShareclassNarrativesIfNeeded(ctx, debugInformation);
    }

    private static void createShareclassesInternal(
        List<ProjectProduct__c> listShareclassCreation,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
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
                errorMessages.add(LOG_ERROR + ERR_SHARECLASS_INSERT_FAILED + err);
                recordsFailed[0]++;
                throw new DmlException(ERR_SHARECLASS_INSERT_FAILED + err);
            }
        }

        List<TaxData__c> taxDataToUpdate = new List<TaxData__c>();
        for (ProjectProduct__c pp : projectProducts) {
            Product__c product = productMap.get(pp.Product__c);

            if (pp.Tax_Data__r == null) continue;
            for (TaxData__c td : pp.Tax_Data__r) {
                if (td.Product__c == null) td.Product__c = product.Id;
                if (td.ShareClass__c == null) td.ShareClass__c = mapProjSCIdToSCId.get(td.ProjectShareclass__c);
                taxDataToUpdate.add(td);
            }
        }

        List<Narrative__c> priipsShareclassNarratives = new List<Narrative__c>();
        for (ProjectProduct__c pp : projectProducts) {
            Product__c product = productMap.get(pp.Product__c);
            Id productId = product.Id;
            String language = (pp.DomiciledIn__c == 'FR') ? 'French' : 'English';

            for (ProjectShareclass__c psc : pp.ProjectShareclasses__r) {
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
    }

    // ============================================================
    // ========================= HELPERS ===========================
    // ============================================================

    // ----- Context classes to reduce local variables -----

    private class CreateFundContext {
        List<ProjectProduct__c> listProjectProductWFields;
        Id fundRecordTypeId;
        Id narrativeRecordTypeId;

        List<Product__c> listNewProduct = new List<Product__c>();
        Map<Id, Product__c> mapProjectByProductId = new Map<Id, Product__c>();

        Map<Id, Product__c> insertedProductsById = new Map<Id, Product__c>();

        List<Share_Class__c> listNewShareClass = new List<Share_Class__c>();
        List<FundManagerAssignment__c> listFundManagerAssignmentToUpdate = new List<FundManagerAssignment__c>();
        List<Narrative__c> listNarrative = new List<Narrative__c>();
        List<Narrative__c> priipsShareclassNarratives = new List<Narrative__c>();
        List<TaxData__c> taxDataToUpdate = new List<TaxData__c>();

        Map<Id, Id> mapProjSCIdToSCId = new Map<Id, Id>();
    }

    private class ModifContext {
        List<ProjectProduct__c> listWithFields;
        Map<Id, Product__c> productMap;
        Map<Id, Share_Class__c> shareclassMap;

        List<Product__c> productsToUpdate = new List<Product__c>();
        List<Share_Class__c> shareclassesToUpdate = new List<Share_Class__c>();

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
    }

    private static CreateFundContext initFundCreationContext(List<ProjectProduct__c> listProjectProductWFields, Id fundRecordTypeId, List<String> debugInformation) {
        CreateFundContext ctx = new CreateFundContext();
        ctx.listProjectProductWFields = listProjectProductWFields;
        ctx.fundRecordTypeId = fundRecordTypeId;
        ctx.narrativeRecordTypeId = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName().get('Narrative').getRecordTypeId();

        for (ProjectProduct__c projectProduct : listProjectProductWFields) {
            Product__c newProduct = ProjectProductBatchUtilities.getNewProduct(projectProduct);
            newProduct.ParentProject__c = projectProduct.Id;
            newProduct.RecordTypeId = fundRecordTypeId;
            newProduct.LaunchDate__c = projectProduct.EndDate__c;
            newProduct.Name = projectProduct.InternalShortName__c;
            newProduct.Validity__c = true;

            ctx.listNewProduct.add(newProduct);
            ctx.mapProjectByProductId.put(projectProduct.Id, newProduct);
            debugInformation.add('[PREPARE] Product initialized for ProjectProduct ' + projectProduct.Id);
        }
        return ctx;
    }

    private static Map<Id, Product__c> upsertProductsForFundCreation(
        CreateFundContext ctx,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
        Map<Id, Product__c> insertedProducts = new Map<Id, Product__c>();
        if (ctx.listNewProduct.isEmpty()) return insertedProducts;

        ProjectProductBatchUtilities.UpsertDebugResult result = ProjectProductBatchUtilities.logUpsertResults(ctx.listNewProduct);

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

        return insertedProducts;
    }

    private static void prepareFundCreationRelatedRecords(
        CreateFundContext ctx,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        for (ProjectProduct__c projectProduct : ctx.listProjectProductWFields) {
            Product__c insertedProduct = ctx.mapProjectByProductId.get(projectProduct.Id);

            if (insertedProduct == null || !ctx.insertedProductsById.containsKey(insertedProduct.Id)) {
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

                ctx.listNewShareClass.add(newSC);
                debugInformation.add('[PREPARE] Shareclass from ProjectShareclass ' + sc.Id + ' prepared.');
            }

            for (FundManagerAssignment__c fma : projectProduct.Fund_Manager_Assignments__r) {
                fma.Product__c = productId;
                fma.StartDate__c = projectProduct.EndDate__c;
                ctx.listFundManagerAssignmentToUpdate.add(fma);
                debugInformation.add('[PREPARE] Fund Manager Assignment linked to product ' + productId);
            }

            for (Narrative__c projectThirdParty : projectProduct.Narratives__r) {
                projectThirdParty.Product__c = productId;
                ctx.listNarrative.add(projectThirdParty);
            }

            List<Narrative__c> autoNarratives = ProjectProductBatchUtilities.createNarratives(
                projectProduct,
                ctx.narrativeRecordTypeId,
                projectProduct.DomiciledIn__c == 'FR' ? 'French' : 'English',
                productId
            );
            ctx.listNarrative.addAll(autoNarratives);
        }
    }

    private static Map<Id, Id> upsertShareclassesForFundCreation(
        CreateFundContext ctx,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
        Map<Id, Id> mapProjSCIdToSCId = new Map<Id, Id>();
        if (ctx.listNewShareClass.isEmpty()) return mapProjSCIdToSCId;

        ProjectProductBatchUtilities.UpsertDebugResult scResult = ProjectProductBatchUtilities.logUpsertResults(ctx.listNewShareClass);

        for (SObject sObj : scResult.successRecords.values()) {
            Share_Class__c sc = (Share_Class__c) sObj;
            Id projScId = (Id) sc.get('ProjectShareclass__c');
            if (projScId != null) {
                mapProjSCIdToSCId.put(projScId, sc.Id);
            }
            insertedRecords.add(sc.Id);
            debugInformation.add('[SUCCESS] Shareclass inserted: ' + sc.Id + ' (from ProjectShareclass ' + projScId + ')');
        }

        for (String err : scResult.errorMap.values()) {
            errorMessages.add(LOG_ERROR + ERR_SHARECLASS_INSERT_FAILED + err);
            recordsFailed[0]++;
            throw new DmlException(LOG_ERROR + ERR_SHARECLASS_INSERT_FAILED + err);
        }

        return mapProjSCIdToSCId;
    }

    private static void preparePriipsNarrativesAndTaxData(
        CreateFundContext ctx,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        // Build narratives + tax update
        for (ProjectProduct__c projectProduct : ctx.listProjectProductWFields) {
            Product__c insertedProduct = ctx.mapProjectByProductId.get(projectProduct.Id);

            if (insertedProduct == null) {
                errorMessages.add(LOG_ERROR + 'Missing Product for ProjectProduct ' + projectProduct.Id);
                recordsFailed[0]++;
                continue;
            }

            Id productId = insertedProduct.Id;
            String language = (projectProduct.DomiciledIn__c == 'FR') ? 'French' : 'English';

            if (projectProduct.ProjectShareclasses__r != null) {
                for (ProjectShareclass__c psc : projectProduct.ProjectShareclasses__r) {
                    Id scId = ctx.mapProjSCIdToSCId.get(psc.Id);
                    if (scId == null && psc.TECH_ShareClass__c != null) {
                        try { scId = Id.valueOf(psc.TECH_ShareClass__c); } catch (Exception e) {}
                    }
                    if (scId == null) {
                        errorMessages.add(LOG_ERROR + 'Missing Share_Class__c Id for ProjectShareclass ' + psc.Id);
                        recordsFailed[0]++;
                        continue;
                    }

                    addSCNarrativeIfNotBlank(
                        ctx.priipsShareclassNarratives, NAME_PRIIPS_SC_INVESTMENT_OBJECTIVE,
                        ctx.narrativeRecordTypeId, 'PRIIPs', SUBTYPE_SC_INV_OBJ,
                        language, productId, scId, psc.ShareclassInvestmentObjective__c
                    );
                    addSCNarrativeIfNotBlank(
                        ctx.priipsShareclassNarratives, NAME_PRIIPS_PERF_FEE_UCITS_KIID,
                        ctx.narrativeRecordTypeId, 'PRIIPs', SUBTYPE_PERF_FEE_UCITS_KIID,
                        language, productId, scId, psc.PerformanceFeeUCITSKIID__c
                    );
                    addSCNarrativeIfNotBlank(
                        ctx.priipsShareclassNarratives, NAME_PRIIPS_PERF_FEE_EPT_KID,
                        ctx.narrativeRecordTypeId, 'PRIIPs', SUBTYPE_PERF_FEE_EPT_KID,
                        language, productId, scId, psc.PerformanceFeeEPTKID__c
                    );
                }
            }

            if (projectProduct.Tax_Data__r != null) {
                for (TaxData__c td : projectProduct.Tax_Data__r) {
                    if (td.Product__c == null) td.Product__c = productId;
                    if (td.ShareClass__c == null) td.ShareClass__c = ctx.mapProjSCIdToSCId.get(td.ProjectShareclass__c);
                    ctx.taxDataToUpdate.add(td);
                }
            }
        }
    }

    private static void upsertAllForFundCreation(
        CreateFundContext ctx,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed,
        List<Id> insertedRecords
    ) {
        List<SObject> toUpsert = new List<SObject>();
        toUpsert.addAll(ctx.priipsShareclassNarratives);
        toUpsert.addAll(ctx.listFundManagerAssignmentToUpdate);
        toUpsert.addAll(ctx.listNarrative);
        toUpsert.addAll(ctx.taxDataToUpdate);

        if (toUpsert.isEmpty()) return;

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

    private static ModifContext initModifContext(List<ProjectProduct__c> listWithFields, Map<Id, Product__c> productMap, Map<Id, Share_Class__c> shareclassMap) {
        ModifContext ctx = new ModifContext();
        ctx.listWithFields = listWithFields;
        ctx.productMap = productMap;
        ctx.shareclassMap = shareclassMap;
        return ctx;
    }

    private static void fillModifContext(
        ModifContext ctx,
        List<String> debugInformation,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        for (ProjectProduct__c pp : ctx.listWithFields) {
            Product__c product = ctx.productMap.get(pp.Product__c);
            Id prodId = pp.Product__c;
            String lang = (pp.DomiciledIn__c == 'FR') ? 'French' : 'English';
            ctx.languageByProductId.put(prodId, lang);

            List<String> fieldsToModify = splitList(pp.TECH_FieldsToModify__c);

            // maps for product narratives
            if (fieldsToModify.contains('InvestmentObjective__c')) {
                ctx.mapInvObj.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'InvestmentObjective__c'));
            }
            if (fieldsToModify.contains('RiskAssociated__c')) {
                ctx.mapRisk.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'RiskAssociated__c'));
            }
            if (fieldsToModify.contains('IntentedRetailInvestor__c')) {
                ctx.mapIntendedRetail.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'IntentedRetailInvestor__c'));
            }
            if (fieldsToModify.contains('ReasonForRHP__c')) {
                ctx.mapReasonForRHP.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'ReasonForRHP__c'));
            }

            // apply product field updates
            applyFieldsOnSObject(product, pp, fieldsToModify, errorMessages, recordsFailed);

            ctx.productsToUpdate.add(product);

            // shareclasses updates + collect PRIIPs texts
            collectShareclassUpdatesAndPriips(ctx, pp, lang, errorMessages, recordsFailed);
        }
    }

    private static void collectShareclassUpdatesAndPriips(
        ModifContext ctx,
        ProjectProduct__c pp,
        String lang,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        if (pp.ProjectShareclasses__r == null) return;

        Id prodId = pp.Product__c;

        for (ProjectShareclass__c sc : pp.ProjectShareclasses__r) {
            if (sc.TECH_ShareClass__c == null) continue;

            Id scIdValue;
            try { scIdValue = Id.valueOf(sc.TECH_ShareClass__c); } catch (Exception e) { continue; }

            if (!ctx.shareclassMap.containsKey(scIdValue)) continue;

            Share_Class__c scToUpdate = ctx.shareclassMap.get(scIdValue);
            Id scId = scToUpdate.Id;

            ctx.scLangById.put(scId, lang);
            ctx.productByScId.put(scId, prodId);

            Set<String> scFieldsToModify = new Set<String>(splitList(sc.TECH_FieldsToModify__c));

            if (scFieldsToModify.contains('ShareclassInvestmentObjective__c') && !String.isBlank(sc.ShareclassInvestmentObjective__c)) {
                ctx.mapSCInvObj.put(scId, sc.ShareclassInvestmentObjective__c);
            }
            if (scFieldsToModify.contains('PerformanceFeeUCITSKIID__c') && !String.isBlank(sc.PerformanceFeeUCITSKIID__c)) {
                ctx.mapSCPerfUCITS.put(scId, sc.PerformanceFeeUCITSKIID__c);
            }
            if (scFieldsToModify.contains('PerformanceFeeEPTKID__c') && !String.isBlank(sc.PerformanceFeeEPTKID__c)) {
                ctx.mapSCPerfEPT.put(scId, sc.PerformanceFeeEPTKID__c);
            }

            scToUpdate.ESMAApplicationStartDate__c = pp.EndDate__c;

            if (!String.isBlank(sc.TECH_FieldsToModify__c)) {
                applyFieldsOnSObject(scToUpdate, sc, new List<String>(scFieldsToModify), errorMessages, recordsFailed);
            }

            ctx.shareclassesToUpdate.add(scToUpdate);
        }
    }

    private static void updateProductsIfNeeded(List<Product__c> productsToUpdate, List<String> debugInformation) {
        if (productsToUpdate == null || productsToUpdate.isEmpty()) return;
        update productsToUpdate;
        debugInformation.add('[UPDATE] Products updated: ' + productsToUpdate.size());
    }

    private static void updateShareclassesIfNeeded(List<Share_Class__c> shareclassesToUpdate, List<String> debugInformation) {
        if (shareclassesToUpdate == null || shareclassesToUpdate.isEmpty()) return;
        update shareclassesToUpdate;
        debugInformation.add('[UPDATE] Shareclasses updated: ' + shareclassesToUpdate.size());
    }

    private static void upsertProductNarrativesIfNeeded(ModifContext ctx, List<String> debugInformation) {
        Set<Id> prodIdsForNarratives = new Set<Id>();
        prodIdsForNarratives.addAll(ctx.mapInvObj.keySet());
        prodIdsForNarratives.addAll(ctx.mapRisk.keySet());
        prodIdsForNarratives.addAll(ctx.mapIntendedRetail.keySet());
        prodIdsForNarratives.addAll(ctx.mapReasonForRHP.keySet());

        if (prodIdsForNarratives.isEmpty()) return;

        Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c
            .getRecordTypeInfosByDeveloperName().get('Narrative')
            .getRecordTypeId();

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

        Map<String, Narrative__c> existingByKey = new Map<String, Narrative__c>();
        for (Narrative__c n : existingNarratives) {
            String key = ProjectProductBatchUtilities.narrativeKey(n.Product__c, n.Language__c, n.Type__c, n.SubType__c);
            existingByKey.put(key, n);
        }

        List<Narrative__c> narrativesToUpsert = new List<Narrative__c>();
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
            ctx.mapInvObj, ctx.languageByProductId, existingByKey,
            'Investment Objective', 'PRIIPS', 'Investment Objective PRIIPS',
            narrativeRecordTypeId, debugInformation
        ));
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
            ctx.mapRisk, ctx.languageByProductId, existingByKey,
            'Risk', 'Main Risk of the Fund', 'Risk Main Risk of the Fund',
            narrativeRecordTypeId, debugInformation
        ));
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
            ctx.mapIntendedRetail, ctx.languageByProductId, existingByKey,
            'PRIIPs', 'INTENDED_RETAIL_INVESTOR', 'PRIIPs Intended Retail Investor',
            narrativeRecordTypeId, debugInformation
        ));
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(
            ctx.mapReasonForRHP, ctx.languageByProductId, existingByKey,
            'PRIIPs', 'REASON_FOR_PHP', 'PRIIPs Reason For PHP',
            narrativeRecordTypeId, debugInformation
        ));

        if (!narrativesToUpsert.isEmpty()) {
            upsert narrativesToUpsert;
            debugInformation.add(LOG_UPSERT + 'Narratives upserted (single DML): ' + narrativesToUpsert.size());
        }
    }

    private static void upsertShareclassNarrativesIfNeeded(ModifContext ctx, List<String> debugInformation) {
        Set<Id> scIdsForNarratives = new Set<Id>();
        scIdsForNarratives.addAll(ctx.mapSCInvObj.keySet());
        scIdsForNarratives.addAll(ctx.mapSCPerfUCITS.keySet());
        scIdsForNarratives.addAll(ctx.mapSCPerfEPT.keySet());

        if (scIdsForNarratives.isEmpty()) return;

        Id narrativeRecordTypeId = Schema.SObjectType.Narrative__c
            .getRecordTypeInfosByDeveloperName().get('Narrative')
            .getRecordTypeId();

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
            ctx.mapSCInvObj, ctx.productByScId, ctx.scLangById, existingByKey,
            'PRIIPs', SUBTYPE_SC_INV_OBJ, NAME_PRIIPS_SC_INVESTMENT_OBJECTIVE,
            narrativeRecordTypeId, debugInformation
        ));
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(
            ctx.mapSCPerfUCITS, ctx.productByScId, ctx.scLangById, existingByKey,
            'PRIIPs', SUBTYPE_PERF_FEE_UCITS_KIID, NAME_PRIIPS_PERF_FEE_UCITS_KIID,
            narrativeRecordTypeId, debugInformation
        ));
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(
            ctx.mapSCPerfEPT, ctx.productByScId, ctx.scLangById, existingByKey,
            'PRIIPs', SUBTYPE_PERF_FEE_EPT_KID, NAME_PRIIPS_PERF_FEE_EPT_KID,
            narrativeRecordTypeId, debugInformation
        ));

        if (!narrativesToUpsert.isEmpty()) {
            upsert narrativesToUpsert;
            debugInformation.add(LOG_UPSERT + '[SC] Narratives upserted (single DML): ' + narrativesToUpsert.size());
        }
    }

    private static List<String> splitList(String semicolonSeparated) {
        List<String> out = new List<String>();
        if (String.isBlank(semicolonSeparated)) return out;
        for (String f : semicolonSeparated.split(';')) {
            if (f != null && !String.isBlank(f.trim())) out.add(f.trim());
        }
        return out;
    }

    private static void applyFieldsOnSObject(
        SObject target,
        SObject source,
        List<String> fieldsToModify,
        List<String> errorMessages,
        Integer[] recordsFailed
    ) {
        for (String field : fieldsToModify) {
            if (String.isBlank(field) || EXCLUDED_FIELDS.contains(field)) continue;
            try {
                target.put(field, source.get(field));
            } catch (Exception e) {
                errorMessages.add(LOG_ERROR + 'Field skipped: ' + field + ' → ' + e.getMessage());
                recordsFailed[0]++;
            }
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
        errorMessages.add(LOG_ERROR + LOG_EXCEPTION_PREFIX + e.getMessage());
        recordsFailed[0]++;
        debugInformation.add('----------------------------------');
        debugInformation.add('[ROLLBACK] ⚠️ Transaction rolled back. Previous logs invalid.');
        debugInformation.add('[ROLLBACK] Reason: ' + e.getMessage());
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
        n.Type__c       = typeVal;
        n.SubType__c    = subtypeVal;
        n.Language__c   = language;
        // n.Product__c  = productId;
        n.ShareClass__c = shareClassId;
        n.Content__c    = richText;
        n.StartDate__c  = System.today();
        bucket.add(n);
    }
}
