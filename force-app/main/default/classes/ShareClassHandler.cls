public  class ShareClassHandler {
    
    public static void updateFormattedName(List<Share_Class__c> newShareclass, Map<Id, Share_Class__c> oldMap) {
        Boolean isInsert = (oldMap == null);

        for (Share_Class__c sc : newShareclass) {
            Boolean needsUpdate = isInsert;

            if (!isInsert) {
                Share_Class__c oldSc = oldMap.get(sc.Id);
                if (oldSc != null) {
                    needsUpdate =
                        String.valueOf(sc.Type__c) != String.valueOf(oldSc.Type__c) ||
                        String.valueOf(sc.Currency__c) != String.valueOf(oldSc.Currency__c) ||
                        String.valueOf(sc.DividendPolicy__c) != String.valueOf(oldSc.DividendPolicy__c) ||
                        String.valueOf(sc.DividendFrequency__c) != String.valueOf(oldSc.DividendFrequency__c) ||
                        String.valueOf(sc.CurrencyHedging__c) != String.valueOf(oldSc.CurrencyHedging__c);
                }
            }

            if (needsUpdate) {
                sc.Name__c = buildFormattedLabel(sc);
            }
        }
    }

    private static String buildFormattedLabel(Share_Class__c sc) {
        String label = '';

        if (!String.isBlank(String.valueOf(sc.Type__c))) {
            label += String.valueOf(sc.Type__c).trim() + ' ';
        }

        if (!String.isBlank(String.valueOf(sc.Currency__c))) {
            label += String.valueOf(sc.Currency__c).trim() + ' ';
        }

        if (String.valueOf(sc.DividendPolicy__c) == 'Accumulating') {
            label += 'Acc ';
        } else if (String.valueOf(sc.DividendPolicy__c) == 'Distributing') {
            switch on sc.DividendFrequency__c {
                when 'Monthly'      { label += 'Mdis '; }
                when 'Quarterly'    { label += 'Qdis '; }
                when 'SemiAnnually' { label += 'Sdis '; }
                when 'Annually'     { label += 'Ydis '; }
            }
        }

        if (String.valueOf(sc.CurrencyHedging__c) == 'True') {
            label += 'Hdg';
        }

        return label.trim();
    }

}