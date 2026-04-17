public with sharing class LookupController {
    /* 
     *   Single Select Lookup
     */
    @AuraEnabled(cacheable=true)
    public static List<SObject> findContacts(String searchKey, String objectApiName, String keyField) {

        System.debug('searchKey: ' + searchKey);
        List<SObject> records =  new List<SObject>();
        if(String.isEmpty(searchKey)) {
            return records;
        }
        String key = '%' + searchKey + '%';
        String soqlTemplate = 'SELECT Id, {0} FROM {1} WHERE {0} LIKE \'\'{2}\'\' ORDER BY {0} LIMIT 10';
        String soql = String.format(soqlTemplate, new List<String> {keyField, objectApiName, key});
        System.debug('soql: ' + soql);
        records = Database.query(soql);
        System.debug('records: ' + records);
        return records;
    }

    /* 
     *   Multi Select Lookup
     */
    //This method retrieves the data from database table. It search input is '*', then retrieve all records
    @AuraEnabled (cacheable=true)
    public static List<SObjectQueryResult> retrieveRecords(String objectName, 
                                                    String fieldAPINames,
                                                    String filterFieldAPIName,
                                                    String strInput){
        
        List<SObjectQueryResult> lstReturnResult = new List<SObjectQueryResult>();
        if(strInput.equals('*')){
            strInput = '';
        }
        String str = strInput + '%';
        String strQueryField = '';
        List<String> fieldList = fieldAPINames.split(',');

        //check if Id is already been passed
        if(!fieldList.contains('Id')){
            fieldList.add('Id');
            strQueryField = String.join(fieldList, ',');
        }else {
            strQueryField = fieldAPINames;
        }

        String strQuery = 'SELECT ' + String.escapeSingleQuotes(strQueryField) 
                        + ' FROM ' 
                        + String.escapeSingleQuotes(objectName) 
                        + ' WHERE ' + filterFieldAPIName + '  LIKE \'' + str + '%\''
                        + ' ORDER BY ' + filterFieldAPIName
                        + ' LIMIT 50';
                        
        System.debug('strQuery=' + strQuery);

        List<SObject> lstResult = database.query(strQuery);
        //create list of records that can be easily be parsable at js controller.
        for(String strField:fieldList){
            for(SObject sobj:lstResult){                
                if(strField != 'Id'){
                    SObjectQueryResult result = new SObjectQueryResult();
                    result.recordId = (String) sobj.get('Id');
                    result.recordName = (String) sobj.get(strField);
                    lstReturnResult.add(result);
                }                
            }
        }
        return lstReturnResult;
    }
    
    public class SObjectQueryResult {
        @AuraEnabled
        public String recordId;

        @AuraEnabled
        public String recordName;
    }
}