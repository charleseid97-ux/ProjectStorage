public without sharing  class ShareClassHandler {
    
    public static void updateFormattedName(List<Share_Class__c> newShareclass, Map<Id, Share_Class__c> oldMap) {
        Boolean isInsert = (oldMap == null);
        
        /* ================= GET RELATED FUNDS ================= */
        Set<Id> fundIds = new Set<Id>();
        for (Share_Class__c sc : newShareclass) {
            if (sc.Fund__c != null) {
                fundIds.add(sc.Fund__c);
            }
        }
        
        Map<Id, Product__c> fundMap = new Map<Id, Product__c>();
        if (!fundIds.isEmpty()) {
            fundMap = new Map<Id, Product__c>([
                SELECT Id, LegalForm__c, Product_Name__c, ProductName__c
                FROM Product__c
                WHERE Id IN :fundIds
            ]);
        }
        
        /* ================= PROCESS SHARE CLASSES ================= */
        for (Share_Class__c sc : newShareclass) {
            
            // Skip on update if override is checked
            if (!isInsert && sc.ShareclassNameOverride__c == true) {
                continue;
            }
            
            Boolean needsUpdate = isInsert;
            
            if (!isInsert) {
                Share_Class__c oldSc = oldMap.get(sc.Id);
                if (oldSc != null) {
                    needsUpdate =
                        String.valueOf(sc.Type__c) != String.valueOf(oldSc.Type__c) ||
                        String.valueOf(sc.Currency__c) != String.valueOf(oldSc.Currency__c) ||
                        String.valueOf(sc.DividendPolicy__c) != String.valueOf(oldSc.DividendPolicy__c) ||
                        String.valueOf(sc.DividendFrequency__c) != String.valueOf(oldSc.DividendFrequency__c) ||
                        String.valueOf(sc.CurrencyHedging__c) != String.valueOf(oldSc.CurrencyHedging__c) ||
                        String.valueOf(sc.Fund__c) != String.valueOf(oldSc.Fund__c) ||
                        
                        // Recalculate if override changed from true to false
                        (oldSc.ShareclassNameOverride__c == true && sc.ShareclassNameOverride__c == false);
                }
            }
            
            if (needsUpdate) {
                Product__c fundRec = fundMap.get(sc.Fund__c);
                sc.Name__c = buildLabel(sc, fundRec, false);
                sc.Name = buildLabel(sc, fundRec, true);
            }
        }
 }        
    
        public static String buildLabel(Share_Class__c sc, Product__c fundRec, Boolean includeProduct) {
            String productName = '';
            
            /* ================= PRODUCT NAME ================= */
            if (includeProduct) {
                if (!String.isBlank(fundRec.Product_Name__c)) {
                    productName = fundRec.Product_Name__c.trim();
                } else if (!String.isBlank(fundRec.ProductName__c)) {
                    productName = fundRec.ProductName__c.trim();
                }
            }
            /* ================= SHARE CLASS VALUES ================= */
            String typeValue = sc.Type__c == null ? '' : String.valueOf(sc.Type__c).trim();
            String currencyValue = sc.Currency__c == null ? '' : String.valueOf(sc.Currency__c).trim();
            String dividendPolicy = sc.DividendPolicy__c == null ? '' : String.valueOf(sc.DividendPolicy__c).trim();
            String dividendFrequency = sc.DividendFrequency__c == null ? '' : String.valueOf(sc.DividendFrequency__c).trim();
            
            /* ================= FUND VALUES ================= */
            String legalForm = '';
            if (fundRec != null && fundRec.LegalForm__c != null) {
                legalForm = String.valueOf(fundRec.LegalForm__c).trim();
            }
            
            Boolean isHedged = String.valueOf(sc.CurrencyHedging__c) == 'True';
            
            List<String> parts = new List<String>();
            
            if (!String.isBlank(productName)) {
                parts.add(productName);
            }
            
            /* ======================= OEIC CASE ========================== */
            if (legalForm == 'OEIC') {
                
                /* ---- Add Type ---- */
                if (!String.isBlank(typeValue)) {
                    parts.add(typeValue);
                }
                
                /* ---- Add Currency ---- */
                if (!String.isBlank(currencyValue)) {
                    parts.add(currencyValue);
                }
                
                /* ---- OEIC + ACCUMULATING ---- */
                if (dividendPolicy == 'Accumulating') {
                    parts.add(isHedged ? 'Acc Hdg' : 'Acc');
                    return String.join(parts, ' ');
                }
                
                /* ---- OEIC + INCOME ---- */
                else if (dividendPolicy == 'Income') {
                    parts.add(isHedged ? 'Inc Hdg' : 'Inc');
                    return String.join(parts, ' ');
                }
                
                /* ---- OEIC + OTHER DIVIDEND POLICY ---- */
                else {
                    return null;
                }
            }
            
            /* ================= NON-OEIC DEFAULT LOGIC =================== */
            
            /* ---- Add Type ---- */
            if (!String.isBlank(typeValue)) {
                parts.add(typeValue);
            }
            
            /* ---- MyInvestor special case ---- */
            if (typeValue == 'MyInvestor') {
                return String.join(parts, ' ');
            }
            
            String tail = '';
            
            /* ---- Add Currency ---- */
            if (!String.isBlank(currencyValue)) {
                tail += currencyValue + ' ';
            }
            
            /* ---- Accumulating ---- */
            if (dividendPolicy == 'Accumulating') {
                tail += 'Acc ';
            }
            
            /* ---- Distributing ---- */
            else if (dividendPolicy == 'Distributing') {
                switch on dividendFrequency {
                    when 'Monthly'       { tail += 'Mdis '; }
                    when 'Quarterly'     { tail += 'Qdis '; }
                    when 'SemiAnnually' { tail += 'Sdis '; }
                    when 'Annually'      { tail += 'Ydis '; }
                    when else            { }
                }
            }
            
            /* ---- Income ---- */
            else if (dividendPolicy == 'Income') {
                switch on dividendFrequency {
                    when 'Monthly'       { tail += 'Minc '; }
                    when 'Quarterly'     { tail += 'Qinc '; }
                    when 'SemiAnnually' { tail += 'Sinc '; }
                    when 'Annually'      { tail += 'Yinc '; }
                    when else            { tail += 'inc '; }
                }
            }
            
            /* ---- Hedging ---- */
            if (isHedged) {
                tail += 'Hdg';
            }
            
            tail = tail.trim();
            
            if (!String.isBlank(tail)) {
                parts.add(tail);
            }
           
            return String.join(parts, ' ');
        }
        
        public static void closeTaxDataOnShareClassClosure(
            List<Share_Class__c> newList,
            Map<Id, Share_Class__c> oldMap
        ) {
            if (newList == null || newList.isEmpty() || oldMap == null) {
                return;
            }
            
            Map<Id, Date> shareClassToCloseDate = new Map<Id, Date>();
            
            for (Share_Class__c sc : newList) {
                Share_Class__c oldSc = oldMap.get(sc.Id);
                if (oldSc == null) {
                    continue;
                }
                
                Boolean statusChanged = sc.Status__c != oldSc.Status__c;
                Boolean isClosedStatus =
                    sc.Status__c == 'Closed - Merged'
                    || sc.Status__c == 'Closed - Liquidated';
                
                if (statusChanged && isClosedStatus && sc.CloseDate__c != null) {
                    shareClassToCloseDate.put(sc.Id, sc.CloseDate__c);
                }
            }
            
            if (shareClassToCloseDate.isEmpty()) {
                return;
            }
            
            List<TaxData__c> taxDataToUpdate = [
                SELECT Id, ShareClass__c, Status__c, EndDate__c
                FROM TaxData__c
                WHERE ShareClass__c IN :shareClassToCloseDate.keySet()
                AND Status__c != 'No'
            ];
            
            if (taxDataToUpdate.isEmpty()) {
                return;
            }
            
            for (TaxData__c td : taxDataToUpdate) {
                td.Status__c = 'No';
                td.EndDate__c = shareClassToCloseDate.get(td.ShareClass__c);
            }
            
            update taxDataToUpdate;
        }

        private static final String TYPE_BELGIUM_SIMULATOR = 'Belgium Simulator';
        private static final String COUNTRY_BE = 'BE';
        private static final String STATUS_YES = 'Yes';

        public static void createBelgiumSimulatorForBelgiumShareClasses(List<Share_Class__c> newShareClasses) {
            if (newShareClasses == null || newShareClasses.isEmpty()) {
                return;
            }

            Set<Id> shareClassIds = new Set<Id>();

            for (Share_Class__c sc : newShareClasses) {
                if (sc.Id != null) {
                    shareClassIds.add(sc.Id);
                }
            }

            if (shareClassIds.isEmpty()) {
                return;
            }

            Map<Id, Share_Class__c> shareClassMap = new Map<Id, Share_Class__c>([
                SELECT Id, DividendPolicy__c, Fund__r.LegalForm__c, Fund__c, LaunchDate__c
                FROM Share_Class__c
                WHERE Id IN :shareClassIds
            ]);

            Set<Id> belgiumShareClassIds = getBelgiumShareClassIds(shareClassIds);

            List<TaxData__c> taxDataToInsert = new List<TaxData__c>();

            for (Share_Class__c sc : shareClassMap.values()) {
                if (shouldCreateBelgiumSimulator(sc, belgiumShareClassIds)) {
                    taxDataToInsert.add(new TaxData__c(
                        ShareClass__c = sc.Id,
                        Product__c = sc.Fund__c,
                        Type__c = TYPE_BELGIUM_SIMULATOR,
                        Country__c = COUNTRY_BE,
                        Status__c = STATUS_YES,
                        Source__c = 'PMT',
                        StartDate__c = sc.LaunchDate__c,
                        EndDate__c = null
                    ));
                }
            }

            if (!taxDataToInsert.isEmpty()) {
                insert taxDataToInsert;
            }
        }

        private static Boolean shouldCreateBelgiumSimulator(
            Share_Class__c sc,
            Set<Id> belgiumShareClassIds
        ) {
            return sc != null
                && sc.DividendPolicy__c == 'Accumulating'
                && sc.Fund__r != null
                && sc.Fund__r.LegalForm__c == 'FCP'
                && belgiumShareClassIds.contains(sc.Id);
        }

        private static Set<Id> getBelgiumShareClassIds(Set<Id> shareClassIds) {
            Set<Id> result = new Set<Id>();

            for (Country__c country : [
                SELECT ShareClass__c
                FROM Country__c
                WHERE ShareClass__c IN :shareClassIds
                AND Country__c = :COUNTRY_BE
            ]) {
                result.add(country.ShareClass__c);
            }

            return result;
        }
    }