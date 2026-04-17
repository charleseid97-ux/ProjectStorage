public class CampaignMemberLoaderController
{
    public static CampaignMemberLoaderService service {
        get {
            if (m_service == null)
            {
                m_service = new CampaignMemberLoaderService();
            }
            return m_service;
        }
    }

    private static CampaignMemberLoaderService m_service;

    @AuraEnabled
    public static List<String> getPreviewRecords(
        Id documentId,
        Id recordId,
        String fieldsSeparator,
        Boolean skipFirstRow
    )
    {
        setServiceConfiguration(documentId, recordId, fieldsSeparator, skipFirstRow);
        return service.getPreviewRecords();
    }

    @AuraEnabled
    public static void insertRecords(
        Id documentId,
        Id recordId,
        String fieldsSeparator,
        Boolean skipFirstRow
    )
    {
        setServiceConfiguration(documentId, recordId, fieldsSeparator, skipFirstRow);
        service.insertRecords();
    }

    @AuraEnabled
    public static void deleteDocument(Id documentId)
    {
        service.documentId = documentId;
        service.insertRecords();
    }

    private static void setServiceConfiguration(
        Id documentId, Id recordId, String fieldsSeparator, Boolean skipFirstRow
    )
    {
        if (documentId != null) service.documentId = documentId;
        if (recordId != null) service.recordId = recordId;
        if (fieldsSeparator != null) service.fieldsSeparator = fieldsSeparator;
        if (skipFirstRow != null) service.skipFirstRow = skipFirstRow;
    }
}