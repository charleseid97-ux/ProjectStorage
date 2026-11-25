/** ──────────────────────────────────────
 * @description Tests of VFC16_SequantisGenerateDraft.genPDF with a mocked Sequantis API: draft PDF of one share class (HTTP 200),
 *                  update of all share classes (HTTP 202, no PDF), error message when required project fields are missing, and the
 *                  exception raised when the OAuth token request fails.
 * @author EL HITARY Achraf
 * @covers VFC16_SequantisGenerateDraft   91%   [21-10-26]
 * @lastModifiedBy Charles EID   [21-10-26]
 ────────────────────────────────────── */
@isTest
private class VFC16_SequantisGenerateDraftTest {

    private static final String TOKEN_OK = 'TOKEN-OK';
    private static final String SC_FIELDS_CURRENCY_TYPE = 'CurrencyIsoCode;Type__c';
    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();

    // Complete project: draft PDF of one share class, update of all share classes, and the OAuth token refused
    @isTest
    static void test_genPDF() {
        ProjectProduct__c pp = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        pp.EndDate__c = Date.today();
        pp.Name = 'PRD - ' + (pp.Name == null ? 'Fund' : pp.Name) + ' - EUR';
        pp.internalShortName__c = 'PP-INT';
        pp.RecommendedHoldingPeriod__c = 5;
        pp.RecommendedHoldingPeriodUnit__c = pickOneOf(ProjectProduct__c.RecommendedHoldingPeriodUnit__c, new List<String>{ 'Years', 'Year', 'Ans' });
        update pp;
        ProjectShareclass__c sc = PMTTestFactoryData.createProjectShareclass(pp.Id, SC_FIELDS_CURRENCY_TYPE);
        PMTTestFactoryData.createProjectShareclass(pp.Id, SC_FIELDS_CURRENCY_TYPE);

        Test.startTest();

        // Draft PDF of one share class
        VFC16_SequantisGenerateDraft ctrl = newController(pp, sc.Id, new SequantisHttpMock(200, TOKEN_OK, 200, 'IGNORED', true));
        ctrl.genPDF();
        System.assert(ctrl.showPDF);
        System.assertNotEquals(null, VFC16_SequantisGenerateDraft.pdf);
        System.assert(String.isBlank(VFC16_SequantisGenerateDraft.errorMessage));

        // Update of all share classes: accepted, no PDF
        ctrl = newController(pp, 'updateAll', new SequantisHttpMock(200, TOKEN_OK, 202, 'Accepted', false));
        ctrl.genPDF();
        System.assert(!ctrl.showPDF);
        System.assert(String.isBlank(VFC16_SequantisGenerateDraft.errorMessage));
        System.assert(!String.isBlank(VFC16_SequantisGenerateDraft.infoMessage));

        // OAuth token refused: exception with the failure details (wrapper "Erreur API : ..." or direct "OAuth token request failed: HTTP 401")
        ctrl = newController(pp, sc.Id, new SequantisHttpMock(401, 'Bad creds', 200, 'IGNORED', true));
        String message;
        try {
            ctrl.genPDF();
        }
        catch (Exception e) {
            message = e.getMessage();
        }

        Test.stopTest();

        System.assert(!String.isBlank(message), 'Expected an exception with a message');
        System.assert(message.contains('OAuth token request failed') || message.contains('401') || message.contains('Erreur API'), 'Expected token failure details in message but was: ' + message);
    }

    // Project missing its required fields: error message, no PDF (a second project in the same test would exceed the SOQL limit)
    @isTest
    static void test_genPDF_missingRequiredFields() {
        ProjectProduct__c pp = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        pp.EndDate__c = Date.today();
        pp.ProductName__c = 'PRD - Fund ABC - EUR';
        update pp;
        ProjectShareclass__c sc = PMTTestFactoryData.createProjectShareclass(pp.Id, SC_FIELDS_CURRENCY_TYPE);

        Test.startTest();

        VFC16_SequantisGenerateDraft ctrl = newController(pp, sc.Id, new SequantisHttpMock(200, TOKEN_OK, 200, 'IGNORED', true));
        ctrl.genPDF();

        Test.stopTest();

        System.assert(!ctrl.showPDF);
        System.assert(VFC16_SequantisGenerateDraft.errorMessage != null && VFC16_SequantisGenerateDraft.errorMessage.startsWith('<br/> generation failed'));
    }

    // Controller of the project page for the selected record, with the static messages reset and the Sequantis mock set
    private static VFC16_SequantisGenerateDraft newController(ProjectProduct__c pp, String selectedRecordId, SequantisHttpMock mock) {
        VFC16_SequantisGenerateDraft ctrl = new VFC16_SequantisGenerateDraft(new ApexPages.StandardController(pp));
        VFC16_SequantisGenerateDraft.selectedRecordId = selectedRecordId;
        VFC16_SequantisGenerateDraft.pdf = null;
        VFC16_SequantisGenerateDraft.infoMessage = null;
        VFC16_SequantisGenerateDraft.errorMessage = null;
        Test.setMock(HttpCalloutMock.class, mock);
        return ctrl;
    }

    // Preferred picklist value when it exists, otherwise the first one
    private static String pickOneOf(Schema.SObjectField f, List<String> preferred) {
        Set<String> prefs = new Set<String>();
        for (String p : preferred) if (p != null) prefs.add(p.toLowerCase());
        for (Schema.PicklistEntry pe : f.getDescribe().getPicklistValues()) {
            String v = pe.getValue();
            if (v != null && prefs.contains(v.toLowerCase())) return v;
        }
        List<Schema.PicklistEntry> all = f.getDescribe().getPicklistValues();
        return all.isEmpty() ? null : all[0].getValue();
    }

    // HTTP mock of the Sequantis authentication and project endpoints
    private class SequantisHttpMock implements HttpCalloutMock {
        Integer tokenCode;
        String tokenBody;
        Integer projectCode;
        String projectBody;
        Boolean returnPdf;

        SequantisHttpMock(Integer tCode, String tBody, Integer pCode, String pBody, Boolean retPdf) {
            tokenCode = tCode;
            tokenBody = tBody;
            projectCode = pCode;
            projectBody = pBody;
            returnPdf = retPdf;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String ep = req.getEndpoint() == null ? '' : req.getEndpoint();
            if (ep.contains('callout:Sequantis/rest/authentication')) {
                res.setStatusCode(tokenCode);
                res.setBody(tokenBody);
                return res;
            }
            if (ep.contains('callout:Sequantis/rest/CARMIGNAC_PROJECT')) {
                res.setStatusCode(projectCode);
                if (projectCode == 200 && returnPdf) res.setBodyAsBlob(Blob.valueOf('PDF-BYTES'));
                else res.setBody(projectBody);
                return res;
            }
            res.setStatusCode(404);
            res.setBody('Unknown endpoint: ' + ep);
            return res;
        }
    }
}