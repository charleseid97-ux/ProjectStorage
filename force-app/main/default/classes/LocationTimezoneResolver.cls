public without sharing class LocationTimezoneResolver {
    
    public class Result {
        public String inputCountry;
        public String inputCity;
        public String normalizedCountry;
        public String normalizedCity;
        public String timezoneId;
        public String gmtOffsetNow;
        public String matchedBy;
        
        public override String toString() {
            return JSON.serializePretty(this);
        }
    }

    public static Result resolve(String country, String city) {
        String normCountry = normalize(country);
        String normCity = normalize(city);

        Map<String, String> countryToTimezone = getCountryToTimezone();
        Map<String, String> cityToTimezone = getCityToTimezone();
        Map<String, String> cityToCountry = getCityToCountry();

        Result r = new Result();
        r.inputCountry = country;
        r.inputCity = city;
        r.normalizedCountry = normCountry;
        r.normalizedCity = normCity;

        String timezoneId;
        String matchedBy;

        // 1) country + city
        if (!String.isBlank(normCountry) && !String.isBlank(normCity)) {
            if (cityToTimezone.containsKey(normCity)) {
                String mappedCountry = cityToCountry.get(normCity);
                if (mappedCountry == null || mappedCountry == normCountry) {
                    timezoneId = cityToTimezone.get(normCity);
                    matchedBy = 'city';
                }
            }

            if (timezoneId == null && countryToTimezone.containsKey(normCountry)) {
                timezoneId = countryToTimezone.get(normCountry);
                matchedBy = 'country';
            }
        }
        // 2) city only
        else if (!String.isBlank(normCity)) {
            if (cityToTimezone.containsKey(normCity)) {
                timezoneId = cityToTimezone.get(normCity);
                matchedBy = 'city';
            }
        }
        // 3) country only
        else if (!String.isBlank(normCountry)) {
            if (countryToTimezone.containsKey(normCountry)) {
                timezoneId = countryToTimezone.get(normCountry);
                matchedBy = 'country';
            }
        }

        r.timezoneId = timezoneId;
        r.matchedBy = matchedBy;

        if (timezoneId != null) {
            TimeZone tz = TimeZone.getTimeZone(timezoneId);
            Integer offsetMs = tz.getOffset(Datetime.now());
            r.gmtOffsetNow = formatOffset(offsetMs);
        }

        return r;
    }

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

    private static Map<String, String> getCountryToTimezone() {
        return new Map<String, String>{
            'andorra' => 'Europe/Andorra',
            'austria' => 'Europe/Vienna',
            'belgium' => 'Europe/Brussels',
            'canada' => 'America/Toronto',
            'digital' => 'UTC',
            'france' => 'Europe/Paris',
            'germany' => 'Europe/Berlin',
            'hungary' => 'Europe/Budapest',
            'ireland' => 'Europe/Dublin',
            'italy' => 'Europe/Rome',
            'japan' => 'Asia/Tokyo',
            'latvia' => 'Europe/Riga',
            'lithuania' => 'Europe/Vilnius',
            'luxembourg' => 'Europe/Luxembourg',
            'monaco' => 'Europe/Monaco',
            'netherlands' => 'Europe/Amsterdam',
            'norway' => 'Europe/Oslo',
            'portugal' => 'Europe/Lisbon',
            'singapore' => 'Asia/Singapore',
            'spain' => 'Europe/Madrid',
            'sweden' => 'Europe/Stockholm',
            'switzerland' => 'Europe/Zurich',
            'united arab emirates' => 'Asia/Dubai',
            'united kingdom' => 'Europe/London',
            'uruguay' => 'America/Montevideo'
        };
    }

    private static Map<String, String> getCityToTimezone() {
        Map<String, String> m = new Map<String, String>();

        // UK
        for (String c : new List<String>{
            'Aberdeen','Belfast','Birmingham','Bristol','Cardiff','Edinburgh','Exeter',
            'Glasgow','Guildford','Harrogate','Leeds','Leicester','Liverpool','London',
            'Manchester','Newcastle','Nottingham','Norwich','Southampton','Wakefield',
            'Windsor','Wolverhampton'
        }) m.put(normalize(c), 'Europe/London');

        // Uruguay
        m.put(normalize('Montevideo'), 'America/Montevideo');

        // Canada
        m.put(normalize('Montreal'), 'America/Toronto');
        m.put(normalize('Montreal'), 'America/Toronto');

        // Singapore
        m.put(normalize('Singapore'), 'Asia/Singapore');

        // Digital
        m.put(normalize('Digital'), 'UTC');

        // Japan
        m.put(normalize('Tokyo'), 'Asia/Tokyo');

        // Latvia / Lithuania / Luxembourg / Monaco
        m.put(normalize('Riga'), 'Europe/Riga');
        m.put(normalize('Vilnius'), 'Europe/Vilnius');
        m.put(normalize('Luxembourg City'), 'Europe/Luxembourg');
        m.put(normalize('Monaco'), 'Europe/Monaco');

        // Netherlands / Norway / Portugal / Sweden
        m.put(normalize('Amsterdam'), 'Europe/Amsterdam');
        m.put(normalize('Amstelveen'), 'Europe/Amsterdam');
        m.put(normalize('Oslo'), 'Europe/Oslo');
        m.put(normalize('Lisbon'), 'Europe/Lisbon');
        m.put(normalize('Porto'), 'Europe/Lisbon');
        m.put(normalize('Stockholm'), 'Europe/Stockholm');

        // Spain
        for (String c : new List<String>{
            'Albacete','Alicante','Barcelona','Bilbao','Gijon','Granada','Logroño',
            'Madrid','Malaga','Murcia-Orihuela','Oviedo','Palma','Pamplona',
            'Salamanca','San Sebastian','Santiago','Valencia','Valladolid',
            'Vigo','Zaragoza','Seville'
        }) m.put(normalize(c), 'Europe/Madrid');
        m.put(normalize('Las Palmas'), 'Atlantic/Canary');

        // Andorra
        m.put(normalize('Andorra la Vella'), 'Europe/Andorra');

        // Austria
        for (String c : new List<String>{
            'Graz','Innsbruck','Klagenfurt','Linz','Salzburg','Vienna'
        }) m.put(normalize(c), 'Europe/Vienna');

        // Belgium
        for (String c : new List<String>{
            'Aalst','Antwerp','Bruges','Brussels','Eghezee','Ghent','Hasselt',
            'Knokke','Leuven','Liege','Mechelen','Mons','Namur','Uccle',
            'Waterloo','Zaventem'
        }) m.put(normalize(c), 'Europe/Brussels');

        // France
        for (String c : new List<String>{
            'Aix-en-Provence','Ajaccio','Amiens','Angers','Annecy','Avignon','Bayonne',
            'Besançon','Biarritz','Bordeaux','Bourg-en-Bresse','Brest','Caen','Cannes',
            'Chambéry','Clermont-Ferrand','Dijon','Grenoble','Hyeres',
            'Issy-les-Moulineaux','La Rochelle','La Roche-sur-Yon','La Seyne-sur-Mer',
            'Laval','Le Mans','Lille','Limoges','Lorient','Lyon','Marseille','Metz',
            'Montpellier','Nancy','Nantes','Nanterre','Neuilly-sur-Seine','Nice','Nîmes',
            'Paris','Perpignan','Porquerolles','Reims','Rennes','Rouen','Saint-Denis',
            'Saint-Étienne','Strasbourg','Toulon','Toulouse','Tours','Trouville',
            'Val d’Isère','Vannes','Versailles'
        }) m.put(normalize(c), 'Europe/Paris');

        // Germany
        for (String c : new List<String>{
            'Augsburg','Berlin','Bonn','Bremen','Cologne','Dresden','Dusseldorf',
            'Frankfurt','Halle','Hamburg','Hannover','Karlsruhe','Kassel','Kiel',
            'Konstanz','Leipzig','Ludwigsburg','Magdeburg','Mainz','Mannheim',
            'Munster','Munich','Nuremberg','Regensburg','Stuttgart','Ulm'
        }) m.put(normalize(c), 'Europe/Berlin');

        // Hungary / Ireland
        m.put(normalize('Budapest'), 'Europe/Budapest');
        m.put(normalize('Dublin'), 'Europe/Dublin');

        // Italy
        for (String c : new List<String>{
            'Arezzo','Bari','Bergamo','Bologna','Catania','Como','Florence','Genoa',
            'Milan','Monza','Naples','Novara','Padua','Palermo','Piacenza','Pisa',
            'Reggio Emilia','Rome','Trento','Trieste','Verona'
        }) m.put(normalize(c), 'Europe/Rome');

        // Switzerland
        for (String c : new List<String>{
            'Basel','Chur','Geneva','Lausanne','Lugano','Zurich'
        }) m.put(normalize(c), 'Europe/Zurich');

        // UAE
        m.put(normalize('Dubai'), 'Asia/Dubai');

        return m;
    }

    private static Map<String, String> getCityToCountry() {
        Map<String, String> m = new Map<String, String>();

        // Optional validation when both are passed
        m.put(normalize('London'), normalize('United Kingdom'));
        m.put(normalize('Manchester'), normalize('United Kingdom'));
        m.put(normalize('Montevideo'), normalize('Uruguay'));
        m.put(normalize('Montreal'), normalize('Canada'));
        m.put(normalize('Montreal'), normalize('Canada'));
        m.put(normalize('Singapore'), normalize('Singapore'));
        m.put(normalize('Tokyo'), normalize('Japan'));
        m.put(normalize('Riga'), normalize('Latvia'));
        m.put(normalize('Vilnius'), normalize('Lithuania'));
        m.put(normalize('Luxembourg City'), normalize('Luxembourg'));
        m.put(normalize('Monaco'), normalize('Monaco'));
        m.put(normalize('Amsterdam'), normalize('Netherlands'));
        m.put(normalize('Oslo'), normalize('Norway'));
        m.put(normalize('Lisbon'), normalize('Portugal'));
        m.put(normalize('Porto'), normalize('Portugal'));
        m.put(normalize('Madrid'), normalize('Spain'));
        m.put(normalize('Las Palmas'), normalize('Spain'));
        m.put(normalize('Vienna'), normalize('Austria'));
        m.put(normalize('Brussels'), normalize('Belgium'));
        m.put(normalize('Paris'), normalize('France'));
        m.put(normalize('Berlin'), normalize('Germany'));
        m.put(normalize('Budapest'), normalize('Hungary'));
        m.put(normalize('Dublin'), normalize('Ireland'));
        m.put(normalize('Rome'), normalize('Italy'));
        m.put(normalize('Zurich'), normalize('Switzerland'));
        m.put(normalize('Dubai'), normalize('United Arab Emirates'));

        return m;
    }
}