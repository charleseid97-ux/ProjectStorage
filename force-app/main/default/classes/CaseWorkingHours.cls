/**
 * @description       : 
 * @author            : Mira EID
 * @group             : 
 * @last modified on  : 09-02-2026
 * @last modified by  : Mira EID
**/
public class CaseWorkingHours {
    
    public static void durationCalculation( List<Case> newCases, Map<Id, Case> oldMap) {
        
        Id bhId = [SELECT Id FROM BusinessHours WHERE Name = 'Webhelp' AND IsActive = true LIMIT 1].Id;
        
        for (Case c : newCases) {
            
            Case oldC = oldMap.get(c.Id);
            
            /* ===================================================
* 1. STATUS DATE STAMPING
* =================================================== */
            
            if (oldC.Status != c.Status) {
                
                if (c.Status == 'Work in progress')
                    c.TECHWorkinProgressDate__c = System.now();
                
                if (c.Status == 'Preview')
                    c.TECHPreviewDate__c = System.now();
                
                if (c.Status == 'Validated')
                    c.ValidationDate__c = System.now();
            }
            
            /* ===================================================
* 2. ON HOLD START
* =================================================== */
            
            if (!oldC.On_Hold__c && c.On_Hold__c &  c.Status == 'Work in progress') {
                c.TECH_OnHoldStart__c = System.now();
            }
            
            /* ===================================================
* 3. ON HOLD END
* =================================================== */
            
            if (oldC.On_Hold__c && !c.On_Hold__c) {
                Decimal holdHours =  businessHoursBetween(
                    oldC.TECH_OnHoldStart__c,
                    System.now(),
                    bhId
                );
                
                c.OnHoldDuration__c =(c.OnHoldDuration__c == null ? 0 : c.OnHoldDuration__c) + holdHours;
                c.TECH_OnHoldStart__c = null;
            }
            
            /* ===================================================
* 4. PHASE DURATION CALCULATIONS
* =================================================== */
            
            // New → Work in Progress
            if (oldC.Status != c.Status && oldC.Status == 'New'&& c.Status == 'Work in progress') {
                
                c.NewtoWorkinProgressDuration__c =
                    businessHoursBetween(
                        c.TECHNewDate__c,
                        c.TECHWorkinProgressDate__c,
                        bhId
                    );
            }
            
            // Work in Progress → Preview
            if (oldC.Status != c.Status && oldC.Status == 'Work in progress' && c.Status == 'Preview') {
                
                Decimal total =
                    businessHoursBetween(
                        c.TECHWorkinProgressDate__c,
                        c.TECHPreviewDate__c,
                        bhId
                    );
                
                Decimal onHold =
                    c.OnHoldDuration__c == null ? 0 : c.OnHoldDuration__c;
                c.WorkinProgresstoPreviewDuration__c = Math.max(0, total - onHold);
            }
            
            // Preview → Validated
            if (oldC.Status != c.Status  && oldC.Status == 'Preview' && c.Status == 'Validated') {
                
                c.PreviewtoValidationDuration__c =
                    businessHoursBetween(
                        c.TECHPreviewDate__c,
                        c.ValidationDate__c,
                        bhId
                    );
            }
            
            // Work in Progress → Validated
            if (oldC.Status != c.Status  && oldC.Status == 'Work in progress' && c.Status == 'Validated') {
                
                c.WorkProgresstoValidationDuration__c =
                    businessHoursBetween(
                        c.TECHWorkinProgressDate__c,
                        c.ValidationDate__c,
                        bhId
                    );
            }
        }
    }
    
    private static final Long MS_TO_HOURS = 1000 * 60 * 60;
    
    private static Decimal businessHoursBetween(
        Datetime startDt,
        Datetime endDt,
        Id bhId
    ) {
        if (startDt == null || endDt == null || startDt >= endDt) {
           return 0;
        }
        Long diffMs = BusinessHours.diff(bhId, startDt, endDt);               
        
        return (Decimal)diffMs / MS_TO_HOURS;
    }
}