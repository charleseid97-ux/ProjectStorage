/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 01-10-2024
 * @last modified by  : SILA Nicolas
**/
public class TextParser {
    @InvocableMethod(label='Search Field Value')
    public static List<OutputParameter> searchFieldValue(List<InputParameter> inputParameters) {
        List<OutputParameter> outputParameters = new List<OutputParameter>();

        String inputText = inputParameters[0].textToParse;
        String fieldName = inputParameters[0].fieldName;

        System.debug('inputText ='+inputText + '/// fieldName'+fieldName);
        // Search for the specified field name in the input text
        String value = findValueByFieldName(inputText, fieldName)?.trim();
        System.debug('value ='+value );

        // Create an output parameter to return information to the Flow
        OutputParameter outputParam = new OutputParameter();
        outputParam.varExtractedValue = value;
        outputParameters.add(outputParam);
        System.debug('outputParameters ='+outputParameters );

        return outputParameters;
    }

    private static String findValueByFieldName(String text, String fieldName) {
        // Implement your searching logic to find the value associated with the specified field name
        // String regexPattern = fieldName + ':\\s*(\\S+)';
        String regexPattern = fieldName + '\\s*:(.*)';
        
        Pattern pattern = Pattern.compile(regexPattern);
        Matcher matcher = pattern.matcher(text);
        System.debug('regexPattern ='+regexPattern + '/// pattern'+pattern);
        System.debug('matcher ='+matcher);
        if (matcher.find()) {
            return matcher.group(1);
        }
        
        return null; // Return null if the field name is not found
    }

    public class InputParameter {
        @InvocableVariable(label='Text to Parse')
        public String textToParse;

        @InvocableVariable(label='Field Name')
        public String fieldName;
    }

    public class OutputParameter {
        @InvocableVariable(label='Extracted Value')
        public String varExtractedValue;
    }
}