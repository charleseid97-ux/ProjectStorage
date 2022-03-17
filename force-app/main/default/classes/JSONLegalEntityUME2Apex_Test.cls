@IsTest
public class JSONLegalEntityUME2Apex_Test {
	
	static testMethod void testParse() {
		String json = '{'+
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
		'            \"requestStatus\": \"ACCEPTED\",'+
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
		'    }';
		JSONLegalEntityUME2Apex r = JSONLegalEntityUME2Apex.parse(json);
		System.assert(r != null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Bdc826bd_2e55_4be5_ab4e_e3aa0314656f objBdc826bd_2e55_4be5_ab4e_e3aa0314656f = new JSONLegalEntityUME2Apex.Bdc826bd_2e55_4be5_ab4e_e3aa0314656f(System.JSON.createParser(json));
		System.assert(objBdc826bd_2e55_4be5_ab4e_e3aa0314656f != null);
		System.assert(objBdc826bd_2e55_4be5_ab4e_e3aa0314656f.x_ins == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.PhoneNumbers objPhoneNumbers = new JSONLegalEntityUME2Apex.PhoneNumbers(System.JSON.createParser(json));
		System.assert(objPhoneNumbers != null);
		System.assert(objPhoneNumbers.numberType == null);
		System.assert(objPhoneNumbers.phoneNo == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.GoogleAddress objGoogleAddress = new JSONLegalEntityUME2Apex.GoogleAddress(System.JSON.createParser(json));
		System.assert(objGoogleAddress != null);
		System.assert(objGoogleAddress.address_components == null);
		System.assert(objGoogleAddress.formatted_address == null);
		System.assert(objGoogleAddress.geometry == null);
		System.assert(objGoogleAddress.place_id == null);
		System.assert(objGoogleAddress.plus_code == null);
		System.assert(objGoogleAddress.types == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.d4bbe86e9_1df4_4471_8531_b174de3d2ce7 obj4bbe86e9_1df4_4471_8531_b174de3d2ce7 = new JSONLegalEntityUME2Apex.d4bbe86e9_1df4_4471_8531_b174de3d2ce7(System.JSON.createParser(json));
		System.assert(obj4bbe86e9_1df4_4471_8531_b174de3d2ce7 != null);
		System.assert(obj4bbe86e9_1df4_4471_8531_b174de3d2ce7.x_exe_ord_beh_cli == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Company objCompany = new JSONLegalEntityUME2Apex.Company(System.JSON.createParser(json));
		System.assert(objCompany != null);
		System.assert(objCompany.guid == null);
		System.assert(objCompany.lei == null);
		System.assert(objCompany.status == null);
		System.assert(objCompany.isBranch == null);
		System.assert(objCompany.companyName == null);
		System.assert(objCompany.companyType == null);
		System.assert(objCompany.country == null);
		System.assert(objCompany.streetAddress == null);
		System.assert(objCompany.googleAddress == null);
		System.assert(objCompany.lat == null);
		System.assert(objCompany.lon == null);
		System.assert(objCompany.website == null);
		System.assert(objCompany.profile == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.QuestionnaireExpirationInfo objQuestionnaireExpirationInfo = new JSONLegalEntityUME2Apex.QuestionnaireExpirationInfo(System.JSON.createParser(json));
		System.assert(objQuestionnaireExpirationInfo != null);
		System.assert(objQuestionnaireExpirationInfo.questStatus == null);
		System.assert(objQuestionnaireExpirationInfo.ddqSubmitted == null);
		System.assert(objQuestionnaireExpirationInfo.questExpirationDate == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.UmeRequest objUmeRequest = new JSONLegalEntityUME2Apex.UmeRequest(System.JSON.createParser(json));
		System.assert(objUmeRequest != null);
		System.assert(objUmeRequest.guid == null);
		System.assert(objUmeRequest.submissionDate == null);
		System.assert(objUmeRequest.resource == null);
		System.assert(objUmeRequest.requestStatus == null);
		System.assert(objUmeRequest.answerDate == null);
		System.assert(objUmeRequest.status == null);
		System.assert(objUmeRequest.answerUser == null);
		System.assert(objUmeRequest.notCancellable == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Viewport objViewport = new JSONLegalEntityUME2Apex.Viewport(System.JSON.createParser(json));
		System.assert(objViewport != null);
		System.assert(objViewport.northeast == null);
		System.assert(objViewport.southwest == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.d75ecbd38_c059_426d_9e8a_39abb36c6528 obj75ecbd38_c059_426d_9e8a_39abb36c6528 = new JSONLegalEntityUME2Apex.d75ecbd38_c059_426d_9e8a_39abb36c6528(System.JSON.createParser(json));
		System.assert(obj75ecbd38_c059_426d_9e8a_39abb36c6528 != null);
		System.assert(obj75ecbd38_c059_426d_9e8a_39abb36c6528.x_0 == null);
		System.assert(obj75ecbd38_c059_426d_9e8a_39abb36c6528.x_2 == null);
		System.assert(obj75ecbd38_c059_426d_9e8a_39abb36c6528.x_3 == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Resource objResource = new JSONLegalEntityUME2Apex.Resource(System.JSON.createParser(json));
		System.assert(objResource != null);
		System.assert(objResource.type == null);
		System.assert(objResource.guid == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Scoring objScoring = new JSONLegalEntityUME2Apex.Scoring(System.JSON.createParser(json));
		System.assert(objScoring != null);
		System.assert(objScoring.sectionScores == null);
		System.assert(objScoring.baseScore == null);
		System.assert(objScoring.countryRiskFactor == null);
		System.assert(objScoring.totalScore == null);
		System.assert(objScoring.nShowStoppers == null);
		System.assert(objScoring.questionnaireExpirationInfo == null);
		System.assert(objScoring.questionaryDescriptor == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.C32faa86_952c_4ba0_bb74_7a0bca2ad21e objC32faa86_952c_4ba0_bb74_7a0bca2ad21e = new JSONLegalEntityUME2Apex.C32faa86_952c_4ba0_bb74_7a0bca2ad21e(System.JSON.createParser(json));
		System.assert(objC32faa86_952c_4ba0_bb74_7a0bca2ad21e != null);
        

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Profile objProfile = new JSONLegalEntityUME2Apex.Profile(System.JSON.createParser(json));
		System.assert(objProfile != null);
		System.assert(objProfile.x_8bc829c9_e788_4782_a933_4db29b6f51df == null);
		System.assert(objProfile.x_02d82ac6_9e4a_4468_80b4_bed0f773c5ab == null);
		System.assert(objProfile.x_6621f5ed_b5d7_4cb8_aa0c_715bc271f01d == null);
		System.assert(objProfile.x_02556f51_9701_458b_a536_f8c8251fe0be == null);
		System.assert(objProfile.x_4bbe86e9_1df4_4471_8531_b174de3d2ce7 == null);
		System.assert(objProfile.x_476f96c5_25d0_4e29_bf92_aeaafcdec78c == null);
		System.assert(objProfile.x_7cce5b98_2673_416a_9b64_9d805d6fd302 == null);
		System.assert(objProfile.x_6a831ddf_34be_4174_80f5_26b6cb20fb26 == null);
		System.assert(objProfile.x_dbb71b06_e991_47de_a238_5daaec813188 == null);
		System.assert(objProfile.x_5c04a549_1c88_454a_ba3d_af1b25768f5f == null);
		System.assert(objProfile.x_0b8b1aba_4e43_4389_a138_31f598d4f028 == null);
		System.assert(objProfile.x_75ecbd38_c059_426d_9e8a_39abb36c6528 == null);
		System.assert(objProfile.x_c1826731_b118_46f4_bfab_a9b15f57f851 == null);
		System.assert(objProfile.x_f97cf9df_91f0_47c0_8e46_e599df3c240f == null);
		System.assert(objProfile.x_c32faa86_952c_4ba0_bb74_7a0bca2ad21e == null);
		System.assert(objProfile.x_7a2340fb_1f4f_4561_9219_2480eb6b0173 == null);
		System.assert(objProfile.x_bdc826bd_2e55_4be5_ab4e_e3aa0314656f == null);
		System.assert(objProfile.x_130fb1b7_e74e_40aa_8bdd_3c1f4d04cdfa == null);
		System.assert(objProfile.x_223a67a3_358d_4824_800b_b7a60198cec0 == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.d476f96c5_25d0_4e29_bf92_aeaafcdec78c obj476f96c5_25d0_4e29_bf92_aeaafcdec78c = new JSONLegalEntityUME2Apex.d476f96c5_25d0_4e29_bf92_aeaafcdec78c(System.JSON.createParser(json));
		System.assert(obj476f96c5_25d0_4e29_bf92_aeaafcdec78c != null);
		System.assert(obj476f96c5_25d0_4e29_bf92_aeaafcdec78c.x_ret_pri_ban == null);
		System.assert(obj476f96c5_25d0_4e29_bf92_aeaafcdec78c.x_wea_man == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Contact objContact = new JSONLegalEntityUME2Apex.Contact(System.JSON.createParser(json));
		System.assert(objContact != null);
		System.assert(objContact.guid == null);
		System.assert(objContact.firstName == null);
		System.assert(objContact.lastName == null);
		System.assert(objContact.email == null);
		System.assert(objContact.phoneNumbers == null);
		System.assert(objContact.userStatus == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Address_components objAddress_components = new JSONLegalEntityUME2Apex.Address_components(System.JSON.createParser(json));
		System.assert(objAddress_components != null);
		System.assert(objAddress_components.long_name == null);
		System.assert(objAddress_components.short_name == null);
		System.assert(objAddress_components.types == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Geometry objGeometry = new JSONLegalEntityUME2Apex.Geometry(System.JSON.createParser(json));
		System.assert(objGeometry != null);
		System.assert(objGeometry.location == null);
		System.assert(objGeometry.location_type == null);
		System.assert(objGeometry.viewport == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Plus_code objPlus_code = new JSONLegalEntityUME2Apex.Plus_code(System.JSON.createParser(json));
		System.assert(objPlus_code != null);
		System.assert(objPlus_code.compound_code == null);
		System.assert(objPlus_code.global_code == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex objJSONLegalEntityUME2Apex = new JSONLegalEntityUME2Apex(System.JSON.createParser(json));
		System.assert(objJSONLegalEntityUME2Apex != null);
		System.assert(objJSONLegalEntityUME2Apex.networkIndex == null);
		System.assert(objJSONLegalEntityUME2Apex.company == null);
		System.assert(objJSONLegalEntityUME2Apex.contact == null);
		System.assert(objJSONLegalEntityUME2Apex.scoring == null);
		System.assert(objJSONLegalEntityUME2Apex.pctAnswered == null);
		System.assert(objJSONLegalEntityUME2Apex.pctValidated == null);
		System.assert(objJSONLegalEntityUME2Apex.status == null);
		System.assert(objJSONLegalEntityUME2Apex.umeRequest == null);
		System.assert(objJSONLegalEntityUME2Apex.nNonansweredFollowups == null);
		System.assert(objJSONLegalEntityUME2Apex.brid == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Country objCountry = new JSONLegalEntityUME2Apex.Country(System.JSON.createParser(json));
		System.assert(objCountry != null);
		System.assert(objCountry.name == null);
		System.assert(objCountry.code == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.d7cce5b98_2673_416a_9b64_9d805d6fd302 obj7cce5b98_2673_416a_9b64_9d805d6fd302 = new JSONLegalEntityUME2Apex.d7cce5b98_2673_416a_9b64_9d805d6fd302(System.JSON.createParser(json));
		System.assert(obj7cce5b98_2673_416a_9b64_9d805d6fd302 != null);
		System.assert(obj7cce5b98_2673_416a_9b64_9d805d6fd302.x_ban_off_bas == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.QuestionaryDescriptor objQuestionaryDescriptor = new JSONLegalEntityUME2Apex.QuestionaryDescriptor(System.JSON.createParser(json));
		System.assert(objQuestionaryDescriptor != null);
		System.assert(objQuestionaryDescriptor.guid == null);
		System.assert(objQuestionaryDescriptor.status == null);
		System.assert(objQuestionaryDescriptor.timestamp == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntityUME2Apex.Location objLocation = new JSONLegalEntityUME2Apex.Location(System.JSON.createParser(json));
		System.assert(objLocation != null);
		System.assert(objLocation.lat == null);
		System.assert(objLocation.lng == null);
	}
}