/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 11-06-2024
 * @last modified by  : SILA Nicolas
**/
trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert,before delete,after delete) {
    // Call the handler method to process the new content document links
    TriggerDispatcher.run(new ContentDocumentLinkTriggerHandler());

}