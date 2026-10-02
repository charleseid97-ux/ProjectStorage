public with sharing class ProjectFeederFlowAction {

    public class Request {
        @InvocableVariable(required=true)
        public Id projectId;
    }

    public class Response {
        @InvocableVariable
        public Id projectId;

        @InvocableVariable
        public String feedersHtml;

        @InvocableVariable
        public String feedersPlain;

        public Response(Id pId, String html, String plain) {
            this.projectId = pId;
            this.feedersHtml = html;
            this.feedersPlain = plain;
        }
    }

    @InvocableMethod(
        label='Get Project Feeders for Email'
        description='Returns feeder-related share classes formatted for email body'
    )
    public static List<Response> getFeeders(List<Request> requests) {
        List<Response> results = new List<Response>();
        if (requests == null || requests.isEmpty()) return results;

        Set<Id> projectIds = collectProjectIds(requests);
        if (projectIds.isEmpty()) return results;

        List<ProjectShareclass__c> rows = queryFeeders(projectIds);
        Map<Id, List<ProjectShareclass__c>> byProject = groupByProject(rows);

        for (Id pid : projectIds) {
            // buildResponse handles empty / null lists
            results.add(buildResponse(pid, byProject.get(pid)));
        }

        return results;
    }

    // ------------------------
    // Helper methods (extracted to reduce cognitive complexity)
    // ------------------------

    private static Set<Id> collectProjectIds(List<Request> requests) {
        Set<Id> projectIds = new Set<Id>();
        for (Request r : requests) {
            if (r != null && r.projectId != null) {
                projectIds.add(r.projectId);
            }
        }
        return projectIds;
    }

    private static List<ProjectShareclass__c> queryFeeders(Set<Id> projectIds) {
        return [
            SELECT Id,
                   ProjectProduct__c,
                   Share_Class_Name__c,
                   Feeder__r.ProductName__c
            FROM ProjectShareclass__c
            WHERE ProjectProduct__c IN :projectIds
              AND Feeder__c != null
            ORDER BY Share_Class_Name__c
        ];
    }

    private static Map<Id, List<ProjectShareclass__c>> groupByProject(List<ProjectShareclass__c> rows) {
        Map<Id, List<ProjectShareclass__c>> byProject = new Map<Id, List<ProjectShareclass__c>>();
        if (rows == null || rows.isEmpty()) return byProject;

        for (ProjectShareclass__c r : rows) {
            if (r.ProjectProduct__c == null) continue;
            if (!byProject.containsKey(r.ProjectProduct__c)) {
                byProject.put(r.ProjectProduct__c, new List<ProjectShareclass__c>());
            }
            byProject.get(r.ProjectProduct__c).add(r);
        }
        return byProject;
    }

    private static Response buildResponse(Id pid, List<ProjectShareclass__c> listSC) {
        if (listSC == null || listSC.isEmpty()) {
            return new Response(pid, '', '');
        }

        String html = '<div><ul style="margin:6px 0 0 18px;">';
        String plain = '';

        for (ProjectShareclass__c sc : listSC) {
            String shareClassName = sc.Share_Class_Name__c == null ? '' : sc.Share_Class_Name__c;
            String feederName = (sc.Feeder__r != null && sc.Feeder__r.ProductName__c != null) ? sc.Feeder__r.ProductName__c : '';

            // simple HTML escaping for safety (avoid raw injection of <, >, & and " )
            html += '<li>' + escapeHtml(shareClassName) + ' – Feeder: ' + escapeHtml(feederName) + '</li>';
            plain += shareClassName + ' – Feeder: ' + feederName + '\n';
        }

        html += '</ul></div>';
        return new Response(pid, html, plain);
    }

    // Minimal HTML-escape helper
    private static String escapeHtml(String input) {
        if (input == null) return '';
        // order matters: & first
        String out = input.replace('&', '&amp;')
                          .replace('<', '&lt;')
                          .replace('>', '&gt;')
                          .replace('"', '&quot;');
        return out;
    }
}