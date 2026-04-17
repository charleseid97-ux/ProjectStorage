@IsTest
public class MetadataUtilsTest {

    @IsTest
    public static void updateMetadataTest() {
        String fullName = 'OfficesAsPerCountry';
        String values = '{"Country__c": "North America", "Office__c": "England"}';
        Map<String, Object> deployedValue = (Map<String, Object>)JSON.deserializeUntyped(values);
        Map<String, Map<String, Object>> listDeployedValue = new Map<String, Map<String, Object>> { 'TEST' => deployedValue };
        MetadataUtils.updateCustomMetadata(fullName, listDeployedValue);
        MetadataUtils.handleResult(new Metadata.DeployResult(), new Metadata.DeployCallbackContext());
    }
    
    @isTest
    public static void updateAgreementCounterTest() {
        Map<String, Decimal> agreementCounter = MetadataUtils.getAgreementCounters();
        List<Decimal> counterCopy = new List<Decimal>();
        for (Decimal counter : agreementCounter.Values()) {
            counter += 1;
            counterCopy.add(counter);
        }
        MetadataUtils.updateAgreementCounters(agreementCounter);
    }

    @isTest
    public static void testGetPreferenceCenterFundsCountries() {
        Map<String, List<String>> listPreferenceCenter = MetadataUtils.getPreferenceCenterFundsCountries();
    }

    @isTest
    public static void testGetPrefCenterFundsFromProductAndCountries() {
        Map<String, String> listPreferenceCenter = MetadataUtils.getPrefCenterFundsFromProductAndCountries();
    }
    
    @isTest
    static void testPreferenceCenterCategory() {
        List<String> res = MetadataUtils.getPreferenceCenterCategory('');
        System.assert(res.size() > 0);
    }
}