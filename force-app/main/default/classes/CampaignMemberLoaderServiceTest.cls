@IsTest
private class CampaignMemberLoaderServiceTest
{
    @IsTest
    static void testMembersImport()
    {
        Id documentId = createDocument();

        Campaign aCampaign = new Campaign(Name = 'Campaign1');

        insert aCampaign;

        List<Contact> contacts = new List<Contact>
        {
            new Contact(FirstName = 'FirstName3', LastName = 'LastName3', Email = 'Email3@domain.com', Source__c = '-'),
            new Contact(FirstName = 'FirstName4', LastName = 'LastName4', Email = 'Email4@domain.com', Source__c = '-')
        };

        insert contacts;

        insert new List<CampaignMember>
        {
            new CampaignMember(CampaignId = aCampaign.Id, ContactId = contacts[0].Id),
            new CampaignMember(CampaignId = aCampaign.Id, ContactId = contacts[1].Id)
        };

        Test.startTest();

        CampaignMemberLoaderController.insertRecords(documentId, aCampaign.Id, ',', true);

        Test.stopTest();

        List<Lead> leads = [
            SELECT
                Id,
                FirstName,
                LastName,
                Email,
                Company,
                Status
            FROM
                Lead
        ];

        System.assertEquals(17, leads.size());
        System.assertEquals('FirstName2', leads[0].FirstName);
        System.assertEquals('LastName2', leads[0].LastName);
        System.assertEquals('email2@domain.com', leads[0].Email);
        System.assertEquals('Company2', leads[0].Company);
        System.assertEquals('Responded', leads[0].Status);

        List<CampaignMember> members = [
            SELECT
                Id,
                FirstName,
                LastName,
                Email,
                Status
            FROM
                CampaignMember
        ];

        System.assertEquals(19, members.size());
        System.assertEquals('FirstName3', members[0].FirstName);
        System.assertEquals('LastName3'.toLowerCase(), members[0].LastName.toLowerCase());
        System.assertEquals('email3@domain.com', members[0].Email);
        System.assertEquals('Responded', members[2].Status);
        System.assertEquals('FirstName2', members[2].FirstName);
        System.assertEquals('LastName2'.toLowerCase(), members[2].LastName.toLowerCase());
        System.assertEquals('email2@domain.com', members[2].Email);
        System.assertEquals('Responded', members[2].Status);
    }

    @IsTest
    static void testCSVImport()
    {
        Id documentId = createDocument();

        Campaign aCampaign = new Campaign(Name = 'Campaign1');

        insert aCampaign;

        Test.startTest();

        List<String> preview = CampaignMemberLoaderController.getPreviewRecords(documentId, aCampaign.Id, ',', true);

        Test.stopTest();

        System.assertEquals(19, preview.size());

        System.assertEquals('FirstName2,LastName2,Email2@domain.com,Company2,FR,Responded,NewLead', preview[0]);
    }

    @IsTest
    static void testLeadStatusUpdate()
    {
        Id documentId = createDocument();

        Campaign aCampaign = new Campaign(Name = 'Campaign1');

        insert aCampaign;

        Lead aLead = new Lead(
            FirstName = 'FirstName3',
            LastName = 'LastName3',
            Email = 'email3@domain.com',
            Company = 'Company3'
        );

        insert aLead;

        CampaignMember member = new CampaignMember(CampaignId = aCampaign.Id, LeadId = aLead.Id);

        insert member;

        member = [SELECT Id, Status FROM CampaignMember WHERE Id = :member.Id];

        System.assertEquals('Sent', [SELECT Id, Status FROM CampaignMember WHERE Id = :member.Id].Status);

        Test.startTest();

        CampaignMemberLoaderController.insertRecords(documentId, aCampaign.Id, ',', true);

        Test.stopTest();

        System.assertEquals('Responded', [SELECT Status FROM Lead WHERE Id = :aLead.Id].Status);
        System.assertEquals('Responded', [SELECT Status FROM CampaignMember WHERE Id = :member.Id].Status);
    }

    @IsTest
    static void testStatusUpdateWithCVent()
    {
        Id documentId = createDocument();

        Campaign aCampaign = new Campaign(Name = 'Campaign1');

        insert aCampaign;

        CventEvents__Event__c event = new CventEvents__Event__c(
            CventEvents__pkg_Category__c = 'Test Package Category',
            CventEvents__pkg_Code__c = 'Test Package Code',
            CventEvents__pkg_EventStub__c = 'Test Package Event Stub',
            CventEvents__pkg_Status__c = 'Active',
            CventEvents__pkg_Title__c = 'Test Package Title'
        );

        insert event;

        CventEvents__EventCampaignEntry__c eventEntry = new CventEvents__EventCampaignEntry__c(
            CventEvents__Campaign__c = aCampaign.Id,
            CventEvents__Event__c = event.Id
        );

        insert eventEntry;

        Lead aLead = new Lead(
            FirstName = 'FirstName3',
            LastName = 'LastName3',
            Email = 'email3@domain.com',
            Company = 'Company3'
        );

        insert aLead;

        CampaignMember member = new CampaignMember(CampaignId = aCampaign.Id, LeadId = aLead.Id);

        insert member;

        member = [SELECT Id, Status FROM CampaignMember WHERE Id = :member.Id];

        System.assertEquals('Sent', [SELECT Id, Status FROM CampaignMember WHERE Id = :member.Id].Status);

        Test.startTest();

        CampaignMemberLoaderController.insertRecords(documentId, aCampaign.Id, ',', true);

        Test.stopTest();

        System.assertEquals('Responded', [SELECT Status FROM Lead WHERE Id = :aLead.Id].Status);
        System.assertEquals('Responded', [SELECT Status FROM CampaignMember WHERE Id = :member.Id].Status);
    }

    static Id createDocument()
    {
        Account aAccount = new Account(
            Name = 'TestAccount',
            BusinessDevelopmentRegion__c = 'BP_FR',
            BillingCountryCode = 'FR'
        );

        insert aAccount;

        Blob bodyBlob=Blob.valueOf(
            String.join(
                new List<String>
                {
                    'FirstName1,LastName1,Email1@domain.com,Company1,FR,Responded',
                    'FirstName2,LastName2,Email2@domain.com,Company2,FR,Responded',
                    'FirstName3,LastName3,Email3@domain.com,Company3,FR,Responded',
                    'FirstName4,LastName4,Email4@domain.com,Company4,FR,Responded',
                    'FirstName5,LastName5,Email5@domain.com,Company5,FR,Responded',
                    'FirstName6,LastName6,Email6@domain.com,Company6,FR,Responded',
                    'FirstName7,LastName7,Email7@domain.com,Company7,FR,Responded',
                    'FirstName8,LastName8,Email8@domain.com,Company8,FR,Responded',
                    'FirstName9,LastName9,Email9@domain.com,Company9,FR,Responded',
                    'FirstName10,LastName10,Email10@domain.com,Company10,FR,Responded',
                    'FirstName11,LastName11,Email11@domain.com,Company11,FR,Responded',
                    'FirstName12,LastName12,Email12@domain.com,Company12,FR,Responded',
                    'FirstName13,LastName13,Email13@domain.com,Company13,FR,Responded',
                    'FirstName14,LastName14,Email14@domain.com,Company14,FR,Responded',
                    'FirstName15,LastName15,Email15@domain.com,Company15,FR,Responded',
                    'FirstName16,LastName16,Email16@domain.com,Company16,FR,Responded',
                    'FirstName17,LastName17,Email17@domain.com,Company17,FR,Responded',
                    'FirstName18,LastName18,Email18@domain.com,Company18,FR,Responded',
                    'FirstName19,LastName19,Email19@domain.com,Company19,FR,Responded',
                    'FirstName20,LastName20,Email20@domain.com,Company20,FR,Responded'
                },
                '\n'
            )
        );

        ContentVersion version = new ContentVersion(
            Title='SampleTitle',
            PathOnClient ='SampleTitle.csv',
            VersionData = bodyBlob,
            Origin = 'H'
        );

        insert version;

        version = [
            SELECT
                Id,
                Title,
                ContentDocumentId
            FROM
                ContentVersion
            WHERE
                Id = :version.Id LIMIT 1
        ];

        insert new ContentDocumentLink(
            LinkedEntityId = aAccount.Id,
            ContentDocumentId = version.ContentDocumentId,
            ShareType = 'V'
        );

        return version.ContentDocumentId;
    }
}