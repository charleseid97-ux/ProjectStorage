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
    public static Map<String, Object> payloadDebug  {get; set;} // Payload pour l'appel du service Sequantis
    public static List<String> payloadKeys { get; set; }
    public static String payloadString { get; set; }
    private  List <ProjectShareclass__c> shareclasses { get; set; }


    public VFC16_SequantisGenerateDraft(ApexPages.standardController con){
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
        system.debug('====genPDF=======shareclasses = ' + shareclasses);
        if(selectedRecordId == 'updateAll'){
            updateAllShareClasses();
            showPDF = false;
            return;
        }
        

        //try {
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
            
       /* } catch (Exception e) {
            System.debug('Erreur globale : ' + e.getMessage());
            throw new AuraHandledException('Erreur API : ' + e.getMessage());
        }*/
    }

    private void updateAllShareClasses() {   
        errorMessage = ''; 
        infoMessage = '';  
            // Step 1 — Fetch authentication token
            String token = fetchAccessToken('/rest/authentication');

            // Step 2 — Iterate through all share class IDs
            for (ProjectShareclass__c shareClass : shareClasses) {
                Id shareClassId = shareClass.Id;
               // try {
                    // Call the external Sequantis API for each share class
                    String response = callSequantisService(token, shareClassId, false);
                    if (response == 'OK') {
                        infoMessage += '<br/>ShareClass '+shareClass.Name__c+' updated successfully.';
                    } else {
                        errorMessage+= '<br/>Error updating ShareClass with ID ' + shareClassId + ': ' + response;
                    }                                    
               // } catch (Exception innerEx) {
                    // Log or handle per-share-class failure
                   // System.debug('Error updating ShareClass with ID ' + shareClassId + ': ' + innerEx.getMessage());
                //}
            }
            if (errorMessage == '') {
                infoMessage = 'All ShareClasses processed.';
            }        
    }
    public  String callSequantisService(String token, String projectShareClassId,Boolean returnPDF) {
        system.debug('====callSequantisService=======projectShareClassId = ' + projectShareClassId);
        Http httpReq = new Http();
        HttpRequest req = new HttpRequest();
        String endpoint;
        Map<String, Object> payload  = new Map<String, Object>();

        // Requetage des champs 
        projectShareClass__c projectShareClassRec = [SELECT Id, Name,Name__c, ISIN__c, Currency__c, MaxRedemptionFee__c, EffectivePerfFees__c, MaxSubscriptionFee__c, EffectiveManagementFees__c, EffectiveServiceFees__c, TransactionCosts__c,
                                ProxyRisk__c, CurrencyHedging__c, HasPerfFees__c, DividendPolicy__c, Status__c, 
                                Retail__c, Professional__c, EligibleCounterparty__c, Basic__c, Informed__c, Advanced__c, ExpertGermany__c, LowestRiskTolGer__c, CanNot__c, CanLimited__c, NoNeedCapGuarantee__c, CanNoLimit__c, Preservation__c, CapitalGrowth__c, Income__c,
                                LeveragedReturn__c, PensionSchemeGer__c, MayTerminateEarlier__c, ExecutionOnly__c, AppropTest__c, InvestAdvice__c, PortfolioManagement__c,
                                ProjectProduct__c, ShareclassInvestmentObjective__c, InvestorType__c,PerformanceFeeUCITSKIID__c,PerformanceFeeEPTKID__c, MaxPerfFees__c,
                                PerformanceFeeMethod__c
                                FROM projectShareClass__c
                                WHERE id = :projectShareClassId];
        
        ProjectProduct__c ProjectProductRec = [SELECT Id, Name, ProductName__c, NAVFrequency__c, RecommendedHoldingPeriod__c,RecommendedHoldingPeriodUnit__c, DomiciledIn__c, LegalForm__c,
                                BenchmarkName__c, MaturityDate__c, CutOffTime__c, AssetClass__c, LEICode__c, ESGLabel__c,
                                MinSustainableInvest__c, MinTaxAlignment__c, SFDRCategory__c, IsUsingPAI__c, EET20080__c, EET20190__c, 
                                EET20200__c, EET20210__c, EET20400__c, EET20430__c, EET20460__c, EET20250__c, AMFESGCommunication__c, HasCarbonTarget__c, EET60440__c, FundSpecificExclusions__c,
                                EndDate__c, Product__c,ParentProduct__c,InvestmentObjective__c,IntentedRetailInvestor__c,ReasonForRHP__c,RedeemCondition__c,LMT__c,
                                internalShortName__c,TECH_RTName__c, BaseCurrency__c,RecordTypeId,DefaultLanguage__c
                            FROM ProjectProduct__c
                            WHERE Id = :projectShareClassRec.ProjectProduct__c];
                  
        // if internalShortName__c , RecommendedHoldingPeriod__c et RecommendedHoldingPeriodUnit__c  empty return error message
        String errorMsg = '';
        if (ProjectProductRec.internalShortName__c == null ){
            errorMsg += '<br/> Internal Short Name is required. ';            
        }
        if (ProjectProductRec.RecommendedHoldingPeriod__c == null ){
            errorMsg += '<br/> Recommended Holding Period is required. ';
        }
        if (ProjectProductRec.RecommendedHoldingPeriodUnit__c == null ){
            errorMsg += '<br/> Recommended Holding Period Unit is required. ';
        }   
        if (errorMsg != ''){
            errorMsg = '<br/> generation failed due to missing required fields '+projectShareClassRec.Name__c+' : '+errorMsg;
            return errorMsg;
        }
        // Ajout des champs
        payload.put('genereKID', returnPDF);
        
        payload.put('portfolioManagement', projectShareClassRec.PortfolioManagement__c); //values : P,B
        payload.put('investmentAdvice', projectShareClassRec.InvestAdvice__c); //values : P,B
        payload.put('executionWithAppropriatenessTestOrNonAdvisedServices', projectShareClassRec.AppropTest__c); //values : P,B
        payload.put('executionOnly', projectShareClassRec.ExecutionOnly__c); //values : P,B
        payload.put('mayBeTerminatedEarly', formatYesNoField(projectShareClassRec.MayTerminateEarlier__c)); //values : Yes, No, NA
        payload.put('returnProfilePensionSchemeGermany', formatYesNoField(projectShareClassRec.PensionSchemeGer__c)); //values : Yes, No, Neutral
        payload.put('optionOrLeveragedReturnProfile', formatYesNoField(projectShareClassRec.LeveragedReturn__c )); //values : Yes, No, Neutral
        payload.put('returnProfileIncome',  formatYesNoField(projectShareClassRec.Income__c)); //values : Yes, No, Neutral
        payload.put('returnProfileGrowth', formatYesNoField(projectShareClassRec.CapitalGrowth__c )); //values : Yes, No, Neutral
        payload.put('returnProfilePreservation', formatYesNoField(projectShareClassRec.Preservation__c )); //values : Yes, No, Neutral
        payload.put('lossBeyondCapital', formatYesNoField(projectShareClassRec.CanNoLimit__c )); //values : Yes, No, Neutral
        payload.put('noCapitalGuarantee', formatYesNoField(projectShareClassRec.NoNeedCapGuarantee__c)); //values : Yes, No, Neutral
        payload.put('limitedCapitalLoss', formatYesNoField(projectShareClassRec.CanLimited__c )); //values : Yes, No, Neutral
        payload.put('noCapitalLoss', formatYesNoField(projectShareClassRec.CanNot__c)); //values : Yes, No, Neutral
        payload.put('notForInvestorsWithTheLowestRiskToleranceGermany', formatYesNoField(projectShareClassRec.LowestRiskTolGer__c)); //values : Yes, No, Neutral
        payload.put('expertInvestorGermany', formatYesNoField(projectShareClassRec.ExpertGermany__c )); //values : Yes, No, Neutral
        payload.put('advancedInvestor', formatYesNoField(projectShareClassRec.Advanced__c)); //values : Yes, No, Neutral
        payload.put('informedInvestor', formatYesNoField(projectShareClassRec.Informed__c )); //values : Yes, No, Neutral
        payload.put('basicInvestor', formatYesNoField(projectShareClassRec.Basic__c)); //values : Yes, No, Neutral
        payload.put('investorTypeEligibleCounterparty', formatYesNoField(projectShareClassRec.EligibleCounterparty__c )); //values : Yes, No, Neutral
        payload.put('investorTypeProfessional', formatYesNoField(projectShareClassRec.Professional__c)); //values : Yes, No, Neutral
        payload.put('investorTypeRetail', formatYesNoField(projectShareClassRec.Retail__c )); //values : Yes, No, Neutral
        payload.put('existingNegativeScreeningStrategy', ProjectProductRec.FundSpecificExclusions__c);
        payload.put('sustainableIndicatorsForGermanMifidMarket', ProjectProductRec.EET60440__c);
        payload.put('carbonReductionObjective', ProjectProductRec.HasCarbonTarget__c);
        payload.put('amfDoctrine', ProjectProductRec.AMFESGCommunication__c);
        payload.put('minInvestSocial', ProjectProductRec.EET20250__c);
        payload.put('otherInvestEnv', ProjectProductRec.EET20460__c);
        payload.put('otherInvestEnvOrSocial', ProjectProductRec.EET20430__c);
        payload.put('minInvestEOrS', ProjectProductRec.EET20400__c);
        payload.put('sustainableInvestSocial', ProjectProductRec.EET20250__c);
        payload.put('nonTaxoEnvSustInvest', ProjectProductRec.EET20200__c);
        payload.put('alignedWithTaxonomy', ProjectProductRec.EET20190__c);
        payload.put('lookedThroughArt9', ProjectProductRec.EET20080__c);
        //payload.put('lookedThroughArt8', ProjectProductRec.EET20070__c);
        payload.put('sfdrAdverseImpact', ProjectProductRec.IsUsingPAI__c);
        payload.put('sfdrCategory', ProjectProductRec.SFDRCategory__c);
        payload.put('minInvestTaxo', ProjectProductRec.MinTaxAlignment__c);
        payload.put('minSustInv', ProjectProductRec.MinSustainableInvest__c);
        payload.put('esgStandard', ProjectProductRec.ESGLabel__c);
        payload.put('statut', projectShareClassRec.Status__c);
        payload.put('leiCode',ProjectProductRec.LEICode__c);
        payload.put('accumulationDistribution', projectShareClassRec.DividendPolicy__c);
        payload.put('proxy', projectShareClassRec.ProxyRisk__c);
        payload.put('hasPerFees', projectShareClassRec.HasPerfFees__c);
        payload.put('assetClass',ProjectProductRec.AssetClass__c);
        payload.put('cutOff',ProjectProductRec.CutOffTime__c);
        payload.put('maturite',ProjectProductRec.MaturityDate__c);
        payload.put('hedge', projectShareClassRec.CurrencyHedging__c);
        payload.put('partDeReference', projectShareClassRec.ProxyRisk__c);
        payload.put('benchmark',ProjectProductRec.BenchmarkName__c);
        payload.put('transactionCosts', projectShareClassRec.TransactionCosts__c);
        payload.put('effectiveServiceFees', projectShareClassRec.EffectiveServiceFees__c);
        payload.put('effectiveManagementFees', projectShareClassRec.EffectiveManagementFees__c);
        payload.put('maxSubscriptionFees', projectShareClassRec.MaxSubscriptionFee__c);
        payload.put('effectivePerfFees', projectShareClassRec.EffectivePerfFees__c);
        payload.put('maxRedemptionFees', projectShareClassRec.MaxRedemptionFee__c);
        payload.put('launchDate', ProjectProductRec.EndDate__c);
        payload.put('legalForm', ProjectProductRec.LegalForm__c );
        payload.put('domiciliation', ProjectProductRec.DomiciledIn__c);
        payload.put('rhp', ProjectProductRec.RecommendedHoldingPeriod__c);
        payload.put('navFrequency',ProjectProductRec.NAVFrequency__c);
        payload.put('currency',projectShareClassRec.Currency__c);
        payload.put('shareName',projectShareClassRec.Name__c);
        payload.put('fundName',ProjectProductRec.ProductName__c);
        payload.put('isin',projectShareClassRec.ISIN__c);
        payload.put('shareClassId','');
        payload.put('productId',ProjectProductRec.Product__c);
        payload.put('projectShareClassId',projectShareClassRec.Id);
        payload.put('projectId',ProjectProductRec.Id);
       

        
        payload.put('maxPerformanceFees', projectShareClassRec.MaxPerfFees__c);
        payload.put('language', ProjectProductRec.DefaultLanguage__c);
        //payload.put('performanceFeeMethod', projectShareClassRec.PerformanceFeeMethod__c  ); 
        String projectInvestmentObjectiveNoHTML = escapeHTML(ProjectProductRec.InvestmentObjective__c );
        String shareClassInvestmentObjectiveNoHTML = escapeHTML(projectShareClassRec.ShareclassInvestmentObjective__c);
        payload.put('projectType',  ProjectProductRec.TECH_RTName__c);
        payload.put('investmentObjective', projectInvestmentObjectiveNoHTML);
        payload.put('internalShortName',  ProjectProductRec.internalShortName__c);

    // add only if project type is not Modification
     Id fundShareClassModificationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundShareClassModification').getRecordTypeId();
     Id fundCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('FundCreation').getRecordTypeId();
     Id shareclassCreationRecordTypeId = Schema.SObjectType.ProjectProduct__c.getRecordTypeInfosByDeveloperName().get('ShareclassCreation').getRecordTypeId();

       Id rtId = ProjectProductRec.RecordTypeId;

if (rtId == fundCreationRecordTypeId) {
    payload.put('sortieAnticipee1', ProjectProductRec.ReasonForRHP__c);
    payload.put('typeInvestisseur', ProjectProductRec.IntentedRetailInvestor__c);
    payload.put('shareClassInvestmentObjective', shareClassInvestmentObjectiveNoHTML);
    payload.put('performanceFeesCommentEPT', projectShareClassRec.PerformanceFeeEPTKID__c);
    payload.put('performanceFeesComment', projectShareClassRec.PerformanceFeeUCITSKIID__c);
}
else if (rtId == shareclassCreationRecordTypeId) {
    payload.put('shareClassInvestmentObjective', shareClassInvestmentObjectiveNoHTML);
    payload.put('performanceFeesCommentEPT', projectShareClassRec.PerformanceFeeEPTKID__c);
    payload.put('performanceFeesComment', projectShareClassRec.PerformanceFeeUCITSKIID__c);
}
       // payload.put('fundcurrency',  ProjectProductRec.BaseCurrency__c); //champ pas encore créé coté Sequantis
        //payload.put('????'  shareClassInvestmentObjectiveNoHTML
        //payload.put('riskNarrative', 'L\'indicateur synthétique de risque indique la probabilité que ce produit...');
        //payload.put('sortieAnticipee','');

        req.setHeader('Authorization', 'Bearer ' + token); 
        req.setHeader('Content-Type','application/json');
        req.setMethod('POST');
        req.setEndpoint('callout:Sequantis/rest/CARMIGNAC_PROJECT');


        // Sérialisation du Map en JSON
        system.debug('payload====='+JSON.serialize(payload));
        payloadDebug = payload;
        payloadKeys = new List<String>(payload.keySet());
        payloadString = JSON.serialize(payload);
        req.setBody(JSON.serialize(payload));

        HttpResponse res = httpReq.send(req);
        system.debug('==============Response status: ' + res.getStatusCode());
        system.debug('==============Response body: ' + res.getBody());    
        if( res.getStatusCode() == 202 ){
            return ('OK')   ;            
        }else if (res.getStatusCode() != 200) {
            throw new CalloutException('Erreur génération PDF (' + res.getStatusCode() + ') : ' + res.getBody());
        }

        return EncodingUtil.base64Encode(res.getBodyAsBlob());
    }

    /* Escape HTML tags from text
    except bold, italic 
    */
    private String escapeHTML(String inputText){
        if(inputText == null) {
            return '';
        }
        // Remove all HTML tags and replace them with a space except <p> and </p> 
        String noHTML = inputText.replaceAll('<(?!\\/??(p|i)>)[^>]+>', ' ');
        // Clean up multiple spaces generated by the replacements
        inputText = noHTML.replaceAll('\\s+', ' ').trim();
        return inputText;
    }   
    /* Escape HTML tags from text
    except bold, italic 
    */
    /*
    private String escapeHTML2(String inputText){
        if (inputText == null) return '';
        // Remove all HTML tags except <b>, </b>, <i>, </i> and replace them with a space
        String noHTML = inputText.replaceAll('<(?!b>|/b>|i>|/i>)[^>]+>', ' ');
        // Clean up multiple spaces generated by the replacements
        noHTML = noHTML.replaceAll('\\s+', ' ').trim();    
        return noHTML;
    }   */
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
        req.setBody('{"userName": "carmignac@sequantis.com", "password": "fPCKUJiXa38Tw7yo!"}');

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
}