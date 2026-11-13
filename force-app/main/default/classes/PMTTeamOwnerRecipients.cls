/** ──────────────────────────────────────
 * @description Custom Email Recipient of Type Apex Resolver (US-20337), Value PMTTeamOwnerRecipients: the owners of the PMT teams of the record's project, for the emails
 *                  (EmailService) and Teams messages (TeamsMessageService) of the PMT. Replaces the 20 owner rows (and the Flows' 20-field formula) with one row.
 *              Owners: the owner field of every team of the PMT matrix on ProjectProduct__c (team key + '__c'), as set by ProjectProductSetupHandler from PMTTeam__mdt
 *                  and PMTOwnerRule__mdt (e.g. Legal by LegalForm__c) and as reassigned on the project; an empty field notifies nobody (e.g. IS on a PS project).
 *              A team with a Notification Condition (PMTTeam__mdt.NotificationCondition__c, a PMTCondition on the project, e.g. ESG only for SFDR 6, 8 or 9) is notified
 *                  only when it is true; an invalid condition is a configuration error.
 *              The record is the project, or a record with one lookup to ProjectProduct__c (Milestone__c, ProjectDocuments__c): one query per object, then one query of the projects.
 * @author Charles EID
 * @testClass TeamsMessageServiceTest
 * @coverage 100%   [12-11-26]
 ────────────────────────────────────── */
public without sharing class PMTTeamOwnerRecipients implements EmailService.RecipientResolver {

    private static final Schema.SObjectType PROJECT_TYPE = ProjectProduct__c.SObjectType;

    // Owners of each record's project, the teams whose Notification Condition is false left out
    public Map<Id, Set<Id>> getUserIds(Set<Id> recordIds) {
        Map<Id, Id> projectIdByRecordId = getProjectIds(recordIds);
        Map<String, PMTCondition> conditionByTeam = getNotificationConditions();
        Map<String, Schema.SObjectField> projectFields = PROJECT_TYPE.getDescribe().fields.getMap();
        Map<String, String> ownerFieldByTeam = new Map<String, String>();
        for (PMTMatrix.Team team : PMTMatrix.get().teams) {
            if (projectFields.containsKey(team.key + '__c')) ownerFieldByTeam.put(team.name, team.key + '__c');
        }
        Set<String> fields = new Set<String>{ 'id' };
        for (String field : ownerFieldByTeam.values()) fields.add(field.toLowerCase());
        for (PMTCondition condition : conditionByTeam.values()) {
            for (String field : condition.projectFields) fields.add(field.toLowerCase());
        }
        Set<Id> projectIds = new Set<Id>(projectIdByRecordId.values());
        Map<Id, ProjectProduct__c> projectById = new Map<Id, ProjectProduct__c>((List<ProjectProduct__c>) Database.query('SELECT ' + String.join(new List<String>(fields), ', ') + ' FROM ProjectProduct__c WHERE Id IN :projectIds'));

        Map<Id, Set<Id>> userIdsByRecordId = new Map<Id, Set<Id>>();
        for (Id recordId : recordIds) {
            ProjectProduct__c project = projectById.get(projectIdByRecordId.get(recordId));
            Set<Id> userIds = new Set<Id>();
            for (String teamName : ownerFieldByTeam.keySet()) {
                if (project == null) break;

                PMTCondition condition = conditionByTeam.get(teamName);
                if (condition != null && !condition.evaluate(project, null)) continue;

                Id ownerId = (Id) project.get(ownerFieldByTeam.get(teamName));
                if (ownerId != null) userIds.add(ownerId);
            }
            userIdsByRecordId.put(recordId, userIds);
        }
        return userIdsByRecordId;
    }

    // The project of each record: itself for a ProjectProduct__c, otherwise its lookup to ProjectProduct__c (one query per object)
    private static Map<Id, Id> getProjectIds(Set<Id> recordIds) {
        Map<Schema.SObjectType, Set<Id>> recordIdsByType = new Map<Schema.SObjectType, Set<Id>>();
        for (Id recordId : recordIds) {
            if (!recordIdsByType.containsKey(recordId.getSObjectType())) recordIdsByType.put(recordId.getSObjectType(), new Set<Id>());
            recordIdsByType.get(recordId.getSObjectType()).add(recordId);
        }
        Map<Id, Id> projectIdByRecordId = new Map<Id, Id>();
        for (Schema.SObjectType recordType : recordIdsByType.keySet()) {
            Set<Id> ids = recordIdsByType.get(recordType);
            if (recordType == PROJECT_TYPE) {
                for (Id recordId : ids) projectIdByRecordId.put(recordId, recordId);
                continue;
            }
            String projectField = getProjectField(recordType);
            List<SObject> records = Database.query('SELECT Id, ' + projectField + ' FROM ' + recordType + ' WHERE Id IN :ids');
            for (SObject record : records) projectIdByRecordId.put(record.Id, (Id) record.get(projectField));
        }
        return projectIdByRecordId;
    }

    // The record's lookup to ProjectProduct__c: exactly one is expected, otherwise the project can't be told (configuration error)
    private static String getProjectField(Schema.SObjectType recordType) {
        List<String> projectFields = new List<String>();
        for (Schema.SObjectField field : recordType.getDescribe().fields.getMap().values()) {
            Schema.DescribeFieldResult describe = field.getDescribe();
            if (describe.getReferenceTo().contains(PROJECT_TYPE)) projectFields.add(describe.getName());
        }
        if (projectFields.size() != 1) throw new EmailService.EmailServiceException('PMTTeamOwnerRecipients: ' + recordType + ' needs exactly one lookup to ProjectProduct__c to find the PMT team owners, found ' + (projectFields.isEmpty() ? 'none' : String.join(projectFields, ', ')) + '.');
        return projectFields[0];
    }

    // Notification Condition of each team that has one, compiled by PMTCondition (project fields only)
    private static Map<String, PMTCondition> getNotificationConditions() {
        Map<String, PMTCondition> conditionByTeam = new Map<String, PMTCondition>();
        for (PMTTeam__mdt team : [SELECT MasterLabel, NotificationCondition__c FROM PMTTeam__mdt]) {
            if (String.isBlank(team.NotificationCondition__c)) continue;

            String error = PMTMatrix.getConditionError(team.NotificationCondition__c, true);
            if (error != null) throw new EmailService.EmailServiceException('PMT team ' + team.MasterLabel + ': its Notification Condition is invalid (' + error + ').');
            conditionByTeam.put(team.MasterLabel, PMTCondition.compile(team.NotificationCondition__c));
        }
        return conditionByTeam;
    }
}