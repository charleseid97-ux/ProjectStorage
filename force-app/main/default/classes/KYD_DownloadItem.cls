public class KYD_DownloadItem 
{
    private static final Elysee_Filesystem__c ELYSEE_FILESYSTEM_PARAMS = Elysee_Filesystem__c.getInstance();
    
        private final KYD_Document_Item__c kyddoc;
    
        public KYD_DownloadItem(ApexPages.StandardController stdController) {
            KYD_Document_Item__c item = (KYD_Document_Item__c)stdController.getRecord();
            System.debug(item);
            this.kyddoc = [SELECT Id, External_Repository_Id__c FROM KYD_Document_Item__c WHERE Id =: item.Id];
        }
        public String getPdf()
        {
            HttpRequest request = new HttpRequest();
            request.setHeader('Content-Type','application/json');
            request.setMethod('GET');
            String pathname = this.kyddoc.External_Repository_Id__c;
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