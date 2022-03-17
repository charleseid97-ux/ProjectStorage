/**
 * @author JL Consulting
 * @date 15/03/2021
 * @description Class used by LWC kYCume to create RelatedPartyContact and RelatedPartyContactRole
 */
public class LegalEntityAP01 {
    /**
     * @date 15/03/2021
     * @description
     * @param recordId
     * @param KYCFirstname
     * @param KYCLastname
     * @param KYCDateofbirth
     * @param KYCRole
     *
     * @return
     */
    @AuraEnabled
    public static String createRelatedPartyContactAndRole(Id recordId, string KYCFirstname, string KYCLastname, Date KYCDateofbirth, String KYCRole) {
        try{
            List<Related_Party_Contact__c> relatedPartyContacts =  getRPCByLegalEntity(KYCFirstname, KYCLastname, recordId);

            Related_Party_Contact__c relatedPartyContact;
            //Check if relatedPartyExist
            if(relatedPartyContacts.isEmpty()){
                relatedPartyContact = createRelatedContactParty(KYCFirstname, KYCLastname, KYCDateofbirth);
                createRelatedContactPartyRole(relatedPartyContact.Id, recordId, KYCRole);
            } else {
                relatedPartyContact = relatedPartyContacts[0];
                if(relatedPartyContacts[0].Related_Parties_Contact_Roles__r.size() == 0) createRelatedContactPartyRole(relatedPartyContact.Id, recordId, KYCRole);
                else return 'Related Party Contact Role already exist';
            }
        }
        catch (Exception e) {
            System.debug('Unable to create the records :' + e.getMessage() + ' ' + e.getCause());
            return e.getMessage();
        }
        return null;
    }

    /**
     * @description  Create Related Contact Party
     * @param firstName
     * @param lastName
     * @param dateOfBirth
     *
     * @return
     */
    public static Related_Party_Contact__c createRelatedContactParty(string firstName, string lastName, Date dateOfBirth){

        Related_Party_Contact__c relatedPartyContact =  new Related_Party_Contact__c(  Name = firstName + ' ' + lastName,
                First_Name__c = firstName,
                Last_Name__c = lastName,
                DateofBirth__c = dateOfBirth,
                Source__c = 'UME');

        insert relatedPartyContact;

        return relatedPartyContact;
    }

    /**
     * @description  Create Related Contact Party Role
     * @param relatedPartyContactId
     * @param legalEntityId
     * @param role
     */
    public static void createRelatedContactPartyRole(Id relatedPartyContactId, Id legalEntityId, String role){
        String mappedRole = mapRoles(role);
        insert new Related_Party_Contact_Role__c(Related_Party_Contact__c = relatedPartyContactId, Legal_Entity__c = legalEntityId, Role__c = mappedRole);
    }

    /**
     * @description map role label from UME to Legal Entity Roles
     * @param role
     *
     * @return
     */
    public static String mapRoles(String role){
        String result = '';
        Map<String, LegalEntityRoleMapping__mdt> settings = Utils.getLegalEntityRoleMapping();
        if(String.isNotBlank(role) && role.indexOf(';') > 0)
            for(String key : role.split(';')) if(settings.containsKey(key)) result += settings.get(key).result__c + ';';
        return result;
    }

    /**
     * @description Query Related Party Contact and Role by name
     * @param firstName
     * @param lastName
     * @param legalEntityId
     *
     * @return
     */
    public static List<Related_Party_Contact__c> getRPCByLegalEntity(String firstName, String lastName, Id legalEntityId){
        return [SELECT Id, (SELECT Id FROM Related_Parties_Contact_Roles__r WHERE Legal_Entity__c =: legalEntityId)
                            FROM Related_Party_Contact__c  WHERE Last_Name__c = : lastName AND First_Name__c =: firstName];
    }

    /**
     * @author Noor
     * @description Call webservice UME and GLEIF to retrieve info by LEIs
     * @param newItems
     *
     * @return
     */
    public static void callLegalEntityWebservices(List<Legal_Entity__c> newItems){

        List<String> lLEIs = new List<String>();

        for (Legal_Entity__c le : newItems) {
            //call the processRecords method and pass the values
            if (le.LEI__c != 'No LEI UME' && le.LEI__c != '')  lLEIs.add(le.LEI__c);
        }
        String leis = string.join(lLEIs,',');
        //TODO replace this callout by a queueAble
        if(String.isNotBlank(leis) && !Test.isRunningTest()) CalloutLegalEntity.processRecords(leis);

    }

}