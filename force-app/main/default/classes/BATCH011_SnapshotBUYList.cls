/**
* @author Abderrahmane TRIA
* @date Creation 15/11/2020
* @group BATCH
* @description BATCH to The quarterly snapshots BUY List
*/
global class BATCH011_SnapshotBUYList implements Database.Batchable<sObject> 
{
    
    //Gather all the records I want to use in the execute method
    global Database.QueryLocator start(Database.BatchableContext BC) 
    {
        return Database.getQueryLocator([SELECT ID, Name, 
                                         Company__c, Company__r.BusinessDevelopmentRegion__c, Company__r.Name,
                                         Comment__c, Fund_Selector__c, Global_Product_Status__c, Local_Buy_List_Items__c, Local_Status__c, 
                                         Product__c, Product__r.Name, 
                                         Status__c, CreatedDate 
                                         FROM Product_Status__c ORDER BY CreatedDate ASC]); // Production source field is Created_Date__c
    }
    
    global void execute(Database.BatchableContext BC, List<Product_Status__c> lstProductStatus) 
    {
        
        //for creating new Snapshot batch.
        List<SnapshotBUYList__c> newSnapshot = new List<SnapshotBUYList__c>();
        
        for (Product_Status__c ps : lstProductStatus) {
            SnapshotBUYList__c snap = new SnapshotBUYList__c();
            
            snap.Buy_List__c = ps.Id; 
            snap.Name = ps.Name;
            snap.Comment__c = ps.Comment__c;
            snap.Fund_Selector__c = ps.Fund_Selector__c;
            snap.Global_Product_Status__c = ps.Global_Product_Status__c;
            snap.Local_Buy_List_Items__c = ps.Local_Buy_List_Items__c;
            snap.Product__c = ps.Product__c; 
            snap.CreationDate__c = System.now();
            
            // Report feilds
            snap.Product_Code__c = ps.Product__r.Name;
            snap.Company_BusinessDevelopmentRegion__c = ps.Company__r.BusinessDevelopmentRegion__c;
            snap.CompanyName__c = ps.Company__r.Name;
            snap.Company__c = ps.Company__c;
            snap.Status__c = ps.Status__c;            
            snap.Local_Status__c = ps.Local_Status__c;
            
            //load up the data for insert
            newSnapshot.add(snap);
        }
        try {
            if( newSnapshot.size()>0 )
                Database.insert(newSnapshot,false);
        } catch(Exception e) {
            System.debug('Snapshot BUY LIST - The following exception has occurred: ' + e);
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        system.debug('Batch Job is Complete -- BATCH011_SnapshotBUYList');
    }
}