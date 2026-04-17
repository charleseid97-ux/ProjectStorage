global with sharing class ContactDigitalInteractionUtil {

    private static String getMonths(Integer m){
        Map<Integer, String> monthsMap = new Map<Integer, String>{1 => 'January',            2 => 'February',            3 => 'March',                4 => 'April',            5 => 'May',            6 => 'June',            
        7 => 'July',            8 => 'August',            9 => 'September',                10 => 'October',            11 => 'November',            12 => 'December'                };
        return monthsMap.get(m);
    }

    @AuraEnabled(cacheable=true)
    public static String disByMonths(String contactId, String clickedButton){

        String type = ' Type__c ';
        String product = ' Product__c ';
        String productType = ' Product__r.Product_Name__c,Type__c';
        String soql = '';
        Integer c = null;
        String m = '';
        String t = '';
        String p = '';

        String soqlTemplate = 'SELECT CALENDAR_MONTH(Date_of_Interaction__c) m, Type__c t {0}, COUNT(Id) c'
        +' FROM Digital_Interaction__c'
        +' WHERE {1} != null AND Date_of_Interaction__c = LAST_N_MONTHS:4  AND contact__c =: contactId'
        +' GROUP BY CALENDAR_MONTH(Date_of_Interaction__c), {2}'
        +' ORDER BY CALENDAR_MONTH(Date_of_Interaction__c), {2}';

        Map<String,Map<String,List<Integer>>> mapMonthTypeCount = new Map<String,Map<String,List<Integer>>>();
        Map<String,List<String>> mapMTypeCount = new Map<String,List<String>>();
        Map<String,List<String>> mapMonthType = new Map<String,List<String>>();
        Set<String> allTypes = new Set<String>();
        List<AggregateResult> records =  new List<AggregateResult>();

        if( clickedButton == 'All'){

            soql = String.format(soqlTemplate, new List<String> {'', type, type});
            records = Database.query(soql);
            for (AggregateResult ar : records) {

                m = getMonths((Integer) ar.get('m')); t = (String) ar.get('t'); c = (Integer) ar.get('c');

                if(!allTypes.contains(t))
                    allTypes.add(t);
            
                if(!mapMTypeCount.containsKey(m)) {
                    mapMTypeCount.put(m, new List<String>{t+'|'+String.valueOf(c)});
                } else {
                    mapMTypeCount.get(m).add(t+'|'+String.valueOf(c));
                }
                
                if(!mapMonthType.containsKey(m)) {
                    mapMonthType.put(m, new List<String>{t});
                } else {
                    mapMonthType.get(m).add(t);
                }
            }
        } else if ( clickedButton == 'Interactions By Product' ){

            soql = String.format(soqlTemplate, new List<String> {', Product__r.Product_Name__c p', product, productType});
            records = Database.query(soql);
            for (AggregateResult ar : records) {
           
                m = getMonths((Integer) ar.get('m')); t = (String) ar.get('t'); p = (String) ar.get('p'); c = (Integer) ar.get('c');
                
                if(!allTypes.contains(t))
                    allTypes.add(t);
                
                if(!mapMTypeCount.containsKey(m)) {
                    mapMTypeCount.put(m, new List<String>{t+'-'+p+'|'+String.valueOf(c)});
                } else {
                    mapMTypeCount.get(m).add(t+'-'+p+'|'+String.valueOf(c));
                }
                
                
                if(!mapMonthType.containsKey(m)) {
                    mapMonthType.put(m, new List<String>{t+'-'+p});
                } else {
                    mapMonthType.get(m).add(t+'-'+p);
                }
            }
        }

        return resultsMap(mapMonthTypeCount, mapMTypeCount, mapMonthType, allTypes);
    }

    private static String resultsMap(Map<String,Map<String,List<Integer>>> mapMonthTypeCount, Map<String,List<String>> mapMTypeCount, Map<String,List<String>> mapMonthType, Set<String> allTypes){

        Map<String,List<Integer>> mapTypeCount = new Map<String,List<Integer>>();
        for(String key:mapMTypeCount.KeySet()){
            Set<String> tempSet = new Set<String>(allTypes);
            
            for(String v:mapMTypeCount.get(key)){
                
                String delimiter = '|';
                String firstSplit = v.substringBefore(delimiter);
                Integer lastSplits = Integer.valueOf(v.substringAfter(delimiter));
                tempSet.remove(firstSplit);
                
                if(!mapTypeCount.containsKey(firstSplit)) {
                    mapTypeCount.put(firstSplit, new List<Integer>{lastSplits});
                } else {
                    mapTypeCount.get(firstSplit).add(lastSplits);
                }
                
            }
            if (tempSet.size() > 0){
                for(String v:tempSet){
                    if(!mapTypeCount.containsKey(v)) {
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
                if(!mapMonthTypeCount.containsKey(k)) {
                    mapMonthTypeCount.put(k,new Map<String,List<Integer>>{v => mapTypeCount.get(v)});
                } else {
                    mapMonthTypeCount.get(k).putAll(new Map<String,List<Integer>>{v => mapTypeCount.get(v)});
                }
            }
        }
        
        return JSON.serialize(mapMonthTypeCount);
    }

    @AuraEnabled(cacheable=true)
    public static List<disDataTableWrapper> retriveDigitalInteraction(String contactId,String clickedButton) {
        
        String query = 'SELECT Id, Content_Item_Name__c, URL__c, Date_of_Interaction__c, Product__r.Id, Product__r.Product_Name__c FROM Digital_Interaction__c WHERE Contact__c=: contactId ';
        String filterSOQL = '';
        
        List<disDataTableWrapper> response = new List<disDataTableWrapper>();
        if (clickedButton == 'Product By Asset' ) {
            filterSOQL = 'AND (Type__c = \'Equity\' OR Type__c = \'FixedIncome\' OR Type__c = \'Diversified\' OR Type__c = \'Profiled\')';
        } else if (clickedButton == 'Content Consumption' ){
            filterSOQL = ' AND (Type__c = \'ProSpace\' OR Type__c = \'FlashNote\' OR Type__c = \'Video\' OR Type__c = \'FundsFocus\' OR Type__c = \'CarmignacNote\' OR Type__c = \'ProSpace\')';
        } else if (clickedButton == 'Marketing Activity' ){
            filterSOQL = ' AND (Type__c = \'Webinar\' OR Type__c = \'Event\' OR Type__c = \'Email\')';
        }
        
        query = query + filterSOQL;
        List<Digital_Interaction__c> lstDis = Database.query(query);

        for (Digital_Interaction__c dis : lstDis) {
            disDataTableWrapper wrapper = new disDataTableWrapper();
            wrapper.diId = dis.Id;
            wrapper.contentItemName = dis.Content_Item_Name__c;
            wrapper.productUrl = '/'+dis.Product__r?.Id;
            wrapper.product = dis.Product__r?.Product_Name__c;
            wrapper.url = dis.URL__c;
            wrapper.createdDate = dis.Date_of_Interaction__c.format('yyyy-MM-dd\' \'HH:mm:ss');
            response.add(wrapper);
        }
        
        return response;
    }

    global class disDataTableWrapper implements Comparable {
        @AuraEnabled
        public Id diId {get;set;}
        @AuraEnabled
        public String contentItemName {get;set;}
        @AuraEnabled
        public String productUrl {get;set;}
        @AuraEnabled
        public String url {get;set;}
        @AuraEnabled
        public String product {get;set;}
        @AuraEnabled
        public String createdDate {get;set;}

        public Integer compareTo(Object compareTo) {
            disDataTableWrapper jobsWrapper = (disDataTableWrapper) compareTo;
            if (createdDate > jobsWrapper.createdDate) return 0;
            if (createdDate < jobsWrapper.createdDate) return 1;
            return -1;   
        }
    }
}