@IsTest
private class VFC16_SequantisGenerateDraftTest {

    // === Constants to avoid duplicated literals ===
    private static final String TOKEN_OK = 'TOKEN-OK';
    private static final String SC_FIELDS_CURRENCY_TYPE = 'CurrencyIsoCode;Type__c';

    // === Record Type ids resolved exactly like your batch test ===
    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();

    private static final Id fundModificationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();

    private static final Id shareclassCreationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('ShareclassCreation').getRecordTypeId();

    // === Minimal helper only for RecommendedHoldingPeriodUnit__c ===
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

    // === HTTP Mock for Sequantis ===
    private class SequantisHttpMock implements HttpCalloutMock {
        Integer tokenCode; String tokenBody;
        Integer projectCode; String projectBody;
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
                if (projectCode == 200 && returnPdf) {
                    res.setBodyAsBlob(Blob.valueOf('PDF-BYTES'));
                } else {
                    res.setBody(projectBody);
                }
                return res;
            }

            res.setStatusCode(404);
            res.setBody('Unknown endpoint: ' + ep);
            return res;
        }
    }

    // === Holder for PP + SC since Apex has no out params ===
    private class DataBundle {
        ProjectProduct__c pp;
        ProjectShareclass__c sc;
        DataBundle(ProjectProduct__c p, ProjectShareclass__c s) {
            pp = p;
            sc = s;
        }
    }

    // === Build data EXACTLY like Test_ProjectProductBatch ===
    private static DataBundle arrangeFundCreationData() {
        ProjectProduct__c pp = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);

        pp.EndDate__c = Date.today();

        if (Schema.sObjectType.ProjectProduct__c.fields.getMap().containsKey('Product_Name__c')) {
            pp.Name = 'PRD - ' + (pp.Name == null ? 'Fund' : pp.Name) + ' - EUR';
        }

        pp.internalShortName__c = 'PP-INT';
        pp.RecommendedHoldingPeriod__c = 5;

        if (Schema.sObjectType.ProjectProduct__c.fields.getMap().containsKey('RecommendedHoldingPeriodUnit__c')) {
            pp.RecommendedHoldingPeriodUnit__c =
                pickOneOf(ProjectProduct__c.RecommendedHoldingPeriodUnit__c,
                    new List<String>{ 'Years', 'Year', 'Ans' });
        }

        update pp;

        ProjectShareclass__c sc =
            PMTTestFactoryData.createProjectShareclass(pp.Id, SC_FIELDS_CURRENCY_TYPE);

        return new DataBundle(pp, sc);
    }

    // ========== TESTS ==========

    @IsTest
    static void test_draft_single_pdf_200() {
        DataBundle d = arrangeFundCreationData();
        ApexPages.StandardController std = new ApexPages.StandardController(d.pp);
        VFC16_SequantisGenerateDraft ctrl = new VFC16_SequantisGenerateDraft(std);
        VFC16_SequantisGenerateDraft.selectedRecordId = d.sc.Id;

        Test.setMock(HttpCalloutMock.class,
            new SequantisHttpMock(200, TOKEN_OK, 200, 'IGNORED', true));

        Test.startTest();
        ctrl.genPDF();
        Test.stopTest();

        System.assert(ctrl.showPDF);
        System.assertNotEquals(null, VFC16_SequantisGenerateDraft.pdf);
        System.assertEquals(null, VFC16_SequantisGenerateDraft.errorMessage);
    }

    @IsTest
    static void test_updateAll_202_info_no_pdf() {
        DataBundle d = arrangeFundCreationData();
        PMTTestFactoryData.createProjectShareclass(d.pp.Id, SC_FIELDS_CURRENCY_TYPE);

        ApexPages.StandardController std = new ApexPages.StandardController(d.pp);
        VFC16_SequantisGenerateDraft ctrl = new VFC16_SequantisGenerateDraft(std);
        VFC16_SequantisGenerateDraft.selectedRecordId = 'updateAll';

        Test.setMock(HttpCalloutMock.class,
            new SequantisHttpMock(200, TOKEN_OK, 202, 'Accepted', false));

        Test.startTest();
        ctrl.genPDF();
        Test.stopTest();

        System.assertEquals(false, ctrl.showPDF);
        System.assert(String.isBlank(VFC16_SequantisGenerateDraft.errorMessage));
        System.assert(!String.isBlank(VFC16_SequantisGenerateDraft.infoMessage));
    }

    @IsTest
    static void test_missing_required_fields_sets_error() {
        ProjectProduct__c pp =
            PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);

        pp.EndDate__c = Date.today();

        if (Schema.sObjectType.ProjectProduct__c.fields.getMap().containsKey('Product_Name__c')) {
            pp.Product_Name__c = 'PRD - Fund ABC - EUR';
        }
        update pp;

        ProjectShareclass__c sc =
            PMTTestFactoryData.createProjectShareclass(pp.Id, SC_FIELDS_CURRENCY_TYPE);

        ApexPages.StandardController std = new ApexPages.StandardController(pp);
        VFC16_SequantisGenerateDraft ctrl = new VFC16_SequantisGenerateDraft(std);
        VFC16_SequantisGenerateDraft.selectedRecordId = sc.Id;

        Test.setMock(HttpCalloutMock.class,
            new SequantisHttpMock(200, TOKEN_OK, 200, 'IGNORED', true));

        Test.startTest();
        ctrl.genPDF();
        Test.stopTest();

        System.assertEquals(false, ctrl.showPDF);
        System.assert(
            VFC16_SequantisGenerateDraft.errorMessage != null &&
            VFC16_SequantisGenerateDraft.errorMessage.startsWith('<br/> generation failed')
        );
    }

    @IsTest
    static void test_service_500_throws() {
        DataBundle d = arrangeFundCreationData();
        ApexPages.StandardController std = new ApexPages.StandardController(d.pp);
        VFC16_SequantisGenerateDraft ctrl = new VFC16_SequantisGenerateDraft(std);
        VFC16_SequantisGenerateDraft.selectedRecordId = d.sc.Id;

        Test.setMock(HttpCalloutMock.class,
            new SequantisHttpMock(200, TOKEN_OK, 500, 'Server error', false));

        try {
            Test.startTest();
            ctrl.genPDF();
            System.assert(false, 'Expected exception');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Erreur génération PDF (500)'));
        } finally {
            Test.stopTest();
        }
    }

    @IsTest
    static void test_token_failure_throws() {
        DataBundle d = arrangeFundCreationData();
        ApexPages.StandardController std = new ApexPages.StandardController(d.pp);
        VFC16_SequantisGenerateDraft ctrl = new VFC16_SequantisGenerateDraft(std);
        VFC16_SequantisGenerateDraft.selectedRecordId = d.sc.Id;

        Test.setMock(HttpCalloutMock.class,
            new SequantisHttpMock(401, 'Bad creds', 200, 'IGNORED', true));

        try {
            Test.startTest();
            ctrl.genPDF();
            System.assert(false, 'Expected token error');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('OAuth token request failed'));
        } finally {
            Test.stopTest();
        }
    }
}
