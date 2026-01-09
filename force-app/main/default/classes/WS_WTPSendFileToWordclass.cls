public with sharing class WS_WTPSendFileToWordclass {
    
    
    private static final String LOGIN_PATH = '/web/api2/v3/auth/login';
    private static final String PROJECT_PATH = '/web/api2/v2/projects/applyTemplate/';
    
    // 🔹 Config metadata (chargée une fois)
    private static final WordclassCredentials__mdt METADATA = WordclassCredentials__mdt.getInstance('Login');
    
    // Helper pour simplifier l'accès aux valeurs
    private static String baseUrl()  { return METADATA.BaseURL__c; }
    private static String username() { return METADATA.Username__c; }
    private static String password() { return METADATA.Password__c; }
    
    
    
    
    public class LoginResponseDTO {
        public String token;
        public Datetime expires;
        public Datetime lastInvalidateAllSessionsPerformed;
    }
    
    public static String login() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl() + LOGIN_PATH);
        req.setMethod('POST');
        
        // Add Headers
        req = buildHeaders(req);
        
        // Add JSON Body
        String body = buildLoginBody(username() , password());
        req.setBody(body);
        
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception e) {
            
            throw new CalloutException('Erreur d’appel HTTP : ' + e.getMessage());
        }
        
        Integer sc = res.getStatusCode();
        if (sc != 200 && sc != 201) {
            
            throw new CalloutException('Login Phrase échoué (' + sc + ') : ' + res.getBody());
        }
        
        LoginResponseDTO dto = (LoginResponseDTO) JSON.deserialize(res.getBody(), LoginResponseDTO.class);
        
        if (String.isBlank(dto.token)) {
            
            throw new CalloutException('Erreur : token non retourné par l’API Phrase.');
        }
        
        System.debug('Token Phrase obtenu : ' + dto.token);
        return dto.token;
    }
    
    // Construct Header
    private static HttpRequest buildHeaders(HttpRequest req) {
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        return req;
    }
    
    // Construct Body
    private static String buildLoginBody(String userName, String password) {
        Map<String, Object> jsonMap = new Map<String, Object>();
        jsonMap.put('userName', userName);
        jsonMap.put('password', password);
        return JSON.serialize(jsonMap);
    }
    
    // Send Request
    private static HttpResponse executeRequest(HttpRequest req) {
        Http http = new Http();
        try {
            return http.send(req);
        } catch (Exception e) {
            throw new CalloutException('Erreur d’appel HTTP : ' + e.getMessage());
        }
    }
    
    
    // Construit un nom de fichier fiable à partir d'un ContentVersion, sans doublon d'extension
    private static String buildUploadFilename(ContentVersion cv) {
        system.debug('cv.PathOnClient : ' + cv.PathOnClient);
        system.debug('cv.Title : ' + cv.Title);
        
        
        // 2) Sinon, partir du Title
        String candidate = String.isBlank(cv.Title) ? 'file' : cv.Title;
        
        // 3) Ajouter l’extension uniquement si elle n’est pas déjà présente à la fin
        if (!String.isBlank(cv.FileExtension)) {
            String lower = candidate.toLowerCase();
            String ext = cv.FileExtension.toLowerCase();
            if (!lower.endsWith('.' + ext)) {
                // si le Title a déjà une autre extension, on n'ajoute rien ; sinon on ajoute
                if (candidate.lastIndexOf('.') == -1) {
                    candidate += '.' + ext;
                }
            }
        }
        return candidate;
    }
    
    private static String toIsoUtc(Datetime dt) {
        return dt == null ? null : dt.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
    
    // Retourne le job avec le workflowLevel le plus élevé (dernière étape du workflow)
    private static Map<String,Object> pickPreferredJob(List<Object> jobsForOneLang) {
        if (jobsForOneLang == null || jobsForOneLang.isEmpty()) return null;
        
        Integer bestLevel = -1;
        Map<String,Object> bestJob = null;
        
        for (Object o : jobsForOneLang) {
            Map<String,Object> j = (Map<String,Object>) o;
            Integer level;
            
            try {
                level = (Integer) j.get('workflowLevel');
            } catch (Exception e) {
                // fallback : si pas de workflowLevel, on dérive à partir du "order" de workflowStep
                Map<String,Object> step = (Map<String,Object>) j.get('workflowStep');
                level = step != null && step.containsKey('order')
                    ? (Integer) step.get('order')
                    : 0;
            }
            
            if (level != null && level > bestLevel) {
                bestLevel = level;
                bestJob = j;
            }
        }
        
        return bestJob;
    }
    
    // Create project from template API
    private static Map<String,Object> createProjectFromTemplate(
        String token,
        String templateUid,
        String name,
        String sourceLang,
        List<String> targetLangs,
        String note,
        Datetime projectDue 
    ){
        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl() + PROJECT_PATH + EncodingUtil.urlEncode(templateUid, 'UTF-8'));
        req.setMethod('POST');
        req = buildHeaders(req);
        req.setHeader('Authorization', authHeader(token));
        
        Map<String, Object> body = new Map<String, Object>();
        body.put('name', name);
        if (!String.isBlank(sourceLang)) body.put('sourceLang', sourceLang);
        if (targetLangs != null && !targetLangs.isEmpty()) body.put('targetLangs', targetLangs);
        if (!String.isBlank(note)) body.put('note', note);
        if (projectDue != null) body.put('dateDue', toIsoUtc(projectDue));
        
        req.setBody(JSON.serialize(body));
        
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception e) {
            
            throw new CalloutException('Erreur d’appel HTTP : ' + e.getMessage());
        }
        Integer sc = res.getStatusCode();
        if (sc != 200 && sc != 201 && sc != 202) {
            
            throw new CalloutException('Create project from template failed (' + sc + ') : ' + res.getBody());
        }
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } catch (Exception e) {
            // Certaines réponses async peuvent être légères; on renvoie un map minimal
            return new Map<String, Object>{ 'raw' => res.getBody(), 'status' => sc };
                }
    }
    
    // Upload file to project API
    private static void uploadFileToProjectBinary(
        String token,
        String projectUid,
        ContentVersion cv,
        List<String> targetLangs,
        Map<String, Case> childByLang,      
        List<WorldclassJob__c> jobsToInsert          
    ) {
        if (cv == null || targetLangs == null || targetLangs.isEmpty()) return;
        
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl() + '/web/api2/v1/projects/' + EncodingUtil.urlEncode(projectUid, 'UTF-8') + '/jobs');
        req.setMethod('POST');
        req.setHeader('Authorization', authHeader(token));
        req.setHeader('Content-Type', 'application/octet-stream');
        req.setHeader('User-Agent', 'Salesforce-Carmignac/1.0');
        req.setTimeout(120000);
        
        String baseName = buildUploadFilename(cv);
        String fileNameRFC5987 = 'UTF-8\'\'' + EncodingUtil.urlEncode(baseName, 'UTF-8');
        req.setHeader('Content-Disposition', 'filename="' + baseName + '"; filename*=' + fileNameRFC5987);
        
        // Langues cibles en tableau (ex: ["en","it","de"])
        String msJson = JSON.serialize(new Map<String, Object>{ 'targetLangs' => targetLangs });
        req.setHeader('Memsource', msJson);
        
        req.setBodyAsBlob(cv.VersionData);
        
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception e) {
            
            throw new CalloutException('Erreur d’appel HTTP : ' + e.getMessage());
        }
        Integer sc = res.getStatusCode();
        
        if (sc == 200 || sc == 201) {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> allJobs = (List<Object>) payload.get('jobs');
            
            if (allJobs == null || allJobs.isEmpty()) return;
            
            // 1) regrouper par langue
            Map<String, List<Object>> jobsByLang = new Map<String, List<Object>>();
            for (Object o : allJobs) {
                Map<String, Object> j = (Map<String, Object>) o;
                String tLang = (String) j.get('targetLang');
                if (String.isBlank(tLang)) continue;
                if (!jobsByLang.containsKey(tLang)) jobsByLang.put(tLang, new List<Object>());
                jobsByLang.get(tLang).add(j);
            }
            
            for (String tLang : jobsByLang.keySet()) {
                Map<String,Object> picked = pickPreferredJob(jobsByLang.get(tLang));
                if (picked == null) continue;
                
                String uid   = (String) picked.get('uid');
                String stat  = (String) picked.get('status');
                Case child   = childByLang.get(tLang);
                
                if (child != null && !String.isBlank(uid)) {
                    jobsToInsert.add(new WorldclassJob__c(
                        WorkTogetherProcess__c = child.Id,
                        ProjectUid__c          = projectUid,
                        JobUid__c              = uid,
                        Name                   = child.Subject,
                        SourceFileName__c      = baseName,
                        Status__c              = stat
                    ));
                }
            }
        } else {
            
            System.debug('❌ Upload KO (HTTP ' + sc + '): ' + res.getBody());
            throw new CalloutException('Upload KO  : ' + res.getBody());
        }
        
    }
    
    // Get ContentVersion per Case
    private static Map<Id, List<ContentVersion>> getContentVersionsByCase(Set<Id> caseIds) {
        Map<Id, List<ContentVersion>> caseIdToVersions = new Map<Id, List<ContentVersion>>();
        if (caseIds == null || caseIds.isEmpty()) return caseIdToVersions;
        
        // ContentDocumentLinks
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :caseIds
        ];
        if (links.isEmpty()) return caseIdToVersions;
        
        // ContentVersions
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);
        
        Map<Id, List<ContentVersion>> docIdToVersions = new Map<Id, List<ContentVersion>>();
        for (ContentVersion v : [
            SELECT Id, Title, VersionData, FileExtension, ContentDocumentId,PathOnClient
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            AND Title LIKE 'Source_%'
            AND IsLatest = true
        ]) {
            if (!docIdToVersions.containsKey(v.ContentDocumentId)) {
                docIdToVersions.put(v.ContentDocumentId, new List<ContentVersion>());
            }
            docIdToVersions.get(v.ContentDocumentId).add(v);
        }
        
        // 3) group by CaseId
        for (ContentDocumentLink l : links) {
            List<ContentVersion> vs = docIdToVersions.get(l.ContentDocumentId);
            if (vs == null || vs.isEmpty()) continue;
            if (!caseIdToVersions.containsKey(l.LinkedEntityId)) {
                caseIdToVersions.put(l.LinkedEntityId, new List<ContentVersion>());
            }
            caseIdToVersions.get(l.LinkedEntityId).addAll(vs);
        }
        return caseIdToVersions;
    }
    
    // Mapping languages Salesforce / API
    private static String mapToPhraseCode(String sfLabel) {
        if (String.isBlank(sfLabel)) return null;
        String key = sfLabel.trim().toLowerCase();
        
        Map<String, String> m = new Map<String, String>{
            'dutch'      => 'nl',
                'english'    => 'en',
                'french'     => 'fr',
                'german'     => 'de',
                'italian'    => 'it',
                'portuguese' => 'pt_pt',  
                'spanish'    => 'es',
                'swedish'    => 'sv',
                'finnish'    => 'fi'
                };
                    
                    return m.containsKey(key)? m.get(key) : key;
    }
    
    @future(callout=true)
    public static void sendForCases(Set<Id> caseIds) {
        Id translationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Translation Request').getRecordTypeId();
        Id subTranslationRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Sub Translation Request').getRecordTypeId();
        
        if (caseIds == null || caseIds.isEmpty()) return;
        
        List<Case> parents = [
            SELECT Id, CaseNumber, Subject, Source_Language__c,Translation_Request_Type__c,Translation_mode__c, Translation_Due_Date__c,
            CreatedBy.Name, CreatedBy.Email, Instructions__c, 
            (SELECT Id, Subject, Sub_Target_language__c, RecordTypeId, Status
             FROM Cases WHERE RecordTypeId = :subTranslationRecordTypeId AND Status != 'Closed') 
            FROM Case
            WHERE Id IN :caseIds 
            AND (Translation_Request_Type__c = 'Translation Only' OR Translation_Request_Type__c = 'Publication and Translation')
            AND RecordTypeId = :translationRecordTypeId
        ];
        if (parents.isEmpty()) return;
        
        Set<Id> parentIds = new Set<Id>();
        for (Case p : parents) parentIds.add(p.Id);
        Map<Id, List<ContentVersion>> filesByParent = getContentVersionsByCase(parentIds);
        system.debug('filesByParent :'+filesByParent.size());
        
        // CALLOUT 1 : Authentification (token)
        String token = null;
        try {
            token = login();
        } catch (Exception e) {
            // Si le login échoue, on log et on stoppe pour éviter des 401 en boucle
            System.debug('Login Phrase échoué: ' + e.getMessage());
            WTP_NotifyBuffer.add(
                new WTP_Notify.Notice(
                    'WS_WTPSendFileToWordclass.sendForCases',
                    'Login Echoue',
                    e.getMessage()
            ));
            WTP_NotifyBuffer.flushAsync('WS_WTPSendFileToWordclass.sendForCases');
            return;
        }
        
        List<Case> parentsToUpdate  = new List<Case>();
        List<WorldclassJob__c> jobsToInsert = new List<WorldclassJob__c>();
        
        // Project Creation
        for (Case parent  : parents) {
            try {
                // a) Construct Target Langs + mapping Lang -> Child
                Set<String> langSet = new Set<String>();
                Map<String, Case> childByLang = new Map<String, Case>();
                for (Case child : parent.Cases) {
                    system.debug('child status :'+ child.Status);
                    String code = mapToPhraseCode(child.Sub_Target_language__c);
                    if (!String.isBlank(code)) {
                        langSet.add(code);
                        childByLang.put(code, child);
                    }
                }
                List<String> targetLangs = new List<String>(langSet);
                if (targetLangs.isEmpty()) {
                    System.debug('Pas de langues cibles pour parent ' + parent.Id);
                    continue;
                }
                
                String projName = 'SF-' + (String.isBlank(parent.Subject) ? '' : '' + parent.Subject);
                
                String sourceLang = mapToPhraseCode(parent.Source_Language__c);
                String note = 'Owner : ' + parent.CreatedBy.Name +
                    ' (' + parent.CreatedBy.Email + ')'+
                    '\nInstructions : ' +parent.Instructions__c;
                
                // Choix du template selon (mode, langue source FR/EN)
                String templateUid = WTP_PhraseApiUtil.getTemplateUid(parent.Translation_mode__c, parent.Source_Language__c);
                system.debug('templateUid : '+templateUid);
                // CALLOUT 2 : Project Creation
                Map<String, Object> created = createProjectFromTemplate(
                    token,
                    templateUid,
                    projName,
                    sourceLang,
                    targetLangs,
                    note,
                    parent.Translation_Due_Date__c
                );
                
                // Extract UID
                String projectUid;
                if (created.containsKey('uid')) {
                    projectUid = String.valueOf(created.get('uid'));
                } else if (created.containsKey('id')) {
                    projectUid = String.valueOf(created.get('id'));
                } else if (created.containsKey('project')) {
                    Map<String, Object> p = (Map<String, Object>)created.get('project');
                    projectUid = String.valueOf(p.get('uid'));
                }
                
                if (String.isBlank(projectUid)) {
                    System.debug('Projet non créé pour parent ' + parent.Id + ' → payload: ' + JSON.serialize(created));
                    continue;
                }
                
                System.debug('Projet Phrase créé pour Case ' + parent.CaseNumber + ' → ' + projectUid);
                
                // CALLOUT 3 : Upload Files
                List<ContentVersion> cvs = filesByParent.get(parent.Id);
                if (cvs != null && !cvs.isEmpty()) {
                    for (ContentVersion cv : cvs) {
                        // Upload files -> one job per lang (child)
                        uploadFileToProjectBinary(token, projectUid, cv, targetLangs, childByLang, jobsToInsert);
                    }
                } else {
                    System.debug('Aucun fichier à uploader pour Case ' + parent.Id);
                }
                // e) Stocker le Project UID Parent Case
                parentsToUpdate.add(new Case(Id = parent.Id, WorldclassProjectId__c = projectUid));
                
            } catch (Exception ex) {
                WTP_NotifyBuffer.add(
                    new WTP_Notify.Notice(
                        'WS_WTPSendFileToWordclass.sendForCases',
                        'Erreur Send Files',
                        ex.getMessage()
                ));
                System.debug('Erreur parent ' + parent.Id + ' : ' + ex.getMessage());
            }
        }
        
        // Update Cases
        if (!jobsToInsert.isEmpty()) {
            try {
                insert jobsToInsert;
                System.debug('📝 ' + jobsToInsert.size() + 'WorldclassJob insertion avec UID Phrase.');
            } catch (Exception e) {
                WTP_NotifyBuffer.add(
                    new WTP_Notify.Notice(
                        'WS_WTPSendFileToWordclass.sendForCases.insertJobs',
                        'Insert WorldclassJob KO',
                        e.getMessage()
                ));
                System.debug('Erreur insert WorldclassJob: ' + e.getMessage());
            }
        }
        if (!parentsToUpdate.isEmpty()) {
            try {
                update parentsToUpdate;
                System.debug('📝 ' + parentsToUpdate.size() + 'Parent Cases mises à jour avec UID Phrase.');
            } catch (Exception e) {
                WTP_NotifyBuffer.add(
                    new WTP_Notify.Notice(
                        'WS_WTPSendFileToWordclass.sendForCases.updateParents',
                        'Update Parent Cases KO',
                        e.getMessage()
                ));
                System.debug('Erreur update Parent Cases: ' + e.getMessage());
            }
        }
        
        WTP_NotifyBuffer.flushAsync('WS_WTPSendFileToWordclass.sendForCases');
        
    }
    
    
    
    public static String authHeader(String token) {
        return 'ApiToken ' + token; 
    }
    
}