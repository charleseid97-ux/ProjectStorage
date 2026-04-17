/*************************************************************************************************************************
Class Name      :  SmartFactory
Class Desc.     :  Helper class for Unit test.This class generate the data for create standard and custom object in unit 
                   test.
                    HOW TO USE
                    1. Just use SmartFactory in your tests to create objects:
                     Account account = (Account)SmartFactory.createSObject('Account');
                     2. The same syntax is used for custom objects:
                     Custom_Object__c customObject = (Custom_Object__c)SmartFactory.createSObject('Custom_Object__c');

Author          :  Alpha FMC

Change History
Date             Author         version             Description                                                         Tag
--------------------------------------------------------------------------------------------------------------------------
Dec-2014         Alpha FMC       0.01            Initial build of class                                                None        
***************************************************************************************************************************/


public with sharing class SmartFactory {
	
  //custom exception 
  public class UnsupportedObjectTypeException extends Exception {}
  
  // Key: sobject.field
  // Value: first picklist value
  private static final Map<String, String> DefaultPicklistValue = new Map<String, String>();
  
  private static Integer CurrentCount = 0;
  
  // Key : SobjectAPIName  For ex. Account 
  // Value : Map<String, Schema.SObjectField>, field map (k:fieldname, v:Schema.Sobjectfield)
  private static final Map<String, Map<String, Schema.SObjectField>> FIELDMAP_CACHE = new Map<String, Map<String, Schema.SObjectField>>();
  
  // can't map by Schema.sObjectType, use object name string instead
  static map<string, set<string>> excludedFields = new map<string, set<string>>{
    'All' => new set<string>{'OwnerId', 'LastModifiedById'},
    'Account' => new set<string>{'FirstName', 'LastName', 'BillingCountry', 'BillingCountryCode'
    							, 'ShippingCountry', 'ShippingCountryCode', 'BillingState', 'BillingStateCode'
    							, 'ShippingState', 'ShippingStateCode', 'Sub_Category__c', 'Category__c'},
    'Contact' => new set<string>{'OtherCountry', 'OtherCountryCode', 'OtherState', 'OtherStateCode', 'MailingCountry', 'MailingCountryCode', 'MailingState', 'MailingStateCode'},
    'Opportunity' => new set<string>{'Win_Lost_Reason__c','Meeting_Note_Id__c'},
    'User' => new set<string>{'CountryCode', 'Country', 'State', 'StateCode'}
  };
  
  public static SObject createSObject(string objectType) {
    return createSObject(objectType, false);
  }
  
  public static SObject createSObject(string objectType, boolean cascade) { 
    
    Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe(); 
    
    Schema.sObjectType token = globalDescribe.get(objectType);
    if (token == null) throw new UnsupportedObjectTypeException('Unsupported ObjectType ' + objectType);
    
    SObject obj;    
    Map<String, Schema.SObjectField> fieldMap;
    
    obj = globalDescribe.get(objectType).newSObject();
    
    // Abhinav: using the cache here to save field describes.
    //fieldMap = globalDescribe.get(objectType).getDescribe().fields.getMap();
    fieldMap = fieldMapFor(objectType);
    
    for (Schema.SObjectField field : fieldMap.values()) {
      setFieldValue(obj, field, cascade);  
    }
    
    return obj;
  }
  
  static String getDefaultPicklistValue(SObject obj, Schema.DescribeFieldResult fieldDescribe) {
    String key = obj.getSObjectType() + '.' + fieldDescribe.getName();
    
    if (!DefaultPicklistValue.containsKey(key)) {
      List<Schema.PicklistEntry> entries = fieldDescribe.getPicklistValues();
      String value = entries.size() > 0 ? entries[0].getValue() : null;
      DefaultPicklistValue.put(key, value);
    }
    
    return DefaultPicklistValue.get(key);
  }
  
  /**
    Returns a field map for a given sobject. 
    
    Note : this method is kept public for Test cases to share the same field map info, without requiring a field desribe.
    
    @param objectType sobject api name for ex. Account
    @returns FieldMap [Key:FieldName,Value:Schema.SObjectField]
  */
  public static  Map<String, Schema.SObjectField> fieldMapFor(String objectType) {
    Map<String, Schema.SObjectField> fieldMap = null;
    String normalizedObjectType = objectType.toLowerCase();
    if (FIELDMAP_CACHE.containsKey(normalizedObjectType)) {
      fieldMap = FIELDMAP_CACHE.get(normalizedObjectType);
    } else {
      fieldMap = Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap();
      // cache it for next use
      FIELDMAP_CACHE.put(normalizedObjectType, fieldMap);
    }
    return fieldMap;
  }
  
  static boolean isExcludedField(Schema.DescribeFieldResult fieldDescribe) {
    return excludedFields.get('All').contains(fieldDescribe.getName());
  }
  
  static boolean isExcludedField(SObject obj, Schema.DescribeFieldResult fieldDescribe) {
    set<string> fields = excludedFields.get(obj.getSObjectType().getDescribe().getName());
    return fields == null ? false : fields.contains(fieldDescribe.getName());
  }
  
  static boolean isPersonAccountField(Schema.DescribeFieldResult fieldDescribe) {
                Boolean CustomPerson = fieldDescribe.getName().substring(fieldDescribe.getName().length()-2,fieldDescribe.getName().length()) == 'pc' && fieldDescribe.isCustom();
                Boolean StandardPerson = fieldDescribe.getName().startsWith('Person') && !fieldDescribe.isCustom();
    return (CustomPerson || StandardPerson);
  }
  
  static void setFieldValue(SObject obj, Schema.SObjectField field, boolean cascade) {
    Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
    
    if (fieldDescribe.isCreateable() && 
      !fieldDescribe.getLocalName().contains ('Jigsaw') &&
      !fieldDescribe.getName().endsWith('pc') && // lookup fields
      !isExcludedField(fieldDescribe) &&
      !isExcludedField(obj, fieldDescribe) &&
      !isPersonAccountField(fieldDescribe))  {
        
      // Lines below commnnted out in order to avoid SmartFactory error //  
      
      // else
      
      
      if(fieldDescribe.getLocalName()=='Username')
      {
        obj.put(field, 'testuser@test.com'); 
      }
      else    
      if (fieldDescribe.getType() == Schema.DisplayType.String) {
        
        obj.put(field, fieldDescribe.isUnique()  || fieldDescribe.getName() == 'FederationIdentifier' ? String.ValueOf(CurrentCount++) : 'A'); 
      }
      else if (fieldDescribe.getType() == Schema.DisplayType.Reference) {
        string referenceObjectType = fieldDescribe.getReferenceTo()[0].getDescribe().getName();
        
        if (referenceObjectType == 'RecordType') {
          setRecordType(obj);
        }
        else if (cascade && referenceObjectType != obj.getSObjectType().getDescribe().getName()) {
          // TODO avoid infinite loop for same-type references
          SObject reference = createSObject(referenceObjectType);
          insert reference;
          obj.put(field, reference.Id);
        }
      } 
      else if (fieldDescribe.getType() == Schema.DisplayType.base64) obj.put(field, blob.valueOf('one'));
      else if (fieldDescribe.getType() == Schema.DisplayType.Boolean) obj.put(field, false);
      else if (fieldDescribe.getType() == Schema.DisplayType.Combobox) obj.put(field, 'one');
      else if (fieldDescribe.getType() == Schema.DisplayType.Currency) obj.put(field, 1);
      else if (fieldDescribe.getType() == Schema.DisplayType.Date) obj.put(field, Date.today());
      else if (fieldDescribe.getType() == Schema.DisplayType.DateTime) obj.put(field, DateTime.now());
      else if (fieldDescribe.getType() == Schema.DisplayType.Double) obj.put(field, fieldDescribe.isUnique()  || fieldDescribe.getName() == 'FederationIdentifier' ? CurrentCount++ : 1); 
      else if (fieldDescribe.getType() == Schema.DisplayType.Email) obj.put(field, 'test1'  + '@test.com');
      else if (fieldDescribe.getType() == Schema.DisplayType.EncryptedString) obj.put(field, 's');
      else if (fieldDescribe.getType() == Schema.DisplayType.Id) { }
      else if (fieldDescribe.getType() == Schema.DisplayType.Integer) {
        obj.put(field, fieldDescribe.isUnique()  || fieldDescribe.getName() == 'FederationIdentifier' ? CurrentCount++ : 1); 
        
      /**
      let's assume no multi select picklist is important
      they may not even exist though...;        
        
      } else if (fieldDescribe.getType() == Schema.DisplayType.MultiPicklist
             && !fieldDescribe.isDefaultedOnCreate()) {
        obj.put(field, getDefaultPicklistValue(obj, fieldDescribe));
      ***/
        
      } else if (fieldDescribe.getType() == Schema.DisplayType.Percent) {
        obj.put(field, 1);
      } else if (fieldDescribe.getType() == Schema.DisplayType.Phone) {
        //obj.put(field, '123-456-7890');
      } else if (fieldDescribe.getType() == Schema.DisplayType.Picklist
             && !fieldDescribe.isDefaultedOnCreate()) {
        obj.put(field, getDefaultPicklistValue(obj, fieldDescribe));
      } else if (fieldDescribe.getType() == Schema.DisplayType.String) obj.put(field, 'onetest');
      else if (fieldDescribe.getType() == Schema.DisplayType.TextArea) obj.put(field, 'one'); 
      else if (fieldDescribe.getType() == Schema.DisplayType.Time) obj.put(field, Time.newInstance(0, 0, 0, 0)); 
      else if (fieldDescribe.getType() == Schema.DisplayType.URL) {
        obj.put(field, 'http://testone'+'.com'); 
      } else {
      }
      
      
      
    }  
  }
  
  static void setRecordType(SObject obj) {
    List<Schema.RecordTypeInfo> recordTypes = obj.getSObjectType().getDescribe().getRecordTypeInfos();
    
    if (recordTypes.size() > 1) { // all objects have default Master type
      
      for (Schema.RecordTypeInfo recordType : recordTypes) {
        if (recordType.isAvailable() && recordType.isDefaultRecordTypeMapping()) {
          obj.put('RecordTypeId', recordType.getRecordTypeId());
        }
      }
    }
    
  }
}