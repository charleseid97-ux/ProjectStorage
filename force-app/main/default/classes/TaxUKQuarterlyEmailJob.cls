global with sharing class TaxUKQuarterlyEmailJob implements Schedulable {
    global void execute(SchedulableContext sc) {
        TaxEmailService.sendUKQuarterlyTransparencyEmails();
    }
}