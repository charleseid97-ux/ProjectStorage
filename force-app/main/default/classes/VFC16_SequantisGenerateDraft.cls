/**
 * @description       : Appel du service Sequantis pour génération des documents PDF PRIIPS KID
 * @author            : Guillaume de ROUZE
 * @group             : 
 * @last modified on  : 06-10-2025
 * @last modified by  : Guillaume de ROUZE
**/

public with sharing class VFC16_SequantisGenerateDraft {
    public  Id recordId {get;set;}
    public static String selectedRecordId {get;set;}
    public List<SelectOption> shareclassOptions {get;set;}
    public static String pdf {get;set;} // PDF en base64  
    public Boolean showPDF {get; set;} // Indique si le PDF est disponible pour affichage 
    public static String infoMessage {get; set;} // Message d'info pour l'utilisateur 
    public static String errorMessage {get; set;} // Message d'erreur pour l'utilisateur
    public static String payloadDebug  {get; set;} // Variable pour debug du payload
    public static List<String> payloadKeys { get; set; }
    public static String payloadString { get; set; } // Variable pour stocker le payload JSON sérialisé (body)
    private  List <ProjectShareclass__c> shareclasses { get; set; }


    // Initialise le contrôleur et récupère les Share Classes du projet.
    public VFC16_SequantisGenerateDraft(ApexPages.standardController con){
        payloadDebug = '';
        showPDF = false;
        recordId = con.getId();
        system.debug('====VFC16_SequantisGenerateDraft=======recordId = ' + recordId);
        shareclasses= [Select Id,Name,Name__c from ProjectShareclass__c where ProjectProduct__c   =: recordId];
        shareclassOptions = new List<SelectOption>();
        shareclassOptions.add(new SelectOption('None','--- Select ---'));
        shareclassOptions.add(new SelectOption('updateAll','Update All ShareClass'));
        for(ProjectShareclass__c sc : shareclasses){
            String optionLabel = sc.Name__c != null ? sc.Name__c : sc.Name;
            shareclassOptions.add(new SelectOption(sc.Id, optionLabel));            
        }   
        system.debug('====VFC16_SequantisGenerateDraft=======shareclasses = ' + shareclasses);
    }
    
    

    // Bouton Draft : génère le PDF et le met dans pdf (base64)
    public  void genPDF() {
        errorMessage = ''; 
        infoMessage = '';  
        system.debug('====genPDF=======shareclasses = ' + shareclasses);
        if(selectedRecordId == 'updateAll'){
            updateAllShareClasses();
            showPDF = false;
            return;
        }
        

        try {
            // Étape 1 — Récupération du token OAuth2
            String token = fetchAccessToken('/rest/authentication');
            
            // Étape 2 — Appel du secallSequantisServicervice pour générer le PDF
            String pdfString = callSequantisService(token, selectedRecordId,true);
            if(pdfString.startsWith('<br/> generation failed')){
                errorMessage = pdfString;
                showPDF = false;
                return;
            }

            // Étape 3 — Encodage base64 pour renvoi au LWC
            pdf = pdfString;
            showPDF = true;
            
        } catch (CalloutException ce) {
            // Laisser remonter pour les tests
            throw ce;
        
        } catch (Exception e) {
            System.debug('Erreur globale : ' + e.getMessage());
            throw new AuraHandledException('Erreur API : ' + e.getMessage());
        }
    }


    // Met à jour l'ensemble des Share Classes du projet dans Sequantis.
    private void updateAllShareClasses() {   
        
            // Step 1 — Fetch authentication token
            String token = fetchAccessToken('/rest/authentication');

            // Step 2 — Iterate through all share class IDs
            for (ProjectShareclass__c shareClass : shareClasses) {
                Id shareClassId = shareClass.Id;
                try {
                    // Call the external Sequantis API for each share class
                    String response = callSequantisService(token, shareClassId, false);
                    if (response == 'OK') {
                        infoMessage += '<br/>ShareClass '+shareClass.Name__c+' updated successfully.';
                    } else {
                        errorMessage+= '<br/>Error updating ShareClass with ID ' + shareClassId + ': ' + response;
                    }                                    
                } catch (Exception innerEx) {
                    // Log or handle per-share-class failure
                    System.debug('Error updating ShareClass with ID ' + shareClassId + ': ' + innerEx.getMessage());
                }
            }

            if (errorMessage == '') {
                infoMessage = 'All ShareClasses processed.';
            }         
    }


    // Construit le payload configuré et appelle le service Sequantis.
    public  String callSequantisService(String token, String projectShareClassId,Boolean returnPDF) {
        payloadDebug = '';
        system.debug('====callSequantisService=======projectShareClassId = ' + projectShareClassId);
        Http httpReq = new Http();
        HttpRequest req = new HttpRequest();
        req.setTimeout(60000);
        Map<String, Object> payload  = new Map<String, Object>();

        // Construit les champs SOQL depuis les mappings configurés.
        List<SequantisDraftMapping__mdt> mappings = SequantisDraftMapping__mdt.getAll().values();

        Set<String> shareClassFields = new Set<String>{
            'Id', 'Name', 'Name__c', 'ProjectProduct__c'
        };
        Set<String> projectProductFields = new Set<String>{
            'Id', 'RecordTypeId', 'EndDate__c', 'internalShortName__c',
            'RecommendedHoldingPeriod__c', 'RecommendedHoldingPeriodUnit__c',
            'ParentProduct__r.ProductName__c'
        };

        addConfiguredQueryFields(mappings, shareClassFields, projectProductFields);

        String shareClassQuery = 'SELECT ' + String.join(new List<String>(shareClassFields), ',')
            + ' FROM ProjectShareclass__c WHERE Id = :projectShareClassId';

        ProjectShareclass__c projectShareClassRec =
            Database.query(shareClassQuery);

        Id projectProductId = projectShareClassRec.ProjectProduct__c;
        String projectProductQuery = 'SELECT ' + String.join(new List<String>(projectProductFields), ',')
            + ' FROM ProjectProduct__c WHERE Id = :projectProductId';

        ProjectProduct__c ProjectProductRec =
            Database.query(projectProductQuery);
        system.debug('====callSequantisService=======endDate = ' + ProjectProductRec.EndDate__c); 
        
        Id fundShareClassModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
        Id fundCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();

        // ---------------------------------------------------------------------
        // BLOCK Sequantis call: only allow sending within 1 month before launch date
        // Applies to Modification record types only (Product / Shareclass Modification)
        // ---------------------------------------------------------------------

       
        // Condition:
        // - record type is a modification RT
        // - launch date exists
        // - launch date is MORE than 1 month from today
     
        if (
            ProjectProductRec.RecordTypeId == fundShareClassModificationRecordTypeId
            && ProjectProductRec.EndDate__c != null
            && ProjectProductRec.EndDate__c > Date.today().addMonths(1)
        ) {
            system.debug('==1==callSequantisService=======generation failed : this project can be send to Sequantis only one month before the launch date');
            String launchDateStr = ProjectProductRec.EndDate__c.format();
             errorMessage = 'Generation failed : this project can be send to Sequantis only one month before the launch date (' + launchDateStr + ')';
             showPDF = false;
            return '<br/> Generation failed : this project can be send to Sequantis only one month before the launch date (' + launchDateStr + ')';
        }
       

        Narrative__c [] narratives = [ select  Type__c, Name, SubType__c
                                from Narrative__c where Type__c = 'Third Party' and SubType__c= 'ManagementCompany'                       
                                and Project__c = :ProjectProductRec.Id 
                                ];
        
        system.debug('====narratives=======narratives = ' + narratives);

                  
        // if internalShortName__c , RecommendedHoldingPeriod__c et RecommendedHoldingPeriodUnit__c  empty return error message
        String errorMsg = '';
        if (ProjectProductRec.internalShortName__c == null ){
            errorMsg += '<br/> Internal Short Name is required. ';            
        }
          
        if (errorMsg != ''){
            errorMsg = '<br/> generation failed due to missing required fields '+projectShareClassRec.Name__c+' : '+errorMsg;
            return errorMsg;
        }

        // Ajout des valeurs dynamiques configurées dans le Custom Metadata
        payload.put('genereKID', returnPDF);
        addConfiguredMappings(payload, ProjectProductRec, projectShareClassRec, mappings);
        // Valeurs calculées ne provenant pas directement d'un champ Salesforce
        payload.put('shareClassId','');
        payload.put('userMail', UserInfo.getUserEmail());

        if (ProjectProductRec.ParentProduct__r != null &&
            ProjectProductRec.ParentProduct__r.ProductName__c != null) {
            payload.put('parentProduct', ProjectProductRec.ParentProduct__r.ProductName__c);
        }

        Id rtId = ProjectProductRec.RecordTypeId;

        // Contrôles obligatoires propres à Fund Creation
        if (rtId == fundCreationRecordTypeId) {
            if (ProjectProductRec.RecommendedHoldingPeriod__c == null ){
                errorMsg += '<br/> Recommended Holding Period is required. ';
            }
            if (ProjectProductRec.RecommendedHoldingPeriodUnit__c == null ){
                errorMsg += '<br/> Recommended Holding Period Unit is required. ';
            }

            if(narratives.size() > 0 ){
                payload.put('managementCompany', narratives[0].Name);
            }
        }



        //payload.put('fundcurrency',  ProjectProductRec.BaseCurrency__c); //champ pas encore créé coté Sequantis
        //payload.put('????'  shareClassInvestmentObjectiveNoHTML
        //payload.put('riskNarrative', 'L\'indicateur synthétique de risque indique la probabilité que ce produit...');
        //payload.put('sortieAnticipee','');

        req.setHeader('Authorization', 'Bearer ' + token); 
        req.setHeader('Content-Type','application/json');
        req.setMethod('POST');
        req.setEndpoint('callout:Sequantis/rest/CARMIGNAC_PROJECT');
        

        // Sérialisation du Map en JSON
        system.debug('payload====='+JSON.serialize(payload));
        payloadKeys = new List<String>(payload.keySet());
        payloadString = JSON.serialize(payload);
        //payloadDebug= payloadString;
        req.setBody(payloadString);

        HttpResponse res = httpReq.send(req);
        system.debug('==============Response status: ' + res.getStatusCode());
        system.debug('==============Response body: ' + res.getBody());    
        if( res.getStatusCode() == 202 ){
            return ('OK')   ;            
        }else if (res.getStatusCode() != 200) {
           errorMessage='Erreur génération PDF (' + res.getStatusCode() + ') : ' + res.getBody();
        }

        return EncodingUtil.base64Encode(res.getBodyAsBlob());
    }


    /**
     * Ajoute au payload les mappings actifs configurés dans SequantisDraftMapping__mdt.
     */
    private void addConfiguredMappings(
        Map<String, Object> payload,
        ProjectProduct__c projectProductRec,
        ProjectShareclass__c projectShareClassRec,
        List<SequantisDraftMapping__mdt> mappings
    ) {
        Schema.RecordTypeInfo recordTypeInfo = Schema.SObjectType.ProjectProduct__c
            .getRecordTypeInfosById()
            .get(projectProductRec.RecordTypeId);

        String recordTypeName = recordTypeInfo.getDeveloperName();

        // Chaque Custom Metadata représente une clé du payload Sequantis.
        for (SequantisDraftMapping__mdt mapping : mappings) {
            if (String.isBlank(mapping.PayloadKey__c)
                || String.isBlank(mapping.SourceObject__c)
                || String.isBlank(mapping.SourceField__c)
                || !isMappingValidForRecordType(mapping.RecordTypes__c, recordTypeName)) {
                continue;
            }

            SObject sourceRecord = getMappingSourceRecord(
                mapping.SourceObject__c,
                projectProductRec,
                projectShareClassRec
            );

            // Ignore une configuration dont l'objet source n'est pas supporté.
            if (sourceRecord == null) {
                continue;
            }

            Object value = sourceRecord.get(mapping.SourceField__c);

            value = transformMappingValue(value, mapping.Transformation__c);
            payload.put(mapping.PayloadKey__c, value);
        }
    }


    /**
     * Retourne l'enregistrement Salesforce contenant le champ configuré.
     */
    private SObject getMappingSourceRecord(
        String sourceObject,
        ProjectProduct__c projectProductRec,
        ProjectShareclass__c projectShareClassRec
    ) {
        if (sourceObject == 'ProjectProduct__c') {
            return projectProductRec;
        }

        if (sourceObject == 'ProjectShareclass__c') {
            return projectShareClassRec;
        }

        return null;
    }


    /**
     * Vérifie si le mapping est applicable au Record Type courant.
     * Un champ RecordTypes__c vide signifie que le mapping est valide pour tous les Record Types.
     */
    private Boolean isMappingValidForRecordType(String configuredRecordTypes, String recordTypeName) {
        if (String.isBlank(configuredRecordTypes)) {
            return true;
        }

        // Les DeveloperName des Record Types sont séparés par des points-virgules.
        for (String configuredRecordType : configuredRecordTypes.split(';')) {
            if (configuredRecordType.trim() == recordTypeName) {
                return true;
            }
        }

        return false;
    }





    /**
     * Applique la transformation définie dans le Custom Metadata.
     */
    private Object transformMappingValue(Object value, String transformation) {
        if (String.isBlank(transformation) || transformation == 'NONE') {
            return value;
        }

        // HTML conserve le comportement historique : null devient une chaîne vide.
        if (transformation == 'HTML') {
            return escapeHTML(value == null ? null : String.valueOf(value));
        }

        if (transformation == 'YES_NO') {
            return value == null ? null : formatYesNoField(String.valueOf(value));
        }

        return value;
    }


    /* Escape HTML tags from text
    except bold, italic and paragraph
    */
    private String escapeHTML(String inputText) {
        if (inputText == null) {
            return '';
        }

        // Remove all HTML tags except p, i, b and strong, including tags with attributes
        String noHTML = inputText.replaceAll(
            '<(?!\\/?(?:p|i|b|strong)(?:\\s[^>]*)?>)[^>]+>',
            ' '
        );

        // Clean up multiple spaces
        inputText = noHTML.replaceAll('\\s+', ' ').trim();
        return inputText;
    }   


    //convert text field 'Yes'/'No'/Neutral to Boolean
    private Boolean formatYesNoField(String fieldValue){
        if(fieldValue == 'Yes'){
            return true;
        } else if(fieldValue == 'No'){
            return false;
        }else{
            return null;
        }
    }
    

   /**
     * Récupère un access token via le Named Credential 'Sequantis'
     * @param tokenPath chemin relatif de l’endpoint token (ex: '/oauth/token')
     */
     public static String fetchAccessToken(String tokenPath) {
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');

        // Utilise le Named Credential
        //req.setEndpoint('callout:Sequantis' + tokenPath);
        req.setEndpoint('callout:Sequantis/rest/authentication/');
        req.setHeader('Content-Type', 'application/json');
        String username = Label.seqlgn;
        String password = Label.seqpwd;

        req.setBody('{"userName": "'+ username +'", "password": "'+ password +'"}');

        
        Http http = new Http();
        HTTPResponse res = http.send(req);
        Integer code = res.getStatusCode();
        if (code < 200 || code >= 300) {
            // Log utile + exception claire
            System.debug(LoggingLevel.ERROR, 'Token call failed: ' + code + ' - ' + res.getBody());
            throw new CalloutException('OAuth token request failed: HTTP ' + code);
        } else {
            System.debug('*** Token : ' + res.getBody());
            return res.getBody();
        }

        //OAuthTokenResponse token = (OAuthTokenResponse) JSON.deserialize(res.getBody(), OAuthTokenResponse.class);
        //if (token == null || String.isBlank(token.access_token)) {
        //    throw new CalloutException('OAuth token response missing access_token');
        //}
        //return token.access_token;

    }
        /**
     * Ajoute aux requêtes SOQL les champs déclarés dans les mappings Sequantis.
     */
    private void addConfiguredQueryFields(
        List<SequantisDraftMapping__mdt> mappings,
        Set<String> shareClassFields,
        Set<String> projectProductFields
    ) {
        Map<String, Schema.SObjectField> shareClassFieldMap =
            Schema.SObjectType.ProjectShareclass__c.fields.getMap();
        Map<String, Schema.SObjectField> projectProductFieldMap =
            Schema.SObjectType.ProjectProduct__c.fields.getMap();

        // Seuls les champs réellement présents sur l'objet sont ajoutés au SELECT.
        for (SequantisDraftMapping__mdt mapping : mappings) {
            if (String.isBlank(mapping.SourceField__c)) {
                continue;
            }

            if (mapping.SourceObject__c == 'ProjectShareclass__c'
                && shareClassFieldMap.containsKey(mapping.SourceField__c)) {
                shareClassFields.add(mapping.SourceField__c);
            } else if (mapping.SourceObject__c == 'ProjectProduct__c'
                && projectProductFieldMap.containsKey(mapping.SourceField__c)) {
                projectProductFields.add(mapping.SourceField__c);
            }
        }
    }
}