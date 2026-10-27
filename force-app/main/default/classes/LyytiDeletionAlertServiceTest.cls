/** ──────────────────────────────────────
 * @description Test class for the Lyyti Deletion Alert, on the deployed LyytiDeletionAlert__mdt records.
 *              One test running the three entry points in turn and checking the email call each one makes:
 *                  CampaignMember deleted directly (FR), Contact merge that sends nothing, Contact deleted (FR, its member
 *                  read from the recycle bin), and Lead deleted (IT).
 * @author Charles EID
 * @covers LyytiDeletionAlertService   98%   [26-10-26]
 ────────────────────────────────────── */
@isTest
private class LyytiDeletionAlertServiceTest {

    @testSetup
    static void setup() {
        Id eventsRecordTypeId = ObjectUtil.getRecordTypeId('Campaign', 'Events');
        Campaign frCampaign = buildCampaign(eventsRecordTypeId, 'FR', '1001');
        Campaign itCampaign = buildCampaign(eventsRecordTypeId, 'IT', '1002');
        insert new List<Campaign>{ frCampaign, itCampaign };

        // "New" is not a status SM016_CampaignMemberTriggerHandler acts on, so inserting these members never attempts a Lyyti callout
        List<CampaignMemberStatus> statuses = new List<CampaignMemberStatus>();
        List<Category_Event__c> categories = new List<Category_Event__c>();
        for (Campaign camp : new List<Campaign>{ frCampaign, itCampaign }) {
            statuses.add(new CampaignMemberStatus(CampaignId = camp.Id, Label = 'New', HasResponded = false, IsDefault = true));
            categories.add(new Category_Event__c(Name = 'default', Campaign__c = camp.Id));
        }
        insert statuses;
        insert categories;

        Account acc = TestDataFactory.getAccount();
        insert acc;

        Map<String, Contact> contactsByLastName = new Map<String, Contact>();
        for (String lastName : new List<String>{ 'FrDirect', 'FrNoLyyti', 'FrCascade', 'FrMaster', 'FrMerged' }) {
            Contact con = TestDataFactory.getContact();
            con.AccountId = acc.Id;
            con.LastName = lastName;
            con.Email = lastName.toLowerCase() + '@carmignac.test.invalid';
            contactsByLastName.put(lastName, con);
        }
        insert contactsByLastName.values();
        Lead itLead = new Lead(FirstName = 'First', LastName = 'ItLead', Email = 'itlead@carmignac.test.invalid', Company = 'Lead Company');
        insert itLead;

        insert new List<CampaignMember>{
            buildMember(frCampaign.Id, contactsByLastName.get('FrDirect').Id, categories[0].Id, '1001-1'),
            buildMember(frCampaign.Id, contactsByLastName.get('FrNoLyyti').Id, categories[0].Id, null),
            buildMember(frCampaign.Id, contactsByLastName.get('FrCascade').Id, categories[0].Id, '1001-3'),
            buildMember(frCampaign.Id, contactsByLastName.get('FrMerged').Id, categories[0].Id, '1001-4'),
            buildMember(itCampaign.Id, itLead.Id, categories[1].Id, '1002-1')
        };
    }

    // ─── Tests ───────────────────────────────────────────────────────────────────
    // Limits.getEmailInvocations() is cumulative between startTest and stopTest: each delete adds 1 email call, the merge adds none
    @isTest
    static void testLyytiDeletionAlerts() {
        List<CampaignMember> membersToDelete = [SELECT Id FROM CampaignMember WHERE Contact.LastName IN ('FrDirect', 'FrNoLyyti')];
        Contact master = [SELECT Id FROM Contact WHERE LastName = 'FrMaster'];
        Contact merged = [SELECT Id FROM Contact WHERE LastName = 'FrMerged'];
        List<Contact> contactsToDelete = [SELECT Id FROM Contact WHERE LastName = 'FrCascade'];
        List<Lead> leadsToDelete = [SELECT Id FROM Lead WHERE LastName = 'ItLead'];

        Test.startTest();

        delete membersToDelete;
        Assert.areEqual(1, Limits.getEmailInvocations(), 'The FR Lyyti member deleted directly is emailed; the member without LyytiId__c adds nothing');

        merge master merged;
        Assert.areEqual(1, Limits.getEmailInvocations(), 'A merge moves the Lyyti member to the master contact: nothing to remove in Lyyti');

        delete contactsToDelete;
        Assert.areEqual(2, Limits.getEmailInvocations(), 'The FR Lyyti member deleted with its Contact is read from the recycle bin and emailed');

        delete leadsToDelete;
        Assert.areEqual(3, Limits.getEmailInvocations(), 'The IT Lyyti member deleted with its Lead is read from the recycle bin and emailed');

        Test.stopTest();
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────────
    private static Campaign buildCampaign(Id recordTypeId, String salesTeam, String lyytiId) {
        return new Campaign(RecordTypeId = recordTypeId, Status = 'Live', Name = 'Campaign ' + salesTeam, Sales_Team__c = salesTeam, Type = 'Survey', Start_Date_Time__c = Datetime.now().addDays(-5), End_Date_Time__c = Date.today().addDays(1), LyytiId__c = lyytiId);
    }

    private static CampaignMember buildMember(Id campaignId, Id linkedId, Id categoryId, String lyytiId) {
        CampaignMember cm = TestDataFactory.getCampaignMember(linkedId, campaignId);
        cm.Status = 'New';
        cm.Category_Event_lookup__c = categoryId;
        cm.LyytiId__c = lyytiId;
        return cm;
    }
}