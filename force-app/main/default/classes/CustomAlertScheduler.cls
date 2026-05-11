/** ──────────────────────────────────────
 * @description Daily schedulable dispatcher for the Custom Alert Framework.
 *              Queries all active ScheduledAlert__mdt records, evaluates each record's
 *                  Frequency against today's date (Daily / Weekly / Biweekly / Monthly),
 *                  and dynamically instantiates the configured ICustomAlerter class via
 *                  Type.forName() to dispatch matching alerts.
 * @author Charles EID
 * @testClass CustomAlertSchedulerTest
 * @coverage 100%  [11-05-26]
 ────────────────────────────────────── */
public with sharing class CustomAlertScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        Integer daysSinceAnchor = Date.newInstance(2000, 1, 2).daysBetween(Date.today());
        Integer dayOfWeek = Math.mod(daysSinceAnchor, 7); // 0=Sun, 1=Mon, ..., 6=Sat
        Integer weekNumber = daysSinceAnchor / 7;

        List<ScheduledAlert__mdt> alerts = [SELECT ApexClass__c, EmailTemplate__c, Frequency__c, BatchSize__c, Description__c
                                            FROM ScheduledAlert__mdt
                                            WHERE IsActive__c = true];

        for (ScheduledAlert__mdt alert : alerts) {
            if (shouldDispatch(alert.Frequency__c, dayOfWeek, weekNumber)) {
                ICustomAlerter alerter = (ICustomAlerter) Type.forName(alert.ApexClass__c).newInstance();
                alerter.dispatch(alert);
            }
        }
    }

    @TestVisible
    private static Boolean shouldDispatch(String frequency, Integer dayOfWeek, Integer weekNumber) {
        if (frequency == 'Daily') {
            return true;
        }
        if (frequency == 'Weekly') {
            return dayOfWeek == 1;
        }
        if (frequency == 'Biweekly') {
            return dayOfWeek == 1 && Math.mod(weekNumber, 2) == 0;
        }
        if (frequency == 'Monthly') {
            return Date.today().day() == 1;
        }
        return false;
    }
}
