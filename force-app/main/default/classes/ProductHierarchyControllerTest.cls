@isTest(SeeAllData = true)
public class ProductHierarchyControllerTest 
{
    public static final String TECH_ContactTechSUNID = '4569872';
    public static final String TECH_WebSiteID = '5483465';
    public static final String PROFESSIONAL_EMAIL = 'ProfessionalEmailproduct@carmignac.com';
    public static final String PERSONAL_EMAIL = 'PersonalEmailproduct@carmignac.com';
    public static final String TEAM_EMAIL = 'TeamEmailproduct@carmignac.com';
    
    public static final String TECH_ContactTechSUNID2 = '45698722';
    public static final String TECH_WebSiteID2 = '54834652';
    public static final String PROFESSIONAL_EMAIL2 = 'ProfessionalEmailproduct2@carmignac.com';
    public static final String PERSONAL_EMAIL2 = 'PersonalEmailproduct2@carmignac.com';
    public static final String TEAM_EMAIL2 = 'TeamEmailproduct2@carmignac.com';
    
    //@testSetup
    /*public static void testData()
    { 
            List<Product__c> products = new List<Product__c>();
            
            Product__c p3 = new Product__c(Name='PStrategy2', Product_Name__c='Product Strategy', Record_Type_Name__c = 'Asset Class', Asset_Class_Code__c = 'EQTY', Sub_Asset_Class_Code__c = 'GLAL');
            Insert p3;
            
            Product__c p2 = new Product__c(Name='PStrategy2', Product_Name__c='Product Strategy', Record_Type_Name__c = 'Regional Focus', Asset_Class_Code__c = 'EQTY', Sub_Asset_Class_Code__c = 'GLAL', Asset_Class__c = p3.Id);
            Insert p2;
            
            Product__c p1 = new Product__c(Name='PStrategy2', Product_Name__c='Product Strategy', Record_Type_Name__c = 'Strategy', Asset_Class_Code__c = 'EQTY', Sub_Asset_Class_Code__c = 'GLAL', Sub_Asset_Class__c = p2.Id);
            Insert p1;
            
            Product__c p0 = new Product__c(Name='PStrategy', Product_Name__c='Product Strategy', Record_Type_Name__c = 'Fund', Asset_Class_Code__c = 'EQTY', Sub_Asset_Class_Code__c = 'GLAL', Strategy__c = p1.Id);
        
        	Insert p0;
        
        	Share_Class__c share = new Share_Class__c();
        
        	share.Fund__c = p0.id;
        
        	insert share;
    }*/
    
    
    @isTest
    public static void productFundHirarchyTest() 
    {
            
        
        	Id prodId1 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, 
                          Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c 
                          FROM Product__c 
                          WHERE Record_Type_Name__c = 'Fund' 
                          AND Strategy__c != null AND Validity__c = true
                          LIMIT 1].Id;
            
            Id prodId2 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Strategy'  
                          AND Sub_Asset_Class__c != null 
                          AND Asset_Class__c != null 
                          LIMIT 1].Id;
        
        	Id prodId3 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Regional Focus' 
                          LIMIT 1].Id;
        
        	Id prodId4 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Asset Class'  
                          LIMIT 1].Id;
        
        
            test.startTest();
            
            productHierarchyController.getProductHierarchy(prodId1, true, true, true);

        	//productHierarchyController.getProductHierarchy(prodId2, true, true, true);
        
        	//productHierarchyController.getProductHierarchy(prodId3, true, true, true);
        
        	//productHierarchyController.getProductHierarchy(prodId4, true, true, true);
        
            test.stopTest();
            
    }
    
    @isTest
    public static void productStrategyHirarchyTest() 
    {
            
        
        	Id prodId1 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Fund' 
                          AND Strategy__c != null 
                          LIMIT 1].Id;
            
            Id prodId2 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Strategy'  
                          AND Sub_Asset_Class__c != null 
                          AND Asset_Class__c != null 
                          LIMIT 1].Id;
        
        	Id prodId3 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Regional Focus' 
                          LIMIT 1].Id;
        
        	Id prodId4 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Asset Class'  
                          LIMIT 1].Id;
        
        
            test.startTest();
            
        	productHierarchyController.getProductHierarchy(prodId2, true, true, true);
               
            test.stopTest();
            
    }
    
    
    @isTest
    public static void productRegFocusHirarchyTest() 
    {
            
        
        	Id prodId1 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Fund' 
                          AND Strategy__c != null 
                          LIMIT 1].Id;
            
            Id prodId2 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Strategy'  
                          AND Sub_Asset_Class__c != null 
                          AND Asset_Class__c != null 
                          LIMIT 1].Id;
        
        	Id prodId3 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Regional Focus' 
                          LIMIT 1].Id;
        
        	Id prodId4 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Asset Class'  
                          LIMIT 1].Id;
        
        
            test.startTest();
                    
        	productHierarchyController.getProductHierarchy(prodId3, true, true, true);
                
            test.stopTest();
            
    }
    
    @isTest
    public static void productAssetClassHirarchyTest() 
    {
            
        
        	Id prodId1 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Fund' 
                          AND Strategy__c != null 
                          LIMIT 1].Id;
            
            Id prodId2 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Strategy'  
                          AND Sub_Asset_Class__c != null 
                          AND Asset_Class__c != null 
                          LIMIT 1].Id;
        
        	Id prodId3 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Regional Focus' 
                          LIMIT 1].Id;
        
        	Id prodId4 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Asset Class'  
                          LIMIT 1].Id;
        
        
            test.startTest();
        
        	productHierarchyController.getProductHierarchy(prodId4, true, true, true);
        
            test.stopTest();
            
    }
    
    @isTest
    public static void allProductHirarchyTest() 
    {
            
        
        	Id prodId1 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Fund' 
                          AND Strategy__c != null 
                          LIMIT 1].Id;
            
            Id prodId2 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Strategy'  
                          AND Sub_Asset_Class__c != null 
                          AND Asset_Class__c != null 
                          LIMIT 1].Id;
        
        	Id prodId3 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Regional Focus' 
                          LIMIT 1].Id;
        
        	Id prodId4 = [SELECT Id, Name, SRI__c, Record_Type_Name__c, Sub_Asset_Class__r.Name, Sub_Asset_Class__r.Record_Type_Name__c, Sub_Asset_Class__r.Validity__c, Sub_Asset_Class__c, Asset_Class__r.Record_Type_Name__c, Asset_Class__r.Name, Asset_Class__r.Validity__c, Asset_Class__c, Strategy__c, Strategy__r.Name, Strategy__r.SRI__c, Strategy__r.Record_Type_Name__c, Strategy__r.Investment_Style__c, Strategy__r.Validity__c, Investment_Style__c, Validity__c FROM Product__c 
                          WHERE Record_Type_Name__c = 'Asset Class'  
                          LIMIT 1].Id;
        
            test.startTest();
        
        	ProductHierarchyAllController.getProductHierarchy(null, true, true, true,'All countries');
        
        	ProductHierarchyAllController.getProductHierarchy(null, true, true, false,'All countries');
        
        	ProductHierarchyAllController.getProductHierarchy(null, true, false, false,'All countries');
        
        	ProductHierarchyAllController.getProductHierarchy(null, true, false, true,'All countries');
        
        	ProductHierarchyAllController.getProductHierarchy(null, false, false, false,'All countries');

            test.stopTest();
            
    }
}