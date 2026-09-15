public without sharing class EventApprovalController {

    public String recordId { get; set; }
    public String openRecordId { get; private set; } // Record réellement ouvert par le bouton
    public String actionParam { get; set; }
    public String stateId { get; set; }
    public String workItemId { get; set; }
    public String processInstanceId { get; set; }
    public String resultMessage { get; set; }
    public String errorMessage { get; set; }
    public Boolean isSuccess { get; set; }

    // Commentaire saisi pour le rejet
    public String rejectComment { get; set; }

    // Permet d'afficher le formulaire de rejet
    public Boolean showRejectForm { get; set; }

    // Initialise les paramètres reçus depuis le lien email.
    public EventApprovalController() {
        recordId = ApexPages.currentPage().getParameters().get('eid');
        actionParam = ApexPages.currentPage().getParameters().get('action');
        stateId = ApexPages.currentPage().getParameters().get('stateId');
        openRecordId = recordId; // Par défaut, on ouvre le record cible
        isSuccess = false;
        showRejectForm = false;
        rejectComment = '';
    }

    /**
     * Méthode appelée à l'ouverture de la page.
     * - approve => traite immédiatement
     * - reject  => affiche le champ commentaire
     */
    public PageReference initPage() {

        if (String.isBlank(recordId)) {
            resultMessage = 'Error';
            errorMessage = 'Missing eid parameter.';
            return null;
        }

        resolveOpenRecordId();

        if (!validateApprovalState()) {
            return null;
        }

        if (actionParam != null && actionParam.toLowerCase() == 'reject') {
            showRejectForm = true;
            return null;
        }

        return processApproval();
    }

    /**
     * Exécute l'approbation ou le rejet.
     * Pour Reject, le commentaire est obligatoire.
     */
    public PageReference processApproval() {

        if (String.isBlank(recordId)) {
            resultMessage = 'Error';
            errorMessage = 'Missing eid parameter.';
            return null;
        }

        try {
            resolveOpenRecordId();

            if (!validateApprovalState()) {
                return null;
            }

            if (actionParam != null && actionParam.toLowerCase() == 'reject' && String.isBlank(rejectComment)) {
                resultMessage = 'Error';
                errorMessage = 'Rejection comment is required.';
                showRejectForm = true;
                return null;
            }

            // Find related ProcessInstanceWorkitem
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id, ProcessInstanceId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :recordId
                LIMIT 1
            ];

            if (workItems.isEmpty()) {
                resultMessage = 'Error';
                errorMessage = 'No ProcessInstanceWorkitem found.';
                showRejectForm = false;
                return null;
            }

            ProcessInstanceWorkitem wi = workItems[0];
            workItemId = wi.Id;
            processInstanceId = wi.ProcessInstanceId;

            // Prepare approval request
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(wi.Id);

            if (actionParam != null && actionParam.toLowerCase() == 'approve') {
                req.setAction('Approve');
                req.setComments('Processed via Visualforce custom approval page.');
            } else if (actionParam != null && actionParam.toLowerCase() == 'reject') {
                req.setAction('Reject');
                req.setComments(rejectComment);
            } else {
                resultMessage = 'Error';
                errorMessage = 'Invalid action parameter. Use approve or reject.';
                return null;
            }

            Approval.ProcessResult result = Approval.process(req);

            showRejectForm = false;

            if (result.isSuccess()) {
                resultMessage = 'Success';
                isSuccess = true;
            } else {
                resultMessage = 'Error';
                errorMessage = joinApprovalErrors(result.getErrors());
            }

        } catch (Exception e) {
            resultMessage = 'Error';
            errorMessage = e.getMessage();
            showRejectForm = false;
        }

        return null;
    }

    /**
     * Si le record est un EventSpeakerApprovals__c,
     * le bouton "Open record" ouvre l'Event lié.
     */
    private void resolveOpenRecordId() {
        try {
            Id rid = (Id)recordId;
            if (rid.getSObjectType() == EventSpeakerApprovals__c.SObjectType) {
                EventSpeakerApprovals__c esa = [
                    SELECT Event__c
                    FROM EventSpeakerApprovals__c
                    WHERE Id = :rid
                    LIMIT 1
                ];
                if (esa.Event__c != null) {
                    openRecordId = (String)esa.Event__c;
                }
            }
        } catch (Exception ignoreException) {
            // recordId non castable en Id ou objet non accessible :
            // on garde openRecordId = recordId
        }
    }

    // Bloque les liens d'approbation obsolètes après modification de la demande.
    private Boolean validateApprovalState() {
        BooklyModificationsManagement.ApprovalStateValidationResult validation =
            BooklyModificationsManagement.validateApprovalState(recordId, stateId);

        if (validation == null || validation.isValid == true) {
            return true;
        }

        // Le formulaire de rejet ne doit pas rester accessible si le lien est obsolète.
        resultMessage = 'Request updated';
        errorMessage = validation.message;
        showRejectForm = false;
        isSuccess = false;
        return false;
    }

    // Convertit les erreurs Approval.ProcessResult en texte lisible.
    private static String joinApprovalErrors(Database.Error[] errors) {
        if (errors == null || errors.isEmpty()) {
            return '';
        }

        List<String> messages = new List<String>();
        for (Database.Error error : errors) {
            messages.add(String.valueOf(error.getStatusCode()) + ': ' + error.getMessage());
        }

        return String.join(messages, ', ');
    }
}