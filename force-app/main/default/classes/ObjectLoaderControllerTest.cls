@IsTest
private class ObjectLoaderControllerTest
{
    @IsTest
    static void testLoadsImport()
    {
        Id documentId = createDocument();

        Campaign aCampaign = new Campaign(Name = 'Campaign1');

        insert aCampaign;

        CampaignMemberLoaderService service = new CampaignMemberLoaderService(documentId, aCampaign.Id, null, null);

        Test.startTest();

        service.insertRecords();

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

        System.assertEquals(19, leads.size());
        System.assertEquals('FirstName2', leads[0].FirstName);
        System.assertEquals('LastName2', leads[0].LastName);
        System.assertEquals('email2@domain.com', leads[0].Email);
        System.assertEquals('Company2', leads[0].Company);
        System.assertEquals('Status2', leads[0].Status);
    }

    @IsTest
    static void testCSVImport()
    {
        Id documentId = createDocument();

        Campaign aCampaign = new Campaign(Name = 'Campaign1');

        insert aCampaign;

        CampaignMemberLoaderService service = new CampaignMemberLoaderService(documentId, aCampaign.Id, ',', true);

        Test.startTest();

        List<String> preview = service.getPreviewRecords();

        Test.stopTest();

        System.assertEquals(19, preview.size());

        System.assertEquals('FirstName2,LastName2,Email2@domain.com,Company2,FR,Status2,NewLead', preview[0]);

        service.deleteDocument();
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
                    'FirstName1,LastName1,Email1@domain.com,Company1,FR,Status1',
                    'FirstName2,LastName2,Email2@domain.com,Company2,FR,Status2',
                    'FirstName3,LastName3,Email3@domain.com,Company3,FR,Status3',
                    'FirstName4,LastName4,Email4@domain.com,Company4,FR,Status4',
                    'FirstName5,LastName5,Email5@domain.com,Company5,FR,Status5',
                    'FirstName6,LastName6,Email6@domain.com,Company6,FR,Status6',
                    'FirstName7,LastName7,Email7@domain.com,Company7,FR,Status7',
                    'FirstName8,LastName8,Email8@domain.com,Company8,FR,Status8',
                    'FirstName9,LastName9,Email9@domain.com,Company9,FR,Status9',
                    'FirstName10,LastName10,Email10@domain.com,Company10,FR,Status10',
                    'FirstName11,LastName11,Email11@domain.com,Company11,FR,Status11',
                    'FirstName12,LastName12,Email12@domain.com,Company12,FR,Status12',
                    'FirstName13,LastName13,Email13@domain.com,Company13,FR,Status13',
                    'FirstName14,LastName14,Email14@domain.com,Company14,FR,Status14',
                    'FirstName15,LastName15,Email15@domain.com,Company15,FR,Status15',
                    'FirstName16,LastName16,Email16@domain.com,Company16,FR,Status16',
                    'FirstName17,LastName17,Email17@domain.com,Company17,FR,Status17',
                    'FirstName18,LastName18,Email18@domain.com,Company18,FR,Status18',
                    'FirstName19,LastName19,Email19@domain.com,Company19,FR,Status19',
                    'FirstName20,LastName20,Email20@domain.com,Company20,FR,Status20'
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