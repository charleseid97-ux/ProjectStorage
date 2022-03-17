public class JSONGeneratorChecker {
    
    public static void writeStringField(JSONGenerator gen, String fieldName, String fieldValue) {
        if(String.isEmpty(fieldValue)) {
            //gen.writeNullField(fieldName); // NULL OR WRITESTRINGFIELD "".
            gen.writeStringField(fieldName, '');
        } else {
            gen.writeStringField(fieldName, fieldValue);
        }
    }
    
}