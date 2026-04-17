/*************************************************************************************************************************
Class Name      :   AccountPlanCtrl
Class Desc.     :   Class used for Account Plan components   
Author          :   Alpha FMC

History
-------
//1.0 BP - Initial build of class on 19/2/2019
***************************************************************************************************************************/

global with sharing class AccountPlanCtrl {
    
    @AuraEnabled
    public static Account_Plan__c getAccountPlan(id recordId) {
        Account_Plan__c ap = [SELECT Name, Executive_Summary__c, Company__c,
                              (SELECT Strength__c, Strength_Type__c, Weakness__c, Weakness_Type__c FROM Strengths_and_Weaknesses__r),
                              (SELECT Threat__c, Threat_Type__c FROM Threats__r),
                              (SELECT Name, Objective_Type__c, Priority__c FROM Account_Plan_Objectives__r)
                              FROM Account_Plan__c WHERE Id =: recordId];
        
        return ap;
    }
    
    public class accountPlanItems {
        @AuraEnabled
        public String Name {get; set;}
        @AuraEnabled
        public Boolean Strengths {get; set;}
        @AuraEnabled
        public Boolean Weaknesses{get; set;}
        @AuraEnabled
        public Boolean Threats {get; set;}
    }
    
    public static Integer cloneCriteriaValidated(Account_Plan__c ap) {
        //0=validated  1=not validated (not most recent)  2=not validated (more than one per year)
        Integer validated = 0;
        Account_Plan__c latestAccPlan = [SELECT Name, Id, CreatedDate FROM Account_Plan__c WHERE Company__c =: ap.Company__c ORDER BY CreatedDate DESC LIMIT 1];
        
        if(latestAccPlan.CreatedDate.year() == System.Today().year()) {
            validated = 2;
        }
        
        if(latestAccPlan.id != ap.id) {
            validated = 1;
        }
        
        return validated;
    }
    
    @AuraEnabled
    public static Account_Plan__c cloneAccountPlanCtrl(id recordId, Account_Plan__c accountPlan, accountPlanItems accountPlanItems, List<Id> objectiveItems) {
        Account_Plan__c newAP = new Account_Plan__c();
        Integer cloneValidation = cloneCriteriaValidated(accountPlan);
        
        if(cloneValidation == 0) {
            accountPlan = [SELECT Name, Executive_Summary__c, Company__c, Revenue_Potential__c,
                           (SELECT Name, Strength__c, Strength_Type__c, Weakness__c, Weakness_Type__c FROM Strengths_and_Weaknesses__r),
                           (SELECT Name, Threat__c, Threat_Type__c FROM Threats__r)
                           FROM Account_Plan__c WHERE Id =: recordId];
            
            newAP.Name = accountPlanItems.Name;
            newAP.Company__c = accountPlan.Company__c;
            newAP.Executive_Summary__c = accountPlan.Executive_Summary__c;
            newAP.Revenue_Potential__c = accountPlan.Revenue_Potential__c;
            insert newAP;
            
            if(accountPlanItems.Strengths) {
                List<Strengths_and_Weaknesses__c> sAdd = new List<Strengths_and_Weaknesses__c>();
                for(Strengths_and_Weaknesses__c sw : accountPlan.Strengths_and_Weaknesses__r) {
                    if(sw.Strength__c != '' && sw.Strength__c != null) {
                        sAdd.add(new Strengths_and_Weaknesses__c(Name = sw.Name,
                                                                 Strength__c = sw.Strength__c, 
                                                                 Strength_Type__c = sw.Strength_Type__c,
                                                                 Account_Plan__c = newAP.Id));
                    }
                }
                insert sAdd;
            }
            
            if(accountPlanItems.Weaknesses) {
                List<Strengths_and_Weaknesses__c> wAdd = new List<Strengths_and_Weaknesses__c>();
                for(Strengths_and_Weaknesses__c sw : accountPlan.Strengths_and_Weaknesses__r) {
                    if(sw.Weakness__c != '' && sw.Weakness__c != null) {
                        wAdd.add(new Strengths_and_Weaknesses__c(Name = sw.Name,
                                                                 Weakness__c = sw.Weakness__c, 
                                                                 Weakness_Type__c = sw.Weakness_Type__c,
                                                                 Account_Plan__c = newAP.Id));
                    }
                }
                insert wAdd;
            }
            
            if(accountPlanItems.Threats) {
                List<Threat__c> tAdd = new List<Threat__c>();
                for(Threat__c t : accountPlan.Threats__r) {
                    if(t.Threat__c != '' && t.Threat__c != null) {
                        tAdd.add(new Threat__c(Name = t.Name,
                                               Threat__c = t.Threat__c, 
                                               Threat_Type__c = t.Threat_Type__c,
                                               Account_Plan__c = newAP.Id));
                    }
                }
                insert tAdd;
            }
            
            if(objectiveItems != null) {
                List<Account_Plan_Objective__c> newAPO = new List<Account_Plan_Objective__c>();
                List<Task> newTasks = new List<Task>();
                Map<Id, List<Task>> planTaskMap = new Map<Id, List<Task>>();
                List<Account_Plan_Objective_Company__c> newCompanies = new List<Account_Plan_Objective_Company__c>();
                Map<Id, List<Account_Plan_Objective_Company__c>> planCompanyMap = new Map<Id, List<Account_Plan_Objective_Company__c>>();
                
                for(Account_Plan_Objective__c apO : [SELECT Name, Objective_Details__c, Objective_Type__c, Priority__c, Due_Date__c, Optional_Related_Company__c,
                                                     (SELECT Subject, Priority, Type, Status, ActivityDate, OwnerId, Owner.Name, Description, Id FROM Tasks WHERE IsClosed <> true),
                                                     (SELECT Name, Company__c FROM Account_Plan_Objective_Companies__r )
                                                     FROM Account_Plan_Objective__c WHERE Id IN: objectiveItems]) {
                                                         
                                                         newAPO.add(new Account_Plan_Objective__c(Name = apO.Name, 
                                                                                                  Objective_Details__c = apO.Objective_Details__c, 
                                                                                                  Objective_Type__c = apO.Objective_Type__c,
                                                                                                  Priority__c = apO.Priority__c,
                                                                                                  Due_Date__c = apO.Due_Date__c.addYears(1),
                                                                                                  Optional_Related_Company__c = apO.Optional_Related_Company__c,
                                                                                                  Account_Plan__c = newAp.Id,
                                                                                                  Previous_Objective__c = apO.Id));
                                                         planTaskMap.put(apO.Id, apO.Tasks);
                                                         planCompanyMap.put(apO.Id, apO.Account_Plan_Objective_Companies__r);
                                                         
                                                     }
                insert newAPO;
                
                for(Account_Plan_Objective__c apPO : [SELECT Previous_Objective__c FROM Account_Plan_Objective__c WHERE Id IN: newAPO]) {
                    for(Task t : planTaskMap.get(apPO.Previous_Objective__c)) {
                        newTasks.add(new Task(Subject = t.Subject, 
                                              Priority = t.Priority, 
                                              Type = t.Type, 
                                              Status = t.Status, 
                                              ActivityDate = t.ActivityDate, 
                                              OwnerId = t.OwnerId, 
                                              Description = t.Description,
                                              WhatId = apPO.Id));
                    }
                    for(Account_Plan_Objective_Company__c c : planCompanyMap.get(apPO.Previous_Objective__c)) {
                        newCompanies.add(new Account_Plan_Objective_Company__c(Name = c.Name,
                                                                               Company__c = c.Company__c,
                                                                               Account_Plan_Objective__c = apPO.Id));
                    }
                }
                
                insert newTasks;
                insert newCompanies;
                
            }        
        } else if(cloneValidation == 1) {
            AuraHandledException ex = new AuraHandledException('You can only clone the most recent Account Plan');
            ex.setMessage('You can only clone the most recent Account Plan');
            throw ex;
        } else if(cloneValidation == 2) {
            AuraHandledException ex = new AuraHandledException('You can only create one Account Plan per year');
            ex.setMessage('You can only create one Account Plan per year');
            throw ex;
        }
        
		return newAP;
    }
    
    
    public class AccountPlanObjective{
        
        @AuraEnabled
        public Account_Plan_Objective__c AccountPlanObjective;
        @AuraEnabled
        public Account_Plan_Objective_Company__c [] CompanyLinks;
        @AuraEnabled
        public String MeetingNotePrefix = Account_Plan_Objective__c.sobjecttype.getDescribe().getKeyPrefix();
        
        AccountPlanObjective(){
            this.CompanyLinks = new List<Account_Plan_Objective_Company__c>();
        }
    }
    
    @AuraEnabled
    public static AccountPlanObjective getAccountPlanObjective(id recordId)
    { 
        AccountPlanObjective result = new AccountPlanObjective();
        
        if (recordId != null){
            
            result.AccountPlanObjective = [SELECT Id,
                                           Name, 
                                           Objective_Type__c, 
                                           Priority__c, 
                                           Objective_Details__c, 
                                           Due_Date__c, 
                                           Account_Plan__c,
                                           (SELECT Name,
                                            Company__c,
                                            Company__r.Name,
                                            Account_Plan_Objective__c
                                            FROM Account_Plan_Objective_Companies__r)
                                           FROM Account_Plan_Objective__c
                                           WHERE Id = :recordId];
                                 
            result.CompanyLinks = result.AccountPlanObjective.Account_Plan_Objective_Companies__r;
                                 
        }else{
            result.AccountPlanObjective = new Account_Plan_Objective__c();
        }

        return result;
    }
    
	@AuraEnabled
    public static Account_Plan_Objective__c getObjective(String ObjectiveId) {
        Account_Plan_Objective__c aPO = [SELECT Name FROM Account_Plan_Objective__c WHERE ID =: ObjectiveId];
        return aPO;
    }

    @AuraEnabled
    public static Account_Plan_Objective__c getObjectiveCtrl(String ObjectiveId) {
        Account_Plan_Objective__c obj = [SELECT Name, 
                                         Objective_Type__c, 
                                         Priority__c, 
                                         Objective_Details__c, 
                                         Due_Date__c, 
                                         Account_Plan__c, 
                                         (SELECT Name, Company__c FROM Account_Plan_Objective_Companies__r)
                                         FROM Account_Plan_Objective__c WHERE ID =: objectiveId];
        return obj;
    }
    
    @AuraEnabled
    public static AccountPlanObjective saveObjectiveCtrl(Account_Plan_Objective__c objective, List<Account_Plan_Objective_Company__c> companyLinks) {                
        upsert objective;
        Account_Plan_Objective_Company__c[] companyLinksToInsert = new List<Account_Plan_Objective_Company__c>();
        Account_Plan_Objective_Company__c[] companyLinksToDelete = new List<Account_Plan_Objective_Company__c>();
        
        if (objective.Id != null){
            
            AccountPlanObjective mnStructure =  getAccountPlanObjective(objective.Id);
            Account_Plan_Objective__c oldAccountPlanObjective =  mnStructure.AccountPlanObjective;
            Account_Plan_Objective_Company__c[] oldCompanyLinks = mnStructure.CompanyLinks;
            
            for (Account_Plan_Objective_Company__c companyLink : companyLinks){
                boolean found = false;
                
                for (Account_Plan_Objective_Company__c oldCompanyLink : oldCompanyLinks){
                    
                    if ((companyLink.Company__c == oldCompanyLink.Company__c && companyLink.Company__c != null && oldCompanyLink.Company__c != null))
                    {
                        found = true;
                        break;
                    }                        
                }
                
                if (!found){
                    companyLink.Account_Plan_Objective__c = objective.Id;
                    companyLink.Name = objective.Name;
                    companyLinksToInsert.add(companyLink);
                }
            }   
            
            for (Account_Plan_Objective_Company__c oldCompanyLink : oldCompanyLinks){
                boolean found = false;
                
                for (Account_Plan_Objective_Company__c companyLink : companyLinks){
                    
                    if ((companyLink.Company__c == oldCompanyLink.Company__c && companyLink.Company__c != null && oldCompanyLink.Company__c != null))
                    {
                        found = true;
                        
                        system.debug('saveMeetingNote meetingLinksToDelete found' +  oldCompanyLink);
                        break;
                    }                        
                }
                
                if (!found){
                    companyLinksToDelete.add(oldCompanyLink);
                }
            }
        }else{
            companyLinksToInsert = companyLinks;
        }
        
        if (companyLinksToInsert.size() >0){
            insert companyLinksToInsert;
        }
        
        if (companyLinksToDelete.size() >0){
            delete companyLinksToDelete;
        }

        return getAccountPlanObjective(objective.Id);
        /*
        Account_Plan_Objective__c obj = new Account_Plan_Objective__c();
        system.debug('BP - O '+objective);
        system.debug('BP - CL '+companyLinks);
        if(objective.Id != null) {
            system.debug('BP - 1');
            obj = [SELECT Name, Objective_Type__c, Priority__c, Objective_Details__c, Due_Date__c, Account_Plan__c FROM Account_Plan_Objective__c WHERE Id=: objective.Id];
            obj.Name = objective.Name;
            obj.Objective_Type__c = objective.Objective_Type__c;
            obj.Priority__c = objective.Priority__c;
            obj.Objective_Details__c = objective.Objective_Details__c;
            obj.Due_Date__c = objective.Due_Date__c;
            update obj;
        } else {
	        system.debug('BP - 2');
            obj = new Account_Plan_Objective__c(Name = objective.Name, 
                                              Objective_Type__c = objective.Objective_Type__c, 
                                              Priority__c = objective.Priority__c, 
                                              Objective_Details__c = objective.Objective_Details__c, 
                                              Due_Date__c = objective.Due_Date__c, 
                                              Account_Plan__c = objective.Account_Plan__c);
            insert obj;
        }*/
        
    }
    
	@AuraEnabled
    public static Task getTask(String TaskId) {
        Task t = [SELECT Subject, Priority, Type, Status, ActivityDate, OwnerId, Owner.Name, Description, Id FROM Task WHERE ID =: TaskId];
        return t;
    }

	@AuraEnabled
    public static List<Task> getTaskList(String ObjectiveId) {
        List<Task> tasks = [SELECT Subject, Priority, Type, Status, ActivityDate, OwnerId, Owner.Name, Description, Id FROM Task WHERE WhatId =: ObjectiveId];
        return tasks;
    }
    
    @AuraEnabled
    public static List<Task> saveTask(String ObjectiveId, Task task) {
        Date ActivityDateVal = Date.valueOf(task.ActivityDate);
        Task thisTask = new Task();
        if(task.Id != null) {
            thisTask = [SELECT WhatId, Subject, Priority, Type, ActivityDate, Status, Description, OwnerId FROM Task WHERE Id =: task.Id];
        }
        thisTask = task;
        
        if(task.Id != null) {
            update thisTask;
        } else {
            insert thisTask;
        }

        return getTaskList(ObjectiveId);
    }
    
    @AuraEnabled
    public static List<Task> delTask(String ObjectiveId, String TaskId) {
        Task delTask = [SELECT Status from Task WHERE Id =: TaskId];
        delete delTask;
        return getTaskList(ObjectiveId);
    }


    @AuraEnabled 
    public static Account_Plan__c initializeExecutiveSummary(String accId){
        String soqlQuery = 'SELECT Name, Id, Company__r.Name, Executive_Summary__c FROM Account_Plan__c WHERE Id = \'' + accId + '\'';
        Account_Plan__c acc = Database.query(soqlQuery);
        return acc;        
    }
    
    @AuraEnabled
    public static void saveExecutiveSummaryCtrl(String accId, String executiveSummaryVal){
        Account_Plan__c acc = new Account_Plan__c(Id = accId);
        acc.Executive_Summary__c = executiveSummaryVal;
        try{
            update acc;
        } catch(DMLException ex) {
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            throw e;
        }
    }

    @AuraEnabled
    public static Account_Plan__c initializeBuyListSummary(String accId){
        String soqlQuery = 'SELECT Name, Id, Company__r.Name, Third_Party_Fund_Architecture__c FROM Account_Plan__c WHERE Id = \'' + accId + '\'';
        Account_Plan__c acc = Database.query(soqlQuery);
        return acc;
    }

    @AuraEnabled
    public static void saveBuyListSummaryCtrl(String accId, String buyListDetailVal){
        Account_Plan__c acc = new Account_Plan__c(Id = accId);
        acc.Third_Party_Fund_Architecture__c = buyListDetailVal;
        try{
            update acc;
        } catch(DMLException ex) {
            AuraHandledException e = new AuraHandledException(ex.getMessage());
            throw e;
        }
    }
    
    @AuraEnabled
    public static List<Opportunity> getOpenOpportunities(String accountPlanId) {
        List<Account> accountIds = new List<Account>();
        List<Opportunity> openOpportunities = new List<Opportunity>();
        if(accountPlanId.startsWith('001')) {
            accountIds = getChildAccountsInHierarchy(accountPlanId);
        } else {
            Account_Plan__c accPlan = [SELECT Name, Company__c FROM Account_Plan__c WHERE Id =: accountPlanId];
            accountIds = getChildAccountsInHierarchy(accPlan.Company__c);
        }

        List<Account> accounts = [SELECT Id,Name,(SELECT Id, Name, RecordType.Name, Owner.Name, StageName, Account.Name FROM Opportunities WHERE isClosed = false AND RecordType.Name <> 'Generic Opportunity') FROM Account WHERE Id in :accountIds];
        
        for(Account ao:accounts) {
            openOpportunities.addAll(ao.Opportunities);
        }
        
        return openOpportunities;
    }
    
    static Map<Id, Integer> accountIdLevelMap = new Map<Id, Integer>();
    static Map<Id, Account> accountDetailsMap = new Map<Id, Account>();
    static Map<Id, List<Account>> parentChildLinkedListMap = new Map<Id, list<Account>>();
    static List<Account> accountHierarchyList = new List<Account>();
    
    public static List<Account> getChildAccountsInHierarchy(Id parentAcctId) {
        
        Boolean endTraversing = false;
        Integer accountLevel = 0;
        List<Account> acctList = new List<Account>();
        
        List<Id> parentIdList = new List<id>();
        parentIdList.add(parentAcctId);
        String query = '';
        
        while(!endTraversing) {
            if(accountLevel == 0) {
                query = 'select Id, Name, ParentId from Account WHERE Id IN :parentIdList';
            } else {
                query = 'select Id, Name, ParentId from Account WHERE ParentId IN :parentIdList';
            }
            try {
                acctList = Database.query(query);
            } catch (QueryException qe) {
                system.debug(qe.getLineNumber() + ' - ' + qe.getStackTraceString());
            }
            if(acctList.size() == 0 ) {
                endTraversing = true;
            } else {
                parentIdList.clear();
                acctList.sort();
                Account a;
                for(Integer i = 0; i < acctList.size(); i++ ) {
                    a = acctList.get(i);
                    parentIdList.add(a.Id);
                    
                    accountIdLevelMap.put(a.Id, accountLevel);
                    accountDetailsMap.put(a.Id, a);
                    
                    if(accountLevel > 0) {
                        if(parentChildLinkedListMap.get(a.ParentId) == null) {
                            parentChildLinkedListMap.put(a.ParentId, new List<Account>()); 
                        }
                        parentChildLinkedListMap.get(a.ParentId).add(a);
                        parentChildLinkedListMap.get(a.ParentId).sort();
                    }
                }
                accountLevel++;
            }
        }
        
        addChildAccountsToList(parentAcctId);
        return accountHierarchyList;
    }
    
    private static void addChildAccountsToList(Id parentAccountId) {
        Account a = accountDetailsMap.get(parentAccountId);
        accountHierarchyList.add(a);

        List<Account> childAccounts = parentChildLinkedListMap.get(parentAccountId);
        if(childAccounts != null) {
            childAccounts.sort();
            for(Account acct : childAccounts) {
                addChildAccountsToList(acct.Id);
            }
        }

        return;
    } 
    
    @AuraEnabled
    public static List < String > getselectOptions(sObject objObject, string fld) {
		return AccountUtil.getselectOptions(objObject, fld);
	}
}