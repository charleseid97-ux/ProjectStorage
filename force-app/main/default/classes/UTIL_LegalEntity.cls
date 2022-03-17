/**
* @author Abderrahmane TRIA
* @date Creation 29/04/2020
* @group Utilities
* @description UTIL_LegalEntity - class contains methods to Call APIs.
*/
public class UTIL_LegalEntity {
    
    //Constants
    public static final string guid = 'b56e935b-8a47-479b-b275-764fb30e5cad';
    public static final string UME_Auth = 'ume bUBTLUprhDRaR6UH5Yth9w:epaNbfiB2iNWmwoLg_b7ew';
    
    
    // Get Legal Entity from lei.info
    public static JSONLegalEntity2Apex getLegalEntity (String lei) {
        String res = callGLEIF(lei);
        if (Test.isRunningTest()) res = getString (1);
        // Deserialize the JSON string into collections of primitive data types.
        JSONLegalEntity2Apex jsonApex = (JSONLegalEntity2Apex)JSON.deserialize(res, JSONLegalEntity2Apex.class);
        return jsonApex;
    }
    
    // Get list of Distributors from UME
    public static List<JSONLegalEntityUME2Apex> getDistributors (String url) {
        String res = callUME(url);
        if (Test.isRunningTest()) res = getString (2);
        System.debug('SLI >> '+ res);
        //Deserialize the JSON string into collections of primitive data types.
        List<JSONLegalEntityUME2Apex>  jsonApex = new List<JSONLegalEntityUME2Apex>();
        if ( res != null )
        	jsonApex = (List<JSONLegalEntityUME2Apex>)JSON.deserialize(res, List<JSONLegalEntityUME2Apex>.class);
        return jsonApex;
    }
    
    // Get Score
    public static JSONScoreUME2Apex getScore (String url) {
        String res = callUME(url);
        if (Test.isRunningTest()) res = getString (3);
        //Deserialize the JSON string into collections of primitive data types.
        JSONScoreUME2Apex jsonApex = new JSONScoreUME2Apex();
        if ( res != null )
            jsonApex = (JSONScoreUME2Apex)JSON.deserialize(res, JSONScoreUME2Apex.class);
        return jsonApex; 
    }
    
    // Get Assessment
    public static JSONAssessmentsUME2Apex getAssessment (String url) {
        String res = callUME(url);
        if (Test.isRunningTest()) res = getString (4);
        //Deserialize the JSON string into collections of primitive data types.
        JSONAssessmentsUME2Apex jsonApex = new JSONAssessmentsUME2Apex();
        if ( res != null )
            jsonApex = (JSONAssessmentsUME2Apex)JSON.deserialize(res, JSONAssessmentsUME2Apex.class);
        return jsonApex; 
    }
    
    // Get Profil
    public static JSONProfileUME2Apex getProfile (String url) {
        String res = callUME(url);
        if (Test.isRunningTest()) res = getString (5);
        //Deserialize the JSON string into collections of primitive data types.
        JSONProfileUME2Apex jsonApex = new JSONProfileUME2Apex();
        if ( res != null )
            jsonApex = (JSONProfileUME2Apex)JSON.deserialize(res, JSONProfileUME2Apex.class);
        return jsonApex; 
    }
    
    // Get KYC
    @AuraEnabled(cacheable=true)
    public static String getKYC (Id recordId) {
        String brid = '';
        String url = '';
        try {
            Legal_Entity__c[] le = [SELECT Id, TECH_brid__c FROM Legal_Entity__c WHERE Id = :recordId];
            if(le != null){
                brid = le[0].TECH_brid__c;
                if (brid != null)
                   return callUME ('/api/v2/brs/'+brid+'/controlled/kyc/persons');
            }
        }catch(System.CalloutException e) {
            System.debug('Callout UME - The following exception has occurred: ' + e.getMessage());
        }
        return null;
    }
    
