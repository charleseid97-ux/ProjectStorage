/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 12-12-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public class CaseTranslationProcess {
    private static final Id translationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Translation Request').getRecordTypeId();
    private static final Id subTranslationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Translation Request').getRecordTypeId();
    private static final Id subPublicationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Publication Request').getRecordTypeId();
    private static final Map<String, Set<String>> languageWebsitePicklist = DependencyPicklistApex.getFieldDependencies('Case', 'Sub_Target_language__c','TargetWebsite__c');

    @AuraEnabled(cacheable=true)
    public static List<String> getTargetWebsiteOptions(List<String> target_languages) {
        List<String> websites = new List<String>();
        for (String language : target_languages) {
            websites.addAll(languageWebsitePicklist.get(language));
        }
        return websites;
    }

    @AuraEnabled(cacheable=true)
    public static List<WebsiteSubTypeAndPriority__mdt> getWebsiteSubTypeAndPriority() {    
        return WebsiteSubTypeAndPriority__mdt.getAll().values();
    }

    @AuraEnabled(cacheable=true)
    public static List<PriorityAndDueDate__mdt> getPriorityAndDueDateDelay() {    
        return PriorityAndDueDate__mdt.getAll().values();
    }

    public static void createDuplicateDocument(List<ContentDocumentLink> newLinks) {

        Set<Id> parentCaseIds = new Set<Id>();

        // Collect parent case IDs from the new content document links
        for (ContentDocumentLink link : newLinks) {

            if (link.LinkedEntityId != null && link.LinkedEntityId.getSObjectType() == Case.SObjectType) {
                parentCaseIds.add(link.LinkedEntityId);
            }
            
        }

        if (parentCaseIds.isEmpty()) {
            return;
        }

        // Query child cases without filtering by Source_Language_c and Target_Language_c
        //             AND RecordTypeId =: subTranslationRecordTypeId

        List<Case> childCases = [
            SELECT Id, ParentId, Source_Language__c, Sub_Target_language__c,Record_Type_Name__c
            FROM Case
            WHERE ParentId IN :parentCaseIds
        ];

        if (childCases.isEmpty()) {
            return;
        }

        // Filter child cases where Source_Language_c equals Target_Language_c
        List<Case> filteredChildCases = new List<Case>();
        for (Case childCase : childCases) {
            if (childCase.Source_Language__c == childCase.Sub_Target_language__c) {
                if (childCase.Record_Type_Name__c == 'Sub Translation Request') {
                    childCase.Status = 'Closed';

                }
                filteredChildCases.add(childCase);
            }
        }

        if (filteredChildCases.isEmpty()) {
            return;
        }

        // Map to store parent case IDs and their corresponding content document links
        Map<Id, List<ContentDocumentLink>> parentCaseLinksMap = new Map<Id, List<ContentDocumentLink>>();

        for (ContentDocumentLink link : newLinks) {
            if (!parentCaseLinksMap.containsKey(link.LinkedEntityId)) {
                parentCaseLinksMap.put(link.LinkedEntityId, new List<ContentDocumentLink>());
            }
            parentCaseLinksMap.get(link.LinkedEntityId).add(link);
        }

        // Collect content document IDs to query related content versions
        Set<Id> contentDocumentIds = new Set<Id>();
        for (List<ContentDocumentLink> links : parentCaseLinksMap.values()) {
            for (ContentDocumentLink link : links) {
                contentDocumentIds.add(link.ContentDocumentId);
            }
        }

        // Query all content versions related to the content document IDs
        Map<Id, ContentVersion> contentVersionMap = new Map<Id, ContentVersion>();
        for (ContentVersion content :  [SELECT ContentDocumentId, Title, PathOnClient, VersionData, File_translation_type__c
                                        FROM ContentVersion
                                        WHERE ContentDocumentId IN :contentDocumentIds]
        ) {
            contentVersionMap.put(content.ContentDocumentId,content);
        }
        List<ContentVersion> newContentVersions = new List<ContentVersion>();
        Map<String, Id> oldToNewContentDocumentMap = new Map<String, Id>();

        // Create new content versions for each document linked to the parent cases
        for (Case childCase : filteredChildCases) {
            List<ContentDocumentLink> parentLinks = parentCaseLinksMap.get(childCase.ParentId);

            if (parentLinks != null) {
                for (ContentDocumentLink parentLink : parentLinks) {
                    ContentVersion oldVersion = contentVersionMap.get(parentLink.ContentDocumentId);
                    if (oldVersion != null) {

                        ContentVersion newVersion = new ContentVersion();
                        String newTitle = oldVersion.Title.replace('Source_','');
                        newVersion.Title = 'Target_' + newTitle;
                        newVersion.PathOnClient = oldVersion.PathOnClient;
                        newVersion.File_translation_type__c = oldVersion.File_translation_type__c;
                        newVersion.VersionData = oldVersion.VersionData;
                        newVersion.TECH_PARENT_VERSION__c = parentLink.ContentDocumentId;
                        newVersion.Origin = 'H'; // Indicate that the document originated from within Salesforce

                        newContentVersions.add(newVersion);
                    }
                }
            }
        }

        if (!newContentVersions.isEmpty()) {
            insert newContentVersions;

            // Map old ContentDocumentIds to new ContentDocumentIds
            for (ContentVersion newVersion : [SELECT Id, ContentDocumentId, Title,TECH_PARENT_VERSION__c FROM ContentVersion WHERE Id IN :newContentVersions]) {
                oldToNewContentDocumentMap.put(newVersion.TECH_PARENT_VERSION__c,newVersion.ContentDocumentId);
            }

            List<ContentDocumentLink> newContentDocumentLinks = new List<ContentDocumentLink>();

            // Create new content document links for the child cases
            for (Case childCase : filteredChildCases) {
                List<ContentDocumentLink> parentLinks = parentCaseLinksMap.get(childCase.ParentId);

                if (parentLinks != null) {
                    for (ContentDocumentLink parentLink : parentLinks) {
                        Id newContentDocumentId = oldToNewContentDocumentMap.get(parentLink.ContentDocumentId);

                        if (newContentDocumentId != null) {
                            ContentDocumentLink newLink = new ContentDocumentLink();
                            newLink.ContentDocumentId = newContentDocumentId;
                            newLink.LinkedEntityId = childCase.Id;
                            newLink.ShareType = parentLink.ShareType;
                            newLink.Visibility = parentLink.Visibility;
                            newContentDocumentLinks.add(newLink);
                        }
                    }
                }
            }

            if (!newContentDocumentLinks.isEmpty()) {
                insert newContentDocumentLinks;
            }
        }
        if(!filteredChildCases.isEmpty()){
            update filteredChildCases;
        }
    }
    

    public static void switchTranslationToPublication(Map<Id,Case> newCases,Map<Id,Case> oldCases) {

        Database.DmlOptions dmlOpts = new Database.DmlOptions();
        
        dmlOpts.assignmentRuleHeader.useDefaultRule = true;
        dmlOpts.EmailHeader.triggerUserEmail = true;
        ID publicationWebHelp = [SELECT id FROM Group WHERE Type = 'Queue' and DeveloperNAME = 'Publication_Queue_WebHelp'].Id;

        for(Case wtp : newCases.values()){
            if(wtp.Status =='Closed' 
                && wtp.Status != oldCases.get(wtp.Id).Status 
                && wtp.RecordTypeId == subTranslationRecordTypeId 
                && wtp.Translation_Request_Type__c =='Publication and Translation'
            ) {
                wtp.RecordTypeId = subPublicationRecordTypeId;
                // wtp.is_translated__c = true;
                
                if(publicationWebHelp != null) {

                    wtp.OwnerId = publicationWebHelp;
                    wtp.setOptions(dmlOpts);

                }
                wtp.Status = 'Work in Progress';

                DateTime now = DateTime.now();
                system.debug('now : '+now);
                system.debug('nbr days : '+PriorityAndDueDate__mdt.getInstance(wtp.Priority).DueDate__c);
                Datetime nowPlusDays = now.addDays(Integer.valueOf(PriorityAndDueDate__mdt.getInstance(wtp.Priority).DueDate__c) );
                system.debug('now : '+nowPlusDays);
                //wtp.DueDate__c = nowPlusDays;
            }
        }

    }

    public static void createChildCases(List<Case> newCases) {

        List<Case> newChilds = new List<Case>();
        String caseStatus = 'Work in progress';
        for(Case wtp : newCases){

            if (wtp.Record_Type_Name__c == 'Translation Request' && wtp.ParentId == null) {

                Database.DmlOptions dmlOpts = new Database.DmlOptions();
                dmlOpts.assignmentRuleHeader.useDefaultRule = true;
                dmlOpts.EmailHeader.triggerUserEmail = true;
                // Set the DML options on the case
                for (String language : wtp.target_languages__c?.split(';')) {
                    
                    Case newCase = new Case(
                        Subject = wtp.Subject +' '+ language,
                        ParentId = wtp.Id,
                        Status = caseStatus,
                        Priority = wtp.Priority,
                        Origin = wtp.Origin,
                        Sub_Target_language__c = language,
                        Translation_mode__c = wtp.Translation_mode__c,
                        CampaignNewletter__c = wtp.CampaignNewletter__c,
                        DueDate__c = wtp.DueDate__c,
                        Translation_Due_Date__c = wtp.Translation_Due_Date__c,
                        Instructions__c = wtp.Instructions__c,
                        Document_type__c = wtp.Document_type__c,
                        RecordTypeId = subTranslationRecordTypeId,
                        Article_ShareClass__c = wtp.Article_ShareClass__c,
                        Article_Funds__c = wtp.Article_Funds__c,
                        Website_Type__c = wtp.Website_Type__c, 
                        Website_SubType__c = wtp.Website_SubType__c,
                        Monthly_Comment_Date__c = wtp.Monthly_Comment_Date__c,
                        Website_Publication__c = wtp.Website_Publication__c,
                        Sensitive_Content__c = wtp.Sensitive_Content__c,
                        SEO_Description__c = wtp.SEO_Description__c, 
                        SEO_Title__c  = wtp.SEO_Title__c,
                        Fund_Promotion__c = wtp.Fund_Promotion__c,
                        Final_Specific_Disclaimer__c = wtp.Final_Specific_Disclaimer__c,
                        Campaign__c = wtp.Campaign__c,
                        Translation_Request_Type__c = wtp.Translation_Request_Type__c,
                        Source_Language__c = wtp.Source_Language__c,
                        Tech_NbrSourceFiles__c = wtp.Tech_NbrSourceFiles__c
                    );

                    if(language == wtp.Source_Language__c){
                        // newCase.Status = 'Closed';
                        if(wtp.Translation_Request_Type__c  != 'Translation Only'){
                            newCase.RecordTypeId = subPublicationRecordTypeId;
                            newCase.Status = 'Work in progress';
                        }
                    }

                    if(wtp.Translation_Request_Type__c == 'Publication Only'){
                        newCase.RecordTypeId = subPublicationRecordTypeId;
                    }

                    if(wtp.Translation_Request_Type__c != 'Translation Only'){
                    
                        Set<String> authorizedLanguages = languageWebsitePicklist.get(language);
                        Set<String> myListSet = new Set<String>(wtp.TargetWebsite__c?.split(';'));
                        // Create a new set to store the intersection
                        Set<String> intersectionSet = new Set<String>();
    
                        // Iterate through the list and check if each element is in the set
                        for (String listItem : authorizedLanguages) {
                            if (myListSet.contains(listItem)) {
                                intersectionSet.add(listItem);
                            }
                        }
                        newCase.TargetWebsite__c =String.join(new List<String>(intersectionSet), ';');
                    }
                    
                    newCase.setOptions(dmlOpts);
                    newChilds.add(newCase);

                }
            }
        }
        insert newChilds;
    }

    @AuraEnabled(cacheable=true)
    public static List<Product__c> getProducts(){
        return ([select Id, Name, Product_Name__c from Product__c where  Validity__c  = true order by Product_Name__c asc]);    
    }

    @AuraEnabled(cacheable=true)
    public static List<Share_Class__c> getShareClassesByFunds(List<String> FundIds) {
        List<Share_Class__c> scList = [SELECT Id, Name, Fund__c, Fund__r.Product_Name__c,Fund__r.Name,   Validity__c, ISIN_Code__c,Country__c,Share_Class_Type__c
                                        FROM Share_Class__c
                                        WHERE Fund__c In :FundIds AND Validity__c = TRUE order by Fund__r.Product_Name__c  asc ,Name asc];

        return scList;
    }

    public static void updateStatusOnAgencyEmail(Map<Id, ContentDocumentLink> newContent) {
        List<Id> emailIds = new List<Id>();
        List<String> agencyEmails = new List<String>();
        List<Case> casesToUpdate = new List<Case>();
        Set<String> imageExtensions = new Set<String>{'jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff', 'svg'};
        
        // Get the list of agency emails
        for (Contact agency : [
                    SELECT Email
                    FROM Contact 
                    WHERE Agency_Translation_language__c != null
        ]) {
            agencyEmails.add(agency.Email);
        }
        System.debug('newContent => '+newContent);

        // Collect ContentDocument IDs from ContentDocumentLink records
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink content : newContent.values()) {
            contentDocumentIds.add(content.ContentDocumentId);
        }
        System.debug('contentDocumentIds => '+contentDocumentIds);

        // Query ContentDocuments in bulk (avoid querying in loops)
        Map<Id, ContentDocument> contentDocumentsMap = new Map<Id, ContentDocument>(
            [SELECT Id, FileExtension 
            FROM ContentDocument 
            WHERE Id IN :contentDocumentIds]
        );
                    System.debug('contentDocumentsMap => '+contentDocumentsMap);

        // Process new content links, only include non-image attachments
        for (ContentDocumentLink content : newContent.values()) { 
            ContentDocument doc = contentDocumentsMap.get(content.ContentDocumentId);
            System.debug('doc => '+doc);

            // Exclude attachments that are images based on file extension
            if (doc != null && !imageExtensions.contains(doc.FileExtension.toLowerCase())) {
                emailIds.add(content.LinkedEntityId);
            }
        }
        System.debug('emailIds => '+emailIds);
        // Fetch and update the relevant cases
        for(Case translationCase : [SELECT Id 
                                    FROM Case 
                                    WHERE Id IN (SELECT ParentId 
                                                FROM EmailMessage 
                                                WHERE Id IN :emailIds  
                                                AND Incoming = true 
                                                AND HasAttachment = true 
                                                AND fromAddress IN :agencyEmails) 
                                    AND RecordTypeId = :subTranslationRecordTypeId 
                                    AND (Translation_mode__c = 'Post-editing' OR Translation_mode__c = 'Full humain')]) {

            translationCase.Status = 'Proofreading Validation';
            translationCase.TECH_TargetReceived__c = true;
            // translationCase.DueDate__c = System.now().addHours(24);
            casesToUpdate.add(translationCase);

        }

        // Update the cases
        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }

    public static void updateStatusOnAgencyEmail3(Map<Id, ContentDocumentLink> newContent) {
        
        List<Id> emailIds = new List<Id>();
        List<String> agencyEmails = new List<String>();
        List<Case> casesToUpdate = new List<Case>();
        for (Contact agency : [
                    SELECT Email
                    FROM Contact 
                    WHERE Agency_Translation_language__c != null
        ]) {
            agencyEmails.add(agency.Email);
        }
        for(ContentDocumentLink content : newContent.values()){ 
                emailIds.add(content.LinkedEntityId);
        }


        for(Case translationCase: [SELECT Id 
                                    FROM Case 
                                    WHERE Id IN (SELECT ParentId FROM EmailMessage WHERE Id IN :emailIds  AND Incoming = true AND HasAttachment = true AND fromAddress IN :agencyEmails) 
                                    AND RecordTypeId =: subTranslationRecordTypeId 
                                    AND (Translation_mode__c = 'Post-editing' OR Translation_mode__c = 'Full humain')])
        {
            translationCase.Status = 'Proofreading Validation';
            translationCase.TECH_TargetReceived__c = true;
            
            translationCase.DueDate__c = System.now().addHours(24);
            casesToUpdate.add(translationCase);
                        
        }
        update casesToUpdate;
    
    }

    public static void sendAgencyEmail(List<ContentDocumentLink> newContent) {
            System.debug('sendAgencyEmail => '+newContent);

        List<Id> casesIds = new List<Id>();
        Map<Id, Id> parentContentMap = new Map<Id, Id>();
        List<Case> childCasesWithEmails = new List<Case>();

        for (ContentDocumentLink content : newContent) {
            casesIds.add(content.LinkedEntityId);
            parentContentMap.put(content.LinkedEntityId, content.ContentDocumentId);
        }

        EmailServicesAddress emailservice = [SELECT LocalPart, EmailDomainName  FROM EmailServicesAddress WHERE Function.FunctionName='EmailToCase' AND isActive = true LIMIT 1];
        String emailToCase = emailservice.LocalPart+'@'+emailservice.EmailDomainName;
        
        EmailTemplate template = [SELECT Id FROM EmailTemplate WHERE DeveloperName ='Agencies_Carmignac_Translation_Request' LIMIT 1];

        List<Case> casesToTreat = [
            SELECT Id, RecordTypeId, Translation_mode__c, ParentId, Sub_Target_language__c, Parent.Owner.Email
            FROM Case
            WHERE ParentId IN :casesIds
            AND RecordTypeId =: subTranslationRecordTypeId
            AND (Translation_mode__c = 'Post-editing' OR Translation_mode__c = 'Full humain')
            AND Sub_Target_language__c != 'French'
            AND Sub_Target_language__c != 'English'
        ];
            System.debug('casesToTreat => '+casesToTreat);

        if (casesToTreat.size() > 0) {
            List<ContentDocumentLink> cdls = [
                SELECT Id, ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :casesIds
            ];

            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentDocumentLink cdl : cdls) {
                contentDocumentIds.add(cdl.ContentDocumentId);
            }

            Map<Id, List<ContentVersion>> contentVersionsByDocumentId = new Map<Id, List<ContentVersion>>();
            for (ContentVersion contentVersion : [
                SELECT Id, ContentDocumentId, Title, VersionData, isLatest, FileExtension, ContentDocument.Title
                FROM ContentVersion
                WHERE ContentDocumentId IN :contentDocumentIds
                AND IsLatest = true
            ]) {
                if (!contentVersionsByDocumentId.containsKey(contentVersion.ContentDocumentId)) {
                    contentVersionsByDocumentId.put(contentVersion.ContentDocumentId, new List<ContentVersion>());
                }
                contentVersionsByDocumentId.get(contentVersion.ContentDocumentId).add(contentVersion);
            }
            System.debug('cdls => '+cdls);

            Map<Id, List<ContentVersion>> caseContentVersionMap = new Map<Id, List<ContentVersion>>();
            for (ContentDocumentLink cdl : cdls) {

                List<ContentVersion> relatedContentVersions = contentVersionsByDocumentId.get(cdl.ContentDocumentId);
                // if (relatedContentVersions != null) {
                if (relatedContentVersions != null) {

                    if (!caseContentVersionMap.containsKey(cdl.LinkedEntityId)) {

                        caseContentVersionMap.put(cdl.LinkedEntityId, new List<ContentVersion>());
                    }
                    caseContentVersionMap.get(cdl.LinkedEntityId).addAll(relatedContentVersions);
                    
                }

            }

            Map<String, List<Contact>> languageContactMap = new Map<String, List<Contact>>();
    
            for (Contact agency : [
                SELECT Id, Agency_Translation_language__c, Email,AccountId
                FROM Contact
                WHERE Agency_Translation_language__c != null
            ]) {
                List<String> translationLanguages = agency.Agency_Translation_language__c.split(';');
                for (String lang : translationLanguages) {
                    if (languageContactMap.containsKey(lang)) {
                        languageContactMap.get(lang).add(agency);
                    } else {
                        languageContactMap.put(lang, new List<Contact>{ agency });
                    }
                }
            }

            // Collect and prepare emails
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            for (Case child : casesToTreat) {
                List<ContentVersion> relatedContentVersions = caseContentVersionMap.get(child.ParentId);

                if (relatedContentVersions?.size()>0) {
                    List<String> toAddresses = new List<String>();
                    for (Contact con : languageContactMap.get(child.Sub_Target_language__c)) {
                        toAddresses.add(con.Email);
                    }

                    System.debug('languageContactMap => '+languageContactMap);

                    if (toAddresses.size() > 0) {
                        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                        mail.setTemplateId(template.Id); // dynamic to dooooo
                        mail.setWhatId(child.Id);
                        mail.setReplyTo(child.Parent.Owner.Email);
                        mail.setToAddresses(toAddresses);
                        mail.setTargetObjectId(languageContactMap.get(child.Sub_Target_language__c)[0].Id);
                        childCasesWithEmails.add(new Case(Id=child.Id,AccountId = languageContactMap.get(child.Sub_Target_language__c)[0].AccountId ));
                        mail.setSenderDisplayName('Carmignac Translation Request');
                        mail.setCcAddresses(new List<String>{
                            emailToCase
                        });
    
                        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
                        for (ContentVersion contentVersion : relatedContentVersions) {

                            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                            attachment.setBody(contentVersion.VersionData);
                            attachment.setFileName(contentVersion.ContentDocument.Title);

                            attachments.add(attachment);
                        }

                        mail.setFileAttachments(attachments);
                        emails.add(mail);

                    }
                }
            }
            
            System.debug('emails => '+emails);
            if (!emails.isEmpty()) {
                if(!Test.isRunningTest()){Messaging.sendEmail(emails);}
                update childCasesWithEmails;
            }
        }
    }

}