/** 
* @author: Pape DIOUF
* @date : Création 04/08/2016
* @date : Modification 04/08/2016
* @description : this Class allow to model Web site Webservices responses .
*/
global class WSResponseWrapper {
    
    public String        Status  {get;set;}
    public String        Message {get;set;}
    public List<SObject> Data    {get;set;}
    public String        TechnicalMessage {get;set;}
    
    //Webservice Status
    public static final String WS_STATUS_ERROR      = 'Error'; 
    public static final String WS_STATUS_ERROR_JSON = 'Incorrect JSON format';
    public static final String WS_STATUS_SUCCESS    = 'Success';
}