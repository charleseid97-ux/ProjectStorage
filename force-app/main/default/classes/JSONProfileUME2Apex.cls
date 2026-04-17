public class JSONProfileUME2Apex {

    public class Address_components {
        public String long_name;
        public String short_name;
        public List<String> types;
    }

    public class Geometry {
        public Bounds bounds;
        public Northeast location;
        public String location_type;
        public Bounds viewport;
    }

    public class GoogleAddress {
        public List<Address_components> address_components;
        public String formatted_address;
        public Geometry geometry;
        public String place_id;
        public List<String> types;
    }

    public class Bounds {
        public Northeast northeast;
        public Northeast southwest;
    }

    public class Country {
        public String name;
        public String code;
    }

    public String guid;
    public String lei;
    public String status;
    public String companyName;
    public String companyType;
    public Country country;
    public String streetAddress;
    public GoogleAddress googleAddress;
    public Double lat;
    public Double lon;
    public Profile profile;
    public String internalId;

    public class Profile {
    }

    public class Northeast {
        public String lat;
        public String lng;
    }

    
    public static JSONProfileUME2Apex parse(String json) {
        return (JSONProfileUME2Apex) System.JSON.deserialize(json, JSONProfileUME2Apex.class);
    }
}