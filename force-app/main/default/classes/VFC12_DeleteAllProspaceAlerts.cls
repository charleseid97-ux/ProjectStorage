/** ──────────────────────────────────────
 * @description Controller of the VFP12_DeleteAllProspaceAlerts page ("Delete all" list button): reads the record Id from the URL.
 * @testClass SM029_WebCommunicationTest
 * @coverage 100%   [08-10-26]
 ────────────────────────────────────── */
public class VFC12_DeleteAllProspaceAlerts {
    
    public String currentRecId { get; set; }
    
    public VFC12_DeleteAllProspaceAlerts(ApexPages.StandardSetController standardSetController) {
        
        currentRecId = Apexpages.currentPage().getParameters().get('id');
        System.debug('DEV -- - - ContactId ' + currentRecId);
    }


}