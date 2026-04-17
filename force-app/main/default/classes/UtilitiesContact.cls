/*************************************************************************************************************************
Class Name      :   Utilitiescontact
Class Desc.     :   Utility Class  used for contact operations     
Author          :   Alpha FMC

Change History
Date             Author         version             Description                                 Requested By           Tag
--------------------------------------------------------------------------------------------------------------------------
Dec-2014         Alpha FMC       0.01            Initial build of class                           Client               None        
***************************************************************************************************************************/
public class UtilitiesContact {
  
  //Constants

    public static final string RT_EmployeeContact = 'Employee';
  
  
  //Querys
  
  
  /** Acts as a cache for the generic SObject method results
   */
  public static map<String, Id> RecordTypeIdsByDevName
  {
    get
    {
      if (RecordTypeIdsByDevName == null)
      {
        RecordTypeIdsByDevName = UtilitiesSObject.getRecordTypeIdsByDeveloperName('Contact');
      }
      return RecordTypeIdsByDevName;
    }
    private set;
  }
  
  public static map<String, Schema.RecordTypeInfo> RecordTypeInfosByDeveloperName
  {
    get
    {
      if (RecordTypeInfosByDeveloperName == null)
      {
        RecordTypeInfosByDeveloperName = UtilitiesSObject.getRecordTypeInfosByDeveloperName('Contact');
      }
      return RecordTypeInfosByDeveloperName;

    }
    private set;    
  }
  
  
  


  //returns info from the current User's Employee Contact  
  public static Contact EmployeeInfo
  {
    get
    {
      if (EmployeeInfo == null)
      {  
        try
        {    
          //alert if this fail, indicates a BIG PROBLEM (user with no contact record)
          EmployeeInfo = [SELECT Name, Email, Phone
                    FROM Contact WHERE User__c = :UserInfo.getUserId()];
        }
        catch (Exception e)
        {
          //throw new ApplicationException('Your Employee Contact is not set up correctly. Please contact CRM Support.');
        }
      }
      return EmployeeInfo;
    }
    private set;
  }


  //returns info from the Employee Contact records of the passed in Contact Ids
  //as not all employees are users (or users of the current system)
  //doesn't retain a static list because during an execution the 
  //relevant content could change
  public static map<Id, Contact> getEmployeeInfosByContact(list<Id> contactIds)
  {  
    return new map<Id, Contact>([SELECT Name, User__c, Email, Phone FROM Contact WHERE Id IN :contactIds]);
  }


  //returns info from the Employee Contact records of the passed in Users
  //doesn't retain a static list because during an execution the 
  //relevant content could change
  public static map<Id, Contact> getEmployeeInfos(list<Id> userIds)
  {
    map<Id, Contact> employeeContacts = new map<Id, Contact>();
    
    for (Contact c : [SELECT Name, User__c,Email, Phone FROM Contact WHERE User__c IN :userIds])
    {
      employeeContacts.put(c.User__c, c);
    }
    
    return employeeContacts;
  }
  
}