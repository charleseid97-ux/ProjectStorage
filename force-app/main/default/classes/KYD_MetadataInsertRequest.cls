/**
 * @author  Saad LOZZI
 * @date    23/07/2021
 * @details ...
 *
 * -- History
 * -- Date        Name                       Version  Remarks
 * -- ----------- -------------------------  -------  ---------------------------------------
 * -- 23/07/2021  Saad LOZZI                  1.0      Create
 */

public class KYD_MetadataInsertRequest
{
    private transient final String DEFAULT_ENTITY_TYPE = 'document';
    private transient final Integer DEFAULT_VERSION = 1;
    private transient final String DEFAULT_STATUS = 'validated';
    private transient final Datetime VALIDITY_DURATION = Datetime.newInstance(3, 0, 0);
    private transient final Boolean DEFAULT_ACTIVE_STATE = true;

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

    public KYD_MetadataInsertRequest()
    {
        this.initialize();
    }

    private void initialize()
    {
        this.entityType = DEFAULT_ENTITY_TYPE;
        this.version = DEFAULT_VERSION;
        this.status = DEFAULT_STATUS;
        this.validityDate = Datetime.now()
            .addYears(VALIDITY_DURATION.year())
            .addMonths(VALIDITY_DURATION.month())
            .addDays(VALIDITY_DURATION.day());
        this.user = UserInfo.getUserEmail();
        this.active = DEFAULT_ACTIVE_STATE;
    }
}