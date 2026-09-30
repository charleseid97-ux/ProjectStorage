/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 29-SEP-2026
 * @last modified by  : Charles EID
**/
public abstract class RestCallout {

    private static final Integer MAX_LOGGED_BODY_LENGTH = 25000;

    public  void callEndPoint(HttpRequest req){
        //Appel au webservice
        HttpResponse res;
        Exception calloutException;

        try{
            req.setMethod(getMethod());
            req.setHeader('Accept-Encoding', 'gzip, deflate, br');

            Http http = new Http();
            res = http.send(req);

            processResponse(res);
        }
        catch(Exception e){
            calloutException = e;
            system.debug('** from restcallout ' + e.getLineNumber() + '/' + e.getMessage());
        } 
        finally {
            logCallout(req, res, calloutException);
        }
    }

    // Journalise chaque appel Lyyti (requête + réponse ou exception) via OperationLogService.
    private void logCallout(HttpRequest req, HttpResponse res, Exception ex) {
        String className = getClassName();

        Map<String, Object> context = new Map<String, Object>();
        context.put('endpoint', req.getEndpoint());
        context.put('httpMethod', req.getMethod());
        context.put('requestBody', truncateForLog(req.getBody()));

        if (res != null) {
            context.put('statusCode', res.getStatusCode());
            context.put('status', res.getStatus());
            context.put('responseBody', truncateForLog(res.getBody()));
        }

        Boolean isError = ex != null || (res != null && res.getStatusCode() >= 400);

        // Buffer only - do not flush here. RestCallout is shared by call sites that make several
        // callouts per transaction (e.g. BATCH_SendCampaignMemberLyyti's loop): flushing after every
        // single callout does a DML insert, and Salesforce forbids a callout after DML in the same
        // transaction, so a per-call flush here silently breaks every callout after the first one.
        // OperationLogService.log() still auto-flushes once the buffer hits its own size cap, and
        // callers are expected to flush once at their natural transaction boundary (matching the
        // pattern used elsewhere in this codebase, e.g. CityWireUpdateBatch).
        OperationLogService.logWithContext(isError ? OperationLogService.Level.ERROR : OperationLogService.Level.INFO, getSourceRecordId(), getSourceObjectApiName(), className + ' - ' + req.getMethod(), buildLogMessage(className, req, res, ex), context, ex, className, 'callEndPoint');
    }

    private String buildLogMessage(String className, HttpRequest req, HttpResponse res, Exception ex) {
        if (ex != null) return className + ' callout to ' + req.getEndpoint() + ' threw ' + ex.getTypeName() + ': ' + ex.getMessage();

        if (res != null) return className + ' callout to ' + req.getEndpoint() + ' returned ' + res.getStatusCode() + ' ' + res.getStatus();

        return className + ' callout to ' + req.getEndpoint() + ' produced no response';
    }

    private String truncateForLog(String value) {
        if (String.isBlank(value) || value.length() <= MAX_LOGGED_BODY_LENGTH) return value;

        return value.substring(0, MAX_LOGGED_BODY_LENGTH) + '... [truncated]';
    }

    // Déduit le nom de la classe concrète (ex. WS_SendCampaign) sans que chaque sous-classe n'ait à le fournir.
    private String getClassName() {
        String defaultToString = String.valueOf(this);
        Integer separatorIndex = defaultToString.indexOf(':');

        return separatorIndex > 0 ? defaultToString.substring(0, separatorIndex) : defaultToString;
    }

    public abstract String getMethod();
    public abstract String setJsonBody();
    public abstract void processResponse(HttpResponse response);

    // Permet à une sous-classe d'associer le log au record source (Campaign, CampaignMember, id externe...).
    public virtual String getSourceRecordId() {
        return null;
    }

    public virtual String getSourceObjectApiName() {
        return null;
    }
}