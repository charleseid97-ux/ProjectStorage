@IsTest
public class JSONProfileUME2Apex_Test {
    
    static testMethod void testParse() {
        String json = '{'+
        '    \"guid\": \"cef40f6d-7a45-47a0-8083-03bf16608de3\",'+
        '    \"lei\": \"549300NQ32SRT0NWPB72\",'+
        '    \"status\": \"ONBOARDING\",'+
        '    \"companyName\": \"\\\"ALETTI & C. BANCA DI INVESTIMENTO MOBILIARE S.P.A.\\\" BREVEMENTE CHIAMATA \\\"BANCA ALETTI & C. S.P.A.\\\"\",'+
        '    \"companyType\": \"DISTRIBUTOR\",'+
        '    \"country\": {'+
        '        \"name\": \"Italy\",'+
        '        \"code\": \"IT\"'+
        '    },'+
        '    \"streetAddress\": \"Passaggio Duomo, 2, 20123 Milano MI, Italy\",'+
        '    \"googleAddress\": {'+
        '        \"address_components\": ['+
        '            {'+
        '                \"long_name\": \"2\",'+
        '                \"short_name\": \"2\",'+
        '                \"types\": ['+
        '                    \"street_number\"'+
        '                ]'+
        '            },'+
        '            {'+
        '                \"long_name\": \"Passaggio Duomo\",'+
        '                \"short_name\": \"Passaggio Duomo\",'+
        '                \"types\": ['+
        '                    \"route\"'+
        '                ]'+
        '            },'+
        '            {'+
        '                \"long_name\": \"Milano\",'+
        '                \"short_name\": \"Milano\",'+
        '                \"types\": ['+
        '                    \"locality\",'+
        '                    \"political\"'+
        '                ]'+
        '            },'+
        '            {'+
        '                \"long_name\": \"Milano\",'+
        '                \"short_name\": \"Milano\",'+
        '                \"types\": ['+
        '                    \"administrative_area_level_3\",'+
        '                    \"political\"'+
        '                ]'+
        '            },'+
        '            {'+
        '                \"long_name\": \"Città Metropolitana di Milano\",'+
        '                \"short_name\": \"MI\",'+
        '                \"types\": ['+
        '                    \"administrative_area_level_2\",'+
        '                    \"political\"'+
        '                ]'+
        '            },'+
        '            {'+
        '                \"long_name\": \"Lombardia\",'+
        '                \"short_name\": \"Lombardia\",'+
        '                \"types\": ['+
        '                    \"administrative_area_level_1\",'+
        '                    \"political\"'+
        '                ]'+
        '            },'+
        '            {'+
        '                \"long_name\": \"Italy\",'+
        '                \"short_name\": \"IT\",'+
        '                \"types\": ['+
        '                    \"country\",'+
        '                    \"political\"'+
        '                ]'+
        '            },'+
        '            {'+
        '                \"long_name\": \"20123\",'+
        '                \"short_name\": \"20123\",'+
        '                \"types\": ['+
        '                    \"postal_code\"'+
        '                ]'+
        '            }'+
        '        ],'+
        '        \"formatted_address\": \"Passaggio Duomo, 2, 20123 Milano MI, Italy\",'+
        '        \"geometry\": {'+
        '            \"bounds\": {'+
        '                \"northeast\": {'+
        '                    \"lat\": \"45.4644619\",'+
        '                    \"lng\": \"9.188440199999999\"'+
        '                },'+
        '                \"southwest\": {'+
        '                    \"lat\": \"45.464298\",'+
        '                    \"lng\": \"9.1882754\"'+
        '                }'+
        '            },'+
        '            \"location\": {'+
        '                \"lat\": \"45.4643528\",'+
        '                \"lng\": \"9.188342\"'+
        '            },'+
        '            \"location_type\": \"ROOFTOP\",'+
        '            \"viewport\": {'+
        '                \"northeast\": {'+
        '                    \"lat\": \"45.4657289302915\",'+
        '                    \"lng\": \"9.189706780291502\"'+
        '                },'+
        '                \"southwest\": {'+
        '                    \"lat\": \"45.46303096970851\",'+
        '                    \"lng\": \"9.187008819708497\"'+
        '                }'+
        '            }'+
        '        },'+
        '        \"place_id\": \"ChIJJ4o3OazGhkcR3buJVPx8R4Y\",'+
        '        \"types\": ['+
        '            \"premise\"'+
        '        ]'+
        '    },'+
        '    \"lat\": 45.4643528,'+
        '    \"lon\": 9.188342,'+
        '    \"profile\": {},'+
        '    \"internalId\": \"L1031\"'+
        '}';
        JSONProfileUME2Apex obj = JSONProfileUME2Apex.parse(json);
        System.assert(obj != null);
    }
}