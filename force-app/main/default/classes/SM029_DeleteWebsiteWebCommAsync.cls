/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : Delete web Communication in queue
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.0    Init
*
*/
public class SM029_DeleteWebsiteWebCommAsync extends AsyncQueueableImplementation implements Database.AllowsCallouts{

    /**
     * Constructor
     *
     * @param sObjects
     * @param index
     * @param batchSize
     */
    public SM029_DeleteWebsiteWebCommAsync(List<SObject> sObjects, Integer index, Integer batchSize) {
        
        super(sObjects, index, batchSize);
    }
    
    public override void processRecordList(List<SObject> processList) {

        SM029_WebCommunication.deleteWebsiteWebComm((List<Web_Communication__c>) processList);
    }

    /*
    * Execute the new bunch of list
    */
    public override void executeNext(List<SObject> sObjects, Integer nextIndex, Integer batchSize){
        
        System.enqueueJob(new SM029_DeleteWebsiteWebCommAsync(sObjects, nextIndex, batchSize));
    }
    
}