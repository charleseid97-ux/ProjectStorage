// ApprovalRestApprover.cls
// Helper class — fallback using Approvals REST action via Named Credential.
// Must be a top-level class (so @future works reliably).

public class ApprovalRestApprover {
    // Public entrypoint used by controller to queue async REST attempt
    public static void queueApprovalViaRest(String awiId, String flowOrchId, String submissionId, String action, String comments) {
        // Fire and forget; @future will perform callout.
        approveViaRestAsync(awiId, flowOrchId, submissionId, action, comments);
    }

    @future(callout=true)
    public static void approveViaRestAsync(String awiId, String flowOrchId, String submissionId, String action, String comments) {
        // NB: configure this Named Credential in your org and grant it API access.
        String namedCredential = 'CalloutToOrg'; // <-- change to your Named Credential name

        String apiVer = 'v56.0'; // adapter si besoin
        String endpoint = 'callout:' + namedCredential + '/services/data/' + apiVer + '/actions/standard/approve';

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        // Try with awiId first (contextId). If your org expects a different key, adapt payload.
        Map<String,Object> input = new Map<String,Object>{
            'action' => action,
            'contextId' => awiId,
            'comments' => comments
        };
        Map<String,Object> bodyMap = new Map<String,Object>{ 'inputs' => new List<Object>{ input } };
        req.setBody(JSON.serialize(bodyMap));

        try {
            HttpResponse resp = http.send(req);
            Integer sc = resp.getStatusCode();
            System.debug('[ApprovalRestApprover] REST status=' + sc + ' body=' + resp.getBody());

            if (sc >= 200 && sc < 300) {
                System.debug('[ApprovalRestApprover] REST approve succeeded for contextId=' + awiId);
                return;
            }

            // try alternative ids
            List<String> candidates = new List<String>();
            if (!String.isBlank(flowOrchId)) candidates.add(flowOrchId);
            if (!String.isBlank(submissionId)) candidates.add(submissionId);

            for (String cand : candidates) {
                input.put('contextId', cand);
                req.setBody(JSON.serialize(bodyMap));
                resp = http.send(req);
                sc = resp.getStatusCode();
                System.debug('[ApprovalRestApprover] REST try contextId=' + cand + ' status=' + sc + ' body=' + resp.getBody());
                if (sc >= 200 && sc < 300) {
                    System.debug('[ApprovalRestApprover] REST approve succeeded for contextId=' + cand);
                    return;
                }
            }

            System.debug('[ApprovalRestApprover] All REST attempts failed. Last status=' + sc + ' body=' + (resp==null?'<null>':resp.getBody()));
        } catch (Exception ex) {
            System.debug('[ApprovalRestApprover] Exception during REST approve: ' + ex);
        }
    }
}
