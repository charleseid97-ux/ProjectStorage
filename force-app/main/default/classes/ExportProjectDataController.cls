public class ExportProjectDataController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getProjectDataToExport(Id recordId) {
        List<Map<String, String>> exportData = new List<Map<String, String>>();
 
        // ✅ Récupération dynamique des champs à extraire pour ProjectProduct
        Map<String, String> projectFieldLabels = new Map<String, String>();
        List<String> projectFields = ExportProjectDataControllerUtilities.getExportableFields('ProjectProduct__c', projectFieldLabels);
 
        // ✅ Récupération du ProjectProduct
        ProjectProduct__c fund = ExportProjectDataControllerUtilities.getProjectProduct(recordId, projectFields);
        if (fund == null) {
            System.debug('⚠️ Aucun ProjectProduct trouvé pour ID: ' + recordId);
            return exportData;
        }
 
        // ✅ Récupération dynamique des champs à extraire pour ProjectShareclass
        Map<String, String> shareclassFieldLabels = new Map<String, String>();
        List<String> shareclassFields = ExportProjectDataControllerUtilities.getExportableFields('ProjectShareclass__c', shareclassFieldLabels);
 
        // ✅ Récupération des ProjectShareclass liés
        List<ProjectShareclass__c> shareclasses = ExportProjectDataControllerUtilities.getProjectShareclasses(recordId, shareclassFields);
 
        for (ProjectShareclass__c shareclass : shareclasses) {
            Map<String, String> row = new Map<String, String>();

            // Ajouter les champs du ProjectProduct avec préfixe clair
            for (String field : projectFields) {
                String label = 'PP - ' + projectFieldLabels.get(field);
                row.put(label, String.valueOf(fund.get(field)));
            }

            // Ajouter les champs du ProjectShareclass avec préfixe clair
            for (String field : shareclassFields) {
                String label = 'SC - ' + shareclassFieldLabels.get(field);
                row.put(label, String.valueOf(shareclass.get(field)));
            }

            exportData.add(row);
        }
        return exportData;
    }
}