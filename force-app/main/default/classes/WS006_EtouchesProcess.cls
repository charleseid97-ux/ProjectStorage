/** 
 * @author : Briag GUEMARD
 * @date : Creation 12/04/2017
 * @date : Modification 12/04/2017
 * @description : web service REST class to handle the get of the status of the processus ID.
 */
@RestResource(urlMapping='/EtouchesProcess/*')
global class WS006_EtouchesProcess {
	
	 private static String  CLASS_NAME = WS006_EtouchesProcess.class.getName();
    
    
     private static list<EM023_Log.errorToLog> listLogError = new list<EM023_Log.errorToLog>();
    
		/** 
 		* @author : Briag GUEMARD
		* @date : Creation 12/04/2017
		* @date : Modification 12/04/2017
    	*/
  
  	
     @HttpPost
     global static WSResponseWrapper doPut(GetProcessID getProcessID){
     	
     	String methodName = 'doPost';
     	
     	WSResponseWrapper response = new WSResponseWrapper();
         
        Savepoint sp = Database.setSavepoint();
        
		//bgu test
       try{
        	
        	response = SM019_Process_Id.getProcessStatus(getProcessID);
        	
        }catch(DmlException e){
        	Database.rollback(sp);
        	
        	response.Message = e.getMessage();
            response.Status = WSResponseWrapper.WS_STATUS_ERROR;
            response.TechnicalMessage = e.getStackTraceString();
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName + '  @RestResource(urlMapping=\'/EtouchesProcess/*\') - Type : DML Excepttion - Response Message  : ' + e.getMessage() +
        	' / Response Status : ' + WSResponseWrapper.WS_STATUS_ERROR +
        	' / Response TechnicalMessage : ' + e.getStackTraceString();   
        	  
        	
        	String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM019_Process_Id.getProcessStatus(getProcessID); / getProcessID : ' + getProcessID.ProcessID ; 
        	
        	
        	EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
        	newErro.dateCreate = Datetime.now();
        	newErro.interfaceName ='WS006_EtouchesProcess';
        	newErro.Data = Data;
        	newErro.error = fullResp;
		        	
        	listLogError.add(newErro);
        	
        	
        }catch(Exception e){
        	Database.rollback(sp);
        	
        	response.Message = e.getMessage();
            response.Status = WSResponseWrapper.WS_STATUS_ERROR;
            response.TechnicalMessage = e.getStackTraceString();
            ObjectUtil.debugLog(CLASS_NAME, methodName, ' [DmlException] : ' + e.getMessage() + ' - ' + e.getStackTraceString() );
            
            String fullResp = methodName + '  @RestResource(urlMapping=\'/EtouchesProcess/*\') - Type : DML Excepttion - Response Message  : ' + e.getMessage() +
        	' / Response Status : ' + WSResponseWrapper.WS_STATUS_ERROR +
        	' / Response TechnicalMessage : ' + e.getStackTraceString();   
        	
        	
        	
        	String Data =  'Class name :' + CLASS_NAME + '  Methodname : SM019_Process_Id.getProcessStatus(getProcessID); / getProcessID : ' + getProcessID.ProcessID ; 
        	
        	
        	
        	EM023_Log.errorToLog newErro = new EM023_Log.errorToLog();
        	newErro.dateCreate = Datetime.now();
        	newErro.interfaceName ='WS006_EtouchesProcess';
        	newErro.Data = Data;
        	newErro.error = fullResp;
		        	
        	listLogError.add(newErro);
        	
        	
        } 
        //String strWSResponse = JSON.serialize(response);
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, ' [response] : '+ response);
        
        EM023_Log.insertLogError(listLogError);
        
        
        return response;
     }
     
    
    /** 
 	* @author : Briag GUEMARD
	* @date : Creation 12/04/2017
	* @date : Modification 12/04/2017
    * @description : This class model the website contact object used as Webservice parameter.
    */
    
    global class GetProcessID{
        global String ProcessID;
       
        
    }
    
     
    	
    	
}