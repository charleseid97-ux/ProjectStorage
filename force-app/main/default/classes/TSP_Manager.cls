/**
 * Created by Saad LOZZI on 31/03/2022.
 */

public with sharing class TSP_Manager implements TxnSecurity.EventCondition
{
    private TSP_Handler handler;
    private final Integer SESSIONS_LIMIT = Integer.valueOf(Label.SESSIONS_LIMIT);

    public Boolean evaluate(SObject event)
    {
        handler = new TSP_Handler();

        if(event.getSObjectType() == ReportEvent.getSObjectType()
                && (
                    event.get('Operation') == 'ReportExported' ||
                    event.get('Operation') == 'ReportExportedAsynchronously' ||
                    event.get('Operation') == 'ReportExportedUsingExcelConnector')
                )
        {
            return handler.evaluate((ReportEvent) event);
        }
        else if(event.getSObjectType() == ApiEvent.getSObjectType())
        {
            return handler.evaluate((ApiEvent) event);
        }
        else if(event.getSObjectType() == LoginEvent.getSObjectType())
        {
            if(sessionLimitViolated(event))
            {
                return true;
            }
        }

        return false;
    }

    private Boolean sessionLimitViolated(SObject event)
    {
        List<AuthSession> sessions = [
                SELECT
                    Id
                FROM
                    AuthSession
                WHERE
                    UsersId =: (String) event.get('UserId')
                AND
                    SessionType = 'UI'
                AND
                    LoginHistory.LoginType != 'Salesforce Outlook Integration'
        ];

        if(sessions.size() > SESSIONS_LIMIT)
        {
            return true;
        }

        return false;
    }
}