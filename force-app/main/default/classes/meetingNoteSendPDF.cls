public class meetingNoteSendPDF {
    
@auraEnabled
    public static void emailPDF(ID meetingNoteId, List<String> userIds){
        
        PageReference pdf = Page.MeetingNotePDF;
        // add parent id to the parameters for standardcontroller
        pdf.getParameters().put('id',meetingNoteId);
        
        // the contents of the attachment from the pdf
        Blob body;
        
        try {
          
          // returns the output of the page as a PDF
          if(Test.isRunningTest()) { 
              body = blob.valueOf('Unit.Test');
          } else {
              body = pdf.getContentAsPDF();
          }
          
        // need to pass unit test -- current bug  
        } catch (VisualforceException e) {
          system.debug('Visualforce error:');
          system.debug(e);
          throw new AuraHandledException('There was an error generating the PDF file');
        }
        
        Meeting_Note__c mn = [SELECT id, Name, Date__c FROM Meeting_Note__c WHERE id = :meetingNoteId];
        
        String Subject = 'Meeting Note - ' + mn.Name + ' - ' + mn.Date__c;
        String fileName = Subject + '.pdf';
        
        list<String> userEmailAddresses = getEmailsFromUserIds(userIds);
        
        for(String address : userEmailAddresses){
            Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
            attach.setContentType('application/pdf');
            attach.setFileName(fileName);
            attach.setInline(false);
            attach.Body = body;
        
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setUseSignature(false);
            mail.setToAddresses(new String[] { address });
            mail.setSubject(Subject);
            mail.setHtmlBody('Please find the details of the meeting note attached in PDF format');
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { attach }); 
            
            // Send the email
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }
    
    public static List<String> getEmailsFromUserIds(List<ID> userIds){
        List<String> emailAddresses = new List<String>();
        List<user> users = [SELECT email FROM User WHERE id IN :userIds];
        
        for(User u : users){
            emailAddresses.add(u.email);
        }
        
        return emailAddresses;
    }
}