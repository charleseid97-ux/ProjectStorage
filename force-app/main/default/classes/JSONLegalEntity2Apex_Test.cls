@IsTest
public class JSONLegalEntity2Apex_Test {
	
	static testMethod void testParse() {
		String json = '{'+
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
		JSONLegalEntity2Apex r = JSONLegalEntity2Apex.parse(json);
		System.assert(r != null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Meta objMeta = new JSONLegalEntity2Apex.Meta(System.JSON.createParser(json));
		System.assert(objMeta != null);
		System.assert(objMeta.pagination == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Entity objEntity = new JSONLegalEntity2Apex.Entity(System.JSON.createParser(json));
		System.assert(objEntity != null);
		System.assert(objEntity.legalName == null);
		System.assert(objEntity.legalAddress == null);
		System.assert(objEntity.headquartersAddress == null);
		System.assert(objEntity.registeredAt == null);
		System.assert(objEntity.registeredAs == null);
		System.assert(objEntity.jurisdiction == null);
		System.assert(objEntity.category == null);
		System.assert(objEntity.legalForm == null);
		System.assert(objEntity.associatedEntity == null);
		System.assert(objEntity.status == null);
		System.assert(objEntity.expiration == null);
		System.assert(objEntity.successorEntity == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.LegalName objLegalName = new JSONLegalEntity2Apex.LegalName(System.JSON.createParser(json));
		System.assert(objLegalName != null);
		System.assert(objLegalName.name == null);
		System.assert(objLegalName.language == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.AssociatedEntity objAssociatedEntity = new JSONLegalEntity2Apex.AssociatedEntity(System.JSON.createParser(json));
		System.assert(objAssociatedEntity != null);
		System.assert(objAssociatedEntity.lei == null);
		System.assert(objAssociatedEntity.name == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.OtherNames objOtherNames = new JSONLegalEntity2Apex.OtherNames(System.JSON.createParser(json));
		System.assert(objOtherNames != null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Expiration objExpiration = new JSONLegalEntity2Apex.Expiration(System.JSON.createParser(json));
		System.assert(objExpiration != null);
		System.assert(objExpiration.datee == null);
		System.assert(objExpiration.reason == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Attributes objAttributes = new JSONLegalEntity2Apex.Attributes(System.JSON.createParser(json));
		System.assert(objAttributes != null);
		System.assert(objAttributes.lei == null);
		System.assert(objAttributes.entity == null);
		System.assert(objAttributes.registration == null);
		System.assert(objAttributes.bic == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex objJSONLegalEntity2Apex = new JSONLegalEntity2Apex(System.JSON.createParser(json));
		System.assert(objJSONLegalEntity2Apex != null);
		System.assert(objJSONLegalEntity2Apex.meta == null);
		System.assert(objJSONLegalEntity2Apex.links == null);
		System.assert(objJSONLegalEntity2Apex.data == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Data objData = new JSONLegalEntity2Apex.Data(System.JSON.createParser(json));
		System.assert(objData != null);
		System.assert(objData.type_Z == null);
		System.assert(objData.id == null);
		System.assert(objData.attributes == null);
		System.assert(objData.relationships == null);
		System.assert(objData.links == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Pagination objPagination = new JSONLegalEntity2Apex.Pagination(System.JSON.createParser(json));
		System.assert(objPagination != null);
		System.assert(objPagination.currentPage == null);
		System.assert(objPagination.perPage == null);
		System.assert(objPagination.from_Z == null);
		System.assert(objPagination.to == null);
		System.assert(objPagination.total == null);
		System.assert(objPagination.lastPage == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Links_Z objLinks_Z = new JSONLegalEntity2Apex.Links_Z(System.JSON.createParser(json));
		System.assert(objLinks_Z != null);
		System.assert(objLinks_Z.related == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Managing_lou objManaging_lou = new JSONLegalEntity2Apex.Managing_lou(System.JSON.createParser(json));
		System.assert(objManaging_lou != null);
		System.assert(objManaging_lou.links == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Relationships objRelationships = new JSONLegalEntity2Apex.Relationships(System.JSON.createParser(json));
		System.assert(objRelationships != null);
		System.assert(objRelationships.managing_lou == null);
		System.assert(objRelationships.lei_issuer == null);
		System.assert(objRelationships.direct_parent == null);
		System.assert(objRelationships.ultimate_parent == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Links_X objLinks_X = new JSONLegalEntity2Apex.Links_X(System.JSON.createParser(json));
		System.assert(objLinks_X != null);
		System.assert(objLinks_X.self == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Links_Y objLinks_Y = new JSONLegalEntity2Apex.Links_Y(System.JSON.createParser(json));
		System.assert(objLinks_Y != null);
		System.assert(objLinks_Y.reporting_exception == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Registration objRegistration = new JSONLegalEntity2Apex.Registration(System.JSON.createParser(json));
		System.assert(objRegistration != null);
		System.assert(objRegistration.initialRegistrationDate == null);
		System.assert(objRegistration.lastUpdateDate == null);
		System.assert(objRegistration.status == null);
		System.assert(objRegistration.nextRenewalDate == null);
		System.assert(objRegistration.managingLou == null);
		System.assert(objRegistration.corroborationLevel == null);
		System.assert(objRegistration.validatedAt == null);
		System.assert(objRegistration.validatedAs == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Direct_parent objDirect_parent = new JSONLegalEntity2Apex.Direct_parent(System.JSON.createParser(json));
		System.assert(objDirect_parent != null);
		System.assert(objDirect_parent.links == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.Links objLinks = new JSONLegalEntity2Apex.Links(System.JSON.createParser(json));
		System.assert(objLinks != null);
		System.assert(objLinks.first == null);
		System.assert(objLinks.last == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.LegalAddress objLegalAddress = new JSONLegalEntity2Apex.LegalAddress(System.JSON.createParser(json));
		System.assert(objLegalAddress != null);
		System.assert(objLegalAddress.language == null);
		System.assert(objLegalAddress.addressLines == null);
		System.assert(objLegalAddress.addressNumber == null);
		System.assert(objLegalAddress.addressNumberWithinBuilding == null);
		System.assert(objLegalAddress.mailRouting == null);
		System.assert(objLegalAddress.city == null);
		System.assert(objLegalAddress.region == null);
		System.assert(objLegalAddress.country == null);
		System.assert(objLegalAddress.postalCode == null);

		json = '{\"TestAMissingObject\": { \"TestAMissingArray\": [ { \"TestAMissingProperty\": \"Some Value\" } ] } }';
		JSONLegalEntity2Apex.RegisteredAt objRegisteredAt = new JSONLegalEntity2Apex.RegisteredAt(System.JSON.createParser(json));
		System.assert(objRegisteredAt != null);
		System.assert(objRegisteredAt.id == null);
		System.assert(objRegisteredAt.other == null);
	}
}