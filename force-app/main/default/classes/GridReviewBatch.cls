/** ──────────────────────────────────────
 * @description Batch class for the Grid Review scheduled alert.
 *              Collects all Grid__c records whose NextReviewDate__c <= today, classifies them
 *                  by Carmignac legal entity (CGL / CGF), and sends an HTML review email
 *                  to the corresponding Top Management queue for each entity.
 *              Implements ICustomAlerter to be dispatched dynamically by CustomAlertScheduler.
 *              Stamps LastReviewSentDate__c on all processed grids after sending.
 * @author Charles EID
 * @testClass GridReviewBatchTest
 * @coverage 97%   [11-05-26]
 ────────────────────────────────────── */
public with sharing class GridReviewBatch implements Database.Batchable<SObject>, Database.Stateful, ICustomAlerter {

    private final static String DATATABLEELEMENT = '{_Datatable_}';

    private Map<Id, Grid__c> cglGrids = new Map<Id, Grid__c>();
    private Map<Id, Grid__c> cgfGrids  = new Map<Id, Grid__c>();
    private ScheduledAlert__mdt alertConfig;

    public GridReviewBatch() {}

    public GridReviewBatch(ScheduledAlert__mdt config) {
        this.alertConfig = config;
    }

    // ICustomAlerter entry point — called by CustomAlertScheduler
    public void dispatch(ScheduledAlert__mdt config) {
        Integer batchSize = (config.BatchSize__c != null) ? (Integer) config.BatchSize__c : 200;
        Database.executeBatch(new GridReviewBatch(config), batchSize);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id, Name, Agreement__r.Name, Agreement__r.Company_Name__c, Agreement__r.Carmignac_Legal_Entity__c, BusinessBackground__c
                                         FROM Grid__c
                                         WHERE NextReviewDate__c <= TODAY
                                         AND Agreement__r.Carmignac_Legal_Entity__c != null]);
    }

    public void execute(Database.BatchableContext bc, List<Grid__c> scope) {
        for (Grid__c grid : scope) {
            String entity = grid.Agreement__r.Carmignac_Legal_Entity__c;
            if (entity == 'CGL') {
                cglGrids.put(grid.Id, grid);
            } else if (entity == 'CGF') {
                cgfGrids.put(grid.Id, grid);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        String orgBaseUrl = URL.getOrgDomainUrl().toExternalForm();
        String templateDevName = alertConfig != null ? alertConfig.EmailTemplate__c : null;
        String templateHtml = getEmailTemplateHtml(templateDevName);

        Map<String, Set<String>> emailsByQueue = getQueueMemberEmails(new Set<String>{'CGL_Top_Management', 'CGF_Top_Management'});
        System.debug('@@@@@@@@emailsByQueue: '+emailsByQueue);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        if (!cglGrids.isEmpty()) {
            Set<String> cglAddresses = emailsByQueue.get('CGL_Top_Management');
            if (cglAddresses != null && !cglAddresses.isEmpty()) {
                System.debug('@@@@@ CGL @@@@cglAddresses != null && !cglAddresses.isEmpty() !!!');
                emails.add(buildEmail(cglGrids, 'CGL', cglAddresses, orgBaseUrl, templateHtml));
            }
        }

        if (!cgfGrids.isEmpty()) {
            Set<String> cgfAddresses = emailsByQueue.get('CGF_Top_Management');
            if (cgfAddresses != null && !cgfAddresses.isEmpty()) {
                System.debug('@@@@ CGF @@@@@cgfAddresses != null && !cgfAddresses.isEmpty() !!!');
                emails.add(buildEmail(cgfGrids, 'CGF', cgfAddresses, orgBaseUrl, templateHtml));
            }
        }
        System.debug('@@@@@@@@@@@@emails: '+emails);

        if (!emails.isEmpty()) {
            if (!Test.isRunningTest()) {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);
                for (Messaging.SendEmailResult result : results) {
                    if (!result.isSuccess()) {
                        System.debug('GridReviewBatch email error: ' + result.getErrors()[0].getMessage());
                    }
                }
            }
        }

        stampLastReviewSentDate();
    }

    private Messaging.SingleEmailMessage buildEmail(Map<Id, Grid__c> grids, String entity, Set<String> toAddresses, String orgBaseUrl, String templateHtml) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSubject('Agreement Grid Review — ' + entity);
        mail.setToAddresses(new List<String>(toAddresses));
        mail.setHtmlBody(templateHtml.replace(DATATABLEELEMENT, buildTableHtml(grids, orgBaseUrl)));
        return mail;
    }

    private String getEmailTemplateHtml(String devName) {
        if (String.isBlank(devName)) {
            return DATATABLEELEMENT;
        }
        List<EmailTemplate> templates = [SELECT HtmlValue FROM EmailTemplate WHERE DeveloperName = :devName LIMIT 1];
        return (templates.isEmpty() || String.isBlank(templates[0].HtmlValue)) ? DATATABLEELEMENT : templates[0].HtmlValue;
    }

    private String buildTableHtml(Map<Id, Grid__c> grids, String orgBaseUrl) {
        String html = '<table border="1" cellpadding="6" cellspacing="0" width="100%" style="border-collapse:collapse; font-family:arial; font-size:11pt;">'
            + '<thead><tr style="background-color:#003366; color:#FFFFFF;">'
            + '<th align="left">Grid Name</th>'
            + '<th align="left">Agreement Name</th>'
            + '<th align="left">Company Name</th>'
            + '<th align="left">Business Background</th>'
            + '</tr></thead><tbody>';

        for (Grid__c grid : grids.values()) {
            String gridUrl = orgBaseUrl + '/' + grid.Id;
            String agreementName = grid.Agreement__r != null ? grid.Agreement__r.Name : '';
            String companyName   = grid.Agreement__r != null ? String.isNotBlank(grid.Agreement__r.Company_Name__c)? grid.Agreement__r.Company_Name__c : '' : '';
            String background    = String.isNotBlank(grid.BusinessBackground__c) ? grid.BusinessBackground__c : '';

            html += '<tr>'
                + '<td><a href="' + gridUrl + '">' + grid.Name + '</a></td>'
                + '<td>' + agreementName + '</td>'
                + '<td>' + companyName + '</td>'
                + '<td>' + background + '</td>'
                + '</tr>';
        }

        html += '</tbody></table>';
        return html;
    }

    private Map<String, Set<String>> getQueueMemberEmails(Set<String> developerNames) {
        Map<Id, String> queueIdToDevName = new Map<Id, String>();
		Map<String, Set<String>> result = new Map<String, Set<String>>();

        for (Group q : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName IN :developerNames]) {
            queueIdToDevName.put(q.Id, q.DeveloperName);
            result.put(q.DeveloperName, new Set<String>());
        }

        Map<Id, Set<String>> groupIdToQueueDevNames = new Map<Id, Set<String>>();
        Set<Id> nestedGroupIds = new Set<Id>();
        
        for (GroupMember gm : [SELECT GroupId, UserOrGroupId, UserOrGroup.Email
                               FROM GroupMember
                               WHERE GroupId IN :queueIdToDevName.keySet()]) {
            String queueDevName = queueIdToDevName.get(gm.GroupId);
            
            if (String.isNotBlank(gm.UserOrGroup.Email)) {
                result.get(queueDevName).add(gm.UserOrGroup.Email);
            } 
            else {
                nestedGroupIds.add(gm.UserOrGroupId);
                if (!groupIdToQueueDevNames.containsKey(gm.UserOrGroupId)) {
                    groupIdToQueueDevNames.put(gm.UserOrGroupId, new Set<String>());
                }
                groupIdToQueueDevNames.get(gm.UserOrGroupId).add(queueDevName);
            }
        }
        
        if (!nestedGroupIds.isEmpty()) {
            for (GroupMember gm : [SELECT GroupId, UserOrGroupId, UserOrGroup.Email
                                   FROM GroupMember
                                   WHERE GroupId IN :nestedGroupIds]) {
                if (String.isNotBlank(gm.UserOrGroup.Email)) {
                    for (String queueDevName : groupIdToQueueDevNames.get(gm.GroupId)) {
                        result.get(queueDevName).add(gm.UserOrGroup.Email);
                    }
                }
            }
        }
        return result;
    }

    private void stampLastReviewSentDate() {
        Map<Id, Grid__c> allGrids = new Map<Id, Grid__c>();
        allGrids.putAll(cglGrids);
        allGrids.putAll(cgfGrids);

        if (allGrids.isEmpty()) {
            return;
        }

        List<Grid__c> toUpdate = new List<Grid__c>();
        for (Id gridId : allGrids.keySet()) {
            toUpdate.add(new Grid__c(Id = gridId, LastReviewSentDate__c = Date.today()));
        }
        update toUpdate;
    }
}