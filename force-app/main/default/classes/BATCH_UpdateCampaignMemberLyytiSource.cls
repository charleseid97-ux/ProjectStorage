/** ──────────────────────────────────────
 * @description Scheduled/batch job that backfills CampaignMember.Lyyti_Source__c for members synced from
 *              Lyyti events. For each Campaign still having unresolved members, calls the Lyyti participant
 *              type and participant APIs to resolve each member's source, remapping "Invited" to "Salesforce".
 * @author Charles EID
 * @testClass BATCH_UpdateCampaignMemberLyytiSrcTest
 * @coverage 92%   [19-08-26]
────────────────────────────────────── */
public class BATCH_UpdateCampaignMemberLyytiSource implements Database.Batchable<sObject>, Database.AllowsCallouts, Schedulable {

    private static final String SOURCE_UNKNOWN = 'Unknown';
    private static final String SOURCE_INVITED = 'Invited';
    private static final String SOURCE_SALESFORCE = 'Salesforce';

    @TestVisible
    private static Integer maxMembersPerCampaignPerRun = 9000;

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Datetime threeMonthsAgo = System.now().addMonths(-3);
        Datetime nowDt = System.now();

        return Database.getQueryLocator([SELECT Id, LyytiId__c
                                         FROM Campaign
                                         WHERE LyytiId__c != null
                                         AND Start_Date_Time__c >= :threeMonthsAgo
                                         AND Start_Date_Time__c <= :nowDt
                                         AND Id IN (SELECT CampaignId 
                                                    FROM CampaignMember 
                                                    WHERE LyytiId__c != null 
                                                    AND (Lyyti_Source__c = null OR Lyyti_Source__c = 'Unknown'))]);
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        List<Campaign> campaigns = (List<Campaign>) scope;

        Set<Id> campaignIds = new Set<Id>();
        for (Campaign c : campaigns) {
            campaignIds.add(c.Id);
        }

        Map<Id, List<CampaignMember>> membersByCampaignId = new Map<Id, List<CampaignMember>>();
        for (CampaignMember cm : [SELECT Id, CampaignId, LyytiId__c
                                  FROM CampaignMember
                                  WHERE CampaignId IN :campaignIds
                                  AND LyytiId__c != null
                                  AND (Lyyti_Source__c = null OR Lyyti_Source__c = 'Unknown')
                                  LIMIT :maxMembersPerCampaignPerRun]) {
            if (!membersByCampaignId.containsKey(cm.CampaignId)) {
                membersByCampaignId.put(cm.CampaignId, new List<CampaignMember>());
            }
            membersByCampaignId.get(cm.CampaignId).add(cm);
        }

        List<CampaignMember> cmToUpdate = new List<CampaignMember>();

        for (Campaign campaign : campaigns) {
            List<CampaignMember> members = membersByCampaignId.get(campaign.Id);
            if (members == null || members.isEmpty()) {
                continue;
            }

            WS_LyytiGetParticipantTypes typeSender = new WS_LyytiGetParticipantTypes(campaign);
            typeSender.sendInDataToExternalService();

            if (!typeSender.success) {
                OperationLogService.error(campaign.Id, 'WS_LyytiGetParticipantTypes', 'Failed to retrieve participant types for campaign ' + campaign.Id);
                continue;
            }

            WS_GetEventParticipants participantsSender = new WS_GetEventParticipants(campaign, 15000, 0, typeSender.participantTypeNameById);
            participantsSender.sendInDataToExternalService();

            if (!participantsSender.success) {
                OperationLogService.error(campaign.Id, 'WS_GetEventParticipants', 'Failed to retrieve participants for campaign ' + campaign.Id);
                continue;
            }

            for (CampaignMember cm : members) {
                // Lyyti's "uid" field on a participant *is* the value stored verbatim in CampaignMember.LyytiId__c
                // (see WS_UpdateCampaignMembers/SM016_CampaignMemberService) - no splitting needed to match here.
                String typeId = participantsSender.participantTypeIdByUid.get(cm.LyytiId__c);
                String label = typeId == null ? null : typeSender.participantTypeNameById.get(typeId);

                String source = String.isBlank(label) ? SOURCE_UNKNOWN : label;
                if (source.trim() == SOURCE_INVITED) {
                    source = SOURCE_SALESFORCE;
                }

                cm.Lyyti_Source__c = source;
                cmToUpdate.add(cm);
            }
        }

        if (!cmToUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(cmToUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    OperationLogService.error(cmToUpdate[i].Id, 'BATCH_UpdateCampaignMemberLyytiSource', 'Failed to update Lyyti_Source__c: ' + results[i].getErrors());
                }
            }
        }

        OperationLogService.flush();
    }

    public void finish(Database.BatchableContext BC) { }

    public void execute(SchedulableContext SC) {
        Database.executeBatch(new BATCH_UpdateCampaignMemberLyytiSource(), 1);
    }
}