public class ProjectProductBatchUtilities {

    public static List<Narrative__c> createNarratives(ProjectProduct__c projectProduct, String recordTypeId, String language, String productId) {
        List<Narrative__c> newNarrative = new List<Narrative__c>();
        String investmentStrategy = projectProduct.InvestmentStrategy__c;
        String investmentObjective = projectProduct.InvestmentObjective__c;
        String riskAssociatedMultiPicklist = projectProduct.RiskAssociated__c;
        String redeemCondition = projectProduct.RedeemCondition__c;
        String lmt = projectProduct.LMT__c;

        if (investmentObjective != '') {
            Narrative__c investmentObjectiveNarrative = new Narrative__c(Name = 'Investment Objective Description', RecordTypeId = recordTypeId, 
                                                                        Type__c = 'Investment Objective', SubType__c = 'Description', Language__c = language, 
                                                                        Product__c = productId, Content__c = investmentObjective, StartDate__c = System.today());
            newNarrative.add(investmentObjectiveNarrative);
        }
        
        if (investmentStrategy != '') {
            Narrative__c investmentStrategyNarrative = new Narrative__c(Name = 'Investment Strategy Description', RecordTypeId = recordTypeId, 
                                                                        Type__c = 'Investment Strategy', SubType__c = 'Description', Language__c = language, 
                                                                        Product__c = productId, Content__c = investmentStrategy, StartDate__c = System.today());
            newNarrative.add(investmentStrategyNarrative);
        }

        if (riskAssociatedMultiPicklist != '') {
            String content = getRiskNarrativeContent(riskAssociatedMultiPicklist);
            Narrative__c riskAssociatedMultiPicklistNarrative = new Narrative__c(Name = 'Risk Main Risk of the Fund', RecordTypeId = recordTypeId, 
                                                                        Type__c = 'Risk', SubType__c = 'Main Risk of the Fund', Language__c = language, 
                                                                        Product__c = productId, Content__c = content, StartDate__c = System.today());
            newNarrative.add(riskAssociatedMultiPicklistNarrative);
        }

        if (redeemCondition != '') {
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
        }


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
                + ' (SELECT Id FROM Narratives__r WHERE Type__c = \'Third Party\')'
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



    /****** WRAPPER LOGS SOBJECT ******/
    public class UpsertDebugResult {
        public Map<String, String> errorMap = new Map<String, String>();
        public Map<String, SObject> failedRecords = new Map<String, SObject>();
        public Map<String, SObject> successRecords = new Map<String, SObject>();
    }
}