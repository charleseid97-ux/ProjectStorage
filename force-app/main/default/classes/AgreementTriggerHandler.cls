/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 11-07-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
public class AgreementTriggerHandler implements  ITriggerHandler {
    //Allows unit tests (or other code) to disable this trigger for the transaction
    public static Boolean triggerDisabled = false;

    public void BeforeInsert(List<SObject> newItems) {
        //TODO  breakdown method by functionality
        if (PAD.canTrigger('AgreementBeforeInsert')) {
            SM034_AgreementService.handleBeforeInsert((List<Convention__c>) newItems);
        }
        if (PAD.canTrigger('attachedKYD_DD')) {
            SM034_AgreementService.attachedKYD_DD((List<Convention__c>)newItems);
        }
    }

    public void BeforeUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {
        //TODO  breakdown method by functionality
        if (PAD.canTrigger('AgreementBeforeUpdate')) {
            SM034_AgreementService.handleBeforeUpdate((List<Convention__c>) newItems.values(),(Map<Id, Convention__c>) oldItems);
        }

        //Validation for approval process
        if (PAD.canTrigger('validateAgreementWhenApproved')) {
            SM034_AgreementService.validateAgreementWhenApproved((Map<Id, Convention__c>) newItems,(Map<Id, Convention__c>) oldItems);
        }

    }

    public void BeforeDelete(Map<Id, SObject> oldItems) { }

    public void AfterInsert(Map<Id, SObject> newItems) {
        SM034_AgreementService.handleRollupCalculate((Map<Id, Convention__c>) newItems, null);

        if (PAD.canTrigger('AgreementAfterInsert')) {
            SM034_AgreementService.createDefaultRebateContact((List<Convention__c>) newItems.values());
        }

        //Noor create Default LegalEntity Agreement Role for Carmignac Gestion or Carmignac Gestion Luxembourd
        if (PAD.canTrigger('AgreementAfterInsert')) {
            SM034_AgreementService.createDefaultCarmignacAgreementRole((List<Convention__c>) newItems.values());
        }

        //Noor create Default LegalEntity Agreement Role for legal entity that match agreement based on the company Id
        if (PAD.canTrigger('AgreementAfterInsert')) {
            SM034_AgreementService.createDefaultLegalEntityAgreementRole((List<Convention__c>) newItems.values());
        }

    }

    public void AfterUpdate(Map<Id, SObject> newItems, Map<Id, SObject> oldItems) {

        SM034_AgreementService.updateChildAgreementWhenTerminated((Map<Id, Convention__c>) newItems, (Map<Id, Convention__c>) oldItems);
		SM034_AgreementService.handleRollupCalculate((Map<Id, Convention__c>) newItems, (Map<Id, Convention__c>) oldItems);
        //method to update the role on agreement role when the code type is changed on the agreement
        if (PAD.canTrigger('updateAgreementRoleWhenCodeTypeChange')) {
            SM034_AgreementService.updateAgreementRoleWhenCodeTypeChange((Map<Id, Convention__c>) newItems, (Map<Id, Convention__c>) oldItems);
        }
    }

    public void AfterDelete(Map<Id, SObject> oldItems) { 
    SM034_AgreementService.handleRollupCalculate((Map<Id, Convention__c>) oldItems, null);
    }

    public void AfterUndelete(Map<Id, SObject> oldItems) { 
    SM034_AgreementService.handleRollupCalculate((Map<Id, Convention__c>) oldItems, null);
    }

    public Boolean isDisabled() {
        if (PAD.canTrigger('AgreementTrigger')) {
            return triggerDisabled;
        }
        else {
            return true;
        }
    }
}