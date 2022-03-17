public class MyTableauController {
    // Holds a reference to the account associated with the page controller
    private final User user;

    // Hold the username of a static Tableau username as a default
    // private static final String DEFAULT_TABLEAU_USERNAME = 'TBL_TST_Admin';

    // The extension constructor initializes the private member
    // variable acct by using the getRecord method from the standard
    // controller.
    public MyTableauController(ApexPages.StandardController stdController) {
        this.user = (User)stdController.getRecord();
        init();
    }

    //Initializes the controller.
    public MyTableauController() {
        this.user = null;
        init();
    }

    // Load the tableau username into a static at page load since this won't change
    private void init() {
    }

    // This is the method that actually determines which field you want to use as the
    // source of the mapping to a Tableau user
    // In our example we use a static string "sfUser" as the string to map.
    private String myCustomFieldMapper() {
        // This customer written class does the "work" need to map and get a Tableau username
        // In our example we use a static string "sfUser" as the string to map.
        User loggedInUser = [SELECT TableauLogin__c FROM User WHERE Id = :UserInfo.getUserId() ]; 
        return loggedInUser.TableauLogin__c;

    }

    private String myCustomFieldMapperFederationId() {
        // This customer written class does the "work" need to map and get a Tableau username
        // In our example we use a static string "sfUser" as the string to map.
        User loggedInUser = [SELECT FederationIdentifier FROM User WHERE Id = :UserInfo.getUserId() ]; 
        return loggedInUser.FederationIdentifier;

    }

    /**
    * Gets the signed identity; always want to generate this in a getter since the constructor
    * only gets called on original page load and timestamp will skew
    */
    public String getSignedIdentity() {
        String signedIdentity = TableauSparklerUtilities.generateSignedIdentity(this.myCustomFieldMapper());
        system.debug('####:'+signedIdentity);
        return signedIdentity;
    }
    
    public String getWebSite() {
        WebserviceParameters__c param_setting = ObjectUtil.getWebserviceParametersByName('EFLAccess');  
        String webSite = param_setting.Endpoint__c;
        return webSite;
    }
    
     public String getTableauLogin() {          
    string TableauLogin  = this.myCustomFieldMapper();
        return TableauLogin;
    }   

     public String getFederationIdentifier() { 
        String FederationIdentifier = this.myCustomFieldMapperFederationId();
        return FederationIdentifier;
    }       



    
}