public class VFC12_DeleteAllProspaceAlerts {
    
    public String currentRecId { get; set; }
    
    public VFC12_DeleteAllProspaceAlerts(ApexPages.StandardSetController standardSetController) {
        
        currentRecId = Apexpages.currentPage().getParameters().get('id');
        System.debug('DEV -- - - ContactId ' + currentRecId);
    }


}