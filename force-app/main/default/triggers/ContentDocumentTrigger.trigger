/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 11-07-2024
 * @last modified by  : SILA Nicolas
**/
trigger ContentDocumentTrigger on ContentDocument (before delete) {
    // Get all ContentDocument IDs that are about to be deleted
    String profileName = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;

        // Check if the profile name does not contain 'Admin'
    if (!profileName.contains('Admin') && !profileName.contains('admin')) {
        // Execute your logic for non-admin users
        System.debug('The user profile does not contain "Admin".');

        Set<Id> documentIds = new Set<Id>();
        for (ContentDocument doc : Trigger.old) {
            documentIds.add(doc.Id);
        }

        // Query ContentDocumentLink to check if the document is linked to a KYD_Document__c record
        List<ContentDocumentLink> linkedFiles = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE ContentDocumentId IN :documentIds 
            AND LinkedEntityId IN (SELECT Id FROM KYD_Document__c)
        ];

        // Prevent deletion if linked to KYD_Document__c
        Set<Id> protectedDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : linkedFiles) {
            protectedDocumentIds.add(link.ContentDocumentId);
        }

        for (ContentDocument doc : Trigger.old) {
            if (protectedDocumentIds.contains(doc.Id)) {
                doc.addError('This file cannot be deleted.');
            }
        }
    }
}