/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 07-01-2025
 * @last modified by  : Khadija EL GDAOUNI
**/
public class CaseEmailReplyController { 
    @AuraEnabled(cacheable=true) 
    public static Case getCaseDetails(Id caseId) { 
        return [ SELECT Id, CaseNumber, ContactId, Contact.Email, Subject, Status, Priority, Sub_Target_language__c FROM Case WHERE Id = :caseId WITH SECURITY_ENFORCED ]; 
    } 

    @AuraEnabled(cacheable=true) 
    public static List<String> getEmailsList(Id caseId) { 
        Case caseRecord = [ SELECT Id, ContactId, Contact.Email, CaseNumber,Sub_Target_language__c FROM Case WHERE Id = :caseId WITH SECURITY_ENFORCED ];

        List<String> toAddresses = new List<String>();
            // get Emails
            system.debug('lang : '+caseRecord.Sub_Target_language__c);
            for (Contact agency :  [SELECT Id, Agency_Translation_language__c, Email, AccountId 
                                    FROM Contact
                                    WHERE Agency_Translation_language__c =: caseRecord.Sub_Target_language__c]){
                                        toAddresses.add(agency.Email);
                                    }
            system.debug('emails : '+toAddresses);
            return toAddresses;
    } 

    @AuraEnabled 
    public static void sendEmailReply(Id caseId,String recipientEmails, String emailBody, List<String> fileIds) { 
        try {  
            // Récupérer les détails du Case 
            Case caseRecord = [
                SELECT Id, ContactId, Contact.Email, CaseNumber, Sub_Target_language__c,
                    (SELECT Id, MessageIdentifier, ThreadIdentifier, Subject,CcAddress 
                     FROM EmailMessages 
                     WHERE Incoming = false 
                     ORDER BY CreatedDate DESC 
                     LIMIT 1)
                FROM Case 
                WHERE Id = :caseId 
                WITH SECURITY_ENFORCED
            ];

            system.debug('recipientEmails : '+recipientEmails);
            // Séparer les emails par ";" 
            List<String> recipientsList = recipientEmails.split(';'); 
            List<String> validEmails = new List<String>(); 
            for (String email : recipientsList) { 
                validEmails.add(email.trim()); 
            }
            // Préparer l'email 
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage(); 
            email.setToAddresses(validEmails); 
            //email.setToAddresses(new String[]{'khadija.el-gdaouni.external@carmignac.com'}); 
            
            // Configurer les en-têtes de réponse si un email précédent existe
            if (!caseRecord.EmailMessages.isEmpty()) {
                EmailMessage originalEmail = caseRecord.EmailMessages[0];
                email.setSubject('Re: ' + originalEmail.Subject);
                email.setInReplyTo(originalEmail.MessageIdentifier);
                email.setReferences(originalEmail.ThreadIdentifier);

                // Ajouter les destinataires en CC de l'email original
                if (String.isNotBlank(originalEmail.CcAddress)) {
                    List<String> ccAddresses = new List<String>();
                    for (String ccAdr : originalEmail.CcAddress.split(';')) { 
                        ccAddresses.add(ccAdr.trim()); 
                    }
                    email.setCcAddresses(ccAddresses);
                }

            } else {
                email.setSubject('Re: Case #' + caseRecord.CaseNumber);
            }
            
            email.setHtmlBody(emailBody);
            
            // Ajouter les pièces jointes 
            if (!fileIds.isEmpty()) { 
                List<ContentVersion> contentVersions = [ SELECT Id, Title, VersionData, FileExtension FROM ContentVersion WHERE ContentDocumentId IN :fileIds AND IsLatest = true WITH SECURITY_ENFORCED ];
                 List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>(); 
                 for (ContentVersion cv : contentVersions) { 
                    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment(); 
                    attachment.setFileName(cv.Title + '.' + cv.FileExtension); 
                    attachment.setBody(cv.VersionData); 
                    attachments.add(attachment); 
                } 
                email.setFileAttachments(attachments); 
            } 
            // Envoyer l'email 
            if(!Test.isRunningTest()){Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email}); }
            // Créer une EmailMessage pour le tracking 
            EmailMessage emailMsg = new EmailMessage(); 
            emailMsg.ParentId = caseId; 
            emailMsg.FromAddress = UserInfo.getUserEmail(); 
            emailMsg.ToAddress = String.join(email.getToAddresses(), ';');
            emailMsg.CcAddress = email.getCcAddresses() != null ? String.join(email.getCcAddresses(), ';') : null; 
            emailMsg.Subject = email.getSubject(); 
            emailMsg.HtmlBody = emailBody; 
            emailMsg.Status = '3'; 
            // Sent 
            insert emailMsg; 

            // Créer les relations pour les pièces jointes
            if (!fileIds.isEmpty()) {
                List<ContentDocumentLink> cdLinks = new List<ContentDocumentLink>();
               
                // Lier les ContentDocuments à l'EmailMessage
                for (String fileId : fileIds) {
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.LinkedEntityId = emailMsg.Id;
                    cdl.ContentDocumentId = fileId;
                    cdl.ShareType = 'V'; // Viewer
                    cdl.Visibility = 'AllUsers';
                    cdLinks.add(cdl);

                    
                }
               
                if (!cdLinks.isEmpty()) {
                    insert cdLinks;
                }
            }
        } catch (Exception e) { 
            throw new AuraHandledException('Erreur lors de l\'envoi de l\'email: ' + e.getMessage()); 
        } 
    } 
}