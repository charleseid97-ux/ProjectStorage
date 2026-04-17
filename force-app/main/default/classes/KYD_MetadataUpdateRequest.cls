/**
 * @author  Saad LOZZI
 * @date    11/08/2021
 * @details ...
 *
 * -- History
 * -- Date        Name                       Version  Remarks
 * -- ----------- -------------------------  -------  ---------------------------------------
 * -- 11/08/2021  Saad LOZZI                  1.0      Create
 */

/**
 * DTO Object representing the Metadata Insert request.
 */
public class KYD_MetadataUpdateRequest
{
    private transient final String DEFAULT_ENTITY_TYPE = 'document';
    private transient final Integer DEFAULT_VERSION = 1;
    private transient final String DEFAULT_STATUS = 'validated';
    private transient final Datetime DEFAULT_VALIDITY_DURATION = Datetime.newInstance(3, 0, 0);
    private transient final Boolean DEFAULT_ACTIVE_STATE = true;

    public String documentId;
    public String salesforceId;
    public String entityType;
    public Integer version;
    public String status;
    public Id kydIds;
    public String originalName;
    public Datetime validityDate;
    public String path;
    public Integer size;
    public String user;
    public Boolean active;
    public String salesforceDocumentTypeId;

    public KYD_MetadataUpdateRequest()
    {
        initialize();
    }

    private void initialize()
    {
        this.entityType = DEFAULT_ENTITY_TYPE;
        this.version = DEFAULT_VERSION;
        this.status = DEFAULT_STATUS;
        this.validityDate = Datetime.now()
            .addYears(DEFAULT_VALIDITY_DURATION.year())
            .addMonths(DEFAULT_VALIDITY_DURATION.month())
            .addDays(DEFAULT_VALIDITY_DURATION.day());
        this.user = UserInfo.getUserEmail();
        this.active = DEFAULT_ACTIVE_STATE;
    }
}