/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 15-07-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public abstract class RestCallout {

    

    public  void callEndPoint(HttpRequest req){
        //Appel au webservice
        try{
            req.setMethod(getMethod());
            req.setHeader('Accept-Encoding', 'gzip, deflate, br');
            
            //req.setHeader('Content-Type', 'application/json; charset=utf-8');
            //req.setEndpoint('callout:'+getNameCredential());
            
            System.debug('requete from RestCallout ' + req);
            
            //req.setBody(setJsonBody());
            
            Http http = new Http();
            HTTPResponse res = http.send(req);
            
            //Helpful debug messages
            System.debug('STATUS_CODE:' + res.getStatusCode());
            String responseJSON = res.getBody();
            System.debug('responseJSON:' + responseJSON);

            
            processResponse(res);
        }catch(Exception e){
            system.debug('** from restcallout ' + e.getLineNumber() + '/' + e.getMessage());
        }
        
    }

    
    public abstract String getMethod();
    public abstract String setJsonBody();
    public abstract void processResponse(HttpResponse response);

}