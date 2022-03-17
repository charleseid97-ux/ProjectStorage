/*
        This class runs the appropriate methods on the trigger handler based on the current trigger context.

        Author: Chris Aldridge, http://chrisaldridge.com
	
Change history :
	2018-08-14  sankaran Fixed a bug which happens when there's no custom metadata configured for object.
                         Fix is to check return value of handler.IsDisabled() against 'true'.
 */
public class TriggerDispatcher
{
	@TestVisible private static Boolean testLock = false;
	@TestVisible private enum BeforeOrAfter {ISBEFORE, ISAFTER}
	@TestVisible private enum TriggerEvent {ISUPDATE, ISINSERT, ISDELETE, ISUNDELETE}
	@TestVisible private static BeforeOrAfter testBeforeOrAfter;
	@TestVisible private static TriggerEvent testEvent;

	/*
	        Call this method from your trigger, passing in an instance of a trigger handler which implements ITriggerHandler.
	        This method will fire the appropriate methods on the handler depending on the trigger context.
	 */
	public static void Run(ITriggerHandler handler)
	{
		// Check to see if the trigger has been disabled. If it has, return
		if (handler.IsDisabled() == true)
			return;

		// Detect the current trigger context and fire the relevant methods on the trigger handler:

		// Before trigger logic
		if ((testLock && testBeforeOrAfter == BeforeOrAfter.ISBEFORE)
		    || (!testLock && Trigger.IsBefore))
		{
			if ((testLock && testEvent == TriggerEvent.ISINSERT)
			    || (!testLock && Trigger.IsInsert))
				handler.BeforeInsert(trigger.new);

			if ((testLock && testEvent == TriggerEvent.ISUPDATE)
			    || (!testLock && Trigger.IsUpdate))
				handler.BeforeUpdate(trigger.newMap, trigger.oldMap);

			if ((testLock && testEvent == TriggerEvent.ISDELETE)
			    || (!testLock && Trigger.IsDelete))
				handler.BeforeDelete(trigger.oldMap);
		}

		// After trigger logic
		if ((testLock && testBeforeOrAfter == BeforeOrAfter.ISAFTER)
		    || (!testLock && Trigger.IsAfter))
		{
			if ((testLock && testEvent == TriggerEvent.ISINSERT)
			    || (!testLock && Trigger.IsInsert))
				handler.AfterInsert(Trigger.newMap);

			if ((testLock && testEvent == TriggerEvent.ISUPDATE)
			    || (!testLock && Trigger.IsUpdate))
				handler.AfterUpdate(trigger.newMap, trigger.oldMap);

			if ((testLock && testEvent == TriggerEvent.ISDELETE)
			    || (!testLock && Trigger.IsDelete))
				handler.AfterDelete(trigger.oldMap);

			if ((testLock && testEvent == TriggerEvent.ISUNDELETE)
			    || (!testLock && Trigger.IsUndelete))
				handler.AfterUndelete(trigger.newMap);
		}
	}
}