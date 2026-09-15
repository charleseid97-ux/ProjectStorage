/** ──────────────────────────────────────
 * @description Single-responsibility HTTP wrapper around the Citywire "GET /Fund/{ISIN}" endpoint. Configuration (Named Credential developer name, timeout) comes from CityWireSettings__mdt;
 *              authentication (X-Api-Key) is injected by the Named Credential itself and never touched here.
 * @author Charles EID
 * @testClass CityWireCalloutServiceTest
 * @coverage 100%   [15-09-26]
────────────────────────────────────── */
public without sharing class CityWireCalloutService {

    private static final String DEFAULT_NAMED_CREDENTIAL = 'CityWireApi';
    private static final Integer DEFAULT_TIMEOUT_MS = 20000;
    private static final Integer MAX_TIMEOUT_MS = 120000;

    public class CityWireCalloutException extends Exception { }

    public class CityWireFundResponseWrapper {
        public String ISIN;
        public String SummaryDisclaimer;
        public String RatingDate;
        public String PublishDate;
        public List<CityWireManagerWrapper> Managers;
    }

    public class CityWireManagerWrapper {
        public Decimal ID;
        public String FirstName;
        public String LastName;
        public CityWireRatingWrapper Rating;
    }

    public class CityWireRatingWrapper {
        public Decimal RatingValue;
        public String Description;
        public String ImageSrc;
        public String Disclaimer;
    }

    public static CityWireFundResponseWrapper getFund(String isin) {
        CityWireSettings__mdt settings = CityWireSettings__mdt.getInstance('Default');
        String namedCredentialName = settings != null && String.isNotBlank(settings.NamedCredentialDeveloperName__c) ? settings.NamedCredentialDeveloperName__c : DEFAULT_NAMED_CREDENTIAL;
        Integer timeoutMs = settings != null && settings.TimeoutMs__c != null ? Integer.valueOf(settings.TimeoutMs__c) : DEFAULT_TIMEOUT_MS;
        timeoutMs = Math.min(timeoutMs, MAX_TIMEOUT_MS);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + namedCredentialName + '/Fund/' + EncodingUtil.urlEncode(isin, 'UTF-8'));
        req.setMethod('GET');
        req.setTimeout(timeoutMs);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } 
        catch (Exception ex) {
            throw new CityWireCalloutException('Citywire callout failed for ISIN ' + isin + ': ' + ex.getMessage(), ex);
        }

        if (res.getStatusCode() != 200) {
            throw new CityWireCalloutException('Citywire callout for ISIN ' + isin + ' returned status ' + res.getStatusCode() + ': ' + res.getStatus());
        }

        try {
            return (CityWireFundResponseWrapper) JSON.deserialize(res.getBody(), CityWireFundResponseWrapper.class);
        } 
        catch (Exception ex) {
            throw new CityWireCalloutException('Citywire response for ISIN ' + isin + ' could not be parsed: ' + ex.getMessage(), ex);
        }
    }
}