global class ProjectProductBatch implements Database.Batchable<SObject>, Database.Stateful {
    static final Id fundShareClassModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
    static final Id fundCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
    static final Id shareclassCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('ShareclassCreation').getRecordTypeId();

    public Integer recordsProcessed = 0;
    public Integer recordsSuccess = 0;
    public Integer recordsFailed = 0;
    public List<id> insertedRecords = new List<id>();
    public List<String> errorMessages = new List<String>();
    public List<String> debugInformation = new List<String>();
    public Datetime startTime;
    public Integer[] recordsFailedWrapper = new Integer[] { 0 };
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        startTime = Datetime.now();
        return Database.getQueryLocator([
            SELECT Id, RecordTypeId, EndDate__c,
            (SELECT Id, Name, Status__c FROM Milestones__r WHERE Name = 'Launch Date' LIMIT 1),
            (SELECT Id, Status__c FROM Project_Product_Childs__r WHERE Status__c != 'Completed' AND Name != 'Design')
            FROM ProjectProduct__c 
            WHERE EndDate__c = TODAY
        ]);
    }

    global void execute(Database.BatchableContext BC, List<ProjectProduct__c> scope) {
        recordsProcessed += scope.size();
        debugInformation.add('[BATCH] Starting execution on ' + scope.size() + ' ProjectProduct__c');

        List<ProjectProduct__c> listFundCreation = new List<ProjectProduct__c>();
        List<ProjectProduct__c> listFundShareClassModification = new List<ProjectProduct__c>();
        List<ProjectProduct__c> listShareclassCreation = new List<ProjectProduct__c>();

        for (ProjectProduct__c pp : scope) {
            if (ProjectProductBatchController.canProcessProjectProduct(pp, debugInformation, errorMessages)) {
                if (pp.RecordTypeId == fundCreationRecordTypeId) {
                    listFundCreation.add(pp);
                } else if (pp.RecordTypeId == fundShareClassModificationRecordTypeId) {
                    listFundShareClassModification.add(pp);
                } else if (pp.RecordTypeId == shareclassCreationRecordTypeId) {
                    listShareclassCreation.add(pp);
                } else {
                    String msg = '[SKIP] Unsupported RecordTypeId for ProjectProduct: ' + pp.Id;
                    debugInformation.add(msg);
                    errorMessages.add(msg);
                    recordsFailedWrapper[0]++;
                }
            } else {
                recordsFailedWrapper[0]++;
            }
        }

        try {
            if (!listFundCreation.isEmpty()) {
                
                ProjectProductBatchController.createFundShareclass(listFundCreation, debugInformation, errorMessages, recordsFailedWrapper, insertedRecords);
                recordsSuccess += insertedRecords.size();
            }
        } catch (Exception e) {
            errorMessages.add('[ERROR] FundCreation: ' + e.getMessage());
            debugInformation.add(e.getStackTraceString());
        }

        try {
            if (!listFundShareClassModification.isEmpty()) {
                ProjectProductBatchController.updateFundShareclassModification(listFundShareClassModification, debugInformation, errorMessages, recordsFailedWrapper, insertedRecords);
                recordsSuccess += insertedRecords.size();
            }
        } catch (Exception e) {
            errorMessages.add('[ERROR] FundShareClassModification: ' + e.getMessage());
            debugInformation.add(e.getStackTraceString());
        }

        try {
            if (!listShareclassCreation.isEmpty()) {
                ProjectProductBatchController.createShareclasses(listShareclassCreation, debugInformation, errorMessages, recordsFailedWrapper, insertedRecords);
                recordsSuccess += insertedRecords.size();
            }
        } catch (Exception e) {
            errorMessages.add('[ERROR] ShareclassCreation: ' + e.getMessage());
            debugInformation.add(e.getStackTraceString());
        }
    }

    global void finish(Database.BatchableContext BC) {
        // Calcul du status final
        String batchStatus = recordsFailedWrapper[0] == 0 ? 'SUCCESS' : (insertedRecords.size() > 0 ? 'PARTIAL SUCCESS' : 'ERROR');
        
        // Création du log personnalisé
        PMTBatchLog__c batchLog = new PMTBatchLog__c(
            BatchJobId__c        = BC.getJobId(),
            Status__c            = batchStatus,
            ExecutionDate__c     = Datetime.now(),
            RecordsProcessed__c  = recordsProcessed,
            RecordsSuccessful__c = insertedRecords.size(),
            RecordsFailed__c     = recordsFailedWrapper[0],
            ErrorMessages__c     = String.join(errorMessages, '\n'),
            DebugInformation__c  = String.join(debugInformation, '\n'),
            DurationMs__c        = Datetime.now().getTime() - startTime.getTime()
        );
        insert batchLog;
        System.debug('batchStatus ' + batchStatus + ' recordsProcessed ' + recordsProcessed +' recordsSuccess '+ insertedRecords.size() + 'recordsFailed ' + recordsFailed  );
        try {  
            //ProjectProductBatchController.sendEmail();
            // Préparation du mail
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            // Récupération de l'environnement
            String orgName = URL.getOrgDomainUrl().getHost().split('\\.')[0];

            // Construction du sujet de l'email
            mail.setSubject('[' + orgName.toUpperCase() + '] Batch ProjectProduct : ' + batchStatus);

            // Adresse destinataire
            mail.setToAddresses(new List<String>{'salesforcesupport@carmignac.com','nicolas.sila.external@carmignac.com'});

            // Corps du mail concis et clair
            String emailBody = 'Bonjour,<br/><br/>'
                + 'Le batch <b>ProjectProductBatch</b> vient de terminer son exécution sur l\'environnement <b>' + orgName.toUpperCase() + '</b>.<br/><br/>'
                + '<u>Résumé de l\'exécution :</u><br/>'
                + '- Status : <b>' + batchStatus + '</b><br/>'
                + '- Records traités : ' + recordsProcessed + '<br/>'
                + '- Succès : ' + recordsSuccess + '<br/>'
                + '- Erreurs : ' + recordsFailedWrapper[0] + '<br/><br/>';

            System.debug('errorMessages ' + errorMessages );

            if (recordsFailedWrapper[0] > 0) {
                emailBody += '<u>Principales erreurs :</u><br/><ul>';
                for(Integer i = 0; i < Math.min(errorMessages.size(), 5); i++) {
                    emailBody += '<li>' + errorMessages[i] + '</li>';
                }
                emailBody += '</ul>';
                if (errorMessages.size() > 5) {
                    emailBody += '(Voir le log complet pour plus de détails)<br/>';
                }
            }

            emailBody += '<br/>Merci,<br/>Salesforce Automation';
            mail.setHtmlBody(emailBody);
            
            if (Test.isRunningTest()){
                System.debug('Batch ProjectProductEmail Alert Tested successfully');
            } else {
                System.debug(emailBody);
                //Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});  
                Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{mail});
                for (Messaging.SendEmailResult result : results) {
                    if (!result.isSuccess()) {
                        System.debug('Erreur envoi email : ' + result.getErrors()[0].getMessage());
                    } else {
                        System.debug('Email envoyé avec succès');
                    }
                } 
            }
        } catch (Exception ex) {
            System.debug(ex.getMessage());
        }
    }
}