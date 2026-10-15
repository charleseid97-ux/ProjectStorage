/** ──────────────────────────────────────
 * @description Logic of ProjectProductBatch: on the launch date, creates the Product__c / Share_Class__c of creation
 *                  projects and applies the selected fields of modification projects, with their narratives,
 *                  Fund Manager Assignments and Tax Data.
 *              A created Product__c takes its project's Scope__c (blank = PS) and PMTScope__c = true (US-20123).
 * @lastModifiedBy Charles EID   [15-10-26]
 * @testClass Test_ProjectProductBatch
 * @coverage 94%   [15-10-26]
 ────────────────────────────────────── */
public class ProjectProductBatchController {

    private static final Set<String> EXCLUDED_FIELDS = new Set<String>{ 'Name' };
    private static final Id FUND_RECORD_TYPE_ID = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
    private static final Id NARRATIVE_RECORD_TYPE_ID = Schema.SObjectType.Narrative__c.getRecordTypeInfosByDeveloperName().get('Narrative').getRecordTypeId();

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

    public static Boolean canProcessProjectProduct(ProjectProduct__c pp, List<String> debugInformation, List<String> errorMessages) {
        Boolean milestoneCompleted = pp.Milestones__r != null && !pp.Milestones__r.isEmpty() && pp.Milestones__r[0].Status__c == 'Completed';
        Boolean allChildCompleted = pp.Project_Product_Childs__r == null || pp.Project_Product_Childs__r.isEmpty();

        if (!milestoneCompleted) logError(LOG_ERROR + 'ProjectProduct ' + pp.Id + ' Milestone "Launch Date" not Completed.', debugInformation, errorMessages);

        if (!allChildCompleted) {
            System.debug('pp.Project_Product_Childs__r:' + pp.Project_Product_Childs__r);
            logError(LOG_ERROR + 'ProjectProduct ' + pp.Id + ' has incomplete Project Product Childs.', debugInformation, errorMessages);
        }

        Boolean isValid = milestoneCompleted && allChildCompleted;
        if (isValid) {
            debugInformation.add('[CHECK PASSED] ProjectProduct ' + pp.Id + ' ready for processing.');
        }
        else {
            debugInformation.add('[SKIP] ProjectProduct ' + pp.Id + ' will not be processed.');
        }
        return isValid;
    }

    public static void createFundShareclass(List<ProjectProduct__c> listFundCreation, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed, List<Id> insertedRecords, List<Id> launchedProjectProductIds) {
        debugInformation.add('[INIT] Fund/Shareclass creation - ' + listFundCreation.size() + ' ProjectProduct(s) to process.');
        Savepoint sp = Database.setSavepoint();

        try {
            List<ProjectProduct__c> listProjectProductWFields = ProjectProductBatchUtilities.getProjectProduct(listFundCreation);
            List<Share_Class__c> listNewShareClass = new List<Share_Class__c>();
            List<Product__c> listNewProduct = new List<Product__c>();
            List<FundManagerAssignment__c> listFundManagerAssignmentToUpdate = new List<FundManagerAssignment__c>();
            List<Narrative__c> listNarrative = new List<Narrative__c>();
            Map<Id, Product__c> mapProjectByProductId = new Map<Id, Product__c>();

            if (listProjectProductWFields == null || listProjectProductWFields.isEmpty()) {
                logError(LOG_ERROR + 'No ProjectProduct enriched. Skipping creation.', debugInformation, errorMessages);
                recordsFailed[0]++;
                return;
            }

            // Préparation des Product__c
            for (ProjectProduct__c projectProduct : listProjectProductWFields) {
                Product__c newProduct = ProjectProductBatchUtilities.getNewProduct(projectProduct);
                newProduct.ParentProject__c = projectProduct.Id;
                newProduct.RecordTypeId = FUND_RECORD_TYPE_ID;
                newProduct.LaunchDate__c = projectProduct.EndDate__c;
                newProduct.Name = projectProduct.InternalShortName__c;
                newProduct.Validity__c = true;
                // US-20123: the product takes its project's Scope (blank = PS) and is flagged as created by the PMT
                newProduct.Scope__c = ProjectProductSetupHandlerUtilities.normalizeScope(projectProduct.Scope__c);
                newProduct.PMTScope__c = true;

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
                failOnInsertErrors(result, 'Product', errorMessages, recordsFailed);
            }

            // Préparation Share Classes, FMA et narratives Product (tous les Products sont insérés ici : un échec d'insertion a déjà levé une exception)
            for (ProjectProduct__c projectProduct : listProjectProductWFields) {
                Id productId = mapProjectByProductId.get(projectProduct.Id).Id;

                for (ProjectShareclass__c sc : projectProduct.ProjectShareclasses__r) {
                    listNewShareClass.add(buildShareclass(sc, productId, projectProduct.EndDate__c));
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

                listNarrative.addAll(ProjectProductBatchUtilities.createNarratives(projectProduct, NARRATIVE_RECORD_TYPE_ID, getLanguage(projectProduct), productId, 'Product'));
            }

            Map<Id, Id> mapProjSCIdToSCId = insertShareclasses(listNewShareClass, debugInformation, errorMessages, recordsFailed, insertedRecords);
            List<Narrative__c> priipsShareclassNarratives = new List<Narrative__c>();
            List<TaxData__c> taxDataToUpdate = new List<TaxData__c>();

            // Liaison TaxData + création narratives Shareclass
            for (ProjectProduct__c projectProduct : listProjectProductWFields) {
                Id productId = mapProjectByProductId.get(projectProduct.Id).Id;
                if (projectProduct.ProjectShareclasses__r != null) addShareclassNarratives(projectProduct, productId, mapProjSCIdToSCId, priipsShareclassNarratives);
                linkTaxData(projectProduct, productId, mapProjSCIdToSCId, taxDataToUpdate);
            }

            // Création des narratives Risk depuis les templates Custom Metadata
            List<Narrative__c> riskNarratives = NarrativeTemplateService.buildRiskNarratives(insertedProducts.values());

            List<SObject> toUpsert = new List<SObject>();
            toUpsert.addAll(priipsShareclassNarratives);
            toUpsert.addAll(riskNarratives);
            toUpsert.addAll(listFundManagerAssignmentToUpdate);
            toUpsert.addAll(listNarrative);
            toUpsert.addAll(taxDataToUpdate);
            upsertAndLog(toUpsert, debugInformation, errorMessages, recordsFailed, insertedRecords);

            markLaunched(listFundCreation, launchedProjectProductIds);
            debugInformation.add('[END] Fund/Shareclass creation complete.');
        }
        catch (Exception e) {
            rollbackAndLog(sp, e, debugInformation, errorMessages, recordsFailed);
        }
    }

    public static void updateFundShareclassModification(List<ProjectProduct__c> listMods, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed, List<Id> insertedRecords, List<Id> launchedProjectProductIds) {
        debugInformation.add('[INIT] Fund/Shareclass modification - ' + listMods.size() + ' ProjectProduct(s) to process.');
        Savepoint sp = Database.setSavepoint();

        try {
            List<ProjectProduct__c> listWithFields = ProjectProductBatchUtilities.getProjectProduct(listMods);
            Map<Id, Product__c> productMap = ProjectProductBatchUtilities.getMapProductByProductId(listWithFields);
            Map<Id, Share_Class__c> shareclassMap = ProjectProductBatchUtilities.getMapShareClassByShareclassId(listWithFields);

            if (productMap == null) {
                errorMessages.add(LOG_ERROR + 'mapProductByProductId is null.');
                recordsFailed[0]++;
                return;
            }

            // Traitement Product + Shareclass, extrait pour réduire la complexité Sonar
            ModificationContext context = new ModificationContext();
            for (ProjectProduct__c pp : listWithFields) {
                processProductModification(pp, productMap, shareclassMap, context, errorMessages, recordsFailed);
            }

            if (!context.productsToUpdate.isEmpty()) {
                update context.productsToUpdate;
                debugInformation.add('[UPDATE] Products updated: ' + context.productsToUpdate.size());

                // Création ou mise à jour des narratives Risk liées aux produits
                List<SObject> riskNarratives = new List<SObject>();
                riskNarratives.addAll(NarrativeTemplateService.buildRiskNarratives(context.productsToUpdate));
                upsertAndLog(riskNarratives, debugInformation, errorMessages, recordsFailed, insertedRecords);
            }

            upsertProductNarratives(context, debugInformation);

            if (!context.shareclassesToUpdate.isEmpty()) {
                update context.shareclassesToUpdate;
                debugInformation.add('[UPDATE] Shareclasses updated: ' + context.shareclassesToUpdate.size());
            }

            upsertShareclassNarratives(context, debugInformation);

            markLaunched(listMods, launchedProjectProductIds);
            debugInformation.add('[END] Fund/Shareclass modification complete.');
        }
        catch (Exception e) {
            rollbackAndLog(sp, e, debugInformation, errorMessages, recordsFailed);
        }
    }

    public static void createShareclasses(List<ProjectProduct__c> listShareclassCreation, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed, List<Id> insertedRecords, List<Id> launchedProjectProductIds) {
        debugInformation.add('[INIT] Shareclass creation for ' + listShareclassCreation.size() + ' ProjectProduct(s).');
        Savepoint sp = Database.setSavepoint();

        try {
            List<Share_Class__c> listNewShareClass = new List<Share_Class__c>();
            List<ProjectProduct__c> projectProducts = ProjectProductBatchUtilities.getProjectProduct(listShareclassCreation);
            Map<Id, Product__c> productMap = ProjectProductBatchUtilities.getMapProductByProductId(projectProducts);

            for (ProjectProduct__c pp : projectProducts) {
                Product__c product = productMap.get(pp.Product__c);

                for (ProjectShareclass__c sc : pp.ProjectShareclasses__r) {
                    Share_Class__c newSC = buildShareclass(sc, product.Id, pp.EndDate__c);
                    newSC.Status__c = 'Active';
                    listNewShareClass.add(newSC);
                    debugInformation.add('[PREPARE] New Shareclass from ProjectShareclass: ' + sc.Id);
                }
            }

            Map<Id, Id> mapProjSCIdToSCId = insertShareclasses(listNewShareClass, debugInformation, errorMessages, recordsFailed, insertedRecords);
            List<TaxData__c> taxDataToUpdate = new List<TaxData__c>();
            List<Narrative__c> priipsShareclassNarratives = new List<Narrative__c>();

            // Liaison des TaxData aux objets créés
            for (ProjectProduct__c pp : projectProducts) {
                Product__c product = productMap.get(pp.Product__c);
                linkTaxData(pp, product.Id, mapProjSCIdToSCId, taxDataToUpdate);
                addShareclassNarratives(pp, product.Id, mapProjSCIdToSCId, priipsShareclassNarratives);
            }

            List<SObject> toUpsert = new List<SObject>();
            toUpsert.addAll(priipsShareclassNarratives);
            toUpsert.addAll(taxDataToUpdate);
            upsertAndLog(toUpsert, debugInformation, errorMessages, recordsFailed, insertedRecords);

            markLaunched(listShareclassCreation, launchedProjectProductIds);
            debugInformation.add('[END] Shareclass creation complete.');
        }
        catch (Exception e) {
            rollbackAndLog(sp, e, debugInformation, errorMessages, recordsFailed);
        }
    }

    // ------------------------- Helpers - création / insertion ---------------------------

    // Share Class créée depuis sa ProjectShareclass, rattachée au Product et lancée à la date du projet
    private static Share_Class__c buildShareclass(ProjectShareclass__c sc, Id productId, Date launchDate) {
        Share_Class__c newSC = ProjectProductBatchUtilities.getNewShareclass(sc, productId);
        newSC.Name = sc.Share_Class_Name__c;
        newSC.LaunchDate__c = launchDate;
        newSC.ProjectShareclass__c = sc.Id;
        newSC.OngoingCostsExante__c = getOngoingCosts(sc);
        return newSC;
    }

    private static Decimal getOngoingCosts(ProjectShareclass__c sc) {
        Decimal mgmtFees = sc.EffectiveManagementFees__c != null ? sc.EffectiveManagementFees__c : 0;
        Decimal serviceFees = sc.EffectiveServiceFees__c != null ? sc.EffectiveServiceFees__c : 0;
        return mgmtFees + serviceFees;
    }

    private static String getLanguage(ProjectProduct__c pp) {
        return pp.DomiciledIn__c == 'FR' ? 'French' : 'English';
    }

    private static Map<Id, Id> insertShareclasses(List<Share_Class__c> listNewShareClass, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed, List<Id> insertedRecords) {
        Map<Id, Id> mapProjSCIdToSCId = new Map<Id, Id>();
        if (listNewShareClass.isEmpty()) return mapProjSCIdToSCId;

        ProjectProductBatchUtilities.UpsertDebugResult result = ProjectProductBatchUtilities.logUpsertResults(listNewShareClass);
        debugInformation.add(LOG_UPSERT + result.successRecords.size() + ' Shareclasses created.');

        for (SObject currentSObject : result.successRecords.values()) {
            Share_Class__c sc = (Share_Class__c) currentSObject;
            Id projScId = (Id) sc.get('ProjectShareclass__c');
            if (projScId != null) mapProjSCIdToSCId.put(projScId, sc.Id);

            insertedRecords.add(sc.Id);
            debugInformation.add('[SUCCESS] Shareclass inserted: ' + sc.Id + ' (from ProjectShareclass ' + projScId + ')');
        }

        failOnInsertErrors(result, 'Shareclass', errorMessages, recordsFailed);
        return mapProjSCIdToSCId;
    }

    // Une erreur d'insertion stoppe le traitement : la première est loggée puis levée (rollback par l'appelant)
    private static void failOnInsertErrors(ProjectProductBatchUtilities.UpsertDebugResult result, String objectLabel, List<String> errorMessages, Integer[] recordsFailed) {
        for (String err : result.errorMap.values()) {
            errorMessages.add(LOG_ERROR + objectLabel + ' insert failed: ' + err);
            recordsFailed[0]++;
            throw new DmlException(LOG_ERROR + objectLabel + ' insert failed: ' + err);
        }
    }

    // Rattache les TaxData du projet au Product et aux Share Classes créés
    private static void linkTaxData(ProjectProduct__c projectProduct, Id productId, Map<Id, Id> mapProjSCIdToSCId, List<TaxData__c> taxDataToUpdate) {
        if (projectProduct.Tax_Data__r == null) return;

        for (TaxData__c td : projectProduct.Tax_Data__r) {
            if (td.Product__c == null) td.Product__c = productId;
            if (td.ShareClass__c == null) td.ShareClass__c = mapProjSCIdToSCId.get(td.ProjectShareclass__c);
            taxDataToUpdate.add(td);
        }
    }

    // Le projet est marqué comme lancé uniquement si l'ensemble du traitement est arrivé à son terme.
    private static void markLaunched(List<ProjectProduct__c> projectProducts, List<Id> launchedProjectProductIds) {
        for (ProjectProduct__c projectProduct : projectProducts) {
            launchedProjectProductIds.add(projectProduct.Id);
        }
    }

    // ------------------------- Helpers - modification ---------------------------

    // Records à mettre à jour et contenus de narratives collectés sur les projets de modification, puis écrits en fin de traitement
    private class ModificationContext {
        public List<Product__c> productsToUpdate = new List<Product__c>();
        public List<Share_Class__c> shareclassesToUpdate = new List<Share_Class__c>();

        // Narratives Product : contenu par Product Id, et langue du Product
        public Map<Id, String> mapInvObj = new Map<Id, String>();
        public Map<Id, String> mapRisk = new Map<Id, String>();
        public Map<Id, String> mapIntendedRetail = new Map<Id, String>();
        public Map<Id, String> mapReasonForRHP = new Map<Id, String>();
        public Map<Id, String> languageByProductId = new Map<Id, String>();

        // Narratives Share Class : contenu par Share Class Id, langue et Product de la Share Class
        public Map<Id, String> mapSCInvObj = new Map<Id, String>();
        public Map<Id, String> mapSCPerfUCITS = new Map<Id, String>();
        public Map<Id, String> mapSCPerfEPT = new Map<Id, String>();
        public Map<Id, String> scLangById = new Map<Id, String>();
        public Map<Id, Id> productByScId = new Map<Id, Id>();
    }

    private static void processProductModification(ProjectProduct__c pp, Map<Id, Product__c> productMap, Map<Id, Share_Class__c> shareclassMap, ModificationContext context, List<String> errorMessages, Integer[] recordsFailed) {
        Product__c product = productMap.get(pp.Product__c);
        context.languageByProductId.put(pp.Product__c, getLanguage(pp));

        List<String> fieldsToModify = getFieldsToModify(pp.TECH_FieldsToModify__c);
        fillProductNarrativeMaps(pp, fieldsToModify, context);
        applyProductFieldUpdates(product, pp, fieldsToModify, errorMessages, recordsFailed);
        context.productsToUpdate.add(product);

        for (ProjectShareclass__c sc : pp.ProjectShareclasses__r) {
            processShareclassModification(sc, pp, shareclassMap, context, errorMessages, recordsFailed);
        }
    }

    private static List<String> getFieldsToModify(String rawFields) {
        List<String> fieldsToModify = new List<String>();
        if (String.isBlank(rawFields)) return fieldsToModify;

        for (String fieldName : rawFields.split(';')) {
            if (!String.isBlank(fieldName)) fieldsToModify.add(fieldName.trim());
        }
        return fieldsToModify;
    }

    private static void fillProductNarrativeMaps(ProjectProduct__c pp, List<String> fieldsToModify, ModificationContext context) {
        Id prodId = pp.Product__c;
        if (fieldsToModify.contains('InvestmentObjective__c')) context.mapInvObj.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'InvestmentObjective__c'));
        if (fieldsToModify.contains('RiskAssociated__c')) context.mapRisk.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'RiskAssociated__c'));
        if (fieldsToModify.contains('IntentedRetailInvestor__c')) context.mapIntendedRetail.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'IntentedRetailInvestor__c'));
        if (fieldsToModify.contains('ReasonForRHP__c')) context.mapReasonForRHP.put(prodId, ProjectProductBatchUtilities.getContentForField(pp, 'ReasonForRHP__c'));
    }

    private static void applyProductFieldUpdates(Product__c product, ProjectProduct__c pp, List<String> fieldsToModify, List<String> errorMessages, Integer[] recordsFailed) {
        for (String fieldName : fieldsToModify) {
            if (String.isBlank(fieldName) || EXCLUDED_FIELDS.contains(fieldName)) continue;

            try {
                product.put(fieldName, pp.get(fieldName));
            }
            catch (Exception e) {
                errorMessages.add(LOG_ERROR + 'Field skipped: ' + fieldName + ' → ' + e.getMessage());
                recordsFailed[0]++;
            }
        }
    }

    private static void processShareclassModification(ProjectShareclass__c sc, ProjectProduct__c pp, Map<Id, Share_Class__c> shareclassMap, ModificationContext context, List<String> errorMessages, Integer[] recordsFailed) {
        if (String.isBlank(sc.TECH_ShareClass__c) || shareclassMap == null) return;

        Id shareClassId;
        try {
            shareClassId = Id.valueOf(sc.TECH_ShareClass__c);
        }
        catch (Exception e) {
            errorMessages.add(LOG_ERROR + 'Invalid Shareclass Id: ' + sc.TECH_ShareClass__c + ' → ' + e.getMessage());
            recordsFailed[0]++;
            return;
        }

        if (!shareclassMap.containsKey(shareClassId)) return;

        Share_Class__c scToUpdate = shareclassMap.get(shareClassId);
        Id scId = scToUpdate.Id;
        context.scLangById.put(scId, getLanguage(pp));
        context.productByScId.put(scId, pp.Product__c);

        Set<String> scFieldsToModify = new Set<String>(getFieldsToModify(sc.TECH_FieldsToModify__c));
        fillShareclassNarrativeMaps(sc, scId, scFieldsToModify, context);
        scToUpdate.ESMAApplicationStartDate__c = pp.EndDate__c;
        applyShareclassFieldUpdates(scToUpdate, sc, scFieldsToModify, errorMessages, recordsFailed);
        context.shareclassesToUpdate.add(scToUpdate);
    }

    private static void fillShareclassNarrativeMaps(ProjectShareclass__c sc, Id scId, Set<String> scFieldsToModify, ModificationContext context) {
        if (scFieldsToModify.contains('ShareclassInvestmentObjective__c') && !String.isBlank(sc.ShareclassInvestmentObjective__c)) context.mapSCInvObj.put(scId, sc.ShareclassInvestmentObjective__c);
        if (scFieldsToModify.contains('PerformanceFeeUCITSKIID__c') && !String.isBlank(sc.PerformanceFeeUCITSKIID__c)) context.mapSCPerfUCITS.put(scId, sc.PerformanceFeeUCITSKIID__c);
        if (scFieldsToModify.contains('PerformanceFeeEPTKID__c') && !String.isBlank(sc.PerformanceFeeEPTKID__c)) context.mapSCPerfEPT.put(scId, sc.PerformanceFeeEPTKID__c);
    }

    private static void applyShareclassFieldUpdates(Share_Class__c scToUpdate, ProjectShareclass__c sc, Set<String> fieldsToModify, List<String> errorMessages, Integer[] recordsFailed) {
        for (String fieldName : fieldsToModify) {
            try {
                scToUpdate.put(fieldName, sc.get(fieldName));
            }
            catch (Exception e) {
                errorMessages.add(LOG_ERROR + 'Shareclass field skipped: ' + fieldName + ' → ' + e.getMessage());
                recordsFailed[0]++;
            }
        }
    }

    // ------------------------- Helpers - narratives ---------------------------

    private static void addShareclassNarratives(ProjectProduct__c pp, Id productId, Map<Id, Id> mapProjSCIdToSCId, List<Narrative__c> priipsShareclassNarratives) {
        String language = getLanguage(pp);

        for (ProjectShareclass__c psc : pp.ProjectShareclasses__r) {
            Id scId = mapProjSCIdToSCId.get(psc.Id);
            addSCNarrativeIfNotBlank(priipsShareclassNarratives, PRIIPS_SC_INVESTMENT_OBJECTIVE, SUBTYPE_SC_INVESTMENT_OBJECTIVE, language, scId, psc.ShareclassInvestmentObjective__c);
            addSCNarrativeIfNotBlank(priipsShareclassNarratives, PRIIPS_PERF_FEE_UCITS, SUBTYPE_PERF_FEE_UCITS, language, scId, psc.PerformanceFeeUCITSKIID__c);
            addSCNarrativeIfNotBlank(priipsShareclassNarratives, PRIIPS_PERF_FEE_EPT, SUBTYPE_PERF_FEE_EPT, language, scId, psc.PerformanceFeeEPTKID__c);
        }
    }

    // Narrative PRIIPs de Share Class (Type PRIIPs, scope Shareclass), ajoutée seulement si le contenu est renseigné
    private static void addSCNarrativeIfNotBlank(List<Narrative__c> bucket, String nameValue, String subtypeVal, String language, Id shareClassId, String richText) {
        if (String.isBlank(richText)) return;

        bucket.add(new Narrative__c(RecordTypeId = NARRATIVE_RECORD_TYPE_ID, Name = nameValue, Type__c = TYPE_PRIIPS, SubType__c = subtypeVal, Language__c = language, ShareClass__c = shareClassId, Content__c = richText, Narrative_Scope__c = 'Shareclass', StartDate__c = System.today()));
    }

    private static void upsertProductNarratives(ModificationContext context, List<String> debugInformation) {
        Set<Id> prodIdsForNarratives = new Set<Id>();
        prodIdsForNarratives.addAll(context.mapInvObj.keySet());
        prodIdsForNarratives.addAll(context.mapRisk.keySet());
        prodIdsForNarratives.addAll(context.mapIntendedRetail.keySet());
        prodIdsForNarratives.addAll(context.mapReasonForRHP.keySet());
        if (prodIdsForNarratives.isEmpty()) return;

        List<Narrative__c> existingNarratives = [SELECT Id, Product__c, Language__c, Type__c, SubType__c, Content__c
                                                 FROM Narrative__c
                                                 WHERE Product__c IN :prodIdsForNarratives
                                                 AND ((Type__c = 'Investment Objective' AND SubType__c = 'PRIIPS') OR (Type__c = 'Risk' AND SubType__c = 'Main Risk of the Fund') OR (Type__c = :TYPE_PRIIPS AND SubType__c = 'INTENDED_RETAIL_INVESTOR') OR (Type__c = :TYPE_PRIIPS AND SubType__c = 'REASON_FOR_PHP'))];

        Map<String, Narrative__c> existingByKey = new Map<String, Narrative__c>();
        for (Narrative__c n : existingNarratives) {
            existingByKey.put(ProjectProductBatchUtilities.narrativeKey(n.Product__c, n.Language__c, n.Type__c, n.SubType__c), n);
        }

        List<Narrative__c> narrativesToUpsert = new List<Narrative__c>();
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(context.mapInvObj, context.languageByProductId, existingByKey, 'Investment Objective', 'PRIIPS', 'Investment Objective PRIIPS', NARRATIVE_RECORD_TYPE_ID, debugInformation));
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(context.mapRisk, context.languageByProductId, existingByKey, 'Risk', 'Main Risk of the Fund', 'Risk Main Risk of the Fund', NARRATIVE_RECORD_TYPE_ID, debugInformation));
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(context.mapIntendedRetail, context.languageByProductId, existingByKey, TYPE_PRIIPS, 'INTENDED_RETAIL_INVESTOR', 'PRIIPs Intended Retail Investor', NARRATIVE_RECORD_TYPE_ID, debugInformation));
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildNarrativesForField(context.mapReasonForRHP, context.languageByProductId, existingByKey, TYPE_PRIIPS, 'REASON_FOR_PHP', 'PRIIPs Reason For PHP', NARRATIVE_RECORD_TYPE_ID, debugInformation));

        if (!narrativesToUpsert.isEmpty()) {
            upsert narrativesToUpsert;
            debugInformation.add(LOG_UPSERT + 'Narratives upserted (single DML): ' + narrativesToUpsert.size());
        }
    }

    private static void upsertShareclassNarratives(ModificationContext context, List<String> debugInformation) {
        Set<Id> scIdsForNarratives = new Set<Id>();
        scIdsForNarratives.addAll(context.mapSCInvObj.keySet());
        scIdsForNarratives.addAll(context.mapSCPerfUCITS.keySet());
        scIdsForNarratives.addAll(context.mapSCPerfEPT.keySet());
        if (scIdsForNarratives.isEmpty()) return;

        List<Narrative__c> existingSCNarratives = [SELECT Id, ShareClass__c, Language__c, Type__c, SubType__c, Content__c, Product__c
                                                   FROM Narrative__c
                                                   WHERE ShareClass__c IN :scIdsForNarratives AND Type__c = :TYPE_PRIIPS AND SubType__c IN (:SUBTYPE_SC_INVESTMENT_OBJECTIVE, :SUBTYPE_PERF_FEE_UCITS, :SUBTYPE_PERF_FEE_EPT)];

        Map<String, Narrative__c> existingByKey = new Map<String, Narrative__c>();
        for (Narrative__c n : existingSCNarratives) {
            existingByKey.put(ProjectProductBatchUtilities.scNarrativeKey(n.ShareClass__c, n.Language__c, n.Type__c, n.SubType__c), n);
        }

        List<Narrative__c> narrativesToUpsert = new List<Narrative__c>();
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(context.mapSCInvObj, context.productByScId, context.scLangById, existingByKey, TYPE_PRIIPS, SUBTYPE_SC_INVESTMENT_OBJECTIVE, PRIIPS_SC_INVESTMENT_OBJECTIVE, NARRATIVE_RECORD_TYPE_ID, debugInformation));
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(context.mapSCPerfUCITS, context.productByScId, context.scLangById, existingByKey, TYPE_PRIIPS, SUBTYPE_PERF_FEE_UCITS, PRIIPS_PERF_FEE_UCITS, NARRATIVE_RECORD_TYPE_ID, debugInformation));
        narrativesToUpsert.addAll(ProjectProductBatchUtilities.buildShareClassNarrativesForField(context.mapSCPerfEPT, context.productByScId, context.scLangById, existingByKey, TYPE_PRIIPS, SUBTYPE_PERF_FEE_EPT, PRIIPS_PERF_FEE_EPT, NARRATIVE_RECORD_TYPE_ID, debugInformation));

        if (!narrativesToUpsert.isEmpty()) {
            upsert narrativesToUpsert;
            debugInformation.add(LOG_UPSERT + '[SC] Narratives upserted (single DML): ' + narrativesToUpsert.size());
        }
    }

    // ------------------------- Helpers - DML / rollback / logs ---------------------------

    private static void upsertAndLog(List<SObject> toUpsert, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed, List<Id> insertedRecords) {
        if (toUpsert.isEmpty()) return;

        ProjectProductBatchUtilities.UpsertDebugResult result = ProjectProductBatchUtilities.logUpsertResults(toUpsert);
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

    private static void rollbackAndLog(Savepoint sp, Exception e, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed) {
        Database.rollback(sp);
        errorMessages.add(LOG_ERROR + 'Exception: ' + e.getMessage());
        recordsFailed[0]++;
        debugInformation.add('----------------------------------');
        debugInformation.add('[ROLLBACK] ⚠️ Transaction rolled back. Previous logs invalid.');
        debugInformation.add('[ROLLBACK] Reason: ' + e.getMessage());
    }

    // Message ajouté à la fois aux informations de debug et aux erreurs du batch
    private static void logError(String msg, List<String> debugInformation, List<String> errorMessages) {
        debugInformation.add(msg);
        errorMessages.add(msg);
    }
}