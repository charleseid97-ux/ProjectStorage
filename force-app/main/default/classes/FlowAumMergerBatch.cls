/** 
 * @description       :  Enhanced Flow and AUM Merger Batch to include all data 
 * @author            : SILA Nicolas 
 * @group             :  
 * @last modified on  : 12-03-2024
 * @last modified by  : SILA Nicolas
**/ 
 
public class FlowAumMergerBatch implements Database.Batchable<SObject>, Database.Stateful {  
 
    // Wrapper class to store aggregated data  
    public class FlowAUMDataWrapper {  
        public Map<String, AggregateData> aggregateFlowData = new Map<String, AggregateData>();  
        public Map<String, AggregateData> aggregateAUMData = new Map<String, AggregateData>();  
    }  
 
    public class AggregateData {  
        public Decimal sub = 0;  
        public Decimal red = 0;  
        public String codeType;  
        public Decimal net = 0;  
        public Decimal amtEURAbs = 0;  
        public Decimal flowTot = 0;  
        public Decimal flowPtf = 0;  
        public Decimal aumTot = 0;  
        public Decimal aumPtf = 0;  
    }  
 
    private FlowAUMDataWrapper dataWrapper = new FlowAUMDataWrapper();  
    private Decimal totalFlowAmtEURAbs = 0; // Total for all flows  
    private Decimal totalAUMAmtEUR = 0; // Total for all AUM  
    private Decimal totalPlatformFlowAmtEURAbs = 0; // Total for platform-specific flows  
    private Decimal totalPlatformAUMAmtEUR = 0; // Total for platform-specific AUM  
    private static final String QUERY_FLOW = 'SELECT Id, Company__c, Company__r.Name, Agreement__c, Agreement__r.Name,Agreement__r.Platform__c, ' +  
            'Agreement__r.Status__c, Agreement__r.ConventionName__c, Agreement__r.MasterConvention__c, ' +  
            'Agreement__r.MasterConvention__r.Name, Agreement__r.MasterConvention__r.ConventionName__c,Agreement__r.Platform__r.Name, ' +  
            'Agreement__r.MasterConvention__r.Code_Type__c, Agreement__r.MasterConvention__r.Ultimate_Parent__c, ' +  
            'AmountEUR__c FROM Flow__c WHERE ValueDate__c = THIS_YEAR ';  
 
    private static final String QUERY_AUM = 'SELECT Id, Company__c, Company__r.Name, Convention__c, Convention__r.Name,Convention__r.Platform__c, ' +  
            'Convention__r.Status__c, Convention__r.ConventionName__c, Convention__r.MasterConvention__c, ' +  
            'Convention__r.MasterConvention__r.Name, Convention__r.MasterConvention__r.ConventionName__c,Convention__r.Platform__r.Name, ' +  
            'Convention__r.MasterConvention__r.Code_Type__c, Convention__r.MasterConvention__r.Ultimate_Parent__c, ' +  
            'AmountEUR__c FROM AUM__c WHERE Last_AUM__c = true  ';  
 
    public Database.QueryLocator start(Database.BatchableContext bc) {  
        List<Platform_Flow_AUM__c> pltfs =  [SELECT ID FROM Platform_Flow_AUM__c];
        delete pltfs;
        return Database.getQueryLocator(QUERY_FLOW);  
    }  
 
    public void execute(Database.BatchableContext bc, List<SObject> scope) {  
        List<Flow__c> flowList = (List<Flow__c>) scope;  
 
        for (Flow__c flow : flowList) {  
            String key = flow.Agreement__r.Platform__c + '-' +  
                        flow.Agreement__c + '-' + flow.Company__c;  
 
            if (!dataWrapper.aggregateFlowData.containsKey(key)) {  
                dataWrapper.aggregateFlowData.put(key, new AggregateData());  
            }  
 
            AggregateData aggregateData = dataWrapper.aggregateFlowData.get(key);  
            Decimal amtEURAbs = flow.AmountEUR__c.abs();  
 
            // Aggregate Flow Data  
            aggregateData.amtEURAbs += amtEURAbs;  
            aggregateData.net += flow.AmountEUR__c;  
            totalFlowAmtEURAbs += amtEURAbs; // Summing up total flow amounts  
            if (flow.AmountEUR__c > 0) {  
                aggregateData.sub += flow.AmountEUR__c;  
            } else if (flow.AmountEUR__c < 0) {  
                aggregateData.red += flow.AmountEUR__c;  
            }  
            aggregateData.codeType = flow.Agreement__r.MasterConvention__r.Code_Type__c;  
            // Track total flow amounts specific to platform agreements  
            if (flow.Agreement__r.MasterConvention__r.Code_Type__c == 'Platform Master Agreement') {  
                totalPlatformFlowAmtEURAbs += amtEURAbs;  
            }  
        }  
    }  
 
    public void finish(Database.BatchableContext bc) {  
        List<AUM__c> aumList = Database.query(QUERY_AUM);  
 
        for (AUM__c aum : aumList) {  
            String key = aum.Convention__r.Platform__c + '-' +  
                        aum.Convention__c + '-' + aum.Company__c;  
 
            if (!dataWrapper.aggregateAUMData.containsKey(key)) {  
                dataWrapper.aggregateAUMData.put(key, new AggregateData());  
            }  
 
            AggregateData aggregateData = dataWrapper.aggregateAUMData.get(key);  
            aggregateData.net += aum.AmountEUR__c;  
            totalAUMAmtEUR += aum.AmountEUR__c; // Summing up total AUM amounts  
            aggregateData.codeType = aum.Convention__r.MasterConvention__r.Code_Type__c;  

            // Track total AUM amounts specific to platform agreements  
            if (aum.Convention__r.MasterConvention__r.Code_Type__c == 'Platform Master Agreement') {  
                totalPlatformAUMAmtEUR += aum.AmountEUR__c;  
            }  
        }  
 
        // Ensure all keys are included in the final merge 
  
        Set<String> allKeys = new Set<String>();  
        allKeys.addAll(dataWrapper.aggregateFlowData.keySet());  
        allKeys.addAll(dataWrapper.aggregateAUMData.keySet());  
        List<Platform_Flow_AUM__c> resultsToInsert = new List<Platform_Flow_AUM__c>();

        // Calculate percentage contributions for Flow and AUM  
        for (String key : allKeys) {  
            AggregateData flowData = dataWrapper.aggregateFlowData.containsKey(key) ? dataWrapper.aggregateFlowData.get(key) : new AggregateData();  
            AggregateData aumData = dataWrapper.aggregateAUMData.containsKey(key) ? dataWrapper.aggregateAUMData.get(key) : new AggregateData();  
 
            if (flowData.amtEURAbs != null && totalFlowAmtEURAbs != 0) {  
                flowData.flowTot = (flowData.amtEURAbs / totalFlowAmtEURAbs) * 100;  
            }  
            if (flowData.amtEURAbs != null && totalPlatformFlowAmtEURAbs != 0) {  
                flowData.flowPtf = (flowData.amtEURAbs / totalPlatformFlowAmtEURAbs) * 100;  
            }  
 
            if (aumData.net != null && totalAUMAmtEUR != 0) {  
                aumData.aumTot = (aumData.net / totalAUMAmtEUR) * 100;  
            }  
            if (aumData.net != null && totalPlatformAUMAmtEUR != 0) {  
                aumData.aumPtf = (aumData.net / totalPlatformAUMAmtEUR) * 100;  
            }  

            // Insert the aggregated data into Platform_Flow_AUM__c object  
            Platform_Flow_AUM__c result = new Platform_Flow_AUM__c();  
            if (key.split('-')[0] != 'null') {  
                result.Platform__c = key.split('-')[0];  
            }  

            if (key.split('-')[1] != 'null') {  
                result.Agreement__c = key.split('-')[1];   
            }

            if (key.split('-')[2] != 'null') {  
                result.Company__c = key.split('-')[2];  
            } 

            // if (flowData.codeType == 'Platform Master Agreement' || aumData.codeType == 'Platform Master Agreement' ) {  
                // result.Percent_Plateform__c = flowData.flowPtf;
                // result.Percent_AUM_Platform__c = aumData.aumPtf;
                // result.Percent_AUM_Total__c = aumData.aumTot;
                // result.Percent_Flow_Total__c = aumData.flowTot;
                
            // }  

            result.YTDFlowTot__c = totalFlowAmtEURAbs;
            result.YTDFlowPtf__c = totalPlatformFlowAmtEURAbs;
            result.LastAUMTot__c = totalAUMAmtEUR;
            result.LastAUMPtf__c = totalPlatformAUMAmtEUR;
            // result.YTD_Flow__c = flowData.net;
            result.Redemption__c = flowData.red;
            result.Subscription__c = flowData.sub;
            result.LastAUM__c = aumData.net;
            resultsToInsert.add(result);
        } 

        insert resultsToInsert; 
        
    } 
}