@isTest
public class PMTTestFactoryData {
    public static FundManager__c createFundManager(String name) {
        FundManager__c manager = new FundManager__c(Name = name, EmpId__c = 123);

        insert manager;
        return manager;
    }

    // Création complète d’un ProjectProduct prêt pour batch
    public static ProjectProduct__c createProjectProductWithAllFields(Id recordTypeId) {
        ProjectProduct__c p = new ProjectProduct__c(
            Name = 'Test Project',
            RecordTypeId = recordTypeId,
            VehicleType__c = 'Funds',
            ProjectStartDate__c = Date.today() - 20,
            EndDate__c = Date.today(),
            RiskAssociated__c = 'Equity;Interest rates;Credit;Currency',
            InvestmentObjective__c = 'Sample Objective',
            InvestmentStrategy__c = 'Sample Strategy',
            DomiciledIn__c = 'FR',
            ProjectStatus__c = 'Closed',
            Product_Name__c = 'toto',
            SFDRCategory__c = '0',
            LegalForm__c = 'Other'
        );
        System.debug('createProjectProductWithAllFields: ' + p.recordTypeId);
        insert p;
        return p;
    }

      public static ProjectProduct__c createProjectProduct(Id recordTypeId) {
        ProjectProduct__c p = new ProjectProduct__c(
            Name = 'Test Project',
            EndDate__c = Date.today(),
            VehicleType__c = 'Funds', // requis pour le trigger
            ProjectStartDate__c = Date.today(),// ✅ Ajout nécessaire pour éviter l'erreur
            RiskAssociated__c = 'Equity;Interest rates;Credit;Currency',
            RecordTypeId = recordTypeId
        );
        insert p;
        return p;
    }
 
    public static FundManagerAssignment__c createFundManagerAssignment(Id projId, Id fundManagerId) {
        FundManagerAssignment__c fma = new FundManagerAssignment__c(
            ProductManagementTool__c = projId,
            FundManager__c = fundManagerId,
            RepOrder__c = '1'
        );
        insert fma;
        return fma;
    }
 
    public static Milestone__c createMilestone(Id projectProductId, String name, Date startDate) {
        Milestone__c milestone = new Milestone__c(
            Name = name,
            Project_product__c = projectProductId,
            StartDate__c = startDate
        );
        insert milestone;
        return milestone;
    }

    public static Id getRecordTypeId(String objectName, String developerName) {
        return Schema.getGlobalDescribe()
            .get(objectName)
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get(developerName)
            .getRecordTypeId();
    }
 
    public static User createTestUser(String alias) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = alias,
            Email = alias + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Europe/Paris',
            Username = alias + '@test.com'
        );
        insert u;
        return u;
    }

    public static ProductProjectSettings__c createMatrice(String stage, String team, String requiredFields, String requiredSHCFields) {
        ProductProjectSettings__c m = new ProductProjectSettings__c(
            ProjectType__c = 'Creation',
            Stage__c = stage,
            Team__c = team,
            Order__c = 1,
            OrderTeam__c = 1,
            RequiredFields__c = requiredFields,
            RequiredFieldsShareClass__c = requiredSHCFields
        );
        insert m;
        return m;
    }
 
    public static ProjectProductChild__c createProjectProductChild(Id parentId, String stage, String teamValues) {
        String rtDevName = (stage == 'Design' || stage == 'Proposal') ? 'DesignAndProposal' : stage;
        Id recordTypeId = getRecordTypeId('ProjectProductChild__c', rtDevName);
 
        ProjectProductChild__c c = new ProjectProductChild__c(
            Name = stage,
            RecordTypeId = recordTypeId,
            ProjectProductParent__c = parentId,
            Status__c = 'Not Started',
            StartDate__c = Date.today(),
            EndDate__c = Date.today().addDays(10),
            TECH_Childtype__c = rtDevName,
            TECH_TeamValidation__c = teamValues
        );
        insert c;
        return c;
    }
 
    public static ProjectShareclass__c createProjectShareclass(Id parentId, String fieldsToModify) {
        ProjectShareclass__c shc = new ProjectShareclass__c(
            ProjectProduct__c = parentId,
            TECH_FieldsToModify__c = fieldsToModify,
            Type__c = 'A',
            CurrencyIsoCode = 'EUR',
            DividendPolicy__c = 'Accumulating',
            CurrencyHedging__c = 'False'
        );
        insert shc;
        return shc;
    }

    public static Product__c getProduct(Id recId, String code, String name, Boolean isActive){
      Product__c prod = new Product__c (RecordTypeId = recId,
                                 Name = code,
                                 Product_Name__c = name,
                                 Validity__c = isActive);
        insert prod;
        return prod;
    }
 
    public static ProjectShareclassChild__c createShareclassChild(Id parentId, String stage) {
        String rtDevName = (stage == 'Design' || stage == 'Proposal') ? 'DesignAndProposal' : stage;
        Id recordTypeId = getRecordTypeId('ProjectShareclassChild__c', rtDevName);
 
        ProjectShareclassChild__c child = new ProjectShareclassChild__c(
            ProjectShareclasses__c = parentId,
            RecordTypeId = recordTypeId,
            TECH_Childtype__c = rtDevName,
            Name = stage,
            Type__c = 'A',
            CurrencyIsoCode = 'EUR',
            DividendPolicy__c = 'Accumulating',
            CurrencyHedging__c = 'False'
        );
        insert child;
        return child;
    }
 
    public static ProjectChildJunction__c createJunction(Id childId, Id shcId) {
        ProjectChildJunction__c junction = new ProjectChildJunction__c(
            ProjectProductChild__c = childId,
            ProjectShareclass__c = shcId
        );
        insert junction;
        return junction;
    }
}