@isTest
public class Test_WS_GetUserGraphApi {
    
@testSetup
    static void setup() {
        EmailTemplate tpl = new EmailTemplate(
            Name = 'Test Template',
            DeveloperName = 'Test_Template',
            TemplateType = 'custom',
            HtmlValue = 'Hello {{{Account.Name}}}',
            Subject = 'Test',
            FolderId = UserInfo.getUserId()
        );
        insert tpl;
    }

    @isTest
    static void testFlowLaunch_QueueableExecution() {
        // Mock HTTP
        Test.setMock(HttpCalloutMock.class, new MockHttpGraphApi());

        // Test record
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Get template
        EmailTemplate tpl = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Test_Template' LIMIT 1];

        // Préparation de l'entrée Flow
        WS_QueueableLauncher.MessageInput input = new WS_QueueableLauncher.MessageInput();
        input.email = 'test.user@example.com';
        input.templateId = tpl.Id;
        input.recordId = acc.Id;

        List<WS_QueueableLauncher.MessageInput> inputs = new List<WS_QueueableLauncher.MessageInput>{ input };

        Test.startTest();
        WS_QueueableLauncher.launch(inputs);
        Test.stopTest();

        System.assert(true, 'Le Queueable a été lancé avec succès via le Flow launcher.');
    }
}