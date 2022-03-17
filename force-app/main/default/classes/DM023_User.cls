/** 
* @author: Briag GUEMARD
* @date : Création 28/03/2017
* @date : Modification 28/03/2017
* @description : 
*/


public  class DM023_User {
	
	 private static String CLASS_NAME = 'DM023_User';
    
    
    
    private static final String ALL_FIELDS = ObjectUtil.constructFieldListForQueryFrom('User');
 	  
    
    public static List<User> getListByIds(List<Id> UserIdList){
        
       
        String methodName = 'getListByIds';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[UserIdList] :' + UserIdList);
        
        String soqlQuery = '';
        
        //Bgu 12/04/2017 - Bug in Apex Test with LastPasswordChangeDate field during Test.
        
        if (Test.isRunningTest()){
        	String ALL_FIELDSTest = 'Id,Username,LastName,FirstName,Name,CompanyName,Division,Department,Title,Street,City,State,PostalCode,Country,StateCode,CountryCode,Latitude,Longitude,GeocodeAccuracy,Email,EmailPreferencesAutoBcc,EmailPreferencesAutoBccStayInTouch,EmailPreferencesStayInTouchReminder,SenderEmail,SenderName,Signature,StayInTouchSubject,StayInTouchSignature,StayInTouchNote,Phone,Fax,MobilePhone,Alias,CommunityNickname,BadgeText,IsActive,TimeZoneSidKey,UserRoleId,LocaleSidKey,ReceivesInfoEmails,ReceivesAdminInfoEmails,EmailEncodingKey,DefaultCurrencyIsoCode,CurrencyIsoCode,ProfileId,UserType,LanguageLocaleKey,EmployeeNumber,DelegatedApproverId,ManagerId,LastLoginDate,CreatedDate,CreatedById,LastModifiedDate,LastModifiedById,SystemModstamp,OfflineTrialExpirationDate,OfflinePdaTrialExpirationDate,UserPermissionsMarketingUser,UserPermissionsOfflineUser,UserPermissionsAvantgoUser,UserPermissionsCallCenterAutoLogin,UserPermissionsMobileUser,UserPermissionsSFContentUser,UserPermissionsInteractionUser,UserPermissionsSupportUser,UserPermissionsChatterAnswersUser,ForecastEnabled,UserPreferencesActivityRemindersPopup,UserPreferencesEventRemindersCheckboxDefault,UserPreferencesTaskRemindersCheckboxDefault,UserPreferencesReminderSoundOff,UserPreferencesDisableAllFeedsEmail,UserPreferencesDisableFollowersEmail,UserPreferencesDisableProfilePostEmail,UserPreferencesDisableChangeCommentEmail,UserPreferencesDisableLaterCommentEmail,UserPreferencesDisProfPostCommentEmail,UserPreferencesApexPagesDeveloperMode,UserPreferencesHideCSNGetChatterMobileTask,UserPreferencesDisableMentionsPostEmail,UserPreferencesDisMentionsCommentEmail,UserPreferencesHideCSNDesktopTask,UserPreferencesHideChatterOnboardingSplash,UserPreferencesHideSecondChatterOnboardingSplash,UserPreferencesDisCommentAfterLikeEmail,UserPreferencesDisableLikeEmail,UserPreferencesSortFeedByComment,UserPreferencesDisableMessageEmail,UserPreferencesDisableBookmarkEmail,UserPreferencesDisableSharePostEmail,UserPreferencesEnableAutoSubForFeeds,UserPreferencesDisableFileShareNotificationsForApi,UserPreferencesShowTitleToExternalUsers,UserPreferencesShowManagerToExternalUsers,UserPreferencesShowEmailToExternalUsers,UserPreferencesShowWorkPhoneToExternalUsers,UserPreferencesShowMobilePhoneToExternalUsers,UserPreferencesShowFaxToExternalUsers,UserPreferencesShowStreetAddressToExternalUsers,UserPreferencesShowCityToExternalUsers,UserPreferencesShowStateToExternalUsers,UserPreferencesShowPostalCodeToExternalUsers,UserPreferencesShowCountryToExternalUsers,UserPreferencesShowProfilePicToGuestUsers,UserPreferencesShowTitleToGuestUsers,UserPreferencesShowCityToGuestUsers,UserPreferencesShowStateToGuestUsers,UserPreferencesShowPostalCodeToGuestUsers,UserPreferencesShowCountryToGuestUsers,UserPreferencesHideS1BrowserUI,UserPreferencesDisableEndorsementEmail,UserPreferencesPathAssistantCollapsed,UserPreferencesCacheDiagnostics,UserPreferencesShowEmailToGuestUsers,UserPreferencesShowManagerToGuestUsers,UserPreferencesShowWorkPhoneToGuestUsers,UserPreferencesShowMobilePhoneToGuestUsers,UserPreferencesShowFaxToGuestUsers,UserPreferencesShowStreetAddressToGuestUsers,UserPreferencesLightningExperiencePreferred,UserPreferencesPreviewLightning,UserPreferencesHideEndUserOnboardingAssistantModal,UserPreferencesHideLightningMigrationModal,UserPreferencesHideSfxWelcomeMat,UserPreferencesHideBiggerPhotoCallout,ContactId,AccountId,CallCenterId,Extension,FederationIdentifier,AboutMe,FullPhotoUrl,SmallPhotoUrl,MediumPhotoUrl,DigestFrequency,DefaultGroupNotificationFrequency,BusinessDevelopmentRegions__c,BypassApexTriggers__c,BypassProcessBuilders__c,BypassValidationRules__c,BypassWorkflowRules__c,Position__c,TECH_TextBusinessDevelopmentRegions__c,TECH_UserEmail__c,newsletter_hierarchy__c,TECH_UserExternalID__c';
        	 soqlQuery = 'SELECT ' + ALL_FIELDSTest + ' FROM User WHERE Id IN: UserIdList';    	
        }else{
         soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM User WHERE Id IN: UserIdList';    	
        }
        
        List<User> listUser = new List<User>((List<User>)Database.query(soqlQuery));
        
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listUser);
        return listUser; 
    }
    
    
    
/** 
* @author: Adolphe SONKO
* @date : Création 04/05/2017
* @date : Modification 04/05/2017
* @description : Get a list of user by their Names
*/
    public static User getListByName(String Name){
        
       
        String methodName = 'getListByName';    
        ObjectUtil.debugLogBegin(CLASS_NAME, methodName, '[Name] :' + Name);
        
        String soqlQuery = '';
                
        if (Test.isRunningTest()){
        	String ALL_FIELDSTest = 'Id,Username,LastName,FirstName,Name,CompanyName,Division,Department,Title,Street,City,State,PostalCode,Country,StateCode,CountryCode,Latitude,Longitude,GeocodeAccuracy,Email,EmailPreferencesAutoBcc,EmailPreferencesAutoBccStayInTouch,EmailPreferencesStayInTouchReminder,SenderEmail,SenderName,Signature,StayInTouchSubject,StayInTouchSignature,StayInTouchNote,Phone,Fax,MobilePhone,Alias,CommunityNickname,BadgeText,IsActive,TimeZoneSidKey,UserRoleId,LocaleSidKey,ReceivesInfoEmails,ReceivesAdminInfoEmails,EmailEncodingKey,DefaultCurrencyIsoCode,CurrencyIsoCode,ProfileId,UserType,LanguageLocaleKey,EmployeeNumber,DelegatedApproverId,ManagerId,LastLoginDate,CreatedDate,CreatedById,LastModifiedDate,LastModifiedById,SystemModstamp,OfflineTrialExpirationDate,OfflinePdaTrialExpirationDate,UserPermissionsMarketingUser,UserPermissionsOfflineUser,UserPermissionsAvantgoUser,UserPermissionsCallCenterAutoLogin,UserPermissionsMobileUser,UserPermissionsSFContentUser,UserPermissionsInteractionUser,UserPermissionsSupportUser,UserPermissionsChatterAnswersUser,ForecastEnabled,UserPreferencesActivityRemindersPopup,UserPreferencesEventRemindersCheckboxDefault,UserPreferencesTaskRemindersCheckboxDefault,UserPreferencesReminderSoundOff,UserPreferencesDisableAllFeedsEmail,UserPreferencesDisableFollowersEmail,UserPreferencesDisableProfilePostEmail,UserPreferencesDisableChangeCommentEmail,UserPreferencesDisableLaterCommentEmail,UserPreferencesDisProfPostCommentEmail,UserPreferencesApexPagesDeveloperMode,UserPreferencesHideCSNGetChatterMobileTask,UserPreferencesDisableMentionsPostEmail,UserPreferencesDisMentionsCommentEmail,UserPreferencesHideCSNDesktopTask,UserPreferencesHideChatterOnboardingSplash,UserPreferencesHideSecondChatterOnboardingSplash,UserPreferencesDisCommentAfterLikeEmail,UserPreferencesDisableLikeEmail,UserPreferencesSortFeedByComment,UserPreferencesDisableMessageEmail,UserPreferencesDisableBookmarkEmail,UserPreferencesDisableSharePostEmail,UserPreferencesEnableAutoSubForFeeds,UserPreferencesDisableFileShareNotificationsForApi,UserPreferencesShowTitleToExternalUsers,UserPreferencesShowManagerToExternalUsers,UserPreferencesShowEmailToExternalUsers,UserPreferencesShowWorkPhoneToExternalUsers,UserPreferencesShowMobilePhoneToExternalUsers,UserPreferencesShowFaxToExternalUsers,UserPreferencesShowStreetAddressToExternalUsers,UserPreferencesShowCityToExternalUsers,UserPreferencesShowStateToExternalUsers,UserPreferencesShowPostalCodeToExternalUsers,UserPreferencesShowCountryToExternalUsers,UserPreferencesShowProfilePicToGuestUsers,UserPreferencesShowTitleToGuestUsers,UserPreferencesShowCityToGuestUsers,UserPreferencesShowStateToGuestUsers,UserPreferencesShowPostalCodeToGuestUsers,UserPreferencesShowCountryToGuestUsers,UserPreferencesHideS1BrowserUI,UserPreferencesDisableEndorsementEmail,UserPreferencesPathAssistantCollapsed,UserPreferencesCacheDiagnostics,UserPreferencesShowEmailToGuestUsers,UserPreferencesShowManagerToGuestUsers,UserPreferencesShowWorkPhoneToGuestUsers,UserPreferencesShowMobilePhoneToGuestUsers,UserPreferencesShowFaxToGuestUsers,UserPreferencesShowStreetAddressToGuestUsers,UserPreferencesLightningExperiencePreferred,UserPreferencesPreviewLightning,UserPreferencesHideEndUserOnboardingAssistantModal,UserPreferencesHideLightningMigrationModal,UserPreferencesHideSfxWelcomeMat,UserPreferencesHideBiggerPhotoCallout,ContactId,AccountId,CallCenterId,Extension,FederationIdentifier,AboutMe,FullPhotoUrl,SmallPhotoUrl,MediumPhotoUrl,DigestFrequency,DefaultGroupNotificationFrequency,BusinessDevelopmentRegions__c,BypassApexTriggers__c,BypassProcessBuilders__c,BypassValidationRules__c,BypassWorkflowRules__c,Position__c,TECH_TextBusinessDevelopmentRegions__c,TECH_UserEmail__c,newsletter_hierarchy__c,TECH_UserExternalID__c';
        	 soqlQuery = 'SELECT ' + ALL_FIELDSTest + ' FROM User WHERE Name =: Name';    	
        }else{
         soqlQuery = 'SELECT ' + ALL_FIELDS + ' FROM User WHERE Name =: Name';    	
        }
        
        List<User> listUser = new List<User>((List<User>)Database.query(soqlQuery));
        User Usertoreturn = new User();
        if(listUser != null && listUser.size() > 0){
             Usertoreturn = listUser.get(0);
        }
       
        ObjectUtil.debugLogEnd(CLASS_NAME, methodName, '[RESULTS] :' + listUser);
       // return listUser; 
        return Usertoreturn;
    }
    
    
 
}