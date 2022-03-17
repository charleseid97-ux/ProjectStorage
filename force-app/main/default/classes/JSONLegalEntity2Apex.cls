/**
* @author Abderrahmane TRIA
* @date Creation 07/04/2020
* @group Parser
* @description JSON Parser Legal Entity
*/
public class JSONLegalEntity2Apex {
    
    public class Meta {
        public Pagination pagination {get;set;} 
        
        public Meta(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'pagination') {
                            pagination = new Pagination(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Meta consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Entity {
        public LegalName legalName {get;set;}
        public LegalAddress legalAddress {get;set;} 
        public LegalAddress headquartersAddress {get;set;} 
        public RegisteredAt registeredAt {get;set;} 
        public String registeredAs {get;set;} 
        public String jurisdiction {get;set;} 
        public String category {get;set;} 
        public RegisteredAt legalForm {get;set;} 
        public AssociatedEntity associatedEntity {get;set;} 
        public String status {get;set;} 
        public Expiration expiration {get;set;} 
        public AssociatedEntity successorEntity {get;set;} 
        
        public Entity(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'legalName') {
                            legalName = new LegalName(parser);
                        } else if (text == 'legalAddress') {
                            legalAddress = new LegalAddress(parser);
                        } else if (text == 'headquartersAddress') {
                            headquartersAddress = new LegalAddress(parser);
                        } else if (text == 'registeredAt') {
                            registeredAt = new RegisteredAt(parser);
                        } else if (text == 'registeredAs') {
                            registeredAs = parser.getText();
                        } else if (text == 'jurisdiction') {
                            jurisdiction = parser.getText();
                        } else if (text == 'category') {
                            category = parser.getText();
                        } else if (text == 'legalForm') {
                            legalForm = new RegisteredAt(parser);
                        } else if (text == 'associatedEntity') {
                            associatedEntity = new AssociatedEntity(parser);
                        } else if (text == 'status') {
                            status = parser.getText();
                        } else if (text == 'expiration') {
                            expiration = new Expiration(parser);
                        } else if (text == 'successorEntity') {
                            successorEntity = new AssociatedEntity(parser);
                        //} else if (text == 'otherAddresses') {
                            //otherAddresses = arrayOfOtherNames(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Entity consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class LegalName {
        public String name {get;set;} 
        public String language {get;set;} 
        
        public LegalName(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'name') {
                            name = parser.getText();
                        } else if (text == 'language') {
                            language = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'LegalName consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class AssociatedEntity {
        public String lei {get;set;} 
        public String name {get;set;} 
        
        public AssociatedEntity(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'lei') {
                            lei = parser.getText();
                        } else if (text == 'name') {
                            name = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'AssociatedEntity consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class OtherNames {
        
        public OtherNames(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        {
                            System.debug(LoggingLevel.WARN, 'OtherNames consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Expiration {
        public String datee {get;set;} 
        public String reason {get;set;} 
        
        public Expiration(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'date') {
                            datee = parser.getText();
                        } else if (text == 'reason') {
                            reason = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Expiration consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Attributes {
        public String lei {get;set;} 
        public Entity entity {get;set;} 
        public Registration registration {get;set;} 
        public List<String> bic {get;set;} 
        
        public Attributes(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'lei') {
                            lei = parser.getText();
                        } else if (text == 'entity') {
                            entity = new Entity(parser);
                        } else if (text == 'registration') {
                            registration = new Registration(parser);
                        } else if (text == 'bic') {
                            bic = arrayOfString(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Attributes consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public Meta meta {get;set;} 
    public Links links {get;set;} 
    public List<Data> data {get;set;}
    public Attributes attributes {get;set;}
    
    public JSONLegalEntity2Apex(JSONParser parser) {
        while (parser.nextToken() != System.JSONToken.END_OBJECT) {
            if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                String text = parser.getText();
                if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                    if (text == 'meta') {
                        meta = new Meta(parser);
                    } else if (text == 'links') {
                        links = new Links(parser);
                        //}else if (text == 'data') {
                        //datas = new Data(parser);
                    } else if (text == 'data') {
                        data = arrayOfData(parser);
                    } else {
                        System.debug(LoggingLevel.WARN, 'JSONLegalEntity2Apex consuming unrecognized property: '+text);
                        consumeObject(parser);
                    }
                }
            }
        }
    }
    
    public class Data {
        public String type_Z {get;set;} // in json: type
        public String id {get;set;} 
        public Attributes attributes {get;set;} 
        public Relationships relationships {get;set;} 
        public Links_X links {get;set;} 
        
        public Data(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'type') {
                            type_Z = parser.getText();
                        } else if (text == 'id') {
                            id = parser.getText();
                        } else if (text == 'attributes') {
                            attributes = new Attributes(parser);
                        } else if (text == 'relationships') {
                            relationships = new Relationships(parser);
                        } else if (text == 'links') {
                            links = new Links_X(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Data consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Pagination {
        public Integer currentPage {get;set;} 
        public Integer perPage {get;set;} 
        public Integer from_Z {get;set;} // in json: from
        public Integer to {get;set;} 
        public Integer total {get;set;} 
        public Integer lastPage {get;set;} 
        
        public Pagination(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'currentPage') {
                            currentPage = parser.getIntegerValue();
                        } else if (text == 'perPage') {
                            perPage = parser.getIntegerValue();
                        } else if (text == 'from') {
                            from_Z = parser.getIntegerValue();
                        } else if (text == 'to') {
                            to = parser.getIntegerValue();
                        } else if (text == 'total') {
                            total = parser.getIntegerValue();
                        } else if (text == 'lastPage') {
                            lastPage = parser.getIntegerValue();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Pagination consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Links_Z {
        public String related {get;set;} 
        
        public Links_Z(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'related') {
                            related = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Links_Z consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Managing_lou {
        public Links_Z links {get;set;} 
        
        public Managing_lou(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'links') {
                            links = new Links_Z(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Managing_lou consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Relationships {
        public Managing_lou managing_lou {get;set;} // in json: managing-lou
        public Managing_lou lei_issuer {get;set;} // in json: lei-issuer
        public Direct_parent direct_parent {get;set;} // in json: direct-parent
        public Direct_parent ultimate_parent {get;set;} // in json: ultimate-parent
        
        public Relationships(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'managing-lou') {
                            managing_lou = new Managing_lou(parser);
                        } else if (text == 'lei-issuer') {
                            lei_issuer = new Managing_lou(parser);
                        } else if (text == 'direct-parent') {
                            direct_parent = new Direct_parent(parser);
                        } else if (text == 'ultimate-parent') {
                            ultimate_parent = new Direct_parent(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Relationships consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Links_X {
        public String self {get;set;} 
        
        public Links_X(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'self') {
                            self = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Links_X consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Links_Y {
        public String reporting_exception {get;set;} // in json: reporting-exception
        
        public Links_Y(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'reporting-exception') {
                            reporting_exception = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Links_Y consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Registration {
        public String initialRegistrationDate {get;set;} 
        public String lastUpdateDate {get;set;} 
        public String status {get;set;} 
        public String nextRenewalDate {get;set;} 
        public String managingLou {get;set;} 
        public String corroborationLevel {get;set;} 
        public RegisteredAt validatedAt {get;set;} 
        public String validatedAs {get;set;} 
        
        public Registration(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'initialRegistrationDate') {
                            initialRegistrationDate = parser.getText();
                        } else if (text == 'lastUpdateDate') {
                            lastUpdateDate = parser.getText();
                        } else if (text == 'status') {
                            status = parser.getText();
                        } else if (text == 'nextRenewalDate') {
                            nextRenewalDate = parser.getText();
                        } else if (text == 'managingLou') {
                            managingLou = parser.getText();
                        } else if (text == 'corroborationLevel') {
                            corroborationLevel = parser.getText();
                        } else if (text == 'validatedAt') {
                            validatedAt = new RegisteredAt(parser);
                        } else if (text == 'validatedAs') {
                            validatedAs = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Registration consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Direct_parent {
        public Links_Y links {get;set;} 
        
        public Direct_parent(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'links') {
                            links = new Links_Y(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Direct_parent consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Links {
        public String first {get;set;} 
        public String last {get;set;} 
        
        public Links(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'first') {
                            first = parser.getText();
                        } else if (text == 'last') {
                            last = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Links consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class LegalAddress {
        public String language {get;set;} 
        public List<String> addressLines {get;set;} 
        public String addressNumber {get;set;} 
        public String addressNumberWithinBuilding {get;set;} 
        public String mailRouting {get;set;} 
        public String city {get;set;} 
        public String region {get;set;} 
        public String country {get;set;} 
        public String postalCode {get;set;} 
        
        public LegalAddress(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'language') {
                            language = parser.getText();
                        } else if (text == 'addressLines') {
                            addressLines = arrayOfString(parser);
                        } else if (text == 'addressNumber') {
                            addressNumber = parser.getText();
                        } else if (text == 'addressNumberWithinBuilding') {
                            addressNumberWithinBuilding = parser.getText();
                        } else if (text == 'mailRouting') {
                            mailRouting = parser.getText();
                        } else if (text == 'city') {
                            city = parser.getText();
                        } else if (text == 'region') {
                            region = parser.getText();
                        } else if (text == 'country') {
                            country = parser.getText();
                        } else if (text == 'postalCode') {
                            postalCode = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'LegalAddress consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class RegisteredAt {
        public String id {get;set;} 
        public String other {get;set;} 
        
        public RegisteredAt(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'id') {
                            id = parser.getText();
                        } else if (text == 'other') {
                            other = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'RegisteredAt consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    
    public static JSONLegalEntity2Apex parse(String json) {
        System.JSONParser parser = System.JSON.createParser(json);
        return new JSONLegalEntity2Apex(parser);
    }
    
    public static void consumeObject(System.JSONParser parser) {
        Integer depth = 0;
        do {
            System.JSONToken curr = parser.getCurrentToken();
            if (curr == System.JSONToken.START_OBJECT || 
                curr == System.JSONToken.START_ARRAY) {
                    depth++;
                } else if (curr == System.JSONToken.END_OBJECT ||
                           curr == System.JSONToken.END_ARRAY) {
                               depth--;
                           }
        } while (depth > 0 && parser.nextToken() != null);
    }
    
    private static List<String> arrayOfString(System.JSONParser p) {
        List<String> res = new List<String>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(p.getText());
        }
        return res;
    }
    
    private static List<Data> arrayOfData(System.JSONParser p) {
        List<Data> res = new List<Data>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new Data(p));
        }
        return res;
    }
    
}