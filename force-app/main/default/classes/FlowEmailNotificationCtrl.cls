public class FlowEmailNotificationCtrl {

    public class InputWrapper {
        @InvocableVariable(required=true label='record Id' description='Project Product record Id')
        public Id recordId; 
    }

    public class OutputWrapper {
        @InvocableVariable
        public List<String> teamNames; 
    }
    
    @InvocableMethod(label='Get Users Names from Record')
   
    public static List<OutputWrapper> getUsers(List<InputWrapper> inputList) {
        System.debug('Start FlowEmailNotificationCtrl');

        List<OutputWrapper> results = new List<OutputWrapper>();

        // Extraire les Ids des ProjectProduct à partir des inputs
        Set<Id> recordIds = new Set<Id>();
        for (InputWrapper input : inputList) {
            recordIds.add(input.recordId);
        }

        // Requête sur ProductProjectSettings
        List<ProductProjectSettings__c> matriceRecords = [
            SELECT Id, TeamOwner__c, Team__c,
            RequiredFields__c, RequiredFieldsShareClass__c,
            NonRequiredFieldsFund__c, NonRequiredFieldsShareClass__c
            FROM ProductProjectSettings__c
        ];

        // Requête sur les ProjectProduct
        List<ProjectProduct__c> projectProducts = [
            SELECT Id, TECH_FieldsToModify__c,
                Communication__r.FirstName, Communication__r.LastName,
                Compliance__r.FirstName, Compliance__r.LastName,
                DBS__r.FirstName, DBS__r.LastName,
                DCO__r.FirstName, DCO__r.LastName,
                DCP__r.FirstName, DCP__r.LastName,
                DCR__r.FirstName, DCR__r.LastName,
                DM__r.FirstName, DM__r.LastName,
                ESG__r.FirstName, ESG__r.LastName,
                Finance__r.FirstName, Finance__r.LastName,
                FundMarketing__r.FirstName, FundMarketing__r.LastName,
                InvestmentPerf__r.FirstName, InvestmentPerf__r.LastName,
                IS__r.FirstName, IS__r.LastName,
                Legal__r.FirstName, Legal__r.LastName,
                OPS__r.FirstName, OPS__r.LastName,
                ProductStrategy__r.FirstName, ProductStrategy__r.LastName,
                Risk__r.FirstName, Risk__r.LastName,
                Technology__r.FirstName, Technology__r.LastName,
                ProductSpecialists__r.FirstName, ProductSpecialists__r.LastName,
                RFP__r.FirstName, RFP__r.LastName,
                Tax__r.FirstName, Tax__r.LastName,
                (SELECT Id, TECH_FieldsToModify__c FROM ProjectShareclasses__r)
            FROM ProjectProduct__c
            WHERE Id IN :recordIds
        ];

        for (ProjectProduct__c projectProduct : projectProducts) {
            OutputWrapper output = new OutputWrapper();
            List<String> userNames = new List<String>();
            String fieldsToModifyProduct = '';
            String fieldsToModifySC = '';

            // Champs TECH à traiter
            if (projectProduct.TECH_FieldsToModify__c != null) {
                fieldsToModifyProduct = projectProduct.TECH_FieldsToModify__c;
            }

            if (projectProduct.ProjectShareclasses__r != null && !projectProduct.ProjectShareclasses__r.isEmpty()) {
                for (ProjectShareclass__c psc : projectProduct.ProjectShareclasses__r) {
                    if (psc.TECH_FieldsToModify__c != null) {
                        fieldsToModifySC += psc.TECH_FieldsToModify__c + ';';
                    }
                }
            }

            Set<String> teamOwner = new Set<String>();

            // Analyse des champs du produit
            if (!String.isBlank(fieldsToModifyProduct)) {
                for (String field : fieldsToModifyProduct.split(';')) {
                    for (ProductProjectSettings__c ppc : matriceRecords) {
                        if ((ppc.RequiredFields__c != null && ppc.RequiredFields__c.contains(field)) ||
                        (ppc.NonRequiredFieldsFund__c != null && ppc.NonRequiredFieldsFund__c.contains(field))) {
                            // if ppc.Team__c == IS && projectProduct.IS__c!=null || ppc.Team__c == PS && projectProduct.PS__c!=null
                            if((ppc.Team__c == 'IS' && projectProduct.IS__c!=null) || (ppc.Team__c == 'Product Strategy' && projectProduct.ProductStrategy__c!=null) || (ppc.Team__c != 'IS' && ppc.Team__c != 'Product Strategy'))
                            {
                                system.debug('ppc.Team__c : ' + ppc.Team__c);
                                system.debug('projectProduct IS '+ projectProduct.IS__c);
                                system.debug('projectProduct PS '+ projectProduct.ProductStrategy__c);
                                teamOwner.add(ppc.Team__c);
                            }
                        }
                    }
                }
            }

            // Analyse des champs des shareclasses
            if (!String.isBlank(fieldsToModifySC)) {
                for (String field : fieldsToModifySC.split(';')) {
                    for (ProductProjectSettings__c ppc : matriceRecords) {
                        if ((ppc.RequiredFieldsShareClass__c != null && ppc.RequiredFieldsShareClass__c.contains(field)) ||
                        (ppc.NonRequiredFieldsShareClass__c != null && ppc.NonRequiredFieldsShareClass__c.contains(field))) {
                            if((ppc.Team__c == 'IS' && projectProduct.IS__c!=null) || (ppc.Team__c == 'Product Strategy' && projectProduct.ProductStrategy__c!=null) || (ppc.Team__c != 'IS' && ppc.Team__c != 'Product Strategy'))
                            {
                                teamOwner.add(ppc.Team__c);
                            }
                        }
                    }
                }
            }

            // Ajout des noms des utilisateurs liés à chaque équipe identifiée
            /*if (teamOwner.contains('OPS') && projectProduct.OPS__r != null) {
                userNames.add(projectProduct.OPS__r.FirstName + ' ' + projectProduct.OPS__r.LastName);
            }
            if (teamOwner.contains('ESG') && projectProduct.ESG__r != null) {
                userNames.add(projectProduct.ESG__r.FirstName + ' ' + projectProduct.ESG__r.LastName);
            }*/

            // Tu peux ajouter ici d'autres mappings similaires selon les équipes
            output.teamNames = new List<String>(teamOwner);
            //output.teamNames = userNames;
            results.add(output);
        }

        System.debug('End FlowEmailNotificationCtrl. Results: ' + results);
        return results;
        
    }

}