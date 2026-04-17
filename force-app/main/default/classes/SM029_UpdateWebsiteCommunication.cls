public class SM029_UpdateWebsiteCommunication extends AsyncQueueableImplementation implements Database.AllowsCallouts {
    /**
     * @param sObjects
     * @param index
     * @param batchSize
     */
    public SM029_UpdateWebsiteCommunication(List<SObject> sObjects, Integer index, Integer batchSize) {
        super(sObjects, index, batchSize);
    }

    /**
     * @param processList
     */
    public override void processRecordList(List<SObject> processList) {
        SM029_WebCommunication.sendWebCommuniction((List<Web_Communication__c>) processList);
    }

    /**
     * Execute the new bunch of list
     */
    public override void executeNext(List<SObject> sObjects, Integer nextIndex, Integer batchSize) {
        System.enqueueJob(new SM029_UpdateWebsiteCommunication(sObjects, nextIndex, batchSize));
    }
}