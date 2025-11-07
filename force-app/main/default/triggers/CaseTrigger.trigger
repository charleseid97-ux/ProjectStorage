/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 06-10-2024
 * @last modified by  : SILA Nicolas
**/
trigger CaseTrigger on Case (after insert,before update, after update) {
    TriggerDispatcher.run(new CaseTriggerHandler());
}