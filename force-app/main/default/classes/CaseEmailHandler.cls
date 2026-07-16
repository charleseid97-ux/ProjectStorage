/**
* @description       : Send email when the ESG request is closed
* @author            : Mira EID
* @group             : 
* @last modified on  : 10-03-2026
* @last modified by  : Mira EID
**/
public class CaseEmailHandler {
    
    public static void sendClosedCaseEmails(List<Case> cases) {
        
        Set<Id> caseIds = new Set<Id>();
        for (Case c : cases) {
            caseIds.add(c.Id);
        }
        
        // Get Case Owners (avoid Owner.Name null issue in bulk)
        Map<Id, Case> caseMap = new Map<Id, Case>(
            [SELECT Id, CaseNumber, Requester__r.Name, Requester__r.Email, Answer__c, ESGRequestLink__c
             FROM Case
             WHERE Id IN :caseIds]
        );
        
        // Get Files linked to Cases
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :caseIds
        ];
        
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }
        
        // Get latest versions
        Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>();
        if (!docIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, Title, VersionData, ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                AND IsLatest = true
                AND Title LIKE '%Answer%'
            ]) {
                versionMap.put(cv.ContentDocumentId, cv);
            }
        }
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (Case c : caseMap.values()) {
            
            // Skip if Owner has no email
            if (c.Requester__r.Email == null) {
                continue;
            }
            
            
            // Prepare attachments for this case
            List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
            
            for (ContentDocumentLink link : links) {
                if (link.LinkedEntityId == c.Id) {
                    
                    ContentVersion cv = versionMap.get(link.ContentDocumentId);
                    if (cv != null) {
                        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                        efa.setFileName(cv.Title);
                        efa.setBody(cv.VersionData);
                        attachments.add(efa);
                    }
                }
            }
            
            // Build HTML Email Body
            String htmlBody = 'Hi ' + c.Requester__r.Name + ',<br/><br/>';
            htmlBody += 'Your ESG request has been closed.<br/><br/>';
            
            // Add answer only if filled
            if (c.Answer__c != null && c.Answer__c.trim() != '') {
                htmlBody += 'Please find below the response to your ESG request:<br/>';
                htmlBody += c.Answer__c + '<br/><br/>';
            }
            
            // Mention attachments if they exist
            if (!attachments.isEmpty()) {
                htmlBody += 'The document(s) related to this response are attached to this email.<br/><br/>';
            }
            
            htmlBody += 'You can access the case here: ';
            htmlBody += c.ESGRequestLink__c + '<br/><br/>';
            htmlBody += 'Let me know if anything further is required.<br/><br/>';
            htmlBody += 'Best regards,';
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setSubject('Response to your ESG Request ');
           // mail.setToAddresses(new List<String>{'mira.eid.external@carmignac.com','imane.kabbaj@carmignac.com' });
            mail.setToAddresses(new List<String>{c.Requester__r.Email});
            mail.setHtmlBody(htmlBody);
            
            if (!attachments.isEmpty()) {
                mail.setFileAttachments(attachments);
            }
            
            emails.add(mail);
        }
        
        if (!emails.isEmpty()) {
            if(!Test.isRunningTest()){
                Messaging.sendEmail(emails);
            }
        }
    }
}