public class strategicNewsSendPDF {
    
@auraEnabled
    public static void emailPDF(ID strategicNewsId, List<String> userIds){
        
        PageReference pdf = Page.StrategicNewsPDF;
        // add parent id to the parameters for standardcontroller
        System.debug('BP1 ' + strategicNewsId);
        System.debug('BP2 ' + userIds);
        pdf.getParameters().put('id',strategicNewsId);
        
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
        
        StrategicNews__c sn = [SELECT id, Name, Title__c FROM StrategicNews__c WHERE id = :strategicNewsId];
        
        String Subject = 'Strategic News - ' + sn.Title__c;
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
            mail.setHtmlBody('Please find the Strategic News details attached in PDF format');
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