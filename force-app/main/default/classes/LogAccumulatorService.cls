public without sharing class LogAccumulatorService {

    private static final Integer MAX_LENGTH = 129000;

    /**
     * Ajoute un log et conserve uniquement les plus récents.
     */
    public static String appendLog(
        String existingLogs,
        String operationName,
        String textLog
    ) {
        String logEntry = buildLogEntry(operationName, textLog);

        String result = String.isBlank(existingLogs)
            ? logEntry
            : existingLogs + '\n\n' + logEntry;

        // Supprime les logs les plus anciens tant que la limite est dépassée
        while (result.length() > MAX_LENGTH) {
            Integer nextEntryIndex = result.indexOf('\n\n___', 1);

            if (nextEntryIndex < 0) {
                result = result.right(Math.min(MAX_LENGTH, result.length()));
                break;
            }

            result = result.substring(nextEntryIndex + 2);
        }

        return result;
    }

    /**
     * Construit un bloc de log standardisé.
     */
    private static String buildLogEntry(
        String operationName,
        String textLog
    ) {
        String userName = UserInfo.getName();

        String timestamp = Datetime.now()
            .format('yyyy-MM-dd HH:mm:ss');

        return '___' + timestamp +
            ' | ' + userName +
            ' | ' + operationName +
            ':\n' +
            (textLog == null ? '' : textLog);
    }
}