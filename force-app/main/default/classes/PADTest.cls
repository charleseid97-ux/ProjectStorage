/** 
* @author: Pape DIOUF
* @date : Création 06/09/2016
* @date : Modification 06/09/2016
* @description : This Class allows to manage trigger bypass.
*/
@IsTest
public class PADTest {
    static testMethod void PAD_Main_TestMethod(){
            PAD myPAD=new PAD();
            PAD.canTrigger('');
            PAD.canTrigger('ContactBeforeInsert');
    }
    
}