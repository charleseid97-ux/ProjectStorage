/**
 * Created by Saad on 02/05/2022.
 */
public class ContentDocumentLinkTriggerHandler implements ITriggerHandler{
    
    //Allows unit tests (or other code) to disable this trigger for the transaction
    // public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {

    }

    public void BeforeDelete(Map<Id, SObject> oldItems) {
        String profileName = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;

        // Check if the profile name does not contain 'Admin'
        if (!profileName.contains('Admin') && !profileName.contains('admin')) {
            // Execute your logic for non-admin users
            System.debug('The user profile does not contain "Admin".');
        
            Map<Id, ContentDocumentLink> newContent = (Map<Id, ContentDocumentLink>) oldItems;
            for(ContentDocumentLink doc : newContent.values()) {
                if (doc.LinkedEntityId != null && doc.LinkedEntityId.getSObjectType() == KYD_Document__c.SObjectType) {
                    doc.addError('This file cannot be deleted.');
                }
            }
        }
    }
    
    public void AfterInsert(Map<Id, SObject> newItems) {
        Id translationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Translation Request').getRecordTypeId();

        Map<Id, ContentDocumentLink> newContent = (Map<Id, ContentDocumentLink>) newItems;
        Map<Id, ContentDocumentLink> newContentTranslation = new Map<Id, ContentDocumentLink>();
        Map<Id, Integer> kydDocumentToDocumentCount = new Map<Id, Integer>(); // To track new document uploads for each KYD Document
        Map<Id, KYD_Document__c> uniqueKydDocumentsToUpdate = new Map<Id, KYD_Document__c>(); // Ensures unique updates
        Set<Id> caseIds = new Set<Id>();

        // Step 1: Count the newly uploaded documents for each KYD Document
        for (ContentDocumentLink cntDocLink : newContent.values()) {
            if (cntDocLink.LinkedEntityId != null && cntDocLink.LinkedEntityId.getSObjectType() == KYD_Document__c.SObjectType) {
                Id kydDocumentId = cntDocLink.LinkedEntityId;

                // Count the number of documents related to each KYD_Document__c
                if (kydDocumentToDocumentCount.containsKey(kydDocumentId)) {
                    kydDocumentToDocumentCount.put(kydDocumentId, kydDocumentToDocumentCount.get(kydDocumentId) + 1);
                } else {
                    kydDocumentToDocumentCount.put(kydDocumentId, 1);
                }

                // Prepare to update the status of KYD_Document__c to 'Uploaded'
                if (!uniqueKydDocumentsToUpdate.containsKey(kydDocumentId)) {
                    uniqueKydDocumentsToUpdate.put(kydDocumentId, new KYD_Document__c(Id = kydDocumentId, Status__c = 'Uploaded'));
                }
            }

            // Handle Case and EmailMessage logic separately
            if (cntDocLink.LinkedEntityId != null && 
                (cntDocLink.LinkedEntityId.getSObjectType() == EmailMessage.SObjectType 
                 || 
                 cntDocLink.LinkedEntityId.getSObjectType() == Case.SObjectType)
               ) {
                newContentTranslation.put(cntDocLink.Id, cntDocLink);
            }
            // Handle Case logic for API calls
            if (cntDocLink.LinkedEntityId != null 
                && cntDocLink.LinkedEntityId.getSObjectType() == Case.SObjectType) {
                caseIds.add(cntDocLink.LinkedEntityId);
            }

        }

        // Step 2: Query the existing document count for each KYD_Document__c in this batch
        List<KYD_Document__c> kydDocumentsWithExistingCounts = [SELECT Id, Document_Count__c FROM KYD_Document__c WHERE Id IN :kydDocumentToDocumentCount.keySet()];

        // Step 3: Update the document count by adding the new counts to the existing count for each KYD Document
        for (KYD_Document__c kydDoc : kydDocumentsWithExistingCounts) {
            Integer newDocumentCount = kydDocumentToDocumentCount.get(kydDoc.Id);
            kydDoc.Document_Count__c = (kydDoc.Document_Count__c != null ? kydDoc.Document_Count__c : 0) + newDocumentCount;
            kydDoc.Status__c = 'Uploaded';

            // Add to the unique update map to ensure there are no duplicate entries
            uniqueKydDocumentsToUpdate.put(kydDoc.Id, kydDoc);
        }

        // Step 4: Update the KYD_Document__c records with new counts and status
        if (!uniqueKydDocumentsToUpdate.isEmpty()) {
            update uniqueKydDocumentsToUpdate.values();
        }
		System.debug('newContentTranslation => '+ newContentTranslation);
        // Case-related processes
        if (!newContentTranslation.isEmpty()) {
            CaseTranslationProcess.createDuplicateDocument(newContentTranslation.values());
            //CaseTranslationProcess.sendAgencyEmail(newContentTranslation.values());
            //CaseTranslationProcess.updateStatusOnAgencyEmail(newContentTranslation);
        }
        if (!caseIds.isEmpty()) {
            Map<Id, Case> parentCases  = new Map<Id, Case>([
                SELECT Id, RecordTypeId
                FROM Case
                WHERE Id IN :caseIds
                AND RecordTypeId =: translationRecordTypeId
            ]);
            // Call Wordclass API
            if (!parentCases.isEmpty()) {
                WS_WTPSendFileToWordclass.sendForCases(parentCases.keySet());
            }
        }
    }



    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
    }

    
    public void AfterDelete(Map<Id, SObject> oldItems) {

        Map<Id, ContentDocumentLink> oldContent = (Map<Id, ContentDocumentLink>) oldItems;
        Map<Id, Integer> kydDocumentToDocumentCount = new Map<Id, Integer>(); // Track the reduction in document count for each KYD Document
        List<KYD_Document__c> kydDocumentsToUpdate = new List<KYD_Document__c>();

        // Step 1: Count the deleted documents for each KYD_Document__c
        for (ContentDocumentLink cntDocLink : oldContent.values()) {
            if (cntDocLink.LinkedEntityId != null && cntDocLink.LinkedEntityId.getSObjectType() == KYD_Document__c.SObjectType) {
                Id kydDocumentId = cntDocLink.LinkedEntityId;

                // Decrease the count of documents related to each KYD_Document__c
                if (kydDocumentToDocumentCount.containsKey(kydDocumentId)) {
                    kydDocumentToDocumentCount.put(kydDocumentId, kydDocumentToDocumentCount.get(kydDocumentId) - 1);
                } else {
                    kydDocumentToDocumentCount.put(kydDocumentId, -1);
                }
            }
        }

        // Step 2: Query the existing document count for each KYD_Document__c in this batch
        List<KYD_Document__c> kydDocumentsWithExistingCounts = [SELECT Id, Document_Count__c FROM KYD_Document__c WHERE Id IN :kydDocumentToDocumentCount.keySet()];

        // Step 3: Update the document count by subtracting the deleted counts for each KYD Document
        for (KYD_Document__c kydDoc : kydDocumentsWithExistingCounts) {
            Integer decreaseCount = kydDocumentToDocumentCount.get(kydDoc.Id);
            kydDoc.Document_Count__c = Math.max((kydDoc.Document_Count__c != null ? kydDoc.Document_Count__c : 0) + decreaseCount, 0); // Ensure count doesn't go below zero
            kydDocumentsToUpdate.add(kydDoc);
        }

        // Step 4: Update the KYD_Document__c records with the new counts
        if (!kydDocumentsToUpdate.isEmpty()) {
            update kydDocumentsToUpdate;
        }
    }


    public void AfterUndelete(Map<Id, SObject> oldItems) {
    }

    public Boolean IsDisabled() {
        // if (PAD.canTrigger('NDATrigger')) {
        //     return triggerDisabled;
        // }
        // else {
            return false;
        // }
    }

}