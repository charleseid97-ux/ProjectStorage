/**
* @author: Noor Goolamnabee
* @date : 05/03/2020
* @description : This batch is used to delete Campaign Member from Inactive or Optout Contact or Lead
*
*
* -- History
* -- Date        Name        Version  Remarks
* -- -----------  ----------  -------  ---------------------------------------
* -- 05-03-2020  JLC
*
*/

public with sharing class BATCH002_DeleteCampaignMember implements Database.Batchable<sObject>{

    String query;

    public  BATCH002_DeleteCampaignMember(String aQuery) {
        query = aQuery;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Database.QueryLocator qloc = Database.getQueryLocator(query);
        return qloc;
    }

    public void execute(Database.BatchableContext context, List<sObject> objects) {

        delete objects;
    }

    public void finish(Database.BatchableContext batchableContext) {
    }


}