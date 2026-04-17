public with sharing class RegistrationCountryDatatableController {

    @AuraEnabled(cacheable=true)
    public static List<CountryDTO> getUniqueCountries(Id productId) {
        List<AggregateResult> aggResults = [
            SELECT 
                Country__c countryApi, 
                RegistrationStatus__c regStatus, 
                MIN(RegistrationDate__c) earliestDate
            FROM Country__c
            WHERE ShareClass__r.Fund__c = :productId
            AND RegistrationStatus__c IN ('REG','INSTITUTIONAL_ONLY')
            GROUP BY Country__c, RegistrationStatus__c
        ];

        List<CountryDTO> results = new List<CountryDTO>();

        for (AggregateResult ar : aggResults) {
            String countryApi = (String)ar.get('countryApi');
            String regStatus = (String)ar.get('regStatus');
            Date minDate = (Date)ar.get('earliestDate');

            // Obtenir le label de la picklist Country__c dynamiquement
            String countryLabel = getPicklistLabel('Country__c', countryApi);
            
            // Obtenir le label de la picklist RegistrationStatus__c dynamiquement
            String regStatusLabel = getPicklistLabel('RegistrationStatus__c', regStatus);

            results.add(new CountryDTO(countryApi, countryLabel, regStatusLabel));
        }

        results.sort(new CountrySorter());
        return results;
    }

    // Méthode pour récupérer dynamiquement le label d'une valeur de picklist
    private static String getPicklistLabel(String fieldName, String value) {
        Schema.DescribeFieldResult fieldResult = Country__c.getSObjectType().getDescribe().fields.getMap().get(fieldName).getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.getValue() == value) {
                return entry.getLabel();
            }
        }
        return value; // fallback au cas où
    }

    public class CountryDTO {
        @AuraEnabled public String country;
        @AuraEnabled public String countryLabel;
        @AuraEnabled public String registrationStatus;
        @AuraEnabled public String formattedDate;

        public CountryDTO(String cApi, String cLabel, String status) {
            country = cApi;
            countryLabel = cLabel;
            registrationStatus = status;
            //formattedDate = regDate != null ? 
            //    DateTime.newInstance(regDate.year(), regDate.month(), regDate.day()).format('dd/MM/yyyy') : null;
        }
    }

    public class CountrySorter implements Comparator<CountryDTO> {
        public Integer compare(Object a, Object b) {
            CountryDTO ca = (CountryDTO)a;
            CountryDTO cb = (CountryDTO)b;
            return ca.countryLabel.compareTo(cb.countryLabel);
        }
    }
}