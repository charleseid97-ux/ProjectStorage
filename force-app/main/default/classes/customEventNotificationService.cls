public with sharing class customEventNotificationService {

    // --------------------
    // Reused literals
    // --------------------
    private static final String TD_DEFAULT = '<td style="padding:6px 0; border-bottom:1px solid #f3f4f6;">';
    private static final String TD_ACC     = '<td style="padding:6px 0; border-bottom:1px solid #f3f4f6; color:#6b7280;">';
    private static final String DIV_CLOSE  = '</div>';

    // --------------------
    // Logging / toggles
    // --------------------
    public static Boolean notificationsDisabled = false;

    // --------------------
    // Trigger entrypoint
    // --------------------
    public static void manageNotifications(Map<Id, Event__c> newItems, Map<Id, Event__c> oldItems) {
        System.debug('ManageNotifications Started');
    }

    private static String buildSpeakersHtml(Id parentId, List<Event__c> children, Map<Id, List<SessionSpeakerProduct__c>> sessionToSpeakers) {
        List<String> parts = new List<String>();
        parts.add(buildSpeakersSection('Parent event', sessionToSpeakers.get(parentId)));

        if (children != null && !children.isEmpty()) {
            for (Event__c c : children) {
                parts.add(buildSpeakersSection('Session: ' + safe(c.title__c), sessionToSpeakers.get(c.Id)));
            }
        }
        return String.join(parts, '');
    }

    private static String buildSpeakersSection(String title, List<SessionSpeakerProduct__c> speakers) {
        List<String> parts = new List<String>();
        parts.add('<div style="margin:0 0 12px 0;">');
        parts.add('<div style="font-weight:bold; font-size:13px; margin:0 0 6px 0;">' + safe(title) + '</div>');

        if (speakers == null || speakers.isEmpty()) {
            parts.add(noSpeakersDiv());
            parts.add(DIV_CLOSE);
            return String.join(parts, '');
        }

        parts.add(tableHeader());
        for (SessionSpeakerProduct__c s : speakers) parts.add(tableRowForSpeaker(s));
        parts.add('</table>');
        parts.add(DIV_CLOSE);

        return String.join(parts, '');
    }

    private static String noSpeakersDiv() {
        return '<div style="font-size:13px; color:#6b7280;">No speakers selected.</div>';
    }

    private static String tableHeader() {
        return '<table style="width:100%; border-collapse:collapse; font-size:13px;">'
             + '<tr>'
             + '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Speaker</th>'
             + '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Account</th>'
             + '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Language</th>'
             + '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Presentation</th>'
             + '<th align="left" style="padding:6px 0; border-bottom:1px solid #e5e7eb;">Product</th>'
             + '</tr>';
    }

    private static String tableRowForSpeaker(SessionSpeakerProduct__c s) {
        String speakerName = (s.speakerContact__r != null) ? s.speakerContact__r.Name : 'Unknown';
        String accName = (s.speakerContact__r != null && s.speakerContact__r.Account != null) ? s.speakerContact__r.Account.Name : '';
        String lang = safe(s.Language__c);
        String pres = safe(s.presentationStatus__c);
        String prod = (s.strategy__c != null) ? 'Yes' : '—';

        return '<tr>'
             + TD_DEFAULT + safe(speakerName) + '</td>'
             + TD_ACC     + safe(accName) + '</td>'
             + TD_DEFAULT + safe(lang) + '</td>'
             + TD_DEFAULT + safe(pres) + '</td>'
             + TD_DEFAULT + safe(prod) + '</td>'
             + '</tr>';
    }

    /**
     * Sécurise l’injection dans HTML email (évite de casser le DOM si texte contient <, &, etc.)
     */
    private static String safe(String v) {
        if (v == null) return '';
        return v
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&#39;');
    }

}