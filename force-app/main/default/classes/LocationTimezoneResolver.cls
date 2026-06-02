public without sharing class LocationTimezoneResolver {
    
    public class Result {
        public String inputCountry;
        public String inputCity;
        public String normalizedCountry;
        public String normalizedCity;
        public String timezoneId;
        public String gmtOffsetNow;
        public String matchedBy;
        
        // Retourne le résultat sous forme JSON lisible
        public override String toString() {
            return JSON.serializePretty(this);
        }
    }

    // Résout la timezone à partir du pays et de la ville
    public static Result resolve(String country, String city) {
        String normCountry = normalize(country);
        String normCity = normalize(city);

        Result r = new Result();
        r.inputCountry = country;
        r.inputCity = city;
        r.normalizedCountry = normCountry;
        r.normalizedCity = normCity;

        String timezoneId;
        String matchedBy;

        // Cherche d'abord une timezone spécifique à la ville
        if (!String.isBlank(normCity)) {
            timezoneId = getCityTimezone(normCountry, normCity);
            if (timezoneId != null) {
                matchedBy = 'city';
            }
        }

        // Si aucune ville ne correspond, utilise la timezone par défaut du pays
        if (timezoneId == null && !String.isBlank(normCountry)) {
            timezoneId = getDefaultCountryTimezone(normCountry);
            if (timezoneId != null) {
                matchedBy = 'country';
            }
        }

        r.timezoneId = timezoneId;
        r.matchedBy = matchedBy;

        // Calcule l'offset GMT actuel uniquement si une timezone est trouvée
        if (timezoneId != null) {
            TimeZone tz = TimeZone.getTimeZone(timezoneId);
            Integer offsetMs = tz.getOffset(Datetime.now());
            r.gmtOffsetNow = formatOffset(offsetMs);
        }

        return r;
    }

    // Cherche une timezone spécifique pour une ville dans le custom metadata
    private static String getCityTimezone(String normCountry, String normCity) {
        for (TimezoneMapping__mdt cfg : getMappings()) {
            if (
                !String.isBlank(cfg.Cities__c) &&
                !String.isBlank(cfg.IANATimezone__c) &&
                (String.isBlank(normCountry) || normalize(cfg.Country__c) == normCountry)
            ) {
                if (containsCity(cfg.Cities__c, normCity)) {
                    return cfg.IANATimezone__c;
                }
            }
        }

        return null;
    }

    // Cherche la timezone par défaut du pays dans le custom metadata
    private static String getDefaultCountryTimezone(String normCountry) {
        for (TimezoneMapping__mdt cfg : getMappings()) {
            if (
                cfg.IsDefault__c == true &&
                !String.isBlank(cfg.Country__c) &&
                !String.isBlank(cfg.IANATimezone__c) &&
                normalize(cfg.Country__c) == normCountry
            ) {
                return cfg.IANATimezone__c;
            }
        }

        return null;
    }

    // Vérifie si la ville est présente dans la liste Cities__c
    private static Boolean containsCity(String cities, String normCity) {
        if (String.isBlank(cities) || String.isBlank(normCity)) return false;

        // Supporte les villes séparées par ; ou ,
        for (String cityValue : cities.replace(',', ';').split(';')) {
            if (normalize(cityValue) == normCity) {
                return true;
            }
        }

        return false;
    }

    // Charge les mappings depuis le custom metadata
    private static List<TimezoneMapping__mdt> getMappings() {
        return [
            SELECT
                Cities__c,
                Country__c,
                IANATimezone__c,
                IsDefault__c
            FROM TimezoneMapping__mdt
        ];
    }

    // Normalise les valeurs pays/ville pour fiabiliser la comparaison
    private static String normalize(String s) {
        if (String.isBlank(s)) return null;

        String x = s.trim().toLowerCase();

        Map<String, String> repl = new Map<String, String>();
        repl.put('à','a'); repl.put('á','a'); repl.put('â','a'); repl.put('ä','a'); repl.put('ã','a'); repl.put('å','a');
        repl.put('ç','c');
        repl.put('è','e'); repl.put('é','e'); repl.put('ê','e'); repl.put('ë','e');
        repl.put('ì','i'); repl.put('í','i'); repl.put('î','i'); repl.put('ï','i');
        repl.put('ñ','n');
        repl.put('ò','o'); repl.put('ó','o'); repl.put('ô','o'); repl.put('ö','o'); repl.put('õ','o');
        repl.put('ù','u'); repl.put('ú','u'); repl.put('û','u'); repl.put('ü','u');
        repl.put('ý','y'); repl.put('ÿ','y');
        repl.put('œ','oe');
        repl.put('æ','ae');
        repl.put('’','\''); 
        repl.put('`','\''); 
        repl.put('´','\'');

        // Remplace les accents et caractères spéciaux connus
        for (String k : repl.keySet()) {
            x = x.replace(k, repl.get(k));
        }

        x = x.replace('-', ' ');
        x = x.replace('_', ' ');
        while (x.contains('  ')) {
            x = x.replace('  ', ' ');
        }

        return x;
    }

    // Formate l'offset timezone en GMT+/-HH:mm
    private static String formatOffset(Integer offsetMs) {
        Integer totalMinutes = offsetMs / (1000 * 60);
        String sign = totalMinutes >= 0 ? '+' : '-';
        Integer absMinutes = Math.abs(totalMinutes);
        Integer hours = absMinutes / 60;
        Integer minutes = Math.mod(absMinutes, 60);

        return 'GMT' + sign +
            String.valueOf(hours).leftPad(2, '0') + ':' +
            String.valueOf(minutes).leftPad(2, '0');
    }
}