public class VFC11_AddAllProSpaceAlerts {
    

    public String currentRecId { get; set; }
    
    public VFC11_AddAllProSpaceAlerts(ApexPages.StandardSetController standardSetController) {
        
        currentRecId = Apexpages.currentPage().getParameters().get('id');
        System.debug('DEV -- - - ContactId ' + currentRecId);
    }

}