public class SM026_DeleteWebsiteContactsAsync extends AsyncQueueableImplementation implements Database.AllowsCallouts{
    
    public SM026_DeleteWebsiteContactsAsync(List<SObject> sObjects, Integer index, Integer batchSize) {
        
        super(sObjects, index, batchSize);
    }
    
    public override void processRecordList(List<SObject> processList) {

        SM026_Contact_Website.deleteWebsiteContact((List<Contact>) processList);
        
    }
    
    
    /*
* Execute the new bunch of list
*/
    public override void executeNext(List<SObject> sObjects, Integer nextIndex, Integer batchSize){
        
        System.enqueueJob(new SM026_DeleteWebsiteContactsAsync(sObjects, nextIndex, batchSize));
    }
    
}