/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 03-07-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
trigger DigitalInteractionDetailsTrigger on Digital_Interaction_Details__c (before insert, before update) {
    TriggerDispatcher.run(new DigitalInteractionDetailsTriggerHandler());
}