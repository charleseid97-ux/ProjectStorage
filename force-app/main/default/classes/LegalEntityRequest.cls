/**
 * @author  Saad LOZZI
 * @date    22/10/2021
 * @details ...
 *
 * -- History
 * -- Date        Name                       Version  Remarks
 * -- ----------- -------------------------  -------  ---------------------------------------
 * -- 22/10/2021  Saad LOZZI                  1.0      Create
 */

public class LegalEntityRequest
{
    private transient final String DEFAULT_ENTITY_TYPE = 'thirdParty';
    private transient final String DEFAULT_ENTITY_SUB_TYPE = 'legalEntity';
    private transient final String DEFAULT_ROLES = 'Distributor';

    public String salesforceId;
    public String lei;
    public String entityStatus;
    public String entityName;
    public String legalName;
    public String locationStreet1;
    public String locationCity;
    public String addressCountry;
    public String locationPostalCode;
    public String countryOfIncorporation;
    public String entityType;
    public String entitySubType;
    public String roles;

    public LegalEntityRequest()
    {
        this.initialize();
    }

    private void initialize()
    {
        this.entityType = DEFAULT_ENTITY_TYPE;
        this.entitySubType = DEFAULT_ENTITY_SUB_TYPE;
        this.roles = DEFAULT_ROLES;

    }
}