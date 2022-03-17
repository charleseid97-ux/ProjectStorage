/** 
* @author: Briag Guemard
* @date : Creation 27/02/2017
* @date : Modification 27/02/2017
* @description : This Class allows to manage Etouches Authorization Token.
*/

public class EM013_Token {
    
    private static String CLASS_NAME = 'EM013_Token';
    
    public static void setToken(String newToken)
    {	
    	String methodName = 'setToken';
    	
    	WebserviceParameters__c TokenNewSet = WebserviceParameters__c.getAll().get('EtouchesAPI');
		 			
		Datetime myDT = Datetime.now();
		 			
		TokenNewSet.Token__c=newToken;
		
		TokenNewSet.LastUpdate__c=	 myDT;
			            
		update TokenNewSet;
		    	
    	ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[Token new] : '+ TokenNewSet.Token__c);
    	
    }
    
    public static String getToken()
    {
    	//Get the Token from the custom settings
    	
    	String methodName = 'getToken';
    	
    	String returnToken='';
    	
    	WebserviceParameters__c Tokenget = WebserviceParameters__c.getAll().get('EtouchesAPI');
		 		
		returnToken= Tokenget.Token__c;		
		
    	ObjectUtil.debugLogEnd(CLASS_NAME, methodName , '[Token get] : '+ Tokenget.Token__c);
    	
    	return returnToken;
    }
    
}