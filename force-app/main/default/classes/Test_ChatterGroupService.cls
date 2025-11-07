@isTest
public class Test_ChatterGroupService {
    
    private static final Id fundCreationRtId = Schema.SObjectType.ProjectProduct__c
        .getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();    
    /*@IsTest
    static void createChatterGroup_Test() {
        ProjectProduct__c proj = PMTTestFactoryData.createProjectProductWithAllFields(fundCreationRtId);
        proj.ProjectStatus__c = 'Active';
        proj.LegalForm__c = 'FCP';
        proj.EndDate__c = Date.today().addDays(10); // to update milestone
        proj.TECH_FieldsToModify__c = 'LegalForm__c';
        
        Test.startTest();
        update proj; // before update & after update triggered
        Test.stopTest();
    }*/
    
    @testSetup
    static void setupData() {
        // Création d'utilisateurs fictifs
        List<User> testUsers = new List<User>();
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        for (Integer i = 0; i < 3; i++) {
            testUsers.add(new User(
                FirstName = 'Test',
                LastName = 'User' + i,
                Email = 'testuser' + i + '@test.com',
                Username = 'testuser' + i + '@test.com.' + System.currentTimeMillis(),
                Alias = 'test' + i,
                TimeZoneSidKey = 'Europe/Paris',
                LocaleSidKey = 'fr_FR',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'fr',
                ProfileId = p.Id
            ));
        }
        insert testUsers;
        
      
    }
    
    @isTest
    static void testCreateGroupWithMembers() {
        // Récupérer les utilisateurs actifs
        List<User> users = [SELECT Id,Username FROM User WHERE FirstName ='Test' AND IsActive = true LIMIT 2];
        system.debug(users[0].Username + ' ' + users[1].Username);
        System.assert(users.size() >= 2, 'Il faut au moins 2 utilisateurs actifs pour le test');
        
        // Préparer les données pour créer un groupe
        Map<String, List<Id>> groupMap = new Map<String, List<Id>>();
        groupMap.put('Projet Test Groupe Unitaire', new List<Id>{ users[0].Id, users[1].Id });
        
        // Appeler la méthode de service
        Test.startTest();
        List<Id> groupIds = ChatterGroupService.createGroupWithMembers(groupMap, 'Description test');
        Test.stopTest();
        
        // Assertions
        System.assertEquals(1, groupIds.size(), 'Un groupe devrait être créé');
        
        // Vérifier que les membres ont bien été ajoutés
        List<CollaborationGroupMember> members = [
            SELECT Id, MemberId, CollaborationGroupId
            FROM CollaborationGroupMember
            WHERE CollaborationGroupId IN :groupIds
        ];
        System.assertEquals(3, members.size(), 'Deux membres devraient avoir été ajoutés au groupe');
    }
    
    @isTest
    static void testUpdateGroupMemberNotifications() {
        // Préparer un groupe et des membres
        CollaborationGroup g = new CollaborationGroup(Name = 'TestNotif', CollaborationType = 'Public', Description = 'Desc');
        insert g;
        
        User u = [SELECT Id FROM User WHERE FirstName ='Test' AND IsActive = true LIMIT 1];
        CollaborationGroupMember m = new CollaborationGroupMember(
            CollaborationGroupId = g.Id,
            MemberId = u.Id,
            NotificationFrequency = 'N'
        );
        insert m;
        
        Test.startTest();
        ChatterGroupService.updateGroupMemberNotifications(new List<Id>{ g.Id }, 'P');
        Test.stopTest();
        
        // Vérifier que la notification a été mise à jour
        CollaborationGroupMember updatedMember = [
            SELECT NotificationFrequency
            FROM CollaborationGroupMember
            WHERE Id = :m.Id
        ];
        System.assertEquals('P', updatedMember.NotificationFrequency, 'La fréquence doit être mise à jour à P');
    }
}