/**
* Created by Saad LOZZI on 31/03/2022.
*/

public with sharing class TSP_Handler
{
    /**
    * @param event ReportEvent
    * @description Verifies whether user violated policies for ReportEvents
    * @return Boolean whether the user violated policies or not
    */
    public Boolean evaluate(ReportEvent event)
    {
        return eventLogic(event);
    }

    /**
    * @param event ApiEvent
    * @description Verifies whether user violated policies for ApiEvent
    * @return Boolean whether the user violated policies or not
    */
    public Boolean evaluate(ApiEvent event)
    {
        return eventLogic(event);
    }

    /**
    * @param event Event Object
    * @description Executes generic logic for all Event Types
    * @return Boolean whether the user violated policies or not
    */
    public Boolean eventLogic(SObject event)
    {
        String objectTypes = (String) event.get('QueriedEntities');
        String objectType  = objectTypes.split(',').get(0);

        TSP_Setting__mdt objectSetting = getTSPSetting(objectType);

        if(objectSetting == null)
        {
            return false;
        }

        Set<Id> excludedUsers = objectSetting.Excluded_Queues__c != null ?
                getExcludedUsers(objectSetting.Excluded_Queues__c) : new Set<Id>();

        String excludedProfiles = objectSetting.Excluded_Profiles__c != null ?
                objectSetting.Excluded_Profiles__c : '';

        return isViolating(
                event,
                objectSetting.Records_Limit__c,
                excludedUsers,
                excludedProfiles
        );
    }
    
    /**
    * @param ObjectType TSP Setting metadata
    * @description Gets the objects TSP Setting metadata
    * @return TSP Setting metadata
    */
    private TSP_Setting__mdt getTSPSetting(String ObjectType)
    {
        List<TSP_Setting__mdt> objectSettings = new List<TSP_Setting__mdt>();
                
        objectSettings = [
            SELECT
                Id,
                Object__c,
                Records_Limit__c,
                Excluded_Queues__c,
                Excluded_Profiles__c
            FROM
                TSP_Setting__mdt
            WHERE
                Object__c = : ObjectType
        ];
        
        if(objectSettings.size() > 0)
        {
            return objectSettings.get(0);
        }
        
        return null;
    }
    
    /**
    * @param event Event Object
    * @param recordsLimit Records limit from the TSP Setting metadata
    * @param excludedUsers Excluded Users from TSP Setting metadata
    * @param excludedProfiles Excluded Profiles from TSP Setting metadata
    * @description Decides whether user is violating or not TSP Policies
    * @return Boolean (violated or not)
    */
    private Boolean isViolating(
        SObject event,
        Decimal recordsLimit,
        Set<Id> excludedUsers,
        String excludedProfiles
    )
    {
        if(
            excludedUsers.contains((String) event.get('UserId'))
            || isProfileExcluded((String) event.get('UserId'), excludedProfiles)
            || recordsLimit == null
        )
        {
            return false;
        }
        
        if((Double) event.get('RowsProcessed') > recordsLimit)
        {
            return true;
        }
        
        return false;
    }
    
    /**
    * @param excludedQueues Excluded Queues from TSP Setting metadata
    * @description Gets a Set of Users that are excluded from the TSP Policies
    * @return Set of Users
    */
    public Set<Id> getExcludedUsers(String excludedQueues)
    {
        Set<Id> userIds = new Set<Id>();

        if(Test.isRunningTest())
        {
            return new Set<Id>();
        }

        List<GroupMember> groupMembers = [
            SELECT
            UserOrGroupId
            FROM
            GroupMember
            WHERE
            GroupId IN : excludedQueues.split(';')
        ];
        
        for(GroupMember groupMember : groupMembers)
        {
            userIds.add(groupMember.UserOrGroupId);
        }
        
        return userIds;
    }

    /**
    * @param userId Id of the User who triggered the Event.
    * @param excludedProfiles Excluded Profiles from TSP Setting metadata
    * @description Gets a Set of Users that are excluded from the TSP Policies
    * @return Set of Users
    */
    private Boolean isProfileExcluded(Id userId, String excludedProfiles)
    {
        if(Test.isRunningTest())
        {
            return false;
        }

        String userProfile = [
            SELECT
                Profile.Name
            FROM
                User
            WHERE
                Id = : userId
        ].Profile.Name;
        
        return excludedProfiles.contains(userProfile);
    }
}