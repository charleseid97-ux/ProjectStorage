@isTest(seeAllData=false)
public class ContactEngagementUtilTest {
    @isTest
    static void testContactDigitalInteractionMetrics() {
        List<Digital_Interaction__c> dis = new List<Digital_Interaction__c>();
        dis = [SELECT Contact__c, 
               URL__c, 
               Content_Item_Name__c, 
               MDS_ID__c, 
               Type__c, 
               Thematic__c,
               Date_of_Interaction__c, 
               CreatedDate,
               LastModifiedDate
               FROM Digital_Interaction__c WHERE Contact__c =: '0035800000rKa3QAAS'];
        
        Test.startTest();
        ContactEngagementUtil.getDIMetricData(null, dis);
        Map<String, Object>  getDIMetrics = ContactEngagementUtil.getContactDigitalInteractionMetrics('0035800000rKa3QAAS', 'all');
        ContactEngagementUtil.getContactDigitalInteractionMetrics('0035800000rKa3QAAS', 'Letter from Edouard Carmignac');
        
        System.assert(getDIMetrics != null);
        Test.stopTest();
    }
    
    @isTest
    static void testDrillDownData() {
        Test.startTest();
        ContactEngagementUtil.getDrillDownData('0035800000rKa3QAAS', 'Letter from Edouard Carmignac', 'all');
        ContactEngagementUtil.getDrillDownData('0035800000rKa3QAAS', 'Letter from Edouard Carmignac', 'Letter from Edouard Carmignac');
        ContactEngagementUtil.getDrillDownData('0035800000rKa3QAAS', 'Letter from Edouard Carmignac', 'Market Analysis');
        Test.stopTest();
    }
    
    @isTest
    static void testCompanyEngagementMetrics() {
        Test.startTest();
        ContactEngagementUtil.getCompanyEngagementMetrics('0015800000l6ttGAAQ');
        Test.stopTest();
    }
    
    @isTest
    static void testDigitalInteractionByMonths() {        
        Test.startTest();
        ContactEngagementUtil.digitalInteractionByMonths('0035800000rKa3QAAS');
        Test.stopTest();
    }    
}