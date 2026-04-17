/*************************************************************************************************************************
Class Name      :   AccountPlanCtrlTest
Class Desc.     :   Class used for Account Plan widget  
Author          :   Alpha FMC
Description     :   Test class for AccountPlanCtrl. 

History
-------
//1.0 - Initial build of class on 19/2/2019
***************************************************************************************************************************/

@isTest
public with sharing class AccountPlanCtrlTest {
    public static Account_Plan_Objective__c objective;
    public static Account_Plan__c testAccPlan;
    
	public static void insertData() {
        Account testAcc = TestFactory.getSimpleAccount();
        insert testAcc;
        testAccPlan = new Account_Plan__c(Name='Test Account Plan', Executive_Summary__c='exec', Company__c=testAcc.Id);
        insert testAccPlan;
        objective = new Account_Plan_Objective__c(Name='Test Objective', Account_Plan__c=testAccPlan.id, Priority__c='High', Objective_Type__c='Financial');
        insert objective;
    }
    
    @isTest static void testTaskManagement(){
        insertData();
        Test.startTest();
        AccountPlanCtrl.getObjective(objective.Id);
        
        Task newTask = new Task(Subject='Test Task', 
                                whatId=objective.Id,
                                Priority='High',
                                ActivityDate=System.today(),
                                OwnerId=System.UserInfo.getUserId());
        List<Task> taskList = AccountPlanCtrl.saveTask(objective.Id, newTask);
        System.assertEquals(true, taskList.size() > 0, 'Task inserted correctly');
        Task returnTask = AccountPlanCtrl.getTask(taskList[0].id);
        system.debug(returnTask);
        system.debug(taskList[0]);
        System.assertEquals(true, returnTask == taskList[0], 'Return task is the same as inserted task');
        
        taskList[0].Priority = 'Low';
        List<Task> updateTaskList = AccountPlanCtrl.saveTask(objective.Id, taskList[0]);
        System.assertEquals(true, updateTaskList.size() == 1, 'No additional Task inserted');
        System.assertEquals(true, updateTaskList[0].Priority == 'Low', 'Task updated correctly');
        
        List<Task> delTaskList = AccountPlanCtrl.delTask(objective.Id, updateTaskList[0].id);
        System.assertEquals(true, delTaskList.size() == 0, 'Tasks are deleted');
        
        List<String> priorities = AccountPlanCtrl.getselectOptions(Schema.getGlobalDescribe().get('Task').newSObject(), 'Priority');
        System.assertEquals(true, priorities.size() > 0, 'Priorities are returned correctly');
        
        Test.stopTest();
    }
    
    @isTest static void testAccPlan(){
        insertData();
        Test.startTest();
       	Account_Plan__c accPlan = AccountPlanCtrl.initializeExecutiveSummary(testAccPlan.Id);
        accPlan.Executive_Summary__c = 'Updated';
        AccountPlanCtrl.saveExecutiveSummaryCtrl(testAccPlan.Id, accPlan.Executive_Summary__c);
        Test.stopTest();
    }

    @isTest static void testSWOT(){
        insertData(); 
        Test.startTest();
        //Testing Threats
        Threat__c saveThreat = ThreatManagerCtrl.saveThreat(testAccPlan.Id, null, 'Test Threat', 'Product');
        System.assertEquals(true, saveThreat != null, 'New threat has been saved');
        Threat__c updateThreat = ThreatManagerCtrl.saveThreat(testAccPlan.Id, saveThreat.Id, 'Test Threat Updated', 'Pricing');
        System.assertEquals(true, updateThreat.Threat__c == 'Test Threat Updated', 'Threat has been updated');
        Threat__c getThreat = ThreatManagerCtrl.loadThreat(saveThreat.Id);
        System.assertEquals(true, getThreat != null, 'Threat has been returned');
        //Testing Strengths
        Strengths_and_Weaknesses__c saveStrength = StrengthsAndWeaknessesManagerCtrl.saveStrength(testAccPlan.Id, null, 'Test Strength', 'Product');
        System.assertEquals(true, saveStrength != null, 'New Strength has been saved');
        Strengths_and_Weaknesses__c updateStrength = StrengthsAndWeaknessesManagerCtrl.saveStrength(testAccPlan.Id, saveStrength.Id, 'Test Strength Updated', 'Pricing');
        System.assertEquals(true, updateStrength.Strength__c == 'Test Strength Updated', 'Strength has been updated');
        Strengths_and_Weaknesses__c getStrength = StrengthsAndWeaknessesManagerCtrl.loadPlanStrength(saveStrength.Id);
        System.assertEquals(true, getStrength != null, 'Strength has been returned');
        //Testing Weaknesses
        Strengths_and_Weaknesses__c saveWeakness = StrengthsAndWeaknessesManagerCtrl.saveWeakness(testAccPlan.Id, null, 'Test Weakness', 'Product');
        System.assertEquals(true, saveWeakness != null, 'New Weakness has been saved');
        Strengths_and_Weaknesses__c updateWeakness = StrengthsAndWeaknessesManagerCtrl.saveWeakness(testAccPlan.Id, saveWeakness.Id, 'Test Weakness Updated', 'Pricing');
        System.assertEquals(true, updateWeakness.Weakness__c == 'Test Weakness Updated', 'Weakness has been updated');
        Strengths_and_Weaknesses__c getWeakness = StrengthsAndWeaknessesManagerCtrl.loadPlanWeakness(saveWeakness.Id);
        System.assertEquals(true, getWeakness != null, 'Weakness has been returned');
        
        AccountPlanCtrl.getOpenOpportunities(testAccPlan.Id);
        Test.stopTest();
    }
}