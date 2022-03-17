/**
* @author: Noor Goolamnabee
* @date : 12/07/2019
* @description : Virtual class to allows to use queueable asynchronously by bunch
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 12-JUL-2019  JLC         1.1    #17135 Implement queueable interface to be able to process campaign in batch
*
*/
public virtual class AsyncQueueableImplementation implements Queueable{

    List<SObject> sObjects {get; set;}
    Integer index;
    Integer batchSize = 50;

    public AsyncQueueableImplementation(List<SObject> sObjects, Integer index, Integer batchSize){
        this.sObjects = sObjects;
        this.index = index;
        this.batchSize = batchSize;
    }

    public void execute(QueueableContext context) {

        Integer count = 0;
        Integer listSize = sObjects.size();
        List<SObject> processList = new List<SObject>();

        for(integer i = (index*batchSize) ; i < ((index + 1)*batchSize) && i < listSize; i++ ){

            processList.add(sObjects.get(i));
            count = i;
        }

        processRecordList(processList) ;
		System.debug('AsyncQueueableImplementation processList'+ processList);
        if(count + 1 < listSize && !Test.isRunningTest() )
            executeNext(sObjects, (this.index +1), batchSize);
            //System.enqueueJob(new AsyncQueueableImplementation(sObjects, (this.index +1), batchSize));
    }

    /*
    * Method to process record list by list
    */
    public virtual void processRecordList(List<SObject> processList){

        System.debug('List get size ' + processList.size());
    }

    /*
   * This we cannot instantiate the child class in the parent need to overide the class
   */
    public virtual void executeNext(List<SObject> sObjects, Integer nextIndex, Integer batchSize){

        System.debug('executeNext ' + nextIndex+ ' of '+ batchSize);
    }
}