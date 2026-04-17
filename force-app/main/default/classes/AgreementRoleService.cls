/**
 * Created by noorgoolamnabee on 17/12/2021.
 */

public with sharing class AgreementRoleService {


    public static void checkUniqueness(List<Agreement_Role__c> agreementRoles) {

        Set<Id> agreementIds = new Set<Id>();
        Set<String> keySet = new Set<String>();

        for(Agreement_Role__c roles : agreementRoles) agreementIds.add(roles.Agreement__c);

        for(Agreement_Role__c role : [SELECT Id, Agreement__c,Legal_Entity__c,Role__c FROM Agreement_Role__c WHERE Agreement__c in : agreementIds ])
            keySet.add(getKey(role));

        for(Agreement_Role__c role : agreementRoles)
            if(keySet.contains(getKey(role)))
                role.addError(Label.VR01_AGREEMENT_ROLE_UNIQUENESS);

    }

    private static String getKey(Agreement_Role__c role){
        //return (role.Agreement__c+'_'+role.Legal_Entity__c+'_'+role.Role__c);
        return (role.Agreement__c+'_'+role.Legal_Entity__c);
    }
}