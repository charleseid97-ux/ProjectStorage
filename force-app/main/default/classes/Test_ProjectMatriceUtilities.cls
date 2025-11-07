@isTest(SeeAllData=true)
private class Test_ProjectMatriceUtilities {
    
    @isTest static void testGetAllMatrice() {
        List<ProductProjectSettings__c> allM = ProjectMatriceUtilities.getAllMatrice();
     
    }
 
    @isTest static void testGetmatriceByTeam() {
        // Récupérer une team existante dans la matrice
        ProductProjectSettings__c rec = [SELECT Team__c FROM ProductProjectSettings__c WHERE ProjectType__c='Creation' LIMIT 1];
        List<ProductProjectSettings__c> byTeam = ProjectMatriceUtilities.getmatriceByTeam(rec.Team__c);
    
    }
 
    @isTest static void testGetmatriceByStep() {
        ProductProjectSettings__c rec = [SELECT Stage__c FROM ProductProjectSettings__c WHERE ProjectType__c='Creation' LIMIT 1];
        List<ProductProjectSettings__c> byStep = ProjectMatriceUtilities.getmatriceByStep(rec.Stage__c);
    
    }
 
    @isTest static void testGetmatriceByTeamStep() {
        ProductProjectSettings__c rec = [SELECT Team__c, Stage__c FROM ProductProjectSettings__c WHERE ProjectType__c='Creation' LIMIT 1];
        ProductProjectSettings__c single = ProjectMatriceUtilities.getmatriceByTeamStep(rec.Team__c, rec.Stage__c);
     
    }
 
    @isTest static void testGetAllRequiredFieldsSHCByStep() {
        Map<String, List<String>> mapSHC = ProjectMatriceUtilities.getAllRequiredFieldsSHCByStep();
     
    }
 
    @isTest static void testGetAllRequiredFieldsByStep() {
        Map<String, List<String>> mapFund = ProjectMatriceUtilities.getAllRequiredFieldsByStep();
     
    }
 
    @isTest static void testGetAllRequiredFieldsByStepShareclass() {
        Map<String, List<String>> mapSC = ProjectMatriceUtilities.getAllRequiredFieldsByStepShareclass();
    
    }
 
    @isTest static void testMapStepByField() {
        // Utiliser une équipe valide
        ProductProjectSettings__c rec = [SELECT Team__c FROM ProductProjectSettings__c WHERE ProjectType__c='Creation' LIMIT 1];
        Map<String, String> mapField = ProjectMatriceUtilities.getMapStepByField(rec.Team__c);
 
    }
 
    @isTest static void testTeamNoRequiredFieldsByStep() {
        Map<String, List<String>> mapNoReq = ProjectMatriceUtilities.getTeamwithNorequiredFieldsByStep();
        System.assertNotEquals(null, mapNoReq);
        // OK même si vide
    }
 
    @isTest static void testAllRequiredAndNonRequired_2() {
        // ShareClass step
        Map<String, String> map1 = ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByStepShareClass();
  
        Map<String, String> map2 = ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByTeamShareClass();
  
        Map<String, String> map3 = ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByStepFund();
 
        Map<String, String> map4 = ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByTeamFund();
   
        Map<String, Map<String, List<String>>> map5 = ProjectMatriceUtilities.getAllRequiredAndNonRequiredFieldsByStepandTeam();

    }
}