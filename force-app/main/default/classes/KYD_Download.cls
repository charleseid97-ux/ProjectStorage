public class KYD_Download
{
    private static final Elysee_Filesystem__c ELYSEE_FILESYSTEM_PARAMS = Elysee_Filesystem__c.getInstance();

    private final KYD_Document__c kyddoc;

    public KYD_Download(ApexPages.StandardController stdController) {
        this.kyddoc = (KYD_Document__c)stdController.getRecord();
    }
    public String getPdf()
    {
        HttpRequest request = new HttpRequest();
        request.setHeader('Content-Type','application/json');
        request.setMethod('GET');
        String pathname = [SELECT Id, External_Repository_Id__c FROM KYD_Document__c WHERE Id =: this.kyddoc.Id].External_Repository_Id__c;
        request.setHeader('Authorization', 'Bearer ' + new KYD_FileService().OAuth());
        request.setHeader('Accept', '/');
        request.setHeader('Accept-Encoding', 'gzip, deflate, br');
        request.setEndpoint(ELYSEE_FILESYSTEM_PARAMS.Download_Endpoint__c +'?Path='+ EncodingUtil.urlEncode(pathname, 'UTF-8'));
        request.setTimeout(120000);
        Http http = new Http();
        HttpResponse res = http.send(request);

        System.debug(res.getStatusCode());
        System.debug(res.getBody());
        return EncodingUtil.base64Encode(res.getBodyAsBlob());
    }
}