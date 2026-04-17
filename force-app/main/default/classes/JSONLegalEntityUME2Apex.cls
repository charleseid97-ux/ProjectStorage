public class JSONLegalEntityUME2Apex {
    
    public class PhoneNumbers {
        public String numberType {get;set;} 
        public String phoneNo {get;set;} 
        
        public PhoneNumbers(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'numberType') {
                            numberType = parser.getText();
                        } else if (text == 'phoneNo') {
                            phoneNo = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'PhoneNumbers consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class GoogleAddress {
        public List<Address_components> address_components {get;set;} 
        public String formatted_address {get;set;} 
        public Geometry geometry {get;set;} 
        public String place_id {get;set;} 
        public Plus_code plus_code {get;set;} 
        public List<String> types {get;set;} 
        
        public GoogleAddress(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'address_components') {
                            address_components = arrayOfAddress_components(parser);
                        } else if (text == 'formatted_address') {
                            formatted_address = parser.getText();
                        } else if (text == 'geometry') {
                            geometry = new Geometry(parser);
                        } else if (text == 'place_id') {
                            place_id = parser.getText();
                        } else if (text == 'plus_code') {
                            plus_code = new Plus_code(parser);
                        } else if (text == 'types') {
                            types = arrayOfString(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'GoogleAddress consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Company {
        public String guid {get;set;} 
        public String lei {get;set;} 
        public String status {get;set;} 
        public Boolean isBranch {get;set;} 
        public String companyName {get;set;} 
        public String companyType {get;set;} 
        public Country country {get;set;} 
        public String streetAddress {get;set;} 
        public GoogleAddress googleAddress {get;set;} 
        public Double lat {get;set;} 
        public Double lon {get;set;} 
        public String website {get;set;} 
        public Profile profile {get;set;} 
        
        public Company(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'guid') {
                            guid = parser.getText();
                        } else if (text == 'lei') {
                            lei = parser.getText();
                        } else if (text == 'status') {
                            status = parser.getText();
                        } else if (text == 'isBranch') {
                            isBranch = parser.getBooleanValue();
                        } else if (text == 'companyName') {
                            companyName = parser.getText();
                        } else if (text == 'companyType') {
                            companyType = parser.getText();
                        } else if (text == 'country') {
                            country = new Country(parser);
                        } else if (text == 'streetAddress') {
                            streetAddress = parser.getText();
                        } else if (text == 'googleAddress') {
                            googleAddress = new GoogleAddress(parser);
                        } else if (text == 'lat') {
                            lat = parser.getDoubleValue();
                        } else if (text == 'lon') {
                            lon = parser.getDoubleValue();
                        } else if (text == 'website') {
                            website = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Company consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class QuestionnaireExpirationInfo {
        public String questStatus {get;set;} 
        public String ddqSubmitted {get;set;} 
        public String questExpirationDate {get;set;} 
        
        public QuestionnaireExpirationInfo(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'questStatus') {
                            questStatus = parser.getText();
                        } else if (text == 'ddqSubmitted') {
                            ddqSubmitted = parser.getText();
                        } else if (text == 'questExpirationDate') {
                            questExpirationDate = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'QuestionnaireExpirationInfo consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Resource {
        public String type {get;set;} // in json: type
        public String guid {get;set;} 
        
        public Resource(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'type') {
                            type = parser.getText();
                        } else if (text == 'guid') {
                            guid = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Resource consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class UmeRequest {
        public String guid {get;set;} 
        public String submissionDate {get;set;} 
        public Resource resource {get;set;} 
        public String requestStatus {get;set;}
        public String answerDate {get;set;} 
        public String status {get;set;} 
        public Contact answerUser {get;set;} 
        public Boolean notCancellable {get;set;} 
        
        public UmeRequest(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'guid') {
                            guid = parser.getText();
                        } else if (text == 'submissionDate') {
                            submissionDate = parser.getText();
                        } else if (text == 'resource') {
                            resource = new Resource(parser);
                        } else if (text == 'requestStatus') {
                            requestStatus = parser.getText();
                        } else if (text == 'answerDate') {
                            answerDate = parser.getText();
                        } else if (text == 'status') {
                            status = parser.getText();
                        } else if (text == 'answerUser') {
                            answerUser = new Contact(parser);
                        } else if (text == 'notCancellable') {
                            notCancellable = parser.getBooleanValue();
                        } else {
                            System.debug(LoggingLevel.WARN, 'UmeRequest consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Viewport {
        public Location northeast {get;set;} 
        public Location southwest {get;set;} 
        
        public Viewport(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'northeast') {
                            northeast = new Location(parser);
                        } else if (text == 'southwest') {
                            southwest = new Location(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Viewport consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }   
    
    public class Scoring {
        public List<Double> sectionScores {get;set;} 
        public Double baseScore {get;set;} 
        public Double countryRiskFactor {get;set;} 
        public Double totalScore {get;set;} 
        public Integer nShowStoppers {get;set;} 
        public QuestionnaireExpirationInfo questionnaireExpirationInfo {get;set;} 
        public QuestionaryDescriptor questionaryDescriptor {get;set;} 
        
        public Scoring(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'sectionScores') {
                            sectionScores = arrayOfDouble(parser);
                        } else if (text == 'baseScore') {
                            baseScore = parser.getDoubleValue();
                        } else if (text == 'countryRiskFactor') {
                            countryRiskFactor = parser.getDoubleValue();
                        } else if (text == 'totalScore') {
                            totalScore = parser.getDoubleValue();
                        } else if (text == 'nShowStoppers') {
                            nShowStoppers = parser.getIntegerValue();
                        } else if (text == 'questionnaireExpirationInfo') {
                            questionnaireExpirationInfo = new QuestionnaireExpirationInfo(parser);
                        } else if (text == 'questionaryDescriptor') {
                            questionaryDescriptor = new QuestionaryDescriptor(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Scoring consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Contact {
        public String guid {get;set;} 
        public String firstName {get;set;} 
        public String lastName {get;set;} 
        public String email {get;set;} 
        public List<PhoneNumbers> phoneNumbers {get;set;} 
        public Integer userStatus {get;set;} 
        
        public Contact(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'guid') {
                            guid = parser.getText();
                        } else if (text == 'firstName') {
                            firstName = parser.getText();
                        } else if (text == 'lastName') {
                            lastName = parser.getText();
                        } else if (text == 'email') {
                            email = parser.getText();
                        } else if (text == 'phoneNumbers') {
                            phoneNumbers = arrayOfPhoneNumbers(parser);
                        } else if (text == 'userStatus') {
                            userStatus = parser.getIntegerValue();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Contact consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Address_components {
        public String long_name {get;set;} 
        public String short_name {get;set;} 
        public List<String> types {get;set;} 
        
        public Address_components(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'long_name') {
                            long_name = parser.getText();
                        } else if (text == 'short_name') {
                            short_name = parser.getText();
                        } else if (text == 'types') {
                            types = arrayOfString(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Address_components consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    public class Northeast {
        public String lat {get;set;} 
        public String lng {get;set;} 
        
        public Northeast(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'lat') {
                            lat = parser.getText();
                        } else if (text == 'lng') {
                            lng = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Northeast consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    public class Bounds {
        public Northeast northeast {get;set;} 
        public Northeast southwest {get;set;} 
        
        public Bounds(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'northeast') {
                            northeast = new Northeast(parser);
                        } else if (text == 'southwest') {
                            southwest = new Northeast(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Bounds consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Geometry {
        public Bounds bounds {get;set;} 
        public Northeast location {get;set;} 
        public String location_type {get;set;} 
        public Bounds viewport {get;set;} 
        
        public Geometry(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'bounds') {
                            bounds = new Bounds(parser);
                        } else if (text == 'location') {
                            location = new Northeast(parser);
                        } else if (text == 'location_type') {
                            location_type = parser.getText();
                        } else if (text == 'viewport') {
                            viewport = new Bounds(parser);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Geometry consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Plus_code {
        public String compound_code {get;set;} 
        public String global_code {get;set;} 
        
        public Plus_code(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'compound_code') {
                            compound_code = parser.getText();
                        } else if (text == 'global_code') {
                            global_code = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Plus_code consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public String networkIndex {get;set;} 
    public Company company {get;set;} 
    public Contact contact {get;set;} 
    public Scoring scoring {get;set;} 
    public Double pctAnswered {get;set;} 
    public Double pctValidated {get;set;} 
    public String status {get;set;} 
    public UmeRequest umeRequest {get;set;} 
    public String nNonansweredFollowups {get;set;} 
    public String brid {get;set;} 
    public List<Address_components> address_components {get;set;}
    public GoogleAddress googleAddress {get;set;} 
    
    public JSONLegalEntityUME2Apex(JSONParser parser) {
        while (parser.nextToken() != System.JSONToken.END_OBJECT) {
            if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                String text = parser.getText();
                if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                    if (text == 'networkIndex') {
                        networkIndex = parser.getText();
                    } else if (text == 'company') {
                        company = new Company(parser);
                    } else if (text == 'contact') {
                        contact = new Contact(parser);
                    } else if (text == 'scoring') {
                        scoring = new Scoring(parser);
                    } else if (text == 'pctAnswered') {
                        pctAnswered = parser.getDoubleValue();
                    } else if (text == 'pctValidated') {
                        pctValidated = parser.getDoubleValue();
                    } else if (text == 'status') {
                        status = parser.getText();
                    } else if (text == 'umeRequest') {
                        umeRequest = new UmeRequest(parser);
                    } else if (text == 'nNonansweredFollowups') {
                        nNonansweredFollowups = parser.getText();
                    } else if (text == 'brid') {
                        brid = parser.getText();
                    } else {
                        System.debug(LoggingLevel.WARN, 'JSONLegalEntityUME2Apex consuming unrecognized property: '+text);
                        consumeObject(parser);
                    }
                }
            }
        }
    }
    
    public class Country {
        public String name {get;set;} 
        public String code {get;set;} 
        
        public Country(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'name') {
                            name = parser.getText();
                        } else if (text == 'code') {
                            code = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Country consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class QuestionaryDescriptor {
        public String guid {get;set;} 
        public String status {get;set;} 
        public String timestamp {get;set;} 
        
        public QuestionaryDescriptor(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'guid') {
                            guid = parser.getText();
                        } else if (text == 'status') {
                            status = parser.getText();
                        } else if (text == 'timestamp') {
                            timestamp = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'QuestionaryDescriptor consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Location {
        public String lat {get;set;} 
        public String lng {get;set;} 
        
        public Location(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == 'lat') {
                            lat = parser.getText();
                        } else if (text == 'lng') {
                            lng = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Location consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    
    public static JSONLegalEntityUME2Apex parse(String json) {
        System.JSONParser parser = System.JSON.createParser(json);
        return new JSONLegalEntityUME2Apex(parser);
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
    
    private static List<Double> arrayOfDouble(System.JSONParser p) {
        List<Double> res = new List<Double>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(p.getDoubleValue());
        }
        return res;
    }
    
    private static List<String> arrayOfString(System.JSONParser p) {
        List<String> res = new List<String>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(p.getText());
        }
        return res;
    }
    
    private static List<PhoneNumbers> arrayOfPhoneNumbers(System.JSONParser p) {
        List<PhoneNumbers> res = new List<PhoneNumbers>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new PhoneNumbers(p));
        }
        return res;
    }
    
    private static List<Address_components> arrayOfAddress_components(System.JSONParser p) {
        List<Address_components> res = new List<Address_components>();
        if (p.getCurrentToken() == null) p.nextToken();
        while (p.nextToken() != System.JSONToken.END_ARRAY) {
            res.add(new Address_components(p));
        }
        return res;
    }
    
    public class Bdc826bd_2e55_4be5_ab4e_e3aa0314656f {
        public String x_ins {get;set;} // in json: _ins
        
        public Bdc826bd_2e55_4be5_ab4e_e3aa0314656f(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == '_ins') {
                            x_ins = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Bdc826bd_2e55_4be5_ab4e_e3aa0314656f consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class d4bbe86e9_1df4_4471_8531_b174de3d2ce7 {
        public String x_adv {get;set;} // in json: _adv
        public String x_exe_ord_beh_cli {get;set;} // in json: _exe_ord_beh_cli
        
        public d4bbe86e9_1df4_4471_8531_b174de3d2ce7(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == '_adv') {
                            x_adv = parser.getText();
                        } else if (text == '_exe_ord_beh_cli') {
                            x_exe_ord_beh_cli = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, '4bbe86e9_1df4_4471_8531_b174de3d2ce7 consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class d75ecbd38_c059_426d_9e8a_39abb36c6528 {
        public String x_0 {get;set;} // in json: _0
        public String x_2 {get;set;} // in json: _2
        public String x_3 {get;set;} // in json: _3
        public String x_4 {get;set;} // in json: _4
        
        public d75ecbd38_c059_426d_9e8a_39abb36c6528(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == '_0') {
                            x_0 = parser.getText();
                        } else if (text == '_2') {
                            x_2 = parser.getText();
                        } else if (text == '_3') {
                            x_3 = parser.getText();
                        } else if (text == '_4') {
                            x_4 = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, '75ecbd38_c059_426d_9e8a_39abb36c6528 consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class C32faa86_952c_4ba0_bb74_7a0bca2ad21e {
        public String x_lat_ame {get;set;} // in json: _lat_ame
        
        public C32faa86_952c_4ba0_bb74_7a0bca2ad21e(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == '_lat_ame') {
                            x_lat_ame = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'C32faa86_952c_4ba0_bb74_7a0bca2ad21e consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class Profile {
        public String x_8bc829c9_e788_4782_a933_4db29b6f51df {get;set;} // in json: _8bc829c9_e788_4782_a933_4db29b6f51df
        public String x_6621f5ed_b5d7_4cb8_aa0c_715bc271f01d {get;set;} // in json: _6621f5ed_b5d7_4cb8_aa0c_715bc271f01d
        public String x_9b7613d5_8cdb_4ac4_bf1f_ef784e638543 {get;set;} // in json: _9b7613d5_8cdb_4ac4_bf1f_ef784e638543
        public String x_02d82ac6_9e4a_4468_80b4_bed0f773c5ab {get;set;} // in json: _02d82ac6_9e4a_4468_80b4_bed0f773c5ab
        public String x_02556f51_9701_458b_a536_f8c8251fe0be {get;set;} // in json: _02556f51_9701_458b_a536_f8c8251fe0be
        public d4bbe86e9_1df4_4471_8531_b174de3d2ce7 x_4bbe86e9_1df4_4471_8531_b174de3d2ce7 {get;set;} // in json: _4bbe86e9_1df4_4471_8531_b174de3d2ce7
        public d476f96c5_25d0_4e29_bf92_aeaafcdec78c x_476f96c5_25d0_4e29_bf92_aeaafcdec78c {get;set;} // in json: _476f96c5_25d0_4e29_bf92_aeaafcdec78c
        public d7cce5b98_2673_416a_9b64_9d805d6fd302 x_7cce5b98_2673_416a_9b64_9d805d6fd302 {get;set;} // in json: _7cce5b98_2673_416a_9b64_9d805d6fd302
        public String x_6a831ddf_34be_4174_80f5_26b6cb20fb26 {get;set;} // in json: _6a831ddf_34be_4174_80f5_26b6cb20fb26
        public String x_dbb71b06_e991_47de_a238_5daaec813188 {get;set;} // in json: _dbb71b06_e991_47de_a238_5daaec813188
        public d75ecbd38_c059_426d_9e8a_39abb36c6528 x_75ecbd38_c059_426d_9e8a_39abb36c6528 {get;set;} // in json: _75ecbd38_c059_426d_9e8a_39abb36c6528
        public String x_c1826731_b118_46f4_bfab_a9b15f57f851 {get;set;} // in json: _c1826731_b118_46f4_bfab_a9b15f57f851
        public String x_f97cf9df_91f0_47c0_8e46_e599df3c240f {get;set;} // in json: _f97cf9df_91f0_47c0_8e46_e599df3c240f
        public C32faa86_952c_4ba0_bb74_7a0bca2ad21e x_c32faa86_952c_4ba0_bb74_7a0bca2ad21e {get;set;} // in json: _c32faa86_952c_4ba0_bb74_7a0bca2ad21e
        public C32faa86_952c_4ba0_bb74_7a0bca2ad21e x_7a2340fb_1f4f_4561_9219_2480eb6b0173 {get;set;} // in json: _7a2340fb_1f4f_4561_9219_2480eb6b0173
        public Bdc826bd_2e55_4be5_ab4e_e3aa0314656f x_bdc826bd_2e55_4be5_ab4e_e3aa0314656f {get;set;} // in json: _bdc826bd_2e55_4be5_ab4e_e3aa0314656f
        public String x_130fb1b7_e74e_40aa_8bdd_3c1f4d04cdfa {get;set;} // in json: _130fb1b7_e74e_40aa_8bdd_3c1f4d04cdfa
        public String x_5c04a549_1c88_454a_ba3d_af1b25768f5f {get;set;} // in json: _5c04a549_1c88_454a_ba3d_af1b25768f5f
        public String x_0b8b1aba_4e43_4389_a138_31f598d4f028 {get;set;} // in json: _0b8b1aba_4e43_4389_a138_31f598d4f028
        public String x_223a67a3_358d_4824_800b_b7a60198cec0 {get;set;} // in json: _223a67a3_358d_4824_800b_b7a60198cec0
        
        public Profile(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == '_8bc829c9_e788_4782_a933_4db29b6f51df') {
                            x_8bc829c9_e788_4782_a933_4db29b6f51df = parser.getText();
                        } else if (text == '_6621f5ed_b5d7_4cb8_aa0c_715bc271f01d') {
                            x_6621f5ed_b5d7_4cb8_aa0c_715bc271f01d = parser.getText();
                        } else if (text == '_9b7613d5_8cdb_4ac4_bf1f_ef784e638543') {
                            x_9b7613d5_8cdb_4ac4_bf1f_ef784e638543 = parser.getText();
                        } else if (text == '_02d82ac6_9e4a_4468_80b4_bed0f773c5ab') {
                            x_02d82ac6_9e4a_4468_80b4_bed0f773c5ab = parser.getText();
                        } else if (text == '_02556f51_9701_458b_a536_f8c8251fe0be') {
                            x_02556f51_9701_458b_a536_f8c8251fe0be = parser.getText();
                        } else if (text == '_4bbe86e9_1df4_4471_8531_b174de3d2ce7') {
                            x_4bbe86e9_1df4_4471_8531_b174de3d2ce7 = new d4bbe86e9_1df4_4471_8531_b174de3d2ce7(parser);
                        } else if (text == '_476f96c5_25d0_4e29_bf92_aeaafcdec78c') {
                            x_476f96c5_25d0_4e29_bf92_aeaafcdec78c = new d476f96c5_25d0_4e29_bf92_aeaafcdec78c(parser);
                        } else if (text == '_7cce5b98_2673_416a_9b64_9d805d6fd302') {
                            x_7cce5b98_2673_416a_9b64_9d805d6fd302 = new d7cce5b98_2673_416a_9b64_9d805d6fd302(parser);
                        } else if (text == '_6a831ddf_34be_4174_80f5_26b6cb20fb26') {
                            x_6a831ddf_34be_4174_80f5_26b6cb20fb26 = parser.getText();
                        } else if (text == '_dbb71b06_e991_47de_a238_5daaec813188') {
                            x_dbb71b06_e991_47de_a238_5daaec813188 = parser.getText();
                        } else if (text == '_75ecbd38_c059_426d_9e8a_39abb36c6528') {
                            x_75ecbd38_c059_426d_9e8a_39abb36c6528 = new d75ecbd38_c059_426d_9e8a_39abb36c6528(parser);
                        } else if (text == '_c1826731_b118_46f4_bfab_a9b15f57f851') {
                            x_c1826731_b118_46f4_bfab_a9b15f57f851 = parser.getText();
                        } else if (text == '_f97cf9df_91f0_47c0_8e46_e599df3c240f') {
                            x_f97cf9df_91f0_47c0_8e46_e599df3c240f = parser.getText();
                        } else if (text == '_c32faa86_952c_4ba0_bb74_7a0bca2ad21e') {
                            x_c32faa86_952c_4ba0_bb74_7a0bca2ad21e = new C32faa86_952c_4ba0_bb74_7a0bca2ad21e(parser);
                        } else if (text == '_7a2340fb_1f4f_4561_9219_2480eb6b0173') {
                            x_7a2340fb_1f4f_4561_9219_2480eb6b0173 = new C32faa86_952c_4ba0_bb74_7a0bca2ad21e(parser);
                        } else if (text == '_bdc826bd_2e55_4be5_ab4e_e3aa0314656f') {
                            x_bdc826bd_2e55_4be5_ab4e_e3aa0314656f = new Bdc826bd_2e55_4be5_ab4e_e3aa0314656f(parser);
                        } else if (text == '_130fb1b7_e74e_40aa_8bdd_3c1f4d04cdfa') {
                            x_130fb1b7_e74e_40aa_8bdd_3c1f4d04cdfa = parser.getText();
                        } else if (text == '_5c04a549_1c88_454a_ba3d_af1b25768f5f') {
                            x_5c04a549_1c88_454a_ba3d_af1b25768f5f = parser.getText();
                        } else if (text == '_0b8b1aba_4e43_4389_a138_31f598d4f028') {
                            x_0b8b1aba_4e43_4389_a138_31f598d4f028 = parser.getText();
                        } else if (text == '_223a67a3_358d_4824_800b_b7a60198cec0') {
                            x_223a67a3_358d_4824_800b_b7a60198cec0 = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, 'Profile consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class d476f96c5_25d0_4e29_bf92_aeaafcdec78c {
        public String x_fin_adv {get;set;} // in json: _fin_adv
        public String x_wea_man {get;set;} // in json: _wea_man
        public String x_ret_pri_ban {get;set;} // in json: _ret_pri_ban
        
        public d476f96c5_25d0_4e29_bf92_aeaafcdec78c(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == '_fin_adv') {
                            x_fin_adv = parser.getText();
                        } else if (text == '_wea_man') {
                            x_wea_man = parser.getText();
                        } else if (text == '_ret_pri_ban') {
                            x_ret_pri_ban = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, '476f96c5_25d0_4e29_bf92_aeaafcdec78c consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
    
    public class d7cce5b98_2673_416a_9b64_9d805d6fd302 {
        public String x_ban_off_bas {get;set;} // in json: _ban_off_bas
        
        public d7cce5b98_2673_416a_9b64_9d805d6fd302(JSONParser parser) {
            while (parser.nextToken() != System.JSONToken.END_OBJECT) {
                if (parser.getCurrentToken() == System.JSONToken.FIELD_NAME) {
                    String text = parser.getText();
                    if (parser.nextToken() != System.JSONToken.VALUE_NULL) {
                        if (text == '_ban_off_bas') {
                            x_ban_off_bas = parser.getText();
                        } else {
                            System.debug(LoggingLevel.WARN, '7cce5b98_2673_416a_9b64_9d805d6fd302 consuming unrecognized property: '+text);
                            consumeObject(parser);
                        }
                    }
                }
            }
        }
    }
}