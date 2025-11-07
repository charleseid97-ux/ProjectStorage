public class ProjectProductBatchController {

    private static final Set<String> EXCLUDED_FIELDS = new Set<String>{ 'Name' };

    public static Boolean canProcessProjectProduct(ProjectProduct__c pp, List<String> debugInformation, List<String> errorMessages) {
    Boolean isValid = true;

    // Condition : Milestone "Launch Date" = Completed
    Boolean milestoneCompleted = false;
    if(pp.Milestones__r != null && !pp.Milestones__r.isEmpty()) {
        milestoneCompleted = (pp.Milestones__r[0].Status__c == 'Completed');
    }

    // Condition: Tous les Project_Product_Childs__r.Status__c = Completed
    // On requête dans la query avant le execute, si la liste est vide c'est que tout les records sont completed --> (SELECT Id, Status__c FROM Project_Product_Childs__r WHERE Status__c != 'Completed')
    Boolean allChildCompleted = true;
    if(pp.Project_Product_Childs__r != null && !pp.Project_Product_Childs__r.isEmpty()) {
        allChildCompleted = false;
    }

    if (!milestoneCompleted) {
        String msg = '[ERROR] ProjectProduct ' + pp.Id + ' Milestone "Launch Date" not Completed.';
        debugInformation.add(msg);
        errorMessages.add(msg);
        isValid = false;
    }

    if (!allChildCompleted) {
        System.debug('pp.Project_Product_Childs__r:' + pp.Project_Product_Childs__r);
        String msg = '[ERROR] ProjectProduct ' + pp.Id + ' has incomplete Project Product Childs.';
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

    public static void createFundShareclass(List<ProjectProduct__c> listFundCreation, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed,List<Id> insertedRecords) {
        debugInformation.add('[INIT] Fund/Shareclass creation - ' + listFundCreation.size() + ' ProjectProduct(s) to process.');
        Savepoint sp = Database.setSavepoint();
        try{
            Id fundRecordTypeId = Schema.SObjectType.Product__c.getRecordTypeInfosByDeveloperName().get('Fund').getRecordTypeId();
            List<ProjectProduct__c> listProjectProductWFields = ProjectProductBatchUtilities.getProjectProduct(listFundCreation);

            List<Share_Class__c> listNewShareClass = new List<Share_Class__c>();
            List<Product__c> listNewProduct = new List<Product__c>();
            List<FundManagerAssignment__c> listFundManagerAssignmentToUpdate = new List<FundManagerAssignment__c>();
            List<Narrative__c> listNarrative = new List<Narrative__c>();
            Map<Id, Product__c> mapProjectByProductId = new Map<Id, Product__c>();

            if (listProjectProductWFields == null || listProjectProductWFields.isEmpty()) {
                String msg = '[ERROR] No ProjectProduct enriched. Skipping creation.';
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
                    Product__c prod = (Product__c)sObj;
                    insertedProducts.put(prod.Id, prod);
                    insertedRecords.add(prod.Id);
                    debugInformation.add('[SUCCESS] Product inserted: ' + prod.Name + ' (Id: ' + prod.Id + ')');
                }
                for (String err : result.errorMap.values()) {
                    errorMessages.add('[ERROR] Product insert failed: ' + err);
                    recordsFailed[0]++; 
                    throw new DmlException('[ERROR] Product insert failed: ' + err);

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
                    //newSC.OngoingCostsExante__c = sc.EffectiveManagementFees__c + sc.EffectiveServiceFees__c;
                    listNewShareClass.add(newSC);
                    debugInformation.add('[PREPARE] Shareclass from ProjectShareclass ' + sc.Id + ' prepared.');
                }

                for (FundManagerAssignment__c fma : projectProduct.Fund_Manager_Assignments__r) {
                    fma.Product__c = productId;
                    fma.StartDate__c = projectProduct.EndDate__c;
                    listFundManagerAssignmentToUpdate.add(fma);
                    debugInformation.add('[PREPARE] Fund Manager Assignment linked to product ' + productId);
                }

                //THIRD PARTIES
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
                    Id projScId = (Id) sc.get('ProjectShareclass__c'); // tu le renseignes plus haut: newSC.ProjectShareclass__c = sc.Id
                    if (projScId != null) {
                        mapProjSCIdToSCId.put(projScId, sc.Id);
                    }
                    insertedRecords.add(sc.Id);

                    debugInformation.add('[SUCCESS] Shareclass inserted: ' + sc.Id + ' (from ProjectShareclass ' + projScId + ')');
                }
            
                // erreurs : log + compteur
                for (String err : scResult.errorMap.values()) {
                    errorMessages.add('[ERROR] Shareclass insert failed: ' + err);
                    recordsFailed[0]++;
                    throw new DmlException('[ERROR] Shareclass insert failed: ' + err);

                }
            }
            List<Narrative__c> priipsShareclassNarratives = new List<Narrative__c>();

            for (ProjectProduct__c projectProduct : listProjectProductWFields) {
                Product__c insertedProduct = mapProjectByProductId.get(projectProduct.Id);
                
                if (insertedProduct == null) {
                    errorMessages.add('[ERROR] Missing Product for ProjectProduct ' + projectProduct.Id);
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
                        errorMessages.add('[ERROR] Missing Share_Class__c Id for ProjectShareclass ' + psc.Id);
                        recordsFailed[0]++;
                        continue;
                    }
            
                    // 1 Narrative par champ RTF non vide
                    addSCNarrativeIfNotBlank(
                        priipsShareclassNarratives,'PRIIPs Share Class Investment Objective',
                        narrativeRecordTypeId,'PRIIPs', 'Share_Class_Investment_Objective',
                        language, productId, scId, psc.ShareClassInvestmentObjective__c
                    );
                    addSCNarrativeIfNotBlank(
                        priipsShareclassNarratives,'PRIIPs Performance fee UCITS KIID',
                        narrativeRecordTypeId, 'PRIIPs', 'Performance_fee_UCITS_KIID',
                        language, productId, scId, psc.PerformanceFeeUCITSKIID__c
                    );
                    addSCNarrativeIfNotBlank(
                        priipsShareclassNarratives,'PRIIPs Performance fee EPT/KID',
                        narrativeRecordTypeId, 'PRIIPs', 'Performance_fee_EPT/KID',
                        language, productId, scId, psc.PerformanceFeeEPTKID__c
                    );
                }
            }

            List<SObject> toUpsert = new List<SObject>();
            toUpsert.addAll(priipsShareclassNarratives);
            toUpsert.addAll(listFundManagerAssignmentToUpdate);
            toUpsert.addAll(listNarrative);

            if (!toUpsert.isEmpty()) {
                ProjectProductBatchUtilities.UpsertDebugResult result = ProjectProductBatchUtilities.logUpsertResults(toUpsert);
                debugInformation.add('[UPSERT] ' + result.successRecords.size() + ' records upserted.');
                for (SObject currentSObject : result.successRecords.values()) {
                    String objectType = currentSObject.getSObjectType().getDescribe().getName();
                    insertedRecords.add((String)currentSObject.get('Id'));

                    debugInformation.add('[UPSERTED] Type: ' + objectType + ' (Id: ' + currentSObject.get('Id') + ')');
                }
                if (!result.errorMap.isEmpty()) {
                    errorMessages.add('[ERROR] ' + result.errorMap.size() + ' upserts failed.');
                    for (String err : result.errorMap.values()) {
                        errorMessages.add(err);
                        recordsFailed[0]++; 
                        throw new DmlException('[ERROR] ' + result.errorMap.size() + ' upserts failed.');

                    }
                }
            }

            debugInformation.add('[END] Fund/Shareclass creation complete.');
        } catch (Exception e) {
            Database.rollback(sp);
            errorMessages.add('[ERROR] Exception: ' + e.getMessage());
            recordsFailed[0]++;
            debugInformation.add('----------------------------------');
            debugInformation.add('[ROLLBACK] ⚠️ Transaction rolled back. Previous logs invalid.');
            debugInformation.add('[ROLLBACK] Reason: ' + e.getMessage());
        }
    }

    public static void updateFundShareclassModification(List<ProjectProduct__c> listMods, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed,List<Id> insertedRecords) {
        debugInformation.add('[INIT] Fund/Shareclass modification - ' + listMods.size() + ' ProjectProduct(s) to process.');
        Savepoint sp = Database.setSavepoint();
        try {
            List<Product__c> productsToUpdate = new List<Product__c>();
            List<Share_Class__c> shareclassesToUpdate = new List<Share_Class__c>();

            List<ProjectProduct__c> listWithFields = ProjectProductBatchUtilities.getProjectProduct(listMods);
            Map<Id, Product__c> productMap = ProjectProductBatchUtilities.getMapProductByProductId(listWithFields);
            Map<Id, Share_Class__c> shareclassMap = ProjectProductBatchUtilities.getMapShareClassByShareclassId(listWithFields);

            if (productMap == null) {
                errorMessages.add('[ERROR] mapProductByProductId is null.');
                recordsFailed[0]++;
                return;
            }

            for (ProjectProduct__c pp : listWithFields) {
                Product__c product = productMap.get(pp.Product__c);
                if (!String.isEmpty(pp.TECH_FieldsToModify__c)) {
                    for (String field : pp.TECH_FieldsToModify__c.split(';')) {
                        if (!EXCLUDED_FIELDS.contains(field)) {
                            try {
                                product.put(field, pp.get(field));
                            } catch (Exception e) {
                                errorMessages.add('[ERROR] Field skipped: ' + field + ' → ' + e.getMessage());
                                recordsFailed[0]++;
                            }
                        }
                    }
                    productsToUpdate.add(product);
                }

                for (ProjectShareclass__c sc : pp.ProjectShareclasses__r) {
                    if (sc.TECH_ShareClass__c != null && shareclassMap.containsKey(Id.valueOf(sc.TECH_ShareClass__c))) {
                        Share_Class__c scToUpdate = shareclassMap.get(Id.valueOf(sc.TECH_ShareClass__c));
                        scToUpdate.ESMAApplicationStartDate__c = pp.EndDate__c;
                        if (!String.isEmpty(sc.TECH_FieldsToModify__c)) {
                            for (String field : sc.TECH_FieldsToModify__c.split(';')) {
                                try {
                                    scToUpdate.put(field, sc.get(field));
                                } catch (Exception e) {
                                    errorMessages.add('[ERROR] Shareclass field skipped: ' + field + ' → ' + e.getMessage());
                                    recordsFailed[0]++;
                                }
                            }
                        }
                        shareclassesToUpdate.add(scToUpdate);
                    }
                }
            }

            if (!productsToUpdate.isEmpty()) {
                update productsToUpdate;
                debugInformation.add('[UPDATE] Products updated: ' + productsToUpdate);
            }
            if (!shareclassesToUpdate.isEmpty()) {
                update shareclassesToUpdate;
                debugInformation.add('[UPDATE] Shareclasses updated: ' + shareclassesToUpdate);
            }

            debugInformation.add('[END] Fund/Shareclass modification complete.');
    
        } catch (Exception e) {
            Database.rollback(sp);
            errorMessages.add('[ERROR] Exception: ' + e.getMessage());
            recordsFailed[0]++;
            debugInformation.add('----------------------------------');
            debugInformation.add('[ROLLBACK] ⚠️ Transaction rolled back. Previous logs invalid.');
            debugInformation.add('[ROLLBACK] Reason: ' + e.getMessage());
        }

    }

    public static void createShareclasses(List<ProjectProduct__c> listShareclassCreation, List<String> debugInformation, List<String> errorMessages, Integer[] recordsFailed, List<Id> insertedRecords) {
        debugInformation.add('[INIT] Shareclass creation for ' + listShareclassCreation.size() + ' ProjectProduct(s).');
        Savepoint sp = Database.setSavepoint();
        try{

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

            if (!listNewShareClass.isEmpty()) {
                ProjectProductBatchUtilities.UpsertDebugResult result = ProjectProductBatchUtilities.logUpsertResults(listNewShareClass);
                debugInformation.add('[UPSERT] ' + result.successRecords.size() + ' Shareclasses created.');
                for (SObject currentSObject : result.successRecords.values()) {
                    String objectType = currentSObject.getSObjectType().getDescribe().getName();
                    debugInformation.add('[UPSERTED] Type: ' + objectType + ' (Id: ' + currentSObject.get('Id') + ')');
                    insertedRecords.add((String)currentSObject.get('Id') );

                }
                for (String err : result.errorMap.values()) {
                    errorMessages.add('[ERROR] Shareclass insert failed: ' + err);
                    recordsFailed[0]++;
                    throw new DmlException('Shareclass insert failed: ' + err);
                }
            }

            debugInformation.add('[END] Shareclass creation complete.');
        } catch (Exception e) {
            Database.rollback(sp);
            errorMessages.add('[ERROR] Exception: ' + e.getMessage());
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
    ){
        if (String.isBlank(richText)) return;

        Narrative__c n = new Narrative__c();
        n.RecordTypeId   = recordTypeId;
        n.Name           = Name;
        n.Type__c        = typeVal;         // 'PRIIPs'
        n.SubType__c     = subtypeVal;      // ex: 'Performance fee UCITS KIID'
        n.Language__c    = language;
        n.Product__c     = productId;       // utile pour le reporting
        n.ShareClass__c  = shareClassId;    // lien vers la SC créée
        n.Content__c     = richText;        // <-- remplace par l'API du champ RTF sur Narrative si différent
        n.StartDate__c   = System.today();
        bucket.add(n);
    }
}