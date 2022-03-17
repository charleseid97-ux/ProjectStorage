/**
 * Created by Noor on 1/29/2021.
 */

public without sharing class AgreementRelatedContact_SM01 {

    public static Map<String, String> BDRCRMEmailList;

    public static void updateContactOnAgreement(Map<Id, ConventionRelatedContact__c> agreementContacts) {

        Set<Id> agreementRebateIds = new Set<Id>();
        Set<Id> agreementReallocationIds = new Set<Id>();

        List<ConventionRelatedContact__c> rebateRelatedContacts = new List<ConventionRelatedContact__c>();
        List<ConventionRelatedContact__c> reallocationRelatedContacts = new List<ConventionRelatedContact__c>();

        for (ConventionRelatedContact__c relatedContact : agreementContacts.values()) {
            if (relatedContact.Role__c == 'Rebate/ IS Contact') {
                agreementRebateIds.add(relatedContact.Convention__c);
                rebateRelatedContacts.add(relatedContact);
            } else if (relatedContact.Role__c == 'Reallocation / IS Contact') {
                agreementReallocationIds.add(relatedContact.Convention__c);
                reallocationRelatedContacts.add(relatedContact);
            }
        }
        //Update RebateContact on agreement and all related Agreement (Parent and Children)
        if (rebateRelatedContacts.size() > 0) updateRebateISContact(rebateRelatedContacts, agreementRebateIds);
        //Update Reallocation Related Contact on the agreement if primary and Update email list
        if (reallocationRelatedContacts.size() > 0) updateReallocationContact(reallocationRelatedContacts, agreementReallocationIds);

    }


    private static Map<String, String> getBusinessRegionEmails() {

        //Map<String, String> BDREmails = new Map<String, String>();
        if (BDRCRMEmailList == null) {
            BDRCRMEmailList = new Map<String, String>();
            for (BDRCRMEmail__mdt BDRCRMEmailItem : [SELECT BusinessRegion__c,crmEmail__c FROM BDRCRMEmail__mdt]) {
                BDRCRMEmailList.put(BDRCRMEmailItem.BusinessRegion__c, BDRCRMEmailItem.crmEmail__c);
            }
        }

        return BDRCRMEmailList;

    }

    public static Map<Id, Convention__c> getAgreementWithAllRelatedContact(Set<Id> agreementIds, String roleType) {
        System.debug('//NGO getAgreementWithAllRelatedContact agreementIds : ' + agreementIds);

        Map<Id, Convention__c> updateAgreements = new Map<Id, Convention__c>([
                SELECT Id,
                        RebateContact__c,
                        Delivery_mode__c,
                        Email_Distribution_List__c,
                        Primary_Rebate_Contact__c,
                        Business_Region__c,
                        Agreement_Type__c,
                        PrimaryReallocationContact__c,
                        (SELECT Id, Contact__r.Email, Contact__r.TeamEmail__c, Primary_Rebate_Contact__c, Role__c FROM ConventionRelatedContacts__r where Role__c = :roleType),
                        (SELECT Id, Name FROM SubConventions__r)
                FROM Convention__c
                WHERE Id IN :agreementIds
        ]);

        System.debug('//NGO updateAgreements : ' + updateAgreements);

        return updateAgreements;
    }

    /**
     * @author Noor
     * @description Construct Agreement emailing list
     *
     * @param agreement
     * @param triggeredRelatedContact
     *
     * @return
     */
    public static String getEmailDistributionList(Convention__c agreement, ConventionRelatedContact__c deletedContact) {

        String emailList = '';

        for (ConventionRelatedContact__c existingRelatedContact : agreement.ConventionRelatedContacts__r) {
            if(deletedContact == null || (deletedContact != null && deletedContact.Id != existingRelatedContact.Id)){
                if (String.isNotBlank(existingRelatedContact.Contact__r.Email)) emailList += existingRelatedContact.Contact__r.Email + ';';
                if (existingRelatedContact.Primary_Rebate_Contact__c && String.isNotBlank(existingRelatedContact.Contact__r.TeamEmail__c)) emailList += existingRelatedContact.Contact__r.TeamEmail__c + ';';
            }
        }

        return emailList;
    }

    /**
     * @author Noor
     * @description Construct Agreement emailing list
     *
     * @param agreement
     * @param triggeredRelatedContact
     *
     * @return
     */
    public static String getBusinessRegionEmails(Convention__c agreement) {

        String emailList = '';

        if (getBusinessRegionEmails().containsKey(agreement.Business_Region__c)) emailList += getBusinessRegionEmails().get(agreement.Business_Region__c) + ';';

        return emailList;
    }

    /**
     * @author  Noor
     * @description Update reallocation contact and emailing list
     *
     * @param relatedContacts
     * @param agreements
     */
    public static void updateReallocationContact(List<ConventionRelatedContact__c> relatedContacts, Set<Id> agreements) {

        List<Convention__c> agreementsToUpdate = new List<Convention__c>();

        Map<Id, Convention__c> agreementsMap = getAgreementWithAllRelatedContact(agreements, 'Reallocation / IS Contact');

        for (ConventionRelatedContact__c relatedContact : relatedContacts) {

            Convention__c agreement = agreementsMap.get(relatedContact.Convention__c);
            if (relatedContact.Primary_Rebate_Contact__c) {
                //Update the Reallocation Contact on the agreement
                agreement.PrimaryReallocationContact__c = relatedContact.Contact__c;
                agreement.ReallocationDeliverymode__c = relatedContact.Delivery_mode__c;
            }
            //Recalculate and Update the Reallocation Email Distribution List
            agreement.ReallocationEmailDistributionList__c = getEmailDistributionList(agreement, null);
            //Add email business regions emails
            agreement.ReallocationEmailDistributionList__c += getBusinessRegionEmails(agreement);

            agreementsToUpdate.add(agreement);
        }

        if (agreementsToUpdate.size() > 0) update agreementsToUpdate;

    }

    public static void updateRebateISContact(List<ConventionRelatedContact__c> newAgreementContacts, Set<Id> agreementIds) {

        Map<String, String> BDREmails = getBusinessRegionEmails();

        List<ConventionRelatedContact__c> updateAgreementContacts = new List<ConventionRelatedContact__c>();

        //Updated to return the related list of sub agreements
        Map<Id, Convention__c> updateAgreements = getAgreementWithAllRelatedContact(agreementIds, 'Rebate/ IS Contact');

        //holds all rebate contacts linked to the Agreement we are adding the rebate contact to. Agreement Id is the key
        Map<Id, List<ConventionRelatedContact__c>> allAgreementContacts = new Map<Id, List<ConventionRelatedContact__c>>();
        //holds all the sub agreements linked to an agreement. Agreement Id is the key
        Map<Id, List<Convention__c>> allSubAgreements = new Map<Id, List<Convention__c>>();
        //holds all rebate contacts linked to sub agreements. Sub agreement Id is the key
        Map<Id, List<ConventionRelatedContact__c>> allSubAgreementContacts = new Map<Id, List<ConventionRelatedContact__c>>();
        //list to hold all rebate contacts to be added to sub agreements
        List<ConventionRelatedContact__c> subContactsToAdd = new List<ConventionRelatedContact__c>();
        List<ConventionRelatedContact__c> subContactsToUpadte = new List<ConventionRelatedContact__c>();

        for (Convention__c a : updateAgreements.values()) {
            allAgreementContacts.put(a.Id, a.ConventionRelatedContacts__r);
            //if the agreement is Master then add all the sub agreements to its map
            if (a.Agreement_Type__c == 'Master') {
                allSubAgreements.put(a.Id, a.SubConventions__r);
            }
        }

        SET<ID> agreementKeys = allSubAgreements.keyset();
        //query all rebate contacts for sub agreements
        Map<Id, Convention__c> subAgreementsWithContacts = new Map<Id, Convention__c>([
                SELECT Id, (
                        SELECT Delivery_mode__c,Contact__r.Email,Contact__r.TeamEmail__c, Primary_Rebate_Contact__c, Role__c
                        FROM ConventionRelatedContacts__r
                )
                FROM Convention__c
                WHERE MasterConvention__c IN :agreementKeys
        ]);

        for (Convention__c a : subAgreementsWithContacts.values()) {
            //add all sub agreement rebate contacts to map
            allSubAgreementContacts.put(a.Id, a.ConventionRelatedContacts__r);
        }

        //loop the new rebate contacts being added
        for (ConventionRelatedContact__c aC : newAgreementContacts) {
            //return the linked agreement from the map
            System.debug('AT ' + aC.Convention__c);
            Convention__c a = updateAgreements.get(aC.Convention__c);

            //if the agreement is a Master agreement
            if (a.Agreement_Type__c == 'Master') {
                //loop all of its sub agreements from the sub agreement map
                for (Convention__c sA : allSubAgreements.get(a.Id)) {
                    //boolean to track if we should add a rebate contact to the sub agreement
                    Boolean addContactToSub = true;
                    //loop all the rebate contacts for this sub agreement
                    for (ConventionRelatedContact__c sC : allSubAgreementContacts.get(sA.Id)) {
                        //if the current rebate contact contact Id is the same as the rebate contact contact Id being added
                        //then we know that the rebate contact already exists in the sub agreement
                        if (sC.Contact__c == aC.Contact__c) {
                            if (sC.Delivery_mode__c != aC.Delivery_mode__c ||
                                    sC.Primary_Rebate_Contact__c != aC.Primary_Rebate_Contact__c ||
                                    sC.Role__c != aC.Role__c) {
                                subContactsToUpadte.add(new ConventionRelatedContact__c(Id = sC.Id,
                                        Convention__c = sA.Id,
                                        Contact__c = aC.Contact__c,
                                        Primary_Rebate_Contact__c = aC.Primary_Rebate_Contact__c,
                                        Role__c = aC.Role__c));
                            }
                            //set the boolean to false so we dont try add it again
                            addContactToSub = false;
                        }
                    }
                    if (addContactToSub) {
                        //if the boolean is true then we create a new rebate contact with the same nformation but linked to the sub agreement
                        //and add it to the list to insert
                        subContactsToAdd.add(new ConventionRelatedContact__c(Convention__c = sA.Id,
                                Contact__c = aC.Contact__c,
                                Delivery_mode__c = aC.Delivery_mode__c,
                                Primary_Rebate_Contact__c = aC.Primary_Rebate_Contact__c,
                                Role__c = aC.Role__c));
                    }
                }
            }

            if (subContactsToAdd.size() > 0) {
                //insert the list of sub agreement rebatet contacts
                insert subContactsToAdd;
            }

            List<ConventionRelatedContact__c> allContacts = allAgreementContacts.get(aC.Convention__c);

            String allContactEmails = '';
            for (ConventionRelatedContact__c aAC : allContacts) {
                if (aAC.Contact__r.Email != '') {
                    allContactEmails = allContactEmails + aAC.Contact__r.Email + ';';
                }
                if (aAC.Primary_Rebate_Contact__c && aAC.Contact__r.TeamEmail__c != '' && aAC.Contact__r.TeamEmail__c != null) {
                    allContactEmails = allContactEmails + aAC.Contact__r.TeamEmail__c + ';';
                }

                if (aC.Primary_Rebate_Contact__c && aAC.Primary_Rebate_Contact__c && (aC.Contact__c != aAC.Contact__c)) {
                    aAC.Primary_Rebate_Contact__c = false;
                    updateAgreementContacts.add(aAC);
                }
            }

            allContactEmails = (allContactEmails.endsWith(';')) ? allContactEmails + BDREmails.get(a.Business_Region__c) : BDREmails.get(a.Business_Region__c);

            a.Email_Distribution_List__c = allContactEmails;

            if (aC.Primary_Rebate_Contact__c) {
                a.Primary_Rebate_Contact__c = aC.Contact__c;
                a.Delivery_mode__c = aC.Delivery_mode__c;
            }
        }
        update updateAgreements.values();
        update updateAgreementContacts;
        if (subContactsToUpadte.size() > 0) {
            //update the list of sub agreement rebatet contacts
            update subContactsToUpadte;
        }

    }

    public static void removeRelatedContactOnAgreement(Map<Id, ConventionRelatedContact__c> delAgreementContacts) {
        Set<Id> agreementIds = new Set<Id>();
        Set<Id> reallocationAgreementIds = new Set<Id>();

        List<Id> contactIds = new List<Id>();
        List<ConventionRelatedContact__c> delRelatedContactAgreement = new List<ConventionRelatedContact__c>();
        List<ConventionRelatedContact__c> reallocationRelatedContactAgreement = new List<ConventionRelatedContact__c>();

        for (ConventionRelatedContact__c relatedContactAgreement : delAgreementContacts.values()) {
            if(relatedContactAgreement.Role__c == 'Rebate/ IS Contact'){
                agreementIds.add(relatedContactAgreement.Convention__c);
                contactIds.add(relatedContactAgreement.Contact__c);
                delRelatedContactAgreement.add(relatedContactAgreement);
            }else if(relatedContactAgreement.Role__c == 'Reallocation / IS Contact'){
                reallocationAgreementIds.add(relatedContactAgreement.Convention__c);
                reallocationRelatedContactAgreement.add(relatedContactAgreement);
            }
        }

        if(delRelatedContactAgreement.size() > 0) removeRebateContact(agreementIds, contactIds, delRelatedContactAgreement);
        if(reallocationRelatedContactAgreement.size() > 0) removeReallocationContact(reallocationRelatedContactAgreement, reallocationAgreementIds);
    }

    /**
     * @author  Noor
     * @description Update reallocation contact and emailing list
     *
     * @param relatedContacts
     * @param agreements
     */
    public static void removeReallocationContact(List<ConventionRelatedContact__c> relatedContacts, Set<Id> agreements) {

        List<Convention__c> agreementsToUpdate = new List<Convention__c>();

        Map<Id, Convention__c> agreementsMap = getAgreementWithAllRelatedContact(agreements, 'Reallocation / IS Contact');

        for (ConventionRelatedContact__c relatedContact : relatedContacts) {

            Convention__c agreement = agreementsMap.get(relatedContact.Convention__c);
            if (relatedContact.Contact__c == agreement.PrimaryReallocationContact__c) {
                //Update the Reallocation Contact on the agreement
                agreement.PrimaryReallocationContact__c = null;
                agreement.ReallocationDeliverymode__c = '';
            }
            //Recalculate and Update the Reallocation Email Distribution List
            agreement.ReallocationEmailDistributionList__c = getEmailDistributionList(agreement, relatedContact);
            //Add email business regions emails
            agreement.ReallocationEmailDistributionList__c += getBusinessRegionEmails(agreement);

            agreementsToUpdate.add(agreement);
        }

        if (agreementsToUpdate.size() > 0) update agreementsToUpdate;

    }

    public static void removeRebateContact(Set<Id> agreementIds, List<Id> contactIds, List<ConventionRelatedContact__c> delRelatedContactAgreement) {

        Boolean subAgrPrimaryRebate = false;

        //Updated to return the related list of sub agreements
        Map<Id, Convention__c> updateAgreements = getAgreementWithAllRelatedContact(agreementIds, 'Rebate/ IS Contact');

        Map<Id, Contact> contactMap = new Map<Id, Contact>([SELECT Id, Email, TeamEmail__c FROM Contact WHERE Id IN:contactIds]);

        //holds all rebate contacts linked to the Agreement we are adding the rebate contact to. Agreement Id is the key
        Map<Id, List<ConventionRelatedContact__c>> allAgreementContacts = new Map<Id, List<ConventionRelatedContact__c>>();
        //holds all the sub agreements linked to an agreement. Agreement Id is the key
        Map<Id, List<Convention__c>> allSubAgreements = new Map<Id, List<Convention__c>>();
        //holds all rebate contacts linked to sub agreements. Sub agreement Id is the key
        Map<Id, List<ConventionRelatedContact__c>> allSubAgreementContacts = new Map<Id, List<ConventionRelatedContact__c>>();
        //list to hold all rebate contacts to be added to sub agreements
        List<ConventionRelatedContact__c> subContactsToDelete = new List<ConventionRelatedContact__c>();
        //list to hold all sub Agreement Name
        List<string> subAgreementName = new List<string>();

        for (Convention__c a : updateAgreements.values()) {
            allAgreementContacts.put(a.Id, a.ConventionRelatedContacts__r);
            allSubAgreements.put(a.Id, a.SubConventions__r);
        }

        SET<ID> agreementKeys = allSubAgreements.keyset();
        //query all rebate contacts for sub agreements
        Map<Id, Convention__c> subAgreementsWithContacts = new Map<Id, Convention__c>([
                SELECT Id, (SELECT Contact__r.Email, Contact__r.TeamEmail__c, Primary_Rebate_Contact__c, Role__c FROM ConventionRelatedContacts__r)
                FROM Convention__c
                WHERE MasterConvention__c IN :agreementKeys
        ]);

        for (Convention__c a : subAgreementsWithContacts.values()) {
            //add all sub agreement rebate contacts to map
            allSubAgreementContacts.put(a.Id, a.ConventionRelatedContacts__r);
        }

        for (ConventionRelatedContact__c aC : delRelatedContactAgreement) {
            //return the linked agreement from the map
            Convention__c a = updateAgreements.get(aC.Convention__c);

            //if the contact is not a Primary Rebate Contact
            if (!aC.Primary_Rebate_Contact__c) {
                //loop all of its sub agreements from the sub agreement map
                for (Convention__c sA : allSubAgreements.get(a.Id)) {
                    //loop all the rebate contacts for this sub agreement
                    for (ConventionRelatedContact__c sC : allSubAgreementContacts.get(sA.Id)) {
                        //if the current rebate contact contact Id is the same as the rebate contact contact Id being added
                        //then we know that the rebate contact already exists in the sub agreement
                        if (sC.Contact__c == aC.Contact__c) {
                            if (!sC.Primary_Rebate_Contact__c) {
                                //and add it to the list to delete
                                subContactsToDelete.add(new ConventionRelatedContact__c(Id = sC.Id));
                            } else {
                                subAgrPrimaryRebate = true;
                                subAgreementName.add(sA.Name);
                            }

                        }
                    }
                    if (subAgrPrimaryRebate)
                        aC.addError('This is a Primary Rebate Contact. Please assign a new Primary Rebate Contact for : ' + subAgreementName + ' before delete.', false);
                }
            } else {
                for (Convention__c sA : allSubAgreements.get(a.Id)) {
                    subAgreementName.add(sA.Name);
                }
                aC.addError('This is a Primary Rebate Contact. Please assign a new Primary Rebate Contact before delete.', false);
            }

            if (subContactsToDelete != null) {
                //delete the list of sub agreement rebatet contacts
                List<ConventionRelatedContact__c> ConvRelatedContDel = [select Id from ConventionRelatedContact__c where Id IN:subContactsToDelete];
                try {
                    //delete the list of sub agreement rebatet contacts
                    delete ConvRelatedContDel;
                } catch (DmlException e) {
                    system.debug('You can not delete this Related Contact !');
                }
            } else {

                String emailDL = updateAgreements.get(aC.Convention__c).Email_Distribution_List__c;
                emailDL = emailDL.replace(contactMap.get(aC.Contact__c).Email, '');
                emailDL = emailDL.replace(';;', ';');
                if (contactMap.get(aC.Contact__c).TeamEmail__c != null) {
                    emailDL = emailDL.replace(contactMap.get(aC.Contact__c).TeamEmail__c, '');
                    emailDL = emailDL.replace(';;', ';');
                }
                if (emailDL.startsWith(';')) {
                    emailDL = emailDL.substring(1, emailDL.length());
                }
                updateAgreements.get(aC.Convention__c).Email_Distribution_List__c = emailDL;
            }
        }
        update updateAgreements.values();
    }

}