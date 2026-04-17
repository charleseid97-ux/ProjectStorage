/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : Create web Communication in queue
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.0    Init
*
*/
public class SM029_SendSelectedWebCommAsync extends AsyncQueueableImplementation implements Database.AllowsCallouts{

    /**
     *
     *
     * @param sObjects
     * @param index
     * @param batchSize
     */
    public SM029_SendSelectedWebCommAsync(List<SObject> sObjects, Integer index, Integer batchSize) {
        
        super(sObjects, index, batchSize);
    }

    /**
     *
     *
     * @param processList
     */
    public override void processRecordList(List<SObject> processList) {

        SM029_WebCommunication.processWebCommunication((List<Web_Communication__c>) processList);
        
    }

    
    /*
* Execute the new bunch of list
*/
    public override void executeNext(List<SObject> sObjects, Integer nextIndex, Integer batchSize){
        
        System.enqueueJob(new SM029_SendSelectedWebCommAsync(sObjects, nextIndex, batchSize));
    }
    
}