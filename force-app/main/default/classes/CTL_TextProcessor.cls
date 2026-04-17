public without sharing class CTL_TextProcessor {

    @AuraEnabled
    public static CorrectionResult correctErrors(String inputText) {
        try {
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            // Add 'InputText' parameter with your desired value
            ConnectApi.WrappedValue inputTextValue = new ConnectApi.WrappedValue();
            inputTextValue.value = inputText;
            inputParams.put('Input:InputText', inputTextValue);
            System.debug('Prompt inputTextValue: ' + inputTextValue);

            CorrectionResult promptResp = (CorrectionResult) JSON.deserialize(EinsteinGenerativeGatewayService.generateResponseFromPromptTemplate('Correction_Test', inputParams), CorrectionResult.class);
            System.debug('Prompt Response: ' + promptResp);

            // // Check for empty or null responses
            // if (String.isBlank(promptResp)) {
            //     throw new AuraHandledException('Empty response from EinsteinGenerativeGatewayService');
            // }
            return promptResp;

        } catch (Exception e) {
            System.debug('Error in CTL_TextProcessor: ' + e.getMessage());
            throw new AuraHandledException('An error occurred: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String processRAG(String inputRAG) {
        try {
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            // Add 'InputText' parameter with your desired value
            ConnectApi.WrappedValue inputTextValue = new ConnectApi.WrappedValue();
            inputTextValue.value = inputRAG;
            inputParams.put('Input:User_instructions', inputTextValue);
            System.debug('Prompt inputTextValue: ' + inputTextValue);

            String promptResp = (String) EinsteinGenerativeGatewayService.generateResponseFromPromptTemplate('RAG_Meeting_Note_Search', inputParams);
            System.debug('Prompt Response: ' + promptResp);

            // // Check for empty or null responses
            // if (String.isBlank(promptResp)) {
            //     throw new AuraHandledException('Empty response from EinsteinGenerativeGatewayService');
            // }
            return promptResp;

        } catch (Exception e) {
            System.debug('Error in CTL_TextProcessor: ' + e.getMessage());
            throw new AuraHandledException('An error occurred: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String productOverview(Id strategyId , String period) {
         try {
             
            Map<String, Object> params = new Map<String, Object>();
        	params.put('Product_Id', strategyId);
        	params.put('Last_x_Months', period);

            Flow.Interview.Product_Overview_Positive posFlow = new Flow.Interview.Product_Overview_Positive(params);
            posFlow.start();             
            
            Flow.Interview.Product_Overview_Negative negFlow = new Flow.Interview.Product_Overview_Negative(params);
            negFlow.start();
             
 			Map<String, Object> inputGlobalParams = new Map<String, Object>();
        	inputGlobalParams.put('negative_meetings', (String)negFlow.getvariableValue('output'));
        	inputGlobalParams.put('positive_meetings', (String)posFlow.getvariableValue('output'));

             
 			Flow.Interview.Product_Overview_Global globFlow = new Flow.Interview.Product_Overview_Global(inputGlobalParams);
 			globFlow.start();
            return  (String)globFlow.getvariableValue('output');

         } catch (Exception e) {
             System.debug('Error in CTL_TextProcessor: ' + e.getMessage());
             throw new AuraHandledException('An error occurred: ' + e.getMessage());
         }
    }

    @AuraEnabled(cacheable=false)
    public static String getPositiveResponse(String strategyId, String period, String country) {
        try {

            Map<String, Object> params = new Map<String, Object>();
        	params.put('Product_Id', strategyId);
        	params.put('Last_x_month', period);
            params.put('Country', country);

            Flow.Interview.Product_Overview_Positive posFlow = new Flow.Interview.Product_Overview_Positive(params);
            posFlow.start();     
            String resp =  (String)posFlow.getvariableValue('output');
            System.debug('Prompt Response: ' + resp);
            return resp;
        } catch (Exception e) {
           System.debug('Error in getPositiveResponse: ' + e.getMessage());
           throw new AuraHandledException('An error occurred: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Product__c> getDemoProducts(String statFilter){
        return ([SELECT Id,Name, Product_Name__c, RecordType.Name FROM Product__c WHERE RecordType.Name = 'Strategy' AND Validity__c = true AND Dedicated_Fund__c = False AND Validity__c = True order by Name asc]);
    }

    @AuraEnabled(cacheable=false)
    public static String getNegativeResponse(String strategyId, String period, String country) {
        try {
            

            Map<String, Object> params = new Map<String, Object>();
        	params.put('Product_Id', strategyId);
        	params.put('Last_x_month', period);
        	params.put('Country', country);
            
            Flow.Interview.Product_Overview_Negative negFlow = new Flow.Interview.Product_Overview_Negative(params);
            negFlow.start();
             
            String resp =  (String)negFlow.getvariableValue('output');
            System.debug('Prompt Response: ' + resp);
            return resp;
        } catch (Exception e) {
            System.debug('Error in getNegativeResponse: ' + e.getMessage());
            throw new AuraHandledException('An error occurred: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String getCrossCountryGlobalResponse(String positiveResp, String negativeResp) {
        try {
            Map<String, Object> inputGlobalParams = new Map<String, Object>();
        	inputGlobalParams.put('negative_meetings', negativeResp);
        	inputGlobalParams.put('positive_meetings', positiveResp);
 			Flow.Interview.Product_Overview_Global globFlow = new Flow.Interview.Product_Overview_Global(inputGlobalParams);
 			globFlow.start();
            return  (String)globFlow.getvariableValue('output');
        } catch (Exception e) {
            System.debug('Error in getCrossCountryGlobalResponse: ' + e.getMessage());
            throw new AuraHandledException('An error occurred: ' + e.getMessage());
        }
    }

    // Define a class to hold the error details
    public class ErrorDetail {
        @AuraEnabled
        public String incorrect_word { get; set; }
        @AuraEnabled
        public String corrected_word { get; set; }
        @AuraEnabled
        public Integer position { get; set; }
    }

    // Define a class to map the JSON structure
    public class CorrectionResult {
        @AuraEnabled
        public String corrected_text_with_errors { get; set; }
        @AuraEnabled
        public String corrected_text { get; set; }
        @AuraEnabled
        public List<ErrorDetail> errors { get; set; }
        @AuraEnabled
        public Integer number_of_errors { get; set; }
    }
}