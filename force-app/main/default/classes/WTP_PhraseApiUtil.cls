public with sharing class WTP_PhraseApiUtil {
    // 🔹 Config metadata (chargée une fois)
    private static final WordclassCredentials__mdt METADATA = WordclassCredentials__mdt.getInstance('Login');

    // Helper pour simplifier l'accès aux valeurs
    private static String baseUrl()  { return METADATA.BaseURL__c; }


    public class NotFoundException extends Exception {}

    // Cache mémoire
    private static Map<String,String> registry;


    // Lit le statut d’un job Phrase
    public static String getJobStatus(String token, String projectUid, String jobUid) {
        try {
            HttpRequest r = new HttpRequest();
            r.setEndpoint(baseUrl() + '/web/api2/v1/projects/' +
                          EncodingUtil.urlEncode(projectUid,'UTF-8') + '/jobs/' +
                          EncodingUtil.urlEncode(jobUid,'UTF-8'));
            r.setMethod('GET');
            r.setHeader('Authorization', WS_WTPSendFileToWordclass.authHeader(token));
            r.setHeader('Accept', 'application/json');
            r.setTimeout(120000);
            HttpResponse resp = new Http().send(r);
            if (resp.getStatusCode() != 200) return null;

            Map<String,Object> m = (Map<String,Object>) JSON.deserializeUntyped(resp.getBody());
            Object s = m.get('status');
            return (s == null) ? null : String.valueOf(s);
        } catch (Exception e) {
            System.debug('getJobStatus error: ' + e.getMessage());
            return null;
        }
    }

    // Construit le nom “Target_...” à partir du nom source
    public static String buildTargetFilename(String sourceFileName) {
        if (String.isBlank(sourceFileName)) return 'Target_file';
        String lower = sourceFileName.toLowerCase();
        if (lower.startsWith('source_')) {
            return 'Target_' + sourceFileName.substring(7);
        } else if (!lower.startsWith('target_')) {
            return 'Target_' + sourceFileName;
        }
        return sourceFileName;
    }

    // Télécharge le fichier cible et renvoie un ContentVersion prêt à insérer
    public static ContentVersion downloadTargetAsContentVersion(
        String token, String projectUid, String jobUid, Id caseId, String sourceFileName
    ) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(baseUrl() + '/web/api2/v1/projects/' +
                            EncodingUtil.urlEncode(projectUid,'UTF-8') + '/jobs/' +
                            EncodingUtil.urlEncode(jobUid,'UTF-8') + '/targetFile');
            req.setMethod('GET');
            req.setHeader('Authorization', WS_WTPSendFileToWordclass.authHeader(token));
            req.setHeader('Accept', 'application/octet-stream');
            req.setHeader('User-Agent', 'Salesforce-Carmignac/1.0');
            req.setTimeout(120000);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                System.debug('Download KO ' + res.getStatusCode() + ' : ' + res.getBody());
                return null;
            }

            String targetFilename = buildTargetFilename(sourceFileName);
            Blob body = res.getBodyAsBlob();

            ContentVersion cv = new ContentVersion();
            cv.ContentLocation = 'S';
            cv.Title = targetFilename;
            cv.PathOnClient = '/' + targetFilename;
            cv.VersionData = body;
            cv.FirstPublishLocationId = caseId;
            cv.File_translation_type__c = true;
            cv.isSource__c = false;
            return cv;

        } catch (Exception e) {
            System.debug('downloadTargetAsContentVersion error: ' + e.getMessage());
            return null;
        }
    }

    // Passe les Cases en "Proofreading" si tous leurs jobs sont COMPLETED
    public static void markTranslatedIfAllJobsCompleted(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) return;

        // A) Cases qui ont AU MOINS un job
        Set<Id> casesWithAnyJob = new Set<Id>();
        for (AggregateResult ar : [
            SELECT WorkTogetherProcess__c c
            FROM WorldclassJob__c
            WHERE WorkTogetherProcess__c IN :caseIds
            GROUP BY WorkTogetherProcess__c
        ]) {
            casesWithAnyJob.add((Id) ar.get('c'));
        }
        if (casesWithAnyJob.isEmpty()) return; // aucun job → ne rien faire

        // B) Cases qui ont ENCORE des jobs non complétés
        Set<Id> casesWithOpenJobs = new Set<Id>();
        for (AggregateResult ar : [
            SELECT WorkTogetherProcess__c c
            FROM WorldclassJob__c
            WHERE WorkTogetherProcess__c IN :casesWithAnyJob
              AND (Status__c = null OR Status__c != 'COMPLETED')
            GROUP BY WorkTogetherProcess__c
        ]) {
            casesWithOpenJobs.add((Id) ar.get('c'));
        }

        // C) Cases elegibles = (ont des jobs) - (ont des jobs non complétés)
        Set<Id> allDone = new Set<Id>(casesWithAnyJob);
        allDone.removeAll(casesWithOpenJobs);
        if (allDone.isEmpty()) return;

        // D) MAJ des Cases (évite update si déjà "Proofreading")
        List<Case> toUpdate = new List<Case>();
        for (Case c : [
            SELECT Id, Status
            FROM Case
            WHERE Id IN :allDone
              AND Status = 'Work in progress'    
        ]) {
            c.Status = 'Proofreading Validation'; 
            c.TECH_TargetReceived__c = true;
            toUpdate.add(c);
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private static void ensureLoaded() {
        if (registry != null) return;
        registry = new Map<String,String>();
        for (WordclassTemplateConfig__mdt row :
             [SELECT Mode__c, SourceLang__c, TemplateUid__c
              FROM WordclassTemplateConfig__mdt]) {
                // ex : IA|fr 1234567
            if (String.isBlank(row.Mode__c) || String.isBlank(row.SourceLang__c) || String.isBlank(row.TemplateUid__c)) continue;
            String key = row.Mode__c.trim().toUpperCase() + '|' + row.SourceLang__c.trim().toLowerCase();
            registry.put(key, row.TemplateUid__c);
        }
    }

    public static String normalizeMode(String modeRaw) {
        if (String.isBlank(modeRaw)) return null;
        String m = modeRaw.trim().toLowerCase();
        if (m == 'deeplpro' || m == 'ia only' ) return 'IA';
        if (m == 'post-editing' || m == 'translation agencies') return 'PE';
        if (m == 'full human' || m == 'full humain') return 'FH';
        return null;
    }

    public static String normalizeSourceToCode(String sourceLabel) {
        if (String.isBlank(sourceLabel)) return null;
        String s = sourceLabel.trim().toLowerCase();
        if (s.startsWith('fr') || s.contains('french'))  return 'fr';
        if (s.startsWith('en') || s.contains('english')) return 'en';
        return null;
    }

    public static String getTemplateUid(String modeRaw, String sourceLangLabel) {
        ensureLoaded();
        String mode = normalizeMode(modeRaw);
        String lang = normalizeSourceToCode(sourceLangLabel);

        if (mode == null) throw new NotFoundException('Mode non reconnu : ' + modeRaw);
        if (lang == null) throw new NotFoundException('Langue source non reconnue : ' + sourceLangLabel);

        String key = mode + '|' + lang;
        if (registry.containsKey(key)) return registry.get(key);

        throw new NotFoundException('Aucune template configurée pour ' + key);
    }

    


}