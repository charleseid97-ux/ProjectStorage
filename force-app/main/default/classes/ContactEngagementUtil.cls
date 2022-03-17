public class ContactEngagementUtil {
    
    //CONTACT ENGAGEMENT V2
    @AuraEnabled
    public static Map<String, Object> getContactDigitalInteractionMetrics(String contactId, String currentTheme) {
        List<Digital_Interaction__c> dis = new List<Digital_Interaction__c>();
        if (currentTheme == 'all') {
            dis = [SELECT Contact__c, 
                   URL__c, 
                   Content_Item_Name__c, 
                   MDS_ID__c, 
                   Type__c, 
                   Thematic__c,
                   Date_of_Interaction__c, 
                   CreatedDate,
                   LastModifiedDate
                   FROM Digital_Interaction__c WHERE Contact__c =: contactId];
        } else {
            dis = [SELECT Contact__c, 
                   URL__c, 
                   Content_Item_Name__c, 
                   MDS_ID__c, 
                   Type__c, 
                   Thematic__c,
                   Date_of_Interaction__c, 
                   CreatedDate,
                   LastModifiedDate
                   FROM Digital_Interaction__c WHERE Contact__c =: contactId AND Thematic__c =: currentTheme];
        }
        
        return getDIMetricData(null, dis);
    } 
    
    @TestVisible
    private static Map<String, Object> getDIMetricData(List<Contact> contacts, List<Digital_Interaction__c> dis) {
        Map<String, Object> metricResult = new Map<String, Object>();
        
        //Initialisation of all total and subtotal counters
        Integer totalVisits = dis.size();
        //Marketing Activity
        Integer totalMKT = 0;
        Integer totalEmails = 0;
        Integer totalEvents = 0;
        Integer totalWebinars = 0;
        
        //Fund Interests
        Integer totalFI = 0;
        Integer totalDiversified  = 0;
        Integer totalEquity = 0;
        Integer totalFixedIncome = 0;
        Integer totalProfiled = 0;
        
        //Content Interest
        Integer totalCI = 0;
        Integer totalQuarterlyReport  = 0;
        Integer totalFlashNote = 0;
        Integer totalVideo = 0;
        Integer totalFundsFocus = 0;
        Integer totalCarmignacNote = 0;
        Integer totalProSpace = 0;
        
        //NEW Thematic
        Integer totalEd = 0;
        Integer totalMA = 0;
        Integer totalPA = 0;
        Integer totalFIS = 0;
        Integer totalThematicE = 0;
        Integer totalEmergingE = 0;
        Integer totalEuropeanE = 0;
        Integer totalSI = 0;
        Integer totalLSS = 0;
        
        for(Digital_Interaction__c di : dis) {
            metricResult.put('LastModified', di.LastModifiedDate.format('dd/MM/yyyy'));
            
            //iterate all Digital Interactions and increment the counter of the Type is belongs to
            if(di.Type__c == 'Diversified') {
                totalDiversified = totalDiversified + 1;
            } else if (di.Type__c == 'Equity') {
                totalEquity = totalEquity + 1;
            } else if (di.Type__c == 'FixedIncome') {
                totalFixedIncome = totalFixedIncome + 1;
            } else if (di.Type__c == 'Profiled') {
                totalProfiled = totalProfiled + 1;
            } else if (di.Type__c == 'QuarterlyReport') {
                totalQuarterlyReport = totalQuarterlyReport + 1;
            } else if (di.Type__c == 'FlashNote') {
                totalFlashNote = totalFlashNote + 1;
            } else if (di.Type__c == 'Video') {
                totalVideo = totalVideo + 1;
            } else if (di.Type__c == 'FundsFocus') {
                totalFundsFocus = totalFundsFocus + 1;
            } else if (di.Type__c == 'CarmignacNote') {
                totalCarmignacNote = totalCarmignacNote + 1;
            } else if (di.Type__c == 'ProSpace') {
                totalProSpace = totalProSpace + 1;
            } else if (di.Type__c == 'Email') {
                totalEmails = totalEmails + 1;
            } else if (di.Type__c == 'Event') {
                totalEvents = totalEvents + 1;
            } else if (di.Type__c == 'Webinar') {
                totalWebinars = totalWebinars + 1;
            }
            
            if(di.Thematic__c == 'Letter from Edouard Carmignac') {
                totalEd = totalEd + 1;
            } else if (di.Thematic__c == 'Market Analysis') {
                totalMA = totalMA + 1;
            } else if (di.Thematic__c == 'Patrimoine Strategy') {
                totalPA = totalPA + 1;
            }else if (di.Thematic__c == 'Fixed Income Strategy') {
                totalFIS = totalFIS + 1;
            } else if (di.Thematic__c == 'Thematic equities') {
                totalThematicE = totalThematicE + 1;
            }else if (di.Thematic__c == 'Emerging equities') {
                totalEmergingE = totalEmergingE + 1;
            } else if (di.Thematic__c == 'European equities') {
                totalEuropeanE = totalEuropeanE + 1;
            } else if (di.Thematic__c == 'Sustainable investing') {
                totalSI = totalSI + 1;
            } else if (di.Thematic__c == 'Long-Short Strategy') {
                totalLSS = totalLSS + 1;
            }
        }
        
        //count the totals for each Record Type : Marketing_Activity (totalMKT), Product_Interest (totalFI), Content_Consumption (totalCI)
        totalMKT = totalEmails + totalEvents + totalWebinars;
        totalFI = totalDiversified  + totalEquity + totalFixedIncome + totalProfiled;
        totalCI = totalQuarterlyReport  + totalFlashNote + totalVideo + totalFundsFocus + totalCarmignacNote + totalProSpace;
        
        //add all counters and totals to the metricResult Map which is returned to the LC
        metricResult.put('TotalMKT', totalMKT);
        metricResult.put('TotalEmails', totalEmails);
        metricResult.put('TotalEmailsPerc', tableWidth(totalMKT, totalEmails));
        metricResult.put('TotalEvents', totalEvents);
        metricResult.put('TotalEventsPerc', tableWidth(totalMKT, totalEvents));
        metricResult.put('TotalWebinars', totalWebinars);
        metricResult.put('TotalWebinarsPerc', tableWidth(totalMKT, totalWebinars));
        
        metricResult.put('TotalFI', totalFI);
        metricResult.put('TotalDiversified', totalDiversified);
        metricResult.put('TotalDiversifiedPerc', tableWidth(totalFI, totalDiversified));
        metricResult.put('TotalEquity', totalEquity);
        metricResult.put('TotalEquityPerc', tableWidth(totalFI, totalEquity));
        metricResult.put('TotalFixedIncome', totalFixedIncome);
        metricResult.put('TotalFixedIncomePerc', tableWidth(totalFI, totalFixedIncome));
        metricResult.put('TotalProfiled', totalProfiled);
        metricResult.put('TotalProfiledPerc', tableWidth(totalFI, totalProfiled));
        
        metricResult.put('TotalCI', totalCI);
        metricResult.put('TotalQuarterlyReport', totalQuarterlyReport);
        metricResult.put('TotalFlashNote', totalFlashNote);
        metricResult.put('TotalVideo', totalVideo);
        metricResult.put('TotalFundsFocus', totalFundsFocus);
        metricResult.put('TotalCarmignacNote', totalCarmignacNote);
        metricResult.put('TotalProSpace', totalProSpace);
        
        metricResult.put('TotalEd', totalEd);
        metricResult.put('totalMA', totalMA);
        metricResult.put('totalPA', totalPA);
        metricResult.put('totalFIS', totalFIS);
        metricResult.put('totalThematicE', totalThematicE);
        metricResult.put('totalEmergingE', totalEmergingE);
        metricResult.put('totalEuropeanE', totalEuropeanE);
        metricResult.put('totalSI', totalSI);
        metricResult.put('totalLSS', totalLSS);
        
        if(contacts != null) {
            metricResult.put('ContactCount', contacts.size());
        }
        
        return metricResult;
    }
    
    //returns List of Digital Interactions filtered by Contact and DI Type for Drill Down data
    @AuraEnabled
    public static List<Digital_Interaction__c> getDrillDownData(String contactId, String clickedSection, String currentTheme) {
        
        List<Digital_Interaction__c> dis = new List<Digital_Interaction__c>();
        if (currentTheme == 'all') {
            dis = [SELECT URL__c, 
                   Content_Item_Name__c, 
                   Type__c, 
                   Date_of_Interaction__c, 
                   Product__r.Name, 
                   Product__r.Id,
                   Thematic__c
                   FROM Digital_Interaction__c
                   WHERE Contact__c =: contactId AND Type__c =: clickedSection
                   ORDER BY Date_of_Interaction__c desc];
        } else if(currentTheme == 'Letter from Edouard Carmignac' && clickedSection == 'Letter from Edouard Carmignac') {
            dis = [SELECT URL__c, 
                   Content_Item_Name__c, 
                   Type__c, 
                   Date_of_Interaction__c, 
                   Product__r.Name, 
                   Product__r.Id,
                   Thematic__c 
                   FROM Digital_Interaction__c
                   WHERE Contact__c =: contactId AND Thematic__c =: currentTheme
                   ORDER BY Date_of_Interaction__c desc];
            
        }else {
            dis = [SELECT URL__c, 
                   Content_Item_Name__c, 
                   Type__c, 
                   Date_of_Interaction__c, 
                   Product__r.Name, 
                   Product__r.Id,
                   Thematic__c 
                   FROM Digital_Interaction__c
                   WHERE Contact__c =: contactId AND Type__c =: clickedSection AND Thematic__c =: currentTheme
                   ORDER BY Date_of_Interaction__c desc];
            
        }
        return dis;
    }
    
    @AuraEnabled
    public static Map<String, Object> getCompanyEngagementMetrics(String companyId) {
        
        List<Contact> contacts = [SELECT Name, Id FROM Contact WHERE AccountId =: companyId];
        
        List<Engagement__c> engagements = [SELECT  Name, 
                                           Id, 
                                           lastModifiedDate, 
                                           Contact__c, 
                                           Emails__c,
                                           Events__c,
                                           Webinars__c,
                                           Diversified__c,
                                           Equity__c,
                                           Fixed_income__c,
                                           Profiled__c,
                                           Quarterly_Report__c,
                                           Flash_Note__c,
                                           Carmignac_Note__c,
                                           Video__c,
                                           Funds_Focus__c,
                                           Pro_Space__c
                                           FROM Engagement__c WHERE Contact__c IN: contacts];
        
        return getMetricData(contacts, engagements);
        
    }
    
    @TestVisible
    private static Map<String, Object> getMetricData(List<Contact> contacts, List<Engagement__c> engagements) {
        Map<String, Object> metricResult = new Map<String, Object>();
        //Marketing Activity
        Integer totalMKT = 0;
        Integer totalEmails = 0;
        Integer totalEvents = 0;
        Integer totalWebinars = 0;
        
        //Fund Interests
        Integer totalFI = 0;
        Integer totalDiversified  = 0;
        Integer totalEquity = 0;
        Integer totalFixedIncome = 0;
        Integer totalProfiled = 0;
        
        //Content Interest
        Integer totalCI = 0;
        Integer totalQuarterlyReport  = 0;
        Integer totalFlashNote = 0;
        Integer totalVideo = 0;
        Integer totalFundsFocus = 0;
        Integer totalCarmignacNote = 0;
        Integer totalProSpace = 0;
        
        for(Engagement__c e : engagements) {
            metricResult.put('LastModified', e.LastModifiedDate.format('dd/MM/yyyy'));
            totalEmails = totalEmails + Integer.valueOf(e.Emails__c);
            totalEvents = totalEvents + Integer.valueOf(e.Events__c);
            totalWebinars = totalWebinars + Integer.valueOf(e.Webinars__c);
            totalMKT = totalEmails + totalEvents + totalWebinars;
            
            totalDiversified  = totalDiversified + Integer.valueOf(e.Diversified__c);
            totalEquity = totalEquity + Integer.valueOf(e.Equity__c);
            totalFixedIncome = totalFixedIncome + Integer.valueOf(e.Fixed_income__c);
            totalProfiled = totalProfiled + Integer.valueOf(e.Profiled__c);
            totalFI = totalDiversified  + totalEquity + totalFixedIncome + totalProfiled;
            
            totalQuarterlyReport  = totalQuarterlyReport + Integer.valueOf(e.Quarterly_Report__c);
            totalFlashNote = totalFlashNote + Integer.valueOf(e.Flash_Note__c);
            totalVideo = totalVideo + Integer.valueOf(e.Video__c);
            totalFundsFocus = totalFundsFocus + Integer.valueOf(e.Funds_Focus__c);
            totalCarmignacNote = totalCarmignacNote + Integer.valueOf(e.Carmignac_Note__c);
            totalProSpace = totalProSpace + Integer.valueOf(e.Pro_Space__c);
            totalCI = totalQuarterlyReport  + totalFlashNote + totalVideo + totalFundsFocus + totalCarmignacNote + totalProSpace;
        }
        
        metricResult.put('TotalMKT', totalMKT);
        metricResult.put('TotalEmails', totalEmails);
        metricResult.put('TotalEmailsPerc', tableWidth(totalMKT, totalEmails));
        metricResult.put('TotalEvents', totalEvents);
        metricResult.put('TotalEventsPerc', tableWidth(totalMKT, totalEvents));
        metricResult.put('TotalWebinars', totalWebinars);
        metricResult.put('TotalWebinarsPerc', tableWidth(totalMKT, totalWebinars));
        
        metricResult.put('TotalFI', totalFI);
        metricResult.put('TotalDiversified', totalDiversified);
        metricResult.put('TotalDiversifiedPerc', tableWidth(totalFI, totalDiversified));
        metricResult.put('TotalEquity', totalEquity);
        metricResult.put('TotalEquityPerc', tableWidth(totalFI, totalEquity));
        metricResult.put('TotalFixedIncome', totalFixedIncome);
        metricResult.put('TotalFixedIncomePerc', tableWidth(totalFI, totalFixedIncome));
        metricResult.put('TotalProfiled', totalProfiled);
        metricResult.put('TotalProfiledPerc', tableWidth(totalFI, totalProfiled));
        
        metricResult.put('TotalCI', totalCI);
        metricResult.put('TotalQuarterlyReport', totalQuarterlyReport);
        metricResult.put('TotalFlashNote', totalFlashNote);
        metricResult.put('TotalVideo', totalVideo);
        metricResult.put('TotalFundsFocus', totalFundsFocus);
        metricResult.put('TotalCarmignacNote', totalCarmignacNote);
        metricResult.put('TotalProSpace', totalProSpace);
        
        if(contacts != null) {
            metricResult.put('ContactCount', contacts.size());
            metricResult.put('EngagementCount', engagements.size());
        }
        
        return metricResult;
        
    }
    
    //Util function to calculate the cell width of Asset Classes in the Product table bar
    public static Double tableWidth(Integer total, Integer sub) {
        Double width = total == 0 ? 0 : (Double.valueOf(sub) / Double.valueOf(total)) * 100;
        return width;
    }
    
    @AuraEnabled(cacheable=true)
    public static String digitalInteractionByMonths(String contactId){
        Map<Integer, String> monthsMap = new Map<Integer, String>{1 => 'January',            2 => 'February',            3 => 'March',                4 => 'April',            5 => 'May',            6 => 'June',            
        7 => 'July',            8 => 'August',            9 => 'September',                10 => 'October',            11 => 'November',            12 => 'December'                }; 
            
            Map<String,Map<String,List<Integer>>> mapMonthTypeCount = new Map<String,Map<String,List<Integer>>>();
    Map<String,List<String>> mapMTypeCount = new Map<String,List<String>>();
    Map<String,List<String>> mapMonthType = new Map<String,List<String>>();
    Set<String> allTypes = new Set<String>();
    for (AggregateResult ar : [
        SELECT CALENDAR_MONTH(Date_of_Interaction__c) m, Type__c t, COUNT(Id) c
        FROM Digital_Interaction__c
        WHERE Type__c != null AND Date_of_Interaction__c = THIS_YEAR  AND contact__c =: contactId
        GROUP BY CALENDAR_MONTH(Date_of_Interaction__c), Type__c
        ORDER BY CALENDAR_MONTH(Date_of_Interaction__c), Type__c]
        ) {
            
            String m = monthsMap.get((Integer) ar.get('m'));
            String t = (String) ar.get('t');
            Integer c = (Integer) ar.get('c');
            
            if(!allTypes.contains(t))
                allTypes.add(t);
            
            
            if(mapMTypeCount.get(m) == null) {
                mapMTypeCount.put(m, new List<String>{t+'|'+String.valueOf(c)});
            } else {
                mapMTypeCount.get(m).add(t+'|'+String.valueOf(c));
            }
            
            
            if(mapMonthType.get(m) == null) {
                mapMonthType.put(m, new List<String>{t});
            } else {
                mapMonthType.get(m).add(t);
            }
        }
    
    Map<String,List<Integer>> mapTypeCount = new Map<String,List<Integer>>();
    for(String key:mapMTypeCount.KeySet()){
        Set<String> tempSet = new Set<String>(allTypes);
        
        for(String v:mapMTypeCount.get(key)){
            
            String delimiter = '|';
            String firstSplit = v.substringBefore(delimiter);
            Integer lastSplits = Integer.valueOf(v.substringAfter(delimiter));
            tempSet.remove(firstSplit);
            
            if(mapTypeCount.get(firstSplit) == null) {
                mapTypeCount.put(firstSplit, new List<Integer>{lastSplits});
            } else {
                mapTypeCount.get(firstSplit).add(lastSplits);
            }
            
        }
        if (tempSet.size() > 0){
            for(String v:tempSet){
                if(mapTypeCount.get(v) == null) {
                    mapTypeCount.put(v, new List<Integer>{0});
                } else {
                    mapTypeCount.get(v).add(0);
                }
            }
        }
    }
    
    for(String key:mapMonthType.KeySet()){
        String k = key;
        for(String v:mapMonthType.get(key)){
            if(mapMonthTypeCount.get(k) == null) {
                mapMonthTypeCount.put(k,new Map<String,List<Integer>>{v => mapTypeCount.get(v)});
            } else {
                mapMonthTypeCount.get(k).putAll(new Map<String,List<Integer>>{v => mapTypeCount.get(v)});
            }
        }
    }
        
        return JSON.serialize(mapMonthTypeCount);
    }
}