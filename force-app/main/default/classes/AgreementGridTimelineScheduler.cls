/** ──────────────────────────────────────
 * @description Schedulable wrapper that launches AgreementGridTimelineBatch daily.
 *              Schedule via Setup → Apex Classes → Schedule Apex, or:
 *              System.schedule('AGT Daily Activation', '0 0 0 * * ?', new AgreementGridTimelineScheduler());
 * @author Charles EID
────────────────────────────────────── */
public with sharing class AgreementGridTimelineScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new AgreementGridTimelineBatch(), 200);
    }
}