    public static String callUME (String url) {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:UME_API'+url);
            request.setMethod('GET');
            request.setHeader('X-ume-CompanyId',guid);
            request.setHeader('Authorization', UME_Auth);
            
            HttpResponse response = http.send(request);
            // If the request is successful, parse the JSON response.
            if (response.getStatusCode() == 200) { System.debug(response.getBody());
                return response.getBody();  
                               
            }
            
        }catch(System.CalloutException e) {
            System.debug('Callout UME - The following exception has occurred: ' + e.getMessage());
        }
        return null;
    }
    
    public static String callGLEIF (String lei) {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:LEI_INFO/api/v1/lei-records?filter[lei]='+lei+'&page[size]=50&page[number]=1');
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Accept', 'application/vnd.api+json');
            request.setHeader('Accept', '*/*; q=1');
            
            HttpResponse response = http.send(request);
            // If the request is successful, parse the JSON response.
            if (response.getStatusCode() == 200) {
                return response.getBody();
            }
            
        } catch(System.CalloutException e) {
            System.debug('Callout GLEIF - The following exception has occurred: ' + e.getMessage());
        } 
        return null;
    }
    
    public static String getRequestStatus (String block) {
        switch on block {
            when 'A' {
                return 'Questionnaire OK';
            }
            when 'B' {
                return 'Request accepted by the distributor, but questionnaire is not available yet';
            }
            when 'C' {
                return 'Request sent, but not accepted by the distributor';
            }
            when 'D' {
                return 'Request not sent yet';
            }
            when 'R' {
                return 'Questionnaire in renewal';
            }            
            when 'P' {
                return 'On Hold';
            }
        }
        return null;
    }
    
    public static String getString (Integer block) {
        switch on block {
            when 1 {	// GLEIF	
                String jsonStrGLEIF = '{'+
                    '   \"meta\":{'+
                    '      \"pagination\":{'+
                    '         \"currentPage\":1,'+
                    '         \"perPage\":15,'+
                    '         \"from\":1,'+
                    '         \"to\":1,'+
                    '         \"total\":1,'+
                    '         \"lastPage\":1'+
                    '      }'+
                    '   },'+
                    '   \"links\":{'+
                    '      \"first\":\"https:\\/\\/api.gleif.org\\/api\\/v1\\/lei-records?filter%5Blei%5D=5067007V6269EHOP3295&page%5Bnumber%5D=1&page%5Bsize%5D=15\",'+
                    '      \"last\":\"https:\\/\\/api.gleif.org\\/api\\/v1\\/lei-records?filter%5Blei%5D=5067007V6269EHOP3295&page%5Bnumber%5D=1&page%5Bsize%5D=15\"'+
                    '   },'+
                    '   \"data\":['+
                    '      {'+
                    '         \"type\":\"lei-records\",'+
                    '         \"id\":\"5067007V6269EHOP3295\",'+
                    '         \"attributes\":{'+
                    '            \"lei\":\"5067007V6269EHOP3295\",'+
                    '            \"entity\":{'+
                    '               \"legalName\":{'+
                    '                  \"name\":\"1875 Finance SA\",'+
                    '                  \"language\":\"DE\"'+
                    '               },'+
                    '               \"otherNames\":['+
                    ''+
                    '               ],'+
                    '               \"transliteratedOtherNames\":['+
                    ''+
                    '               ],'+
                    '               \"legalAddress\":{'+
                    '                  \"language\":\"DE\",'+
                    '                  \"addressLines\":['+
                    '                     \"rue XXXI-D\\u00e9cembre 40\"'+
                    '                  ],'+
                    '                  \"addressNumber\":null,'+
                    '                  \"addressNumberWithinBuilding\":null,'+
                    '                  \"mailRouting\":null,'+
                    '                  \"city\":\"Gen\\u00e8ve\",'+
                    '                  \"region\":\"CH-GE\",'+
                    '                  \"country\":\"CH\",'+
                    '                  \"postalCode\":\"1207\"'+
                    '               },'+
                    '               \"headquartersAddress\":{'+
                    '                  \"language\":\"DE\",'+
                    '                  \"addressLines\":['+
                    '                     \"rue XXXI-D\\u00e9cembre 40\"'+
                    '                  ],'+
                    '                  \"addressNumber\":null,'+
                    '                  \"addressNumberWithinBuilding\":null,'+
                    '                  \"mailRouting\":null,'+
                    '                  \"city\":\"Gen\\u00e8ve\",'+
                    '                  \"region\":\"CH-GE\",'+
                    '                  \"country\":\"CH\",'+
                    '                  \"postalCode\":\"1207\"'+
                    '               },'+
                    '               \"registeredAt\":{'+
                    '                  \"id\":\"RA000548\",'+
                    '                  \"other\":null'+
                    '               },'+
                    '               \"registeredAs\":\"CHE112734090\",'+
                    '               \"jurisdiction\":\"CH\",'+
                    '               \"category\":null,'+
                    '               \"legalForm\":{'+
                    '                  \"id\":\"MVII\",'+
                    '                  \"other\":null'+
                    '               },'+
                    '               \"associatedEntity\":{'+
                    '                  \"lei\":null,'+
                    '                  \"name\":null'+
                    '               },'+
                    '               \"status\":\"ACTIVE\",'+
                    '               \"expiration\":{'+
                    '                  \"date\":null,'+
                    '                  \"reason\":null'+
                    '               },'+
                    '               \"successorEntity\":{'+
                    '                  \"lei\":null,'+
                    '                  \"name\":null'+
                    '               },'+
                    '               \"otherAddresses\":['+
                    ''+
                    '               ]'+
                    '            },'+
                    '            \"registration\":{'+
                    '               \"initialRegistrationDate\":\"2017-12-15T13:13:52Z\",'+
                    '               \"lastUpdateDate\":\"2020-03-24T17:08:58Z\",'+
                    '               \"status\":\"ISSUED\",'+
                    '               \"nextRenewalDate\":\"2020-12-18T16:15:49Z\",'+
                    '               \"managingLou\":\"506700LOLO7M6V0E4247\",'+
                    '               \"corroborationLevel\":\"FULLY_CORROBORATED\",'+
                    '               \"validatedAt\":{'+
                    '                  \"id\":\"RA000548\",'+
                    '                  \"other\":null'+
                    '               },'+
                    '               \"validatedAs\":\"CHE112734090\"'+
                    '            },'+
                    '            \"bic\":['+
                    '               \"FNECCHG1XXX\"'+
                    '            ]'+
                    '         },'+
                    '         \"relationships\":{'+
                    '            \"managing-lou\":{'+
                    '               \"links\":{'+
                    '                  \"related\":\"https:\\/\\/api.gleif.org\\/api\\/v1\\/lei-records\\/5067007V6269EHOP3295\\/managing-lou\"'+
                    '               }'+
                    '            },'+
                    '            \"lei-issuer\":{'+
                    '               \"links\":{'+
                    '                  \"related\":\"https:\\/\\/api.gleif.org\\/api\\/v1\\/lei-records\\/5067007V6269EHOP3295\\/lei-issuer\"'+
                    '               }'+
                    '            },'+
                    '            \"direct-parent\":{'+
                    '               \"links\":{'+
                    '                  \"reporting-exception\":\"https:\\/\\/api.gleif.org\\/api\\/v1\\/lei-records\\/5067007V6269EHOP3295\\/direct-parent-reporting-exception\"'+
                    '               }'+
                    '            },'+
                    '            \"ultimate-parent\":{'+
                    '               \"links\":{'+
                    '                  \"reporting-exception\":\"https:\\/\\/api.gleif.org\\/api\\/v1\\/lei-records\\/5067007V6269EHOP3295\\/ultimate-parent-reporting-exception\"'+
                    '               }'+
                    '            }'+
                    '         },'+
                    '         \"links\":{'+
                    '            \"self\":\"https:\\/\\/api.gleif.org\\/api\\/v1\\/lei-records\\/5067007V6269EHOP3295\"'+
                    '         }'+
                    '      }'+
                    '   ]'+
                    '}';
                return jsonStrGLEIF;
            }	
            when 2 {	// UME
                String jsonUMEStr = '[{'+
                    '        \"networkIndex\": \"1\",'+
                    '        \"company\": {'+
                    '            \"guid\": \"d34eb867-0a6e-4c1a-8f80-cfd90e83c45f\",'+
                    '            \"lei\": \"815600EB9E6DCD050385\",'+
                    '            \"status\": \"ACTIVE\",'+
                    '            \"isBranch\": false,'+
                    '            \"companyName\": \"\\\"BANCA PASSADORE & C. - SOCIETA\' PER AZIONI\\\"\",'+
                    '            \"companyType\": \"DISTRIBUTOR\",'+
                    '            \"country\": {'+
                    '                \"name\": \"Italy\",'+
                    '                \"code\": \"IT\"'+
                    '            },'+
                    '            \"streetAddress\": \"Via Ettore Vernazza, 27, 16121 Genova GE, Italy\",'+
                    '            \"googleAddress\": {'+
                    '                \"address_components\": ['+
                    '                    {'+
                    '                        \"long_name\": \"27\",'+
                    '                        \"short_name\": \"27\",'+
                    '                        \"types\": ['+
                    '                            \"street_number\"'+
                    '                        ]'+
                    '                    },'+
                    '                    {'+
                    '                        \"long_name\": \"Via Ettore Vernazza\",'+
                    '                        \"short_name\": \"Via Ettore Vernazza\",'+
                    '                        \"types\": ['+
                    '                            \"route\"'+
                    '                        ]'+
                    '                    },'+
                    '                    {'+
                    '                        \"long_name\": \"Genova\",'+
                    '                        \"short_name\": \"Genova\",'+
                    '                        \"types\": ['+
                    '                            \"locality\",'+
                    '                            \"political\"'+
                    '                        ]'+
                    '                    },'+
                    '                    {'+
                    '                        \"long_name\": \"Genova\",'+
                    '                        \"short_name\": \"Genova\",'+
                    '                        \"types\": ['+
                    '                            \"administrative_area_level_3\",'+
                    '                            \"political\"'+
                    '                        ]'+
                    '                    },'+
                    '                    {'+
                    '                        \"long_name\": \"Città Metropolitana di Genova\",'+
                    '                        \"short_name\": \"GE\",'+
                    '                        \"types\": ['+
                    '                            \"administrative_area_level_2\",'+
                    '                            \"political\"'+
                    '                        ]'+
                    '                    },'+
                    '                    {'+
                    '                        \"long_name\": \"Liguria\",'+
                    '                        \"short_name\": \"Liguria\",'+
                    '                        \"types\": ['+
                    '                            \"administrative_area_level_1\",'+
                    '                            \"political\"'+
                    '                        ]'+
                    '                    },'+
                    '                    {'+
                    '                        \"long_name\": \"Italy\",'+
                    '                        \"short_name\": \"IT\",'+
                    '                        \"types\": ['+
                    '                            \"country\",'+
                    '                            \"political\"'+
                    '                        ]'+
                    '                    },'+
                    '                    {'+
                    '                        \"long_name\": \"16121\",'+
                    '                        \"short_name\": \"16121\",'+
                    '                        \"types\": ['+
                    '                            \"postal_code\"'+
                    '                        ]'+
                    '                    }'+
                    '                ],'+
                    '                \"formatted_address\": \"Via Ettore Vernazza, 27, 16121 Genova GE, Italy\",'+
                    '                \"geometry\": {'+
                    '                    \"location\": {'+
                    '                        \"lat\": \"44.4075149\",'+
                    '                        \"lng\": \"8.9358244\"'+
                    '                    },'+
                    '                    \"location_type\": \"ROOFTOP\",'+
                    '                    \"viewport\": {'+
                    '                        \"northeast\": {'+
                    '                            \"lat\": \"44.4088638802915\",'+
                    '                            \"lng\": \"8.937173380291503\"'+
                    '                        },'+
                    '                        \"southwest\": {'+
                    '                            \"lat\": \"44.4061659197085\",'+
                    '                            \"lng\": \"8.934475419708498\"'+
                    '                        }'+
                    '                    }'+
                    '                },'+
                    '                \"place_id\": \"ChIJV-3yBuhD0xIRxg1lhmlPEh8\",'+
                    '                \"plus_code\": {'+
                    '                    \"compound_code\": \"CW5P+28 Genoa, Metropolitan City of Genoa, Italy\",'+
                    '                    \"global_code\": \"8FPCCW5P+28\"'+
                    '                },'+
                    '                \"types\": ['+
                    '                    \"street_address\"'+
                    '                ]'+
                    '            },'+
                    '            \"lat\": 44.4075149,'+
                    '            \"lon\": 8.9358244,'+
                    '            \"website\": \"www.bancapassadore.it\",'+
                    '            \"profile\": {'+
                    '                \"_8bc829c9_e788_4782_a933_4db29b6f51df\": \"s.p.a.\",'+
                    '                \"_02d82ac6_9e4a_4468_80b4_bed0f773c5ab\": \"1947-01-26T23:00:00.000Z\",'+
                    '                \"_6621f5ed_b5d7_4cb8_aa0c_715bc271f01d\": \"none\",'+
                    '                \"_02556f51_9701_458b_a536_f8c8251fe0be\": \"_0to10\",'+
                    '                \"_4bbe86e9_1df4_4471_8531_b174de3d2ce7\": {'+
                    '                    \"_adv\": \"true\",'+
                    '                    \"_exe\": \"true\",'+
                    '                    \"_rec_tra_ord\": \"true\",'+
                    '                    \"_exe_ord_beh_cli\": \"true\"'+
                    '                },'+
                    '                \"_476f96c5_25d0_4e29_bf92_aeaafcdec78c\": {'+
                    '                    \"_ret_pri_ban\": \"true\",'+
                    '                    \"_wea_man\": \"true\",'+
                    '                    \"_cus\": \"true\"'+
                    '                },'+
                    '                \"_7cce5b98_2673_416a_9b64_9d805d6fd302\": {'+
                    '                    \"_ban_off_bas\": \"true\"'+
                    '                },'+
                    '                \"_6a831ddf_34be_4174_80f5_26b6cb20fb26\": \"all bank transactions\",'+
                    '                \"_dbb71b06_e991_47de_a238_5daaec813188\": \"Banca d\'Italia / Consob\",'+
                    '                \"_5c04a549_1c88_454a_ba3d_af1b25768f5f\": \"_ffi\",'+
                    '                \"_0b8b1aba_4e43_4389_a138_31f598d4f028\": \"Yes\",'+
                    '                \"_75ecbd38_c059_426d_9e8a_39abb36c6528\": {'+
                    '                    \"_0\": \"true\",'+
                    '                    \"_1\": \"true\",'+
                    '                    \"_2\": \"true\",'+
                    '                    \"_3\": \"true\"'+
                    '                },'+
                    '                \"_c1826731_b118_46f4_bfab_a9b15f57f851\": \"_5\",'+
                    '                \"_f97cf9df_91f0_47c0_8e46_e599df3c240f\": \"_more_20\",'+
                    '                \"_c32faa86_952c_4ba0_bb74_7a0bca2ad21e\": {'+
                    '                    \"_eur\": \"true\"'+
                    '                },'+
                    '                \"_7a2340fb_1f4f_4561_9219_2480eb6b0173\": {'+
                    '                    \"_eur\": \"true\"'+
                    '                },'+
                    '                \"_bdc826bd_2e55_4be5_ab4e_e3aa0314656f\": {'+
                    '                    \"_ret_non_pro\": \"true\",'+
                    '                    \"_ins\": \"true\"'+
                    '                },'+
                    '                \"_130fb1b7_e74e_40aa_8bdd_3c1f4d04cdfa\": \"_80_to_100\",'+
                    '                \"_223a67a3_358d_4824_800b_b7a60198cec0\": \"www.bancapassadore.it\"'+
                    '            }'+
                    '        },'+
                    '        \"contact\": {'+
                    '            \"guid\": \"c1899602-01f3-4a99-87b4-51ce5e573be1\",'+
                    '            \"firstName\": \"Giampiero\",'+
                    '            \"lastName\": \"Negro\",'+
                    '            \"email\": \"giampiero.negro@bancapassadore.it\",'+
                    '            \"phoneNumbers\": ['+
                    '                {'+
                    '                    \"numberType\": \"work\",'+
                    '                    \"phoneNo\": \"010-5393330\"'+
                    '                }'+
                    '            ],'+
                    '            \"userStatus\": 2'+
                    '        },'+
                    '        \"scoring\": {'+
                    '            \"sectionScores\": ['+
                    '                0.0,'+
                    '                100.0,'+
                    '                0.0,'+
                    '                0.0,'+
                    '                19.986390314440403,'+
                    '                0.0,'+
                    '                0.0'+
                    '            ],'+
                    '            \"baseScore\": 27.99795854716606,'+
                    '            \"countryRiskFactor\": 1.0,'+
                    '            \"totalScore\": 27.99795854716606,'+
                    '            \"nShowStoppers\": 0,'+
                    '            \"questionnaireExpirationInfo\": {'+
                    '                \"questStatus\": \"expired\",'+
                    '                \"ddqSubmitted\": \"2018-10-31T16:42:54+0000\",'+
                    '                \"questExpirationDate\": \"2019-10-31T16:42:54+0000\"'+
                    '            },'+
                    '            \"questionaryDescriptor\": {'+
                    '                \"guid\": \"5805da82-3748-4b4f-8dd6-c32a7d4abf8d\",'+
                    '                \"status\": \"ACTIVE\",'+
                    '                \"timestamp\": \"2020-01-24T18:58:51+0000\"'+
                    '            }'+
                    '        },'+
                    '        \"pctAnswered\": 0.5576923076923077,'+
                    '        \"pctValidated\": 0.1282051282051282,'+
                    '        \"status\": \"R\",'+
                    '        \"umeRequest\": {'+
                    '            \"guid\": \"5cf1e6f1-997c-4224-abdb-c569885d7cb8\",'+
                    '            \"submissionDate\": \"2019-12-11T13:23:11+0000\",'+
                    '            \"resource\": {'+
                    '                \"type\": \"BR\",'+
                    '                \"guid\": \"d34eb867-0a6e-4c1a-8f80-cfd90e83c45f\"'+
                    '            },'+
                    '            \"requestStatus\": 1,'+
                    '            \"answerDate\": \"2019-12-11T13:32:32+0000\",'+
                    '            \"status\": \"(B)\",'+
                    '            \"answerUser\": {'+
                    '                \"guid\": \"1c2cb386-05d8-4e98-9a66-df4a2625a25c\",'+
                    '                \"firstName\": \"Rolf\",'+
                    '                \"lastName\": \"Bachner\",'+
                    '                \"email\": \"rolf.bachner@ume.solutions\",'+
                    '                \"phoneNumbers\": ['+
                    '                    {'+
                    '                        \"numberType\": \"mobile\",'+
                    '                        \"phoneNo\": \"+352 621 167 181\"'+
                    '                    },'+
                    '                    {'+
                    '                        \"numberType\": \"work\",'+
                    '                        \"phoneNo\": \"+352 288 127 40\"'+
                    '                    }'+
                    '                ],'+
                    '                \"userStatus\": 2'+
                    '            },'+
                    '            \"notCancellable\": false'+
                    '        },'+
                    '        \"nNonansweredFollowups\": \"0\",'+
                    '        \"brid\": \"adff36a9-4e07-4f52-a99a-37803284ba89\"'+
                    '    }]'; 
                return jsonUMEStr;
            }
            when 3 {	//  Score UME	
                String jsonScore = '{\"yellowThreshold\":20.0,\"redThreshold\":30.0}';
                return jsonScore;
            }
            when 4 {    //  Assessment UME
                String jsonAssessment = '{'+
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
                return jsonAssessment;
            }
            when 5 {    //  Profil UME
                String jsonProfil = '{'+
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
                return jsonProfil;
            }
            
        }
        return null;
    }
    
}