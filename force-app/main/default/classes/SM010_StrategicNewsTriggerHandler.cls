/** 
* @author: Adolphe SONKO
* @date : Création 13/09/2016
* @date : Modification 13/09/2016
* @description : This Class allows to manage triggers in SM010_Strategic News Status entity.
*/


public class SM010_StrategicNewsTriggerHandler {
    
    private static String CLASS_NAME = SM010_StrategicNewsTriggerHandler.class.getName();
    
    /**
* @auteur : Adolphe SONKO
* @date : Creation 14/09/2016
* @date : Modification 15/09/2016
* @description : This method 
* @param : List<StrategicNews> StratNews This parameter is the the new triggered StrategicNews.
* @return : N/A.
*/
    public static void onAfterInsert(List<StrategicNews__c> StratNews){
        
        String methodName = 'onAfterInsert';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [StrategicNews__c] : ' + StratNews);
        
        for(StrategicNews__c sn : StratNews){
            List<Strategic_News_Products__c> lstSNPToInsert = new List<Strategic_News_Products__c>();
            
            if (!String.isEmpty(sn.Product_Ids__c)) {
                List<String> lstIdProducts = sn.Product_Ids__c.split(';');
                set<string> setIdProducts = new set<string>(lstIdProducts);
                for (String pId : setIdProducts){
                    Strategic_News_Products__c snp = new Strategic_News_Products__c();
                    snp.Product__c	= pId;
                    snp.Strategic_News__c = sn.Id;
                    lstSNPToInsert.add(snp);
                }
            }
            System.debug('===> '+lstSNPToInsert);
            if(lstSNPToInsert.size() > 0){
                try {
                    insert lstSNPToInsert;
                } catch (Exception exp) {
                    throw new AuraHandledException(exp.getMessage());
                }
            }
            //if(((sn.CompanyIsGAM__c == false && !ObjectUtil.isEmpty(sn.GlobalAccount__c))
            //     || sn.CompanyIsGAM__c == true)){
            
            //      // Send email to only the HOC
            //      if(sn.Type__c == 'Agreement & Pricing'){ // 'Agreement & Pricing' --> Send email to related accounts
            //         EM010_StrategicNewsSendEmail.StrategicNews_EmailAlert2();
            //      } 
            
            //      if(sn.Type__c != 'Agreement & Pricing'){ // NOT 'Agreement & Pricing' --> Send email to related accounts
            //         if(sn.CompanyIsGAM__c == true){    
            //              EM010_StrategicNewsSendEmail.StrategicNews_EmailAlert1(new Set<String> {sn.Company__c}); // the company is a GAM
            //          } else {
            //              EM010_StrategicNewsSendEmail.StrategicNews_EmailAlert1(new Set<String> {sn.GlobalAccount__c}); // the company is not a GAM
            //          }
            //      }   
            
            // }     
            
            // if((sn.CompanyIsGAM__c == false && ObjectUtil.isEmpty(sn.GlobalAccount__c))){				
            //     EM010_StrategicNewsSendEmail.StrategicNews_EmailAlert3(sn.Company__c);
            // }
            
        }
    }       
}