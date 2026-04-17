@IsTest
public class JSONAssessmentsUME2Apex_Test {
	
	static testMethod void testParse() {
		String json = '{'+
		'                \"guid\": \"cba502d1-2b76-4812-a7b1-1b854a11e064\",'+
		'                \"assessmentDate\": \"2018-12-15T13:40:49+0000\",'+
		'                \"expirationDate\": \"2020-06-15T13:40:49+0000\",'+
		'                \"assessingUser\": {'+
		'                                \"guid\": \"6db1b881-551a-46c7-8c8e-3efc5392dc3e\",'+
		'                                \"firstName\": \"Abderrahmae\",'+
		'                                \"lastName\": \"TRIA\",'+
		'                                \"email\": \"abderrahmane.tria@alphafmc.com\",'+
		'                                \"phoneNumbers\": ['+
		'                                                {'+
		'                                                                \"numberType\": \"work\",'+
		'                                                                \"phoneNo\": \"+34 91 450 3180\"'+
		'                                                },'+
		'                                                {'+
		'                                                                \"numberType\": \"mobile\",'+
		'                                                                \"phoneNo\": \"+34 691 128 143\"'+
		'                                                }'+
		'                                ],'+
		'                                \"userStatus\": 2'+
		'                },'+
		'                \"summary\": \"new assessment\\n\",'+
		'                \"scoringFactor\": 2.98,'+
		'                \"assessmentScore\": 2,'+
		'                \"assessmentStatus\": 1'+
		'}';
		JSONAssessmentsUME2Apex obj = JSONAssessmentsUME2Apex.parse(json);
		System.assert(obj != null);
	}
}