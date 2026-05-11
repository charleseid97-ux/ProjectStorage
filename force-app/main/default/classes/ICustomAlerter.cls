/** ──────────────────────────────────────
 * @description Interface for the Custom Alert Framework.
 *              Any class registered in ScheduledAlert__mdt must implement this interface.
 *              The dispatch method is called by CustomAlertScheduler with the full metadata
 *                  config record, giving the implementing class access to EmailTemplate__c,
 *                  BatchSize__c, and any other configured values.
 * @author Charles EID
 ────────────────────────────────────── */
public interface ICustomAlerter {
    void dispatch(ScheduledAlert__mdt config);
}
