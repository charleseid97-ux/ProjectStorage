public abstract class ObjectLoaderService
{
    public class ImportException extends Exception {}

    protected final Integer IMPORT_PREVIEW_SIZE = 50;
    protected final Integer MAX_PROCESSING_RECORDS = 1000;
    protected final String DEFAULT_FIELDS_SEPARATOR = ',';
    protected final Boolean DEFAULT_SKIP_FIRST_ROW = true;
    private final String ERROR_EMAIL_SUBJECT = 'Campaign Members Import Error';

    public Id documentId { get; set; }
    public Id recordId { get; set; }
    public String fieldsSeparator { get; set; }
    public Boolean skipFirstRow { get; set; }

    public ObjectLoaderService()
    {
        if (fieldsSeparator == null)
        {
            fieldsSeparator = DEFAULT_FIELDS_SEPARATOR;
        }
        if (skipFirstRow == null)
        {
            skipFirstRow = DEFAULT_SKIP_FIRST_ROW;
        }
    }

    public ObjectLoaderService(Id documentId, Id recordId, String fieldsSeparator, Boolean skipFirstRow)
    {
        if (fieldsSeparator == null)
        {
            fieldsSeparator = DEFAULT_FIELDS_SEPARATOR;
        }
        if (skipFirstRow == null)
        {
            skipFirstRow = DEFAULT_SKIP_FIRST_ROW;
        }
        this.documentId = documentId;
        this.recordId = recordId;
        this.fieldsSeparator = fieldsSeparator;
        this.skipFirstRow = skipFirstRow;
    }

    public virtual List<String> getPreviewRecords()
    {
        StringSplitIterator iterator = new StringSplitIterator(getFileContent());

        if (skipFirstRow && iterator.hasNext()) iterator.next();

        return iterator.next(IMPORT_PREVIEW_SIZE);
    }

    public abstract void insertRecords();

    protected String getFileContent()
    {
        ImportException ex = new ImportException('A CSV document is required for importing objects.');

        if (documentId == null) throw ex;

        ContentVersion[] versions = [
            SELECT
                Id,
                VersionData
            FROM
                ContentVersion
            WHERE
                ContentDocumentId = :documentId
        ];

        if (versions.size() == 0) throw ex;

        return versions[0].VersionData.toString().replaceAll('\\r', '');
    }

    @TestVisible
    protected void deleteDocument()
    {
        delete [SELECT Id FROM ContentDocument WHERE Id = :documentId];
    }

    protected void sendErrorEmail(String errorMessage, String addressTo)
    {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String> { addressTo });
        mail.setSubject(ERROR_EMAIL_SUBJECT);
        mail.setPlainTextBody(errorMessage);
        if(!Test.isRunningTest()) Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });   
    }
}