public class SM026_SendSelectedLeadsAsync extends AsyncQueueableImplementation implements Database.AllowsCallouts{
    
    public SM026_SendSelectedLeadsAsync(List<SObject> sObjects, Integer index, Integer batchSize) {
        
        super(sObjects, index, batchSize);
    }
    
    public override void processRecordList(List<SObject> processList) {
        
        SM026_Lead_Website sCont = new SM026_Lead_Website();
        sCont.processSelectedLeads((List<Lead>) processList);
        
    }

    
    /*
* Execute the new bunch of list
*/
    public override void executeNext(List<SObject> sObjects, Integer nextIndex, Integer batchSize){
        
        System.enqueueJob(new SM026_SendSelectedLeadsAsync(sObjects, nextIndex, batchSize));
    }
    
}