trigger FundFieldApplicabilityHistoryTrigger on Fund_Field_ApplicabilityHistory__c (before insert, before update) {
    FundFieldApplicabilityHistoryHandler.handleBeforeInsertUpdate(Trigger.new);
}
