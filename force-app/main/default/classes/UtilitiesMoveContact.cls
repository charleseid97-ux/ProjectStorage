public with sharing class UtilitiesMoveContact {
    
    //
    public static void save(Contact cont, 
                        Contact newContact, 
                        Account toAccount,
                        boolean isSameHierarchy, 
                        boolean moveToInactiveContacts, 
                        Date dateLeft
                        ){
        
        Account generalContactAccount = UtilitiesAccount.InactiveContactsAccount;
        system.debug('BP - NC '+newContact);
        // They get this if not in the same hierarchy
        if (generalContactAccount.Id!= cont.AccountId && !isSameHierarchy ) 
        {
      
            Former_Employment_Relationship__c fer = new Former_Employment_Relationship__c( 
                Account__c = cont.AccountId,
                Email__c =  cont.Email,
                Reports_to__c = cont.ReportsToId,
                Corporate_Title__c = cont.CorporateTitle__c,
                Job_Function__c = cont.JobFunction__c,
                Job_Title__c = cont.JobTitle__c,
                Business_Card_Title__c = cont.Business_Card_Title__c,
                Title__c = cont.Title,
                Fax__c = cont.Fax,
                Phone__c = cont.Phone,
                Mobile_Phone__c = cont.MobilePhone,
                Contact__c = cont.Id,
                Mailing_Street__c = cont.MailingStreet,
                Mailing_City__c = cont.MailingCity,
                Mailing_Postcode__c = cont.MailingPostalCode,
                Mailing_Country__c = cont.MailingCountry,
                Date_Left__c = date.today()
            );
            insert fer; 
        }                
                    
        // General contact gets address blanked without the option
        if (moveToInactiveContacts == true) 
        {          
            cont.AccountId = generalContactAccount.Id;
            cont.CorporateTitle__c = '';
            cont.JobFunction__c = '';
            cont.JobTitle__c = '';
            cont.Title = '';
            cont.Phone = '';
            cont.MobilePhone = '';
            cont.MailingCity = '';
            cont.MailingCountry = '';
            cont.MailingLatitude = 0;
            cont.MailingLongitude = 0;
            cont.MailingPostalCode = '';
            cont.MailingState = '';
            cont.MailingStreet = '';
            cont.OtherCity = '';
            cont.OtherCountry = '';
            cont.OtherLatitude = 0;
            cont.OtherLongitude = 0;
            cont.OtherPostalCode = '';
            cont.OtherState = '';
            cont.OtherStreet = '';
            cont.ContactStatus__c = 'false';

            // Change RecordType to Inactive External Contact
            cont.RecordTypeId = UtilitiesContact.RecordTypeIdsByDevName.get('Inactive_External_Contact');          
        }
        
        // General account and new hierarchy gets email options set and other things cleared.
        if (moveToInactiveContacts == true || isSameHierarchy == false) 
        {
         
            cont.HasOptedOutOfEmail = false;  
            cont.AssistantName = '';
            cont.AssistantPhone = '';
            //cont.Assistant_Email__c = '';
            cont.Fax = '';
            cont.Department = '';
            //ReportsTo reset if moving Hierarchy
            cont.ReportsToId = null;
        }
        
        // new & existing hierarchy gets this.
        if (!moveToInactiveContacts) cont.AccountId = newContact.AccountId; 
        
        // And if we copy from the account address (odd one this because what if we DON'T?)
        if (!moveToInactiveContacts && newContact.Use_Company_Address__c==true) {
            cont.MailingStreet = toAccount.BillingStreet;
            cont.MailingCity = toAccount.BillingCity;
            cont.MailingPostalCode = toAccount.BillingPostalCode;
            cont.MailingCountry = toAccount.BillingCountry;
            cont.MailingLatitude = toAccount.BillingLatitude;
            cont.MailingLongitude = toAccount.BillingLatitude;
            cont.OtherStreet = toAccount.ShippingStreet;
            cont.OtherCity = toAccount.ShippingCity;
            cont.OtherPostalCode = toAccount.ShippingPostalCode;
            cont.OtherCountry = toAccount.ShippingCountry;
            cont.OtherLatitude = toAccount.ShippingLatitude;
            cont.OtherLongitude = toAccount.ShippingLatitude;
        }
        
        //If the Contact moves from 'Inactive Contacts' org to a new company, change the Recordtype to 'External Contact'
        if (!moveToInactiveContacts && cont.RecordTypeId == UtilitiesContact.RecordTypeIdsByDevName.get('Inactive_External_Contact'))
        {
          cont.RecordTypeId =  UtilitiesContact.RecordTypeIdsByDevName.get('Contact_DistributionContact');
        }
        // Any records not moveToGeneral
        if (!moveToInactiveContacts) {
            cont.ContactStatus__c = 'true';
            cont.Email = newContact.Email;
            cont.Title = newContact.Title;
            cont.CorporateTitle__c = newContact.CorporateTitle__c;
            cont.JobFunction__c = newContact.JobFunction__c;
            cont.JobTitle__c = newContact.JobTitle__c;
            cont.Business_Card_Title__c = newContact.Business_Card_Title__c;
            cont.Phone = newContact.Phone;
            cont.MobilePhone = newContact.MobilePhone;
            cont.HasOptedOutOfEmail = newContact.HasOptedOutOfEmail;
            cont.Subscriber__c = newContact.Subscriber__c;
          //cont.Use_Company_Address__c = newContact.Use_Company_Address__c;
        }
                            
        cont.Bypass_Apex__c = true;
        
        update cont;
        
        List<Case> WTPList = new List<Case>();
        for(Case WTP : [SELECT AccountId FROM Case WHERE ContactId =: cont.Id]) {
        	WTP.AccountId = cont.AccountId;
            WTPList.add(WTP);
        }
        update WTPList;
        
    }
    
    public static boolean checkSameHierarchy(Id fromAccountId, Account toAccount){
        
        boolean result = false;
        Id inactiveAccount = UtilitiesAccount.InactiveContactsAccount.Id;
        
        if (toAccount != null && toAccount.Id != null){
	        
	        Set<Id> fromHierarchy = new Set<Id>();    // Account hierarchy evaluation
	        Account fromAccount = new Account();

	        fromAccount = [SELECT Id, Parent.Id, Parent.Parent.Id, Parent.Parent.Parent.Id, Parent.Parent.Parent.Parent.Id, Parent.Parent.Parent.Parent.Parent.Id FROM Account WHERE Id = :fromAccountId];
            System.debug('BP : FA '+ fromAccount);
	        toAccount   = [SELECT Id, Parent.Id, Parent.Parent.Id, Parent.Parent.Parent.Id, Parent.Parent.Parent.Parent.Id, Parent.Parent.Parent.Parent.Parent.Id, BillingStreet, BillingCity, BillingPostalCode, BillingLongitude, BillingLatitude,  BillingCountry,  BillingState, ShippingStreet, ShippingCity, ShippingPostalCode, ShippingLongitude, ShippingLatitude,  ShippingCountry, ShippingState  FROM Account WHERE Id = :toAccount.Id];
            System.debug('BP : TA '+ toAccount);
	        
	        if (fromAccount.Id != null) fromHierarchy.add(fromAccount.Id);   
	        if (fromAccount.Parent.Id != null) fromHierarchy.add(fromAccount.Parent.Id);
	        if (fromAccount.Parent.Parent.Id != null) fromHierarchy.add(fromAccount.Parent.Parent.Id);
	        if (fromAccount.Parent.Parent.Parent.Id != null) fromHierarchy.add(fromAccount.Parent.Parent.Parent.Id);
	        if (fromAccount.Parent.Parent.Parent.Parent.Id != null) fromHierarchy.add(fromAccount.Parent.Parent.Parent.Parent.Id);
	        if (fromAccount.Parent.Parent.Parent.Parent.Parent.Id != null) fromHierarchy.add(fromAccount.Parent.Parent.Parent.Parent.Parent.Id);
	                                
	        result = false;
	        
	        if (fromHierarchy.contains(toAccount.Id)) result = true;
	        if (toAccount.Parent.Id != null && fromHierarchy.contains (toAccount.Parent.Id)) result = true; 
	        if (toAccount.Parent.Parent.Id != null && fromHierarchy.contains (toAccount.Parent.Parent.Id)) result = true; 
	        if (toAccount.Parent.Parent.Parent.Id != null && fromHierarchy.contains (toAccount.Parent.Parent.Parent.Id)) result = true; 
	        if (toAccount.Parent.Parent.Parent.Parent.Id != null && fromHierarchy.contains (toAccount.Parent.Parent.Parent.Parent.Id)) result = true; 
	        if (toAccount.Parent.Parent.Parent.Parent.Parent.Id != null && fromHierarchy.contains (toAccount.Parent.Parent.Parent.Parent.Parent.Id)) result = true; 

        }
        return result;
    }
}