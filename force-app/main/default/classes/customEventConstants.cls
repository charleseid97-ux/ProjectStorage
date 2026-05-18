public without sharing class customEventConstants {

    /*
     * Public Group names used to send Product Schedule alerts
     */
    public static final String GROUP_EQUITY_ALERTE_SCHEDULE = 'Equity_Alerte_Schedule';
    public static final String GROUP_FI_ALERTE_SCHEDULE = 'FI_Alerte_Schedule';
    public static final String GROUP_DIVERSIFIED_ALERTE_SCHEDULE = 'Diversified_Alerte_Schedule';
    public static final String GROUP_ALTERNATIVES_ALERTE_SCHEDULE = 'Alternatives_Alerte_Schedule';
    public static final String GROUP_PE_ALERTE_SCHEDULE = 'PE_Alerte_Schedule';

    /*
     * Range values
     */
    public static final String RANGE_EQUITY = 'Equity';
    public static final String RANGE_FIXED_INCOME = 'Fixed Income';
    public static final String RANGE_DIVERSIFIED = 'Diversified';
    public static final String RANGE_ALTERNATIVE = 'Alternative';
    public static final String RANGE_PRIVATE_ASSETS = 'Private Assets';

    /*
     * Event statuses
     */
    public static final String STATUS_DRAFT = 'Draft';
    public static final String STATUS_REJECTED = 'Rejected';
    public static final String STATUS_SUBMITTED_TO_EVENT_TEAM = 'SubmittedToEventTeam';
    public static final String STATUS_WAITING_FOR_SPEAKER_APPROVALS = 'WaitingForSpeakerApprovals';
    public static final String STATUS_FULLY_APPROVED = 'FullyApproved';
    public static final String STATUS_PARTIALLY_APPROVED = 'PartiallyApproved';

    /*
     * Speaker approval statuses
     */
    public static final String APPROVAL_STATUS_SUBMITTED = 'Submitted';
    public static final String APPROVAL_STATUS_APPROVED = 'Approved';
    public static final String APPROVAL_STATUS_APPROVED_SPEAKER = 'approved_speaker';
    public static final String APPROVAL_STATUS_APPROVED_HOP = 'approved_hop';
    public static final String APPROVAL_STATUS_REJECTED = 'rejected';
    public static final String APPROVAL_STATUS_RECALLED = 'Recalled';

    /*
     * Mapping Range -> Public Group Name
     */
    public static final Map<String, String> RANGE_TO_GROUP = new Map<String, String>{
        RANGE_EQUITY => GROUP_EQUITY_ALERTE_SCHEDULE,
        RANGE_FIXED_INCOME => GROUP_FI_ALERTE_SCHEDULE,
        RANGE_DIVERSIFIED => GROUP_DIVERSIFIED_ALERTE_SCHEDULE,
        RANGE_ALTERNATIVE => GROUP_ALTERNATIVES_ALERTE_SCHEDULE,
        RANGE_PRIVATE_ASSETS => GROUP_PE_ALERTE_SCHEDULE
    };
}