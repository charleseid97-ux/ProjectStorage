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

        Set<Id> projectIds = new Set<Id>();
        for (Request r : requests) {
            if (r != null && r.projectId != null) projectIds.add(r.projectId);
        }
        if (projectIds.isEmpty()) return results;

        List<ProjectShareclass__c> rows = [
            SELECT Id,
                   ProjectProduct__c,
                   Share_Class_Name__c,
                   Feeder__r.ProductName__c
            FROM ProjectShareclass__c
            WHERE ProjectProduct__c IN :projectIds
              AND Feeder__c != null
            ORDER BY Share_Class_Name__c
        ];

        Map<Id, List<ProjectShareclass__c>> byProject = new Map<Id, List<ProjectShareclass__c>>();
        for (ProjectShareclass__c r : rows) {
            if (!byProject.containsKey(r.ProjectProduct__c)) {
                byProject.put(r.ProjectProduct__c, new List<ProjectShareclass__c>());
            }
            byProject.get(r.ProjectProduct__c).add(r);
        }

        for (Id pid : projectIds) {

            List<ProjectShareclass__c> listSC = byProject.containsKey(pid)
                ? byProject.get(pid)
                : new List<ProjectShareclass__c>();

            // ✅ Si aucun feeder => on renvoie vide (rien à afficher)
            if (listSC.isEmpty()) {
                results.add(new Response(pid, '', ''));
                continue;
            }

            String html = '<div>'
                        + '<ul style="margin:6px 0 0 18px;">';
            String plain = '';

            for (ProjectShareclass__c sc : listSC) {
                String shareClassName = sc.Share_Class_Name__c;
                String feederName = (sc.Feeder__r != null) ? sc.Feeder__r.ProductName__c : '';

                html += '<li>' + shareClassName + ' – Feeder: ' + feederName + '</li>';
                plain += shareClassName + ' – Feeder: ' + feederName + '\n';
            }

            html += '</ul></div>';

            results.add(new Response(pid, html, plain));
        }

        return results;
    }
}
