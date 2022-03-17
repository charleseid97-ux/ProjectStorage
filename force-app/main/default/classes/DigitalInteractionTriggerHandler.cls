public class DigitalInteractionTriggerHandler {
    
    public static void beforeInsert(List<Digital_Interaction__c> DigitalInteractions) {
        
        Map<String, Id> diRtMap = RecordTypeUtil.GetRecordTypeIdsByDeveloperName(Digital_Interaction__c.SObjectType);
        Map<String, Id> productIdMap = new Map<String, Id>();
        for(Product__c p : [SELECT Product_Name__c , Id FROM Product__c WHERE Validity__c = true]) {
            productIdMap.put(p.Product_Name__c.toLowerCase() , p.Id);
        }
        
        for(Digital_Interaction__c di : DigitalInteractions) {
            String rtName = getRecordTypeName(di.Type__c);
            di.recordTypeId = diRtMap.get(rtName);
            
            if(rtName == 'Product_Interests') {
                di.Product__c = productIdMap.get(getProductNameFromURL(di.URL__c));
            }
            // ATA 15/07/2020
            if ( di.Contact__c != null){
                Id contactOrLeadId = di.Contact__c;
                String objectName = contactOrLeadId.getSObjectType().getDescribe().getName();
                if ( objectName == 'Lead' && di.Lead_lu__c == null)
                    di.Lead_lu__c = di.Contact__c;
                else if ( objectName == 'Contact' && di.Contact_lu__c == null)
                    di.Contact_lu__c = di.Contact__c;
            }
            di.Thematic__c = getThematicFromURL(di.URL__c);
            
        }
    }
    
    static String getRecordTypeName(String diType) {
        String rtName = '';
        if(diType == 'QuarterlyReport' || diType == 'FlashNote' || diType == 'CarmignacNote' || 
           diType == 'Video' || diType == 'FundsFocus' || diType == 'ProSpace') {
               rtName = 'Content_Consumption';
           } else if(diType == 'Email' || diType == 'Event' || diType == 'Webinar') {
               rtName = 'Marketing_Activity';
           } else{
               rtName = 'Product_Interests';
           }
        
        return rtName;
    } 
    
    static String getProductNameFromURL(String URL) {
        /*
        Map<String, String> URLFundNameSearchValMap = new Map<String, String>{'en_GB' => 'funds', 'it_IT' => 'fundi'};
        String subURL = URL.substring(URL.indexOf('carmignac'), URL.length());
        String cCode = subURL.substring(subURL.indexOf('/')+1, subURL.indexOf('/')+6);
        String FundNameSearchVal = URLFundNameSearchValMap.get(cCode);
        */
        URL = URL.replaceAll('/fondi/', '/funds/').replaceAll('/fonds/', '/funds/').replaceAll('/fondsangebot/', '/funds/');
        String fundNameSearchVal = '/funds/';
        Integer fundIndex = URL.indexOf(fundNameSearchVal);
        if(fundIndex != -1) {
            String productToEnd = URL.subString(fundIndex + fundNameSearchVal.length(), URL.length());
            Integer fundIndexEnd = productToEnd.indexOf('/') != -1 ? productToEnd.indexOf('/') : productToEnd.length();
            
            return productToEnd.substring(0, fundIndexEnd).replaceAll('-', ' ');
        } else {
            return '';
        }       
    }
    
    static List<Thematic__mdt> lstThematic = [SELECT Thematic__c,Thematic_values__c FROM Thematic__mdt];
    static String getThematicFromURL(String URL) {
        
        List<String> lstURL = URL.split('/');
        Map<String, String> mapThematics = new Map<String, String>();
        
        for (Thematic__mdt Item : lstThematic ) {
            mapThematics.put(Item.Thematic__c, Item.Thematic_values__c);
        }
        
        for (String thematic : mapThematics.keySet()) {
            List<String> lstValuesThematic = mapThematics.get(thematic).split(';');
            if(containsAny(lstURL, lstValuesThematic))
                return thematic;
                
        }
        return 'N/A';
    }
    
    public static boolean containsAny(List<String> lstURL, List<String> values) {
        for (String i : values) {
            for ( String j : lstURL)
                if (j.contains(i))
                    return true;
        }
        return false;
    }
}