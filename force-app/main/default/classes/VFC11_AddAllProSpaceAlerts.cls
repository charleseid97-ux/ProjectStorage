/** ──────────────────────────────────────
 * @description Controller of the VFP11_AddAllProSpaceAlerts page ("Add all" list button): reads the record Id from the URL.
 * @testClass SM029_WebCommunicationTest
 * @coverage 100%   [08-10-26]
 ────────────────────────────────────── */
public class VFC11_AddAllProSpaceAlerts {
    

    public String currentRecId { get; set; }
    
    public VFC11_AddAllProSpaceAlerts(ApexPages.StandardSetController standardSetController) {
        
        currentRecId = Apexpages.currentPage().getParameters().get('id');
        System.debug('DEV -- - - ContactId ' + currentRecId);
    }

}