/**
* @author Abderrahmane TRIA
* @date Creation 30/04/2020
* @group TEST
* @description JSON Parser Score UME
*/
@IsTest
public class JSONScoreUME2Apex_Test {
    
    static testMethod void testParse() {
        String json = '{\"yellowThreshold\":20.0,\"redThreshold\":30.0}';
        JSONScoreUME2Apex obj = JSONScoreUME2Apex.parse(json);
        System.assert(obj != null);
    }
    
}