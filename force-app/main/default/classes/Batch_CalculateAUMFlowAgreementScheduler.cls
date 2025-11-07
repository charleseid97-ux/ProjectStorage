/**
 * @description       : 
 * @author            : Khadija EL GDAOUNI
 * @group             : 
 * @last modified on  : 11-07-2024
 * @last modified by  : Khadija EL GDAOUNI
**/
global class Batch_CalculateAUMFlowAgreementScheduler implements Schedulable {
    
    global void execute(SchedulableContext SC) {
        Batch_CalculateAUMFlowAgreement b = new Batch_CalculateAUMFlowAgreement();
        Database.executebatch(b, 50);
     }
}