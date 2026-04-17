/** 
* @author: Adolphe SONKO
* @date : Création 13/09/2016
* @date : Modification 13/09/2016
* @description : This Class allows to manage triggers in Relationship Status entity.
*/

public class SM009_RelationshipStatusTriggerHandler {

	
    private static String  CLASS_NAME = SM009_RelationshipStatusTriggerHandler.class.getName();
    
     /**
     * @auteur : Adolphe SONKO
     * @date : Creation 13/09/2016
     * @date : Modification 13/09/2016
     * @description : This method 
     * @param : A list of triggered relationship status
     * @return : N/A.
     */
    public static void onAfterUpdate(List<RelationshipStatus__c> relationships , Map<Id, RelationshipStatus__c> oldRelationships){
        
        String methodName = 'onAfterUpdate';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, ' [relationships] : ' + relationships);
        
        for(RelationshipStatus__c relstatus : relationships){
            if(relstatus != oldRelationships.get(relstatus.Id)){
                if( (relstatus.CompanyIsGAM__c == false && !ObjectUtil.isEmpty(relstatus.GlobalAccount__c)) 
              		 ||  relstatus.CompanyIsGAM__c == true){
				
                    // For HOC
                    EM008_RelationshipStatusSendEmail.RelationshipStatus_EmailAlert1();
                       
                    // For related companies
                    if(relstatus.CompanyIsGAM__c == true){    
                        EM008_RelationshipStatusSendEmail.RelationshipStatus_EmailAlert2(new Set<String> {relstatus.Company__c}); // the company is a GAM
                    } else {
                        EM008_RelationshipStatusSendEmail.RelationshipStatus_EmailAlert2(new Set<String> {relstatus.GlobalAccount__c}); // the company is not a GAM
                    }
        		}
            }
            
        	
        }                
    }       
}