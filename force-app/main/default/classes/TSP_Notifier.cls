/**
 * Created by Saad LOZZI on 16/05/2022.
 */

public with sharing class TSP_Notifier implements TxnSecurity.EventCondition
{
    private final Set<String> blockedObjects = getBlockedObjects();

    // Retrieves dynamically the objects configured for Transaction Security monitoring.
    private static Set<String> getBlockedObjects()
    {
        Set<String> configuredObjects = new Set<String>();

        // Custom Metadata configuration defines which objects must be monitored.
        for(TSP_Setting__mdt setting : TSP_Setting__mdt.getAll().values())
        {
            if(String.isNotBlank(setting.Object__c))
            {
                configuredObjects.add(setting.Object__c.trim());
            }
        }

        return configuredObjects;
    }

    public Boolean evaluate(SObject event)
    {
        if(!shouldExecute(event))
        {
            return false;
        }

        TSP_Manager manager = new TSP_Manager();
        return manager.evaluate(event);
    }

    public Boolean shouldExecute(SObject event)
    {
        String objectTypesString = (String) event.get('QueriedEntities');
        Set<String> objectTypes  = new Set<String>(objectTypesString.split(','));

        for(String objectType : objectTypes)
        {
            if(blockedObjects.contains(objectType))
            {
                return true;
            }
        }

        return false;
    }
}