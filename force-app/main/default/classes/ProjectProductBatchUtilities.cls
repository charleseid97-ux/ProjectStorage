public class ProjectProductBatchUtilities {

    public static List<Narrative__c> createNarratives(ProjectProduct__c projectProduct, String recordTypeId, String language, String productId, String scope) {
        List<Narrative__c> newNarrative = new List<Narrative__c>();
        String investmentStrategy = projectProduct.InvestmentStrategy__c;
        String investmentObjective = projectProduct.InvestmentObjective__c;
        String riskAssociatedMultiPicklist = projectProduct.RiskAssociated__c;
        //String riskNotConsideredPicklist = projectProduct.RiskNotConsideredinIndicator__c;
        String intendedRetail = projectProduct.IntentedRetailInvestor__c;
        String reasonForRHP = projectProduct.ReasonForRHP__c;
        /*String redeemCondition = projectProduct.RedeemCondition__c;
        String lmt = projectProduct.LMT__c;*/

        if (investmentObjective != '') {
            Narrative__c investmentObjectiveNarrative = new Narrative__c(Name = 'Investment Objective PRIIPS', RecordTypeId = recordTypeId, Narrative_Scope__c = scope,
                                                                        Type__c = 'Investment Objective', SubType__c = 'PRIIPS', Language__c = language, 
                                                                        Product__c = productId, Content__c = investmentObjective, StartDate__c = System.today());
            newNarrative.add(investmentObjectiveNarrative);
        }
        
        if (investmentStrategy != '') {
            Narrative__c investmentStrategyNarrative = new Narrative__c(Name = 'Investment Strategy Description', RecordTypeId = recordTypeId, Narrative_Scope__c = scope,
                                                                        Type__c = 'Investment Strategy', SubType__c = 'Description', Language__c = language, 
                                                                        Product__c = productId, Content__c = investmentStrategy, StartDate__c = System.today());
            newNarrative.add(investmentStrategyNarrative);
        }

        if (riskAssociatedMultiPicklist != '') {
            String content = getRiskNarrativeContent(riskAssociatedMultiPicklist);
            Narrative__c riskAssociatedMultiPicklistNarrative = new Narrative__c(Name = 'Risk Main Risk of the Fund', RecordTypeId = recordTypeId, Narrative_Scope__c = scope, 
                                                                        Type__c = 'Risk', SubType__c = 'Main Risk of the Fund', Language__c = language, 
                                                                        Product__c = productId, Content__c = content, StartDate__c = System.today());
            newNarrative.add(riskAssociatedMultiPicklistNarrative);
        }
        // Send Legal form
        /*if (riskNotConsideredPicklist != '') {
            String content = getRiskNotConsideredContent(riskNotConsideredPicklist);
            Narrative__c riskNotConsideredPicklistNarrative = new Narrative__c(Name = 'Risk Main Risk of the Fund', RecordTypeId = recordTypeId, Narrative_Scope__c = scope, 
                                                                        Type__c = 'Risk', SubType__c = 'Main Risk of the Fund', Language__c = language, 
                                                                        Product__c = productId, Content__c = content, StartDate__c = System.today());
            newNarrative.add(riskNotConsideredPicklistNarrative);
        }*/

        if (intendedRetail != '') {
            Narrative__c intendedRetailNarrative = new Narrative__c(Name = 'PRIIPs Intended Retail Investor', RecordTypeId = recordTypeId, Narrative_Scope__c = scope, 
                                                                        Type__c = 'PRIIPs', SubType__c = 'INTENDED_RETAIL_INVESTOR', Language__c = language, 
                                                                        Product__c = productId, Content__c = intendedRetail, StartDate__c = System.today());
            newNarrative.add(intendedRetailNarrative);
        }

        if (reasonForRHP != '') {
            Narrative__c reasonForRHPNarrative = new Narrative__c(Name = 'PRIIPs Reason For PHP', RecordTypeId = recordTypeId, Narrative_Scope__c = scope, 
                                                                        Type__c = 'PRIIPs', SubType__c = 'REASON_FOR_PHP', Language__c = language, 
                                                                        Product__c = productId, Content__c = reasonForRHP, StartDate__c = System.today());
            newNarrative.add(reasonForRHPNarrative);
        }

        /*if (redeemCondition != '') {
            Narrative__c redeemConditionNarrative = new Narrative__c(Name = 'PRIIPs Redeem Condition', RecordTypeId = recordTypeId, 
                                                                        Type__c = 'PRIIPs', SubType__c = 'REDEEM_CONDITION', Language__c = language, 
                                                                        Product__c = productId, Content__c = redeemCondition, StartDate__c = System.today());
            newNarrative.add(redeemConditionNarrative);
        }

        if (lmt != '') {
            Narrative__c lmtNarrative = new Narrative__c(Name = 'PRIIPs LMT', RecordTypeId = recordTypeId, 
                                                                        Type__c = 'PRIIPs', SubType__c = 'LMT', Language__c = language, 
                                                                        Product__c = productId, Content__c = lmt, StartDate__c = System.today());
            newNarrative.add(lmtNarrative);
        }*/


        return newNarrative;
    }

    public static Map<Id, Share_Class__c> getMapShareClassByShareclassId(List<ProjectProduct__c> listFundShareClassModification) {
        List<ProjectShareclass__c> listProjectShareclass = ProjectProductBatchUtilities.getProjectShareclass(listFundShareClassModification);
        Set<Id> setShareclassId = new Set<Id>();
        Map<Id, Share_Class__c> mapShareclassByShareclassId = new Map<Id, Share_Class__c>();

        for (ProjectShareclass__c projectShareclass : listProjectShareclass) {
              if (projectShareclass.TECH_ShareClass__c != null) {
                    setShareclassId.add(Id.valueOf(projectShareclass.TECH_ShareClass__c));
                }
        }

        if (!setShareclassId.isEmpty()) {
            for (Share_Class__c shareclass :  [SELECT Id FROM Share_Class__c WHERE Id IN :setShareclassId]) {
                mapShareclassByShareclassId.put(shareclass.Id, shareclass);
            }
            if (!mapShareclassByShareclassId.isEmpty()) {
                return mapShareclassByShareclassId;
            }
            System.debug('[ERROR] mapShareclassByShareclassId is EMPTY');
            return null;
        } else {
            System.debug('[ERROR] SET SHARECLASS is EMPTY');
        }
        return null;
    }


    public static Map<Id, Product__c> getMapProductByProductId(List<ProjectProduct__c> listProjectProduct) {
        Set<Id> setProductIds = new Set<Id>();
        Map<Id, Product__c> mapProductByProductId = new Map<Id, Product__c>();

        for (ProjectProduct__c projectProduct : listProjectProduct) {
            if (projectProduct.Product__c != null) {
                setProductIds.add(projectProduct.Product__c);
            }
        }

        for (Product__c currentProduct :  [SELECT Id FROM Product__c WHERE Id IN :setProductIds]) {
            mapProductByProductId.put(currentProduct.Id, currentProduct);
        }

        if (!mapProductByProductId.isEmpty()) {
            return mapProductByProductId;
        }

        return null;
    }
    
    public static List<ProjectProduct__c> getProjectProduct(List<ProjectProduct__c> listProjectProduct) {
        Set<Id> setProjetctIds = getProjectProductIds(listProjectProduct);
        if (setProjetctIds != null) {

            //We get ProjectProduct + ProjectShareclass + FundManagerAssignment
            String query = 'SELECT ' + RecordCloneHelper.getAllFieldNames('ProjectProduct__c') + ','
                + ' (SELECT ' + RecordCloneHelper.getAllFieldNames('ProjectShareclass__c')  + ' FROM ProjectShareclasses__r),'
                + ' (SELECT Id FROM Fund_Manager_Assignments__r),'
                + ' (SELECT Id FROM Narratives__r WHERE Type__c = \'Third Party\'),'
                + ' (SELECT Id, ProjectShareclass__c, ProjectProduct__c, Product__c, ShareClass__c, Type__c, Status__c, Source__c '
                + '    FROM Tax_Data__r '
                + '    WHERE Source__c = \'PMT\' AND Status__c = \'Requested\' '
                + '      AND (Product__c = NULL OR ShareClass__c = NULL)'
                + ' )'
                + ' FROM ProjectProduct__c WHERE Id IN :setProjetctIds';
            System.debug('query: ' + query);
            List<ProjectProduct__c> listProjectProductWFields = Database.query(query);

         
            if (!listProjectProductWFields.isEmpty()) {
                   System.debug('[DEBUG BATCH] geProjectPRoduct is not NULL');
                return listProjectProductWFields;
            }
        } else {
                System.debug('[DEBUG BATCH] setProjetctIds IS NULL');
        }
      
        System.debug('[DEBUG] getProjectProduct returned null');
        return null;
    }

    public static Product__c getNewProduct(ProjectProduct__c projectProduct) {
        Product__c newProduct = new Product__c();
        newProduct = (Product__c)RecordCloneHelper.batchCloneRecordFields((SObject)projectProduct, (SObject)newProduct);
        return newProduct;
    }

    public static Share_Class__c getNewShareclass(ProjectShareclass__c projectShareclass, Id productId) {
        Share_Class__c newShareClass = new Share_Class__c();
        newShareClass = (Share_Class__c)RecordCloneHelper.batchCloneRecordFields((SObject)projectShareclass, (SObject)newShareClass);
        newShareClass.Fund__c = productId;
        return newShareClass;
    }

    public static Boolean shouldAbortProcess(UpsertDebugResult debugResult, String contextLabel) {
        if (debugResult == null || debugResult.successRecords.isEmpty()) {
            System.debug('[ABORT] ' + contextLabel + ' : aucun enregistrement inséré avec succès. Traitement interrompu.');
            return true;
        }
        return false;
    }
    
    public static UpsertDebugResult logUpsertResults(List<SObject> recordsToUpsert) {
        UpsertDebugResult result = new UpsertDebugResult();
 
        if (recordsToUpsert.isEmpty()) {
            return result;
        }
 
        List<Database.UpsertResult> saveResults = Database.upsert(recordsToUpsert, false);
        Integer index = 0;
 
        for (Database.UpsertResult sr : saveResults) {
            String key = 'record_' + index;
            if (!sr.isSuccess()) {
                for (Database.Error error : sr.getErrors()) {
                    result.errorMap.put(key, error.getMessage());
                    System.debug('[BATCH ERROR] KEY: ' + key + ' - ' + error.getMessage());
                    result.failedRecords.put(key, recordsToUpsert[index]);
                    System.debug('[BATCH RECORD ERROR] KEY: ' + key + ' - ' + recordsToUpsert[index]);
                }
            } else {
                result.successRecords.put(key, recordsToUpsert[index]);
                System.debug('[BATCH RECORD SUCCESS] KEY: ' + key + ' - ' + recordsToUpsert[index]);
            }
            index++;
        }
        return result;
    }

    // version of UpsertDebugResult that siplay fields with error
   /* public static UpsertDebugResult logUpsertResults(List<SObject> recordsToUpsert) {
    UpsertDebugResult result = new UpsertDebugResult();

    if (recordsToUpsert == null || recordsToUpsert.isEmpty()) {
        return result;
    }

    List<Database.UpsertResult> saveResults = Database.upsert(recordsToUpsert, false);

    for (Integer index = 0; index < saveResults.size(); index++) {
        Database.UpsertResult sr = saveResults[index];
        SObject record = recordsToUpsert[index];
        String key = 'record_' + index;

        if (!sr.isSuccess()) {
            for (Database.Error error : sr.getErrors()) {
                List<String> fieldNames = new List<String>();

                if (error.getFields() != null) {
                    for (String fieldName : error.getFields()) {
                        fieldNames.add(fieldName);
                    }
                }

                String objectName = record.getSObjectType().getDescribe().getName();

                String recordName = '(no Name field)';
                Map<String, Object> populatedFields = record.getPopulatedFieldsAsMap();
                if (populatedFields.containsKey('Name')) {
                    recordName = String.valueOf(record.get('Name'));
                }

                String detailedError =
                    'Object=' + objectName +
                    ', RecordKey=' + key +
                    ', RecordName=' + recordName +
                    ', StatusCode=' + String.valueOf(error.getStatusCode()) +
                    ', Fields=' + String.join(fieldNames, ', ') +
                    ', Message=' + error.getMessage();

                result.errorMap.put(key, detailedError);
                result.failedRecords.put(key, record);

                System.debug(LoggingLevel.ERROR, '[BATCH ERROR] ' + detailedError);
                System.debug(LoggingLevel.ERROR, '[FAILED RECORD VALUES] ' + JSON.serializePretty(record.getPopulatedFieldsAsMap()));
            }
        } else {
            record.put('Id', sr.getId());
            result.successRecords.put(key, record);
            System.debug(LoggingLevel.INFO, '[BATCH RECORD SUCCESS] KEY: ' + key + ' - ' + record);
        }
    }

    return result;
}*/
    
     public static List<ProjectShareclass__c> getProjectShareclass(List<ProjectProduct__c> listProjectProduct) {
        List<ProjectShareclass__c> listProjectShareclass = new List<ProjectShareclass__c>();
        listProjectShareclass = [SELECT Id, TECH_ShareClass__c, TECH_FieldsToModify__c FROM ProjectShareclass__c WHERE ProjectProduct__c IN :listProjectProduct];
        
        if (!listProjectShareclass.isEmpty()) {
            return listProjectShareclass;
        }
        return null;
    }

    /*****PRIVATE****/
    private static Set<Id> getProjectProductIds(List<ProjectProduct__c> listProjectProduct) {
        
        Set<Id> setProjetctIds = new Set<Id>();
        for (ProjectProduct__c  projectProduct: listProjectProduct) {
            setProjetctIds.add(projectProduct.Id);            
        }

        if (!setProjetctIds.isEmpty()) {
            return setProjetctIds;
        }

        System.debug('[DEBUG] getProjectProductIds returned null');
        return null;
    }

    /*****PRIVATE****/
    private static String getRiskNarrativeContent(String riskAssociatedMultiPicklist) {
        String content = '';
        List<String> listRiskAssociated = new List<String>();
        if (riskAssociatedMultiPicklist == '' || riskAssociatedMultiPicklist == null) {
            return 'The Fund presents a risk of loss of capital.';
        }
        if (riskAssociatedMultiPicklist.contains(';')) {
            listRiskAssociated = riskAssociatedMultiPicklist.split(';');
        } else {
            listRiskAssociated.add(riskAssociatedMultiPicklist);
        }
      
        for (String risk : listRiskAssociated) {
            if (risk == 'Equity') {
                content += 'EQUITY: The Fund may be affected by stock price variations, the scale of which is dependent on external factors, stock trading volumes or market capitalization.\n';
            }
            if (risk == 'Interest rates') {
                content += 'INTEREST RATE: Interest rate risk results in a decline in the net asset value in the event of changes in interest rates.\n';
            }
            if (risk == 'Credit') {
                content += 'CREDIT: Credit risk is the risk that the issuer may default.\n';
            }
            if (risk == 'Currency') {
                content += 'CURRENCY: Currency risk is linked to exposure to a currency other than the Fund\'s valuation currency, either through direct investment or the use of forward financial instruments.\n';
            }
        }

        content += 'The Fund presents a risk of loss of capital.';
        return content;
    }

    private static String getRiskNotConsideredContent(String riskNotConsideredPicklist) {
        String content = '';
        List<String> listRiskAssociated = new List<String>();
        if (riskNotConsideredPicklist == '' || riskNotConsideredPicklist == null) {
            return '';
        }
       
            // Condition sur Legal form et riskNotConsideredPicklist value
            //If FCP { switch riskNotConsideredPicklist }
            //projet modification
            if (riskNotConsideredPicklist == 'Counterparty risk') {
                content += 'EQUITY: The Fund may be affected by stock price variations, the scale of which is dependent on external factors, stock trading volumes or market capitalization.\n';
            }
            if (riskNotConsideredPicklist == 'Credit risk') {
                content += 'INTEREST RATE: Interest rate risk results in a decline in the net asset value in the event of changes in interest rates.\n';
            }
            if (riskNotConsideredPicklist == 'Liquidity risk') {
                content += 'CREDIT: Credit risk is the risk that the issuer may default.\n';
            }
            if (riskNotConsideredPicklist == 'Pooled investments in secondaries risk') {
                content += 'CURRENCY: Currency risk is linked to exposure to a currency other than the Fund\'s valuation currency, either through direct investment or the use of forward financial instruments.\n';
            }
            if (riskNotConsideredPicklist == 'Risks associated with China') {
                content += 'CURRENCY: Currency risk is linked to exposure to a currency other than the Fund\'s valuation currency, either through direct investment or the use of forward financial instruments.\n';
            }

        content += 'The Fund presents a risk of loss of capital.';
        return content;
    }

    private static Set<Id> getProjectProductIds(List<ProjectProduct__c> listProjectProduct, String fieldName) {
        Set<Id> setProjetctIds = new Set<Id>();
        for (ProjectProduct__c  projectProduct: listProjectProduct) {
            setProjetctIds.add(projectProduct.Id);            
        }

        if (!setProjetctIds.isEmpty()) {
            return setProjetctIds;
        }

        System.debug('[DEBUG] getProjectProductIds returned null');
        return null;
    }
    

    /**
     * Retourne le contenu à mettre dans la narrative pour un ProjectProduct et un champ donné.
     * - pour RiskAssociated__c : utilise getRiskNarrativeContent()
     * - pour les autres : retourne la valeur brute (ou '' si null)
     */
    public static String getContentForField(ProjectProduct__c pp, String fieldApiName) {
        if (pp == null || String.isBlank(fieldApiName)) return '';

        try {
            if (fieldApiName == 'RiskAssociated__c') {
                String raw = (String) pp.get('RiskAssociated__c');
                return getRiskNarrativeContent(raw);
            } else {
                Object val = pp.get(fieldApiName);
                return val == null ? '' : String.valueOf(val);
            }
        } catch (Exception e) {
            System.debug('[ERROR] getContentForField: ' + e.getMessage());
            return '';
        }
    }

    public static String narrativeKey(Id productId, String language, String typeVal, String subTypeVal) {
        return String.valueOf(productId) + '|' + language + '|' + typeVal + '|' + subTypeVal;
    }

    /**
     * Construit (sans DML) la liste des Narrative__c à upsert pour un champ.
     * - existingByKey : map des narratives existants indexés par Product|Lang|Type|SubType
     */
    public static List<Narrative__c> buildNarrativesForField(
        Map<Id, String> contentByProductId,
        Map<Id, String> languageByProductId,
        Map<String, Narrative__c> existingByKey,
        String typeVal,
        String subTypeVal,
        String nameVal,
        Id narrativeRecordTypeId,
        List<String> debugInformation
    ) {
        List<Narrative__c> out = new List<Narrative__c>();
        if (contentByProductId == null || contentByProductId.isEmpty()) return out;

        for (Id prodId : contentByProductId.keySet()) {
            String content = contentByProductId.get(prodId);
            if (String.isBlank(content)) continue;

            String lang = languageByProductId.containsKey(prodId) ? languageByProductId.get(prodId) : 'English';
            String key = narrativeKey(prodId, lang, typeVal, subTypeVal);

            Narrative__c existing = existingByKey.get(key);

            if (existing == null) {
                Narrative__c n = new Narrative__c();
                n.RecordTypeId = narrativeRecordTypeId;
                n.Name = nameVal;
                n.Type__c = typeVal;
                n.SubType__c = subTypeVal;
                n.Language__c = lang;
                n.Product__c = prodId;
                n.Content__c = content;
                n.StartDate__c = System.today();
                out.add(n);

                debugInformation.add('[NARRATIVE] CREATE ' + typeVal + '/' + subTypeVal + ' for Product ' + prodId + ' (' + lang + ')');
            } else if (existing.Content__c == null || existing.Content__c != content) {
                existing.Content__c = content;
                existing.StartDate__c = System.today();
                out.add(existing);

                debugInformation.add('[NARRATIVE] UPDATE ' + existing.Id + ' ' + typeVal + '/' + subTypeVal + ' for Product ' + prodId + ' (' + lang + ')');
            }
        }

        return out;
    }

    public static String scNarrativeKey(Id shareClassId, String language, String typeVal, String subTypeVal) {
        return String.valueOf(shareClassId) + '|' + language + '|' + typeVal + '|' + subTypeVal;
    }

    /**
     * Construit (sans DML) des narratives liés à une ShareClass (ShareClass__c),
     * et conserve Product__c pour le reporting.
     *
     * contentByShareClassId : ShareClassId -> contenu
     * productByShareClassId : ShareClassId -> ProductId
     */
    public static List<Narrative__c> buildShareClassNarrativesForField(
        Map<Id, String> contentByShareClassId,
        Map<Id, String> productByShareClassId,
        Map<Id, String> languageByShareClassId,
        Map<String, Narrative__c> existingByKey,
        String typeVal,
        String subTypeVal,
        String nameVal,
        Id narrativeRecordTypeId,
        List<String> debugInformation
    ) {
        List<Narrative__c> out = new List<Narrative__c>();
        if (contentByShareClassId == null || contentByShareClassId.isEmpty()) return out;

        for (Id scId : contentByShareClassId.keySet()) {
            String content = contentByShareClassId.get(scId);
            if (String.isBlank(content)) continue;

            String lang = languageByShareClassId.containsKey(scId) ? languageByShareClassId.get(scId) : 'English';
            String key  = scNarrativeKey(scId, lang, typeVal, subTypeVal);

            Narrative__c existing = existingByKey.get(key);

            if (existing == null) {
                Narrative__c n = new Narrative__c();
                n.RecordTypeId  = narrativeRecordTypeId;
                n.Name          = nameVal;
                n.Type__c       = typeVal;
                n.SubType__c    = subTypeVal;
                n.Language__c   = lang;
                n.ShareClass__c = scId;
                //n.Product__c    = productByShareClassId.get(scId); // reporting
                n.Content__c    = content;
                n.StartDate__c  = System.today();
                out.add(n);

                debugInformation.add('[NARRATIVE][SC] CREATE ' + typeVal + '/' + subTypeVal + ' for ShareClass ' + scId + ' (' + lang + ')');
            } else if (existing.Content__c == null || existing.Content__c != content) {
                existing.Content__c   = content;
                existing.StartDate__c = System.today();
                // si tu veux forcer le reporting à jour :
                //existing.Product__c   = productByShareClassId.get(scId);

                out.add(existing);
                debugInformation.add('[NARRATIVE][SC] UPDATE ' + existing.Id + ' ' + typeVal + '/' + subTypeVal + ' for ShareClass ' + scId + ' (' + lang + ')');
            }
        }

        return out;
    }


    /****** WRAPPER LOGS SOBJECT ******/
    public class UpsertDebugResult {
        public Map<String, String> errorMap = new Map<String, String>();
        public Map<String, SObject> failedRecords = new Map<String, SObject>();
        public Map<String, SObject> successRecords = new Map<String, SObject>();
    }
}