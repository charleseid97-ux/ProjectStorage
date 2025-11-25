public with sharing class WTP_Notify {
    private static final String DEFAULT_EMAIL = 'salesforcesupport@carmignac.com'; // à adapter

    public class Notice {
        public String classe;
        public String summary;
        public String details;
        public Notice(String classe, String summary, String details) {
            this.classe   = classe;
            this.summary = summary;
            this.details = details;
        }
    }


// -------- EMAIL --------
    public static void alert(Notice n) {
        try {
            system.debug('email debut');
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new String[] { DEFAULT_EMAIL });
            m.setSubject('[WTP/Wordclass] ⚠️ ' + safe(n.summary));
            m.setPlainTextBody(buildPlainBody(n));
            if (!Test.isRunningTest()) {Messaging.sendEmail(new Messaging.SingleEmailMessage[] { m });}
        } catch (Exception ignore) {
             system.debug('email error '+ ignore.getMessage());
            // éviter de faire échouer la txn juste pour l’alerte
        }
    }
    
    public static void alertAsync(Notice n) {
        try {
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
                System.enqueueJob(new WTP_NotifyQueueable(n));
            } else {
                System.debug('⚠️ alertAsync: limite Queueable atteinte, on log seulement: ' + n.summary);
            }
        } catch (Exception ex) {
            System.debug('enqueue alertAsync KO: ' + ex.getMessage());
        }
    }
    
    public static Notice mergeNotices(String classe, List<Notice> notices) {
        if (notices == null || notices.isEmpty()) {
            return new Notice(classe, 'Aucune alerte', '');
        }
    
        // Résumé global (titre du mail)
        String summary = notices.size() + ' alerte(s) générée(s) pendant ' + classe;
    
        // Corps détaillé
        List<String> lines = new List<String>();
        Integer idx = 1;
        for (Notice n : notices) {
            lines.add('[' + idx + '] ' + safe(n.summary));
            if (!String.isBlank(n.details)) {
                lines.add('    ' + truncate(n.details, 2000)); // limite à 2000 caractères
            }
            idx++;
        }
    
        String details = String.join(lines, '\n');
        return new Notice(classe, summary, details);
    }


    // -------- Helpers --------
    private static String buildPlainBody(Notice n) {
        List<String> lines = new List<String>();
        lines.add('Contexte : ' + safe(n.classe));
        if (!String.isBlank(n.summary)) lines.add('Résumé    : ' + safe(n.summary));
        if (!String.isBlank(n.details)) lines.add('Détails   : ' + safe(n.details));
        lines.add('Horodatage: ' + String.valueOf(System.now()));
        return String.join(lines, '\n');
    }

    private static String safe(String s) { return s == null ? '' : s; }
    
    private static String truncate(String s, Integer maxLen) {
        if (s == null) return '';
        return (s.length() <= maxLen) ? s : (s.substring(0, maxLen) + ' … (tronc.)');
    }
}