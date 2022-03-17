/*************************************************************************************************************************
Class Name      :   UtilitiesAccount
Class Desc.     :   Utility Class  used for Account   
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
Dec-2014         Alpha FMC       0.01            Initial build of class                           Client               None 
2015-12-22 djb use Internal_Organisation for employee account
***************************************************************************************************************************/
public class UtilitiesAccount {
  
    //Constants
    
    public static final string RT_EmployeeAccount = 'Internal_Organisation';
    public static final string RT_InactiveContacts = 'Company_for_Inactive_External_Contacts';
    

      
    
    
    /**
	* Assumes there is only one Account with the RecordType.DeveloperName = Company_for_Inactive_External_Contacts 
	* and model will break if there is more or less
	* For future: if the org hits 10k inactive contacts, there must be a process to sideline an Inactive Contacts
	* Account and add a new one.
	* @return Account the holding company for inactive contacts
	*/
    
    public static Account InactiveContactsAccount
    {
        get
        {
            if (InactiveContactsAccount == null)
            {
                Id InactiveContactRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(RT_InactiveContacts).getRecordTypeId();
                InactiveContactsAccount = [SELECT Id, Name FROM Account WHERE RecordTypeId = :InactiveContactRecordTypeId LIMIT 1];
            }
            return InactiveContactsAccount;
        }
        private set;
    }
    
    public static map<String, Id> RecordTypeIdsByDevName
    {
        get
        {
            if (RecordTypeIdsByDevName == null)
            {
                RecordTypeIdsByDevName = UtilitiesSObject.getRecordTypeIdsByDeveloperName('Account');
            }
            return RecordTypeIdsByDevName;
        }
        private set;
    }
    
    public static map<String, Schema.RecordTypeInfo> RecordTypeInfosByDevName
    {
        get 
        {
            if (RecordTypeInfosByDevName == null) 
                RecordTypeInfosByDevName = UtilitiesSObject.getRecordTypeInfosByDeveloperName('Account');
            
            return  RecordTypeInfosByDevName;
        }       
        private set;
    }

}