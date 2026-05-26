global with sharing class TaxUKQuarterlyEmailJob implements Schedulable {

    @TestVisible
    private static Boolean forceRunForTest = false;

    global void execute(SchedulableContext sc) {
        if (!forceRunForTest && !shouldRunToday()) {
            return;
        }

        TaxEmailService.sendUKQuarterlyTransparencyEmails();
    }

    private static Boolean shouldRunToday() {
        Date today = Date.today();

        if (today.month() == 12) {
            return today.day() == 15;
        }

        if (!new Set<Integer>{3, 6, 9}.contains(today.month())) {
            return false;
        }

        return today == getLastBusinessDayOfMonth(today);
    }

    @TestVisible
    private static Date getLastBusinessDayOfMonth(Date inputDate) {
        Date lastDay = Date.newInstance(
            inputDate.year(),
            inputDate.month(),
            Date.daysInMonth(inputDate.year(), inputDate.month())
        );

        Datetime lastDayDt = Datetime.newInstance(
            lastDay.year(),
            lastDay.month(),
            lastDay.day()
        );

        String dayName = lastDayDt.format('E');

        if (dayName == 'Sat') {
            return lastDay.addDays(-1);
        }

        if (dayName == 'Sun') {
            return lastDay.addDays(-2);
        }

        return lastDay;
    }
}