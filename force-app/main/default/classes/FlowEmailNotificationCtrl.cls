/** ──────────────────────────────────────
 * @description Invocable action for the FL_PMT_EmailNotifications flow: returns the teams owning the fields selected
 *                  for modification (TECH_FieldsToModify__c) on a Project Product and its Share Classes.
 *              Teams come from the PMT matrix restricted to the project's Scope (PMTMatrix.forScope, FIX-20178);
 *                  fields are matched exactly (no substring match).
 * @lastModifiedBy Charles EID   [09-10-26]
 * @testClass Test_FlowEmailNotificationCtrl
 * @coverage 100%   [09-10-26]
 ────────────────────────────────────── */
public class FlowEmailNotificationCtrl {

    @InvocableMethod(label='Get Users Names from Record')
    public static List<OutputWrapper> getUsers(List<InputWrapper> inputList) {
        List<OutputWrapper> results = new List<OutputWrapper>();

        // Extraire les Ids des ProjectProduct à partir des inputs
        Set<Id> recordIds = new Set<Id>();
        for (InputWrapper input : inputList) {
            recordIds.add(input.recordId);
        }
        
        PMTMatrix matrix = PMTMatrix.get(); // FIX-20178: matrice PMT (PMTFieldRule__mdt) au lieu de ProductProjectSettings__c

        // Requête sur les ProjectProduct
        List<ProjectProduct__c> projectProducts = [SELECT Id, TECH_FieldsToModify__c, Scope__c, Communication__r.FirstName, Communication__r.LastName, Compliance__r.FirstName, Compliance__r.LastName, DBS__r.FirstName, DBS__r.LastName, DCO__r.FirstName, DCO__r.LastName, 
                                                        DCP__r.FirstName, DCP__r.LastName, DCR__r.FirstName, DCR__r.LastName, DM__r.FirstName, DM__r.LastName, ESG__r.FirstName, ESG__r.LastName, Finance__r.FirstName, Finance__r.LastName, FundMarketing__r.FirstName, FundMarketing__r.LastName, 
                                                        InvestmentPerf__r.FirstName, InvestmentPerf__r.LastName, IS__r.FirstName, IS__r.LastName, Legal__r.FirstName, Legal__r.LastName, OPS__r.FirstName, OPS__r.LastName, ProductStrategy__r.FirstName, ProductStrategy__r.LastName, 
                                                        Risk__r.FirstName, Risk__r.LastName, Technology__r.FirstName, Technology__r.LastName, ProductSpecialists__r.FirstName, ProductSpecialists__r.LastName, RFP__r.FirstName, RFP__r.LastName, Tax__r.FirstName, Tax__r.LastName,
                                                        (SELECT Id, TECH_FieldsToModify__c FROM ProjectShareclasses__r)
                                                   FROM ProjectProduct__c
                                                   WHERE Id IN :recordIds];

        for (ProjectProduct__c projectProduct : projectProducts) {
            OutputWrapper output = new OutputWrapper();
            List<String> userNames = new List<String>();
            String fieldsToModifyProduct = '';
            String fieldsToModifySC = '';

            if (projectProduct.TECH_FieldsToModify__c != null) fieldsToModifyProduct = projectProduct.TECH_FieldsToModify__c; // Champs TECH à traiter

            if (projectProduct.ProjectShareclasses__r != null && !projectProduct.ProjectShareclasses__r.isEmpty()) {
                for (ProjectShareclass__c psc : projectProduct.ProjectShareclasses__r) {
                    if (psc.TECH_FieldsToModify__c != null) {
                        fieldsToModifySC += psc.TECH_FieldsToModify__c + ';';
                    }
                }
            }

            Set<String> teamOwner = new Set<String>();

            PMTMatrix scopedMatrix = matrix.forScope(ProjectProductSetupHandlerUtilities.normalizeScope(projectProduct.Scope__c)); // FIX-20178: seules les équipes du Scope du projet (PS ou IS) sont retenues (PMTTeam__mdt.Scope__c)

            // Analyse des champs du produit
            if (!String.isBlank(fieldsToModifyProduct)) {
                for (String field : fieldsToModifyProduct.split(';')) {
                    for (PMTMatrix.FieldRule rule : scopedMatrix.rules) {
                        if (rule.getAllFund().contains(field)) teamOwner.add(rule.team);
                    }
                }
            }

            // Analyse des champs des shareclasses
            if (!String.isBlank(fieldsToModifySC)) {
                for (String field : fieldsToModifySC.split(';')) {
                    for (PMTMatrix.FieldRule rule : scopedMatrix.rules) {
                        if (rule.getAllShareClass().contains(field)) teamOwner.add(rule.team);
                    }
                }
            }

            // Tu peux ajouter ici d'autres mappings similaires selon les équipes
            output.teamNames = new List<String>(teamOwner);
            results.add(output);
        }
        return results;
    }

    // ------------------------------------- WRAPPERS -------------------------------------

    public class InputWrapper {
        @InvocableVariable(required=true label='record Id' description='Project Product record Id')
        public Id recordId; 
    }

    public class OutputWrapper {
        @InvocableVariable
        public List<String> teamNames; 
    }
}