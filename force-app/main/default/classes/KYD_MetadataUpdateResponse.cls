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
 * DTO Object representing the response of a Metadata Insert request.
 */
@SuppressWarnings('ApexUnusedDeclaration')
public class KYD_MetadataUpdateResponse {
	public Boolean active;
    public String clientId;
    public Datetime dateCreated;
    public Datetime dateModified;
    public String documentId;
    public Integer documentTypeId;
    public String entityType;
    public String kydIds;
    public String nature;
    public String originalName;
    public String path;
    public String permaLink;
    public String salesforceDocumentTypeId;
    public Id salesforceId;
    public Integer size;
    public String status;
    public String subNature;
    public String thirdpartyIds;
    public String userCreated;
    public Datetime validityDate;
    public Integer version;
}