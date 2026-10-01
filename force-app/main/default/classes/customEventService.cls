public without sharing class customEventService {

    // Constants
    private static final String SEP_NAME_PARTS = ' – ';
    private static final String EMPTY = '';

    private static final Map<String,String> SALES_TEAM_CODE_MAP = new Map<String,String>{
        'All countries'  => 'ALL',
        'Belgium'        => 'BE',
        'France'         => 'FR',
        'Germany'        => 'DE',
        'International'  => 'INT',
        'Italy'          => 'IT',
        'Luxembourg'     => 'LU',
        'Netherlands'    => 'NL',
        'Nordics'        => 'SE',
        'Spain'          => 'ES',
        'Switzerland'    => 'CH',
        'United Kingdom' => 'GB',
        'DCP'            => 'DCP'
    };

    // ---------------------------
    // Event Name construction
    // ---------------------------

    // Build event Name from date, SalesTeam code, title and speakers
    public static void setEventName(List<Event__c> events, Boolean isInit) {
        if (events == null || events.isEmpty()) return;

        Map<Id, String> eventToSpeakers = isInit ? new Map<Id, String>() : getSpeakers(events);

        for (Event__c e : events) {
            String datePart    = (e.startDate__c != null) ? String.valueOf(e.startDate__c) : null;
            String salesTeamPart = salesTeamToCode(e.SalesTeam__c);
            String titlePart   = e.Title__c;
            String speakerPart = isInit ? null : eventToSpeakers.get(e.Id);

            e.Name = joinNonBlank(
                new List<String>{ datePart, salesTeamPart, titlePart, speakerPart },
                SEP_NAME_PARTS
            );
        }
    }

  



    // ---------------------------
    // Helpers: format / join / parse
    // ---------------------------
    

    // Join non-blank parts with separator
    private static String joinNonBlank(List<String> parts, String sep) {
        if (parts == null || parts.isEmpty()) return EMPTY;
        List<String> kept = new List<String>();
        for (String p : parts) {
            if (!String.isBlank(p)) kept.add(p);
        }
        return kept.isEmpty() ? EMPTY : String.join(kept, sep);
    }

    

    // Accept "HH:MM" or "HH:MM:SS"
    private static List<Integer> parseTimeParts(String timeTxt) {
        if (String.isBlank(timeTxt)) return null;
        String v = timeTxt.trim();
        if (!v.contains(':')) return null;
        List<String> seg = v.split(':');
        if (seg.size() < 2) return null;
        try {
            Integer hh = Integer.valueOf(seg[0]);
            Integer mm = Integer.valueOf(seg[1]);
            Integer ss = (seg.size() >= 3) ? Integer.valueOf(seg[2]) : 0;
            return new List<Integer>{ hh, mm, ss };
        } catch (Exception ex) {
            return null;
        }
    }

    

    // ---------------------------
    // Country mapping
    // ---------------------------

   // Convert SalesTeam label to SalesTeam code
    private static String salesTeamToCode(String salesTeamRaw) {
        if (String.isBlank(salesTeamRaw)) return '';
        String key = salesTeamRaw.trim();
        if (SALES_TEAM_CODE_MAP.containsKey(key)) {
            return SALES_TEAM_CODE_MAP.get(key);
        }
        return key;
    }

    // ---------------------------
    // Copy billing address logic
    // ---------------------------

    public static void copyCompanyBillingAddressToEvent(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        system.debug('=====copyCompanyBillingAddressToEvent started');
        if (newEvents == null || newEvents.isEmpty()) return;
        Map<Id, Event__c> oldById = (oldMap == null) ? new Map<Id, Event__c>() : oldMap;

        Eligibility elig = collectEligibility(newEvents, oldById);
        system.debug('=====Eligibility collected: ' + elig.eligibleEventIds.size() + ' eligible events, ' + elig.accountIds.size() + ' unique accounts');
        if (elig.accountIds.isEmpty()) return;

        Map<Id, Account> accById = queryAccounts(elig.accountIds);
        applyBillingToEligibleEvents(newEvents, elig.eligibleEventIds, accById);
    }

    // Model grouping event eligibility and account ids
    private class Eligibility {
        Set<Id> eligibleEventIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
    }

    // Determine which events are eligible and collect account ids
    private static Eligibility collectEligibility(List<Event__c> newEvents, Map<Id, Event__c> oldById) {
        Eligibility out = new Eligibility();
        for (Event__c e : newEvents) {
            if (!isBaseCopyCandidate(e)) continue;
            Boolean eligible = isInsert(e, oldById) || isUpdateTriggerConditionMet(e, oldById);
            if (!eligible) continue;
            out.eligibleEventIds.add(e.Id);
            out.accountIds.add(e.Company__c);
        }
        return out;
    }

    // Basic checks for copy candidate
    private static Boolean isBaseCopyCandidate(Event__c e) {
        if (e == null) return false;
        if (e.CopyAddress__c != true) return false;
        if (!isEventLocationEmpty(e)) return false;
        if (e.Company__c == null) return false;
        return true;
    }

    // Determine if record is an insert
    private static Boolean isInsert(Event__c e, Map<Id, Event__c> oldById) {
        return e.Id == null || oldById == null || !oldById.containsKey(e.Id);
    }

    // Determine update trigger conditions
    private static Boolean isUpdateTriggerConditionMet(Event__c e, Map<Id, Event__c> oldById) {
        if (e == null || e.Id == null) return false;
        if (oldById == null || !oldById.containsKey(e.Id)) return false;
        Event__c oldE = oldById.get(e.Id);
        Boolean copyJustEnabled = (oldE.CopyAddress__c != true) && (e.CopyAddress__c == true);
        Boolean companyChangedWhileCopyEnabled = (oldE.Company__c != e.Company__c) && (e.CopyAddress__c == true);
        return copyJustEnabled || companyChangedWhileCopyEnabled;
    }

    // Query Accounts by collected ids
    private static Map<Id, Account> queryAccounts(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) return new Map<Id, Account>();
        List<Account> accounts = [
            SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode, BillingCountry
            FROM Account
            WHERE Id IN :accountIds
            WITH SECURITY_ENFORCED
        ];
        return new Map<Id, Account>(accounts);
    }

    // Apply billing info into eligible events
    private static void applyBillingToEligibleEvents(
        List<Event__c> newEvents,
        Set<Id> eligibleEventIds,
        Map<Id, Account> accById
    ) {
        system.debug('=====Applying billing to eligible events, count=' + ((newEvents != null) ? newEvents.size() : 0) + ', eligibleEventIds=' + eligibleEventIds + ', accById size=' + ((accById != null) ? accById.size() : 0));
        if (newEvents == null || newEvents.isEmpty()) return;
        if (accById == null || accById.isEmpty()) return;

        for (Event__c e : newEvents) {
            if (!isBaseCopyCandidate(e)) continue;
            if (e.Id != null && eligibleEventIds != null && !eligibleEventIds.contains(e.Id)) continue;

            Account a = accById.get(e.Company__c);
            if (a == null || isAccountBillingEmpty(a)) continue;
            copyBillingToEvent(e, a);
        }
    }

    // Copy account billing fields into event fields
    private static void copyBillingToEvent(Event__c e, Account a) {
        system.debug('=====Copying billing from account ' + a.Id + ' to event ' + e.Id);
        e.LocationAddress__c  = a.BillingStreet;
        e.city__c     = a.BillingCity;
        e.LocationPostCode__c = a.BillingPostalCode;
        e.country__c  = a.BillingCountry;
        e.LocationName__c     = a.Name;
    }

    private static Boolean isEventLocationEmpty(Event__c ev) {
        return String.isBlank(ev.LocationAddress__c)
            && String.isBlank(ev.city__c)
            && String.isBlank(ev.country__c)
            && String.isBlank(ev.LocationPostCode__c)
            && String.isBlank(ev.LocationName__c);
    }

    private static Boolean isAccountBillingEmpty(Account a) {
        return String.isBlank(a.BillingStreet)
            && String.isBlank(a.BillingCity)
            && String.isBlank(a.BillingPostalCode)
            && String.isBlank(a.BillingCountry);
    }

    // ---------------------------
    // Event Team / Approval helper
    // ---------------------------
    // BEFORE UPDATE:
    // When events are created, speakers are not yet linked, so Name is incomplete.
    // Once speakers are added (after insert), the record is updated → we recompute Name
    // and move the status from Draft to SubmittedToEventTeam.
    // The actual approval submission must happen in AFTER UPDATE.
    public static void setReadyForApprovalProcess(List<Event__c> events, Map<Id, Event__c> oldMap) {
        if (events == null || events.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }

        // Recompute name with speakers now available
        setEventName(events, false);

        for (Event__c evt : events) {
            if (evt == null || evt.Id == null) continue;

            Event__c oldEvt = oldMap.get(evt.Id);
            if (oldEvt == null) continue;

            // If still Draft after update → ready to be submitted
            if (oldEvt.Status__c == 'Draft' && evt.Status__c == 'Draft') {
                evt.Status__c = 'SubmittedToEventTeam';
            }
        }
    }
    // AFTER UPDATE: submits the Event to Event Team approval when its status changes.
    public static void startEventTeamApprovalAfterUpdate(List<Event__c> events,Map<Id, Event__c> oldMap) {
        

        if (events == null || events.isEmpty() || oldMap == null) return;

        Set<Id> eventIdsToSubmit = new Set<Id>();

        // Keep only Events that have just entered SubmittedToEventTeam.
        for (Event__c evt : events) {
            if (
                evt != null &&
                evt.Id != null &&
                evt.Status__c == 'SubmittedToEventTeam' &&
                oldMap.get(evt.Id).Status__c != 'SubmittedToEventTeam'
            ) {
                eventIdsToSubmit.add(evt.Id);
            }
        }

        if (eventIdsToSubmit.isEmpty()) return;

        Set<Id> eventsAlreadyInEventTeamApproval = new Set<Id>();
        List<Approval.ProcessWorkitemRequest> organizerRemovalRequests =
            new List<Approval.ProcessWorkitemRequest>();

        // Detect an Event Team process already running and remove obsolete Organizer approvals.
        for (ProcessInstanceWorkitem workitem : [
            SELECT Id,
                   ProcessInstance.TargetObjectId,
                   ProcessInstance.ProcessDefinition.DeveloperName
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId IN :eventIdsToSubmit
        ]) {
            String processName =
                workitem.ProcessInstance.ProcessDefinition.DeveloperName;

            // Never submit the same Event Team approval twice.
            if (processName == 'EventApprovalProcess') {
                eventsAlreadyInEventTeamApproval.add(
                    workitem.ProcessInstance.TargetObjectId
                );
                continue;
            }

            // Organizer approval cannot remain active when returning to Event Team.
            if (processName == 'OrganizerApprovalProcess') {
                Approval.ProcessWorkitemRequest removalRequest =
                    new Approval.ProcessWorkitemRequest();

                removalRequest.setWorkitemId(workitem.Id);
                removalRequest.setAction('Removed');
                removalRequest.setComments(
                    'Event returned to Event Team approval.'
                );

                organizerRemovalRequests.add(removalRequest);
            }
        }

        // Free the Event before starting the Event Team approval.
        if (!organizerRemovalRequests.isEmpty()) {
            Approval.process(organizerRemovalRequests);
        }

        for (Id eventId : eventIdsToSubmit) {
            if (eventsAlreadyInEventTeamApproval.contains(eventId)) continue;

            // Submit exactly one Event Team approval.
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(eventId);
            req.setProcessDefinitionNameOrId('EventApprovalProcess');
            Approval.process(req);
        }
    }
    // ---------------------------
    // Campaign creation from Event__c
    // ---------------------------

    // Crée ou synchronise la Campaign liée à l'Event.
    public static void createCampaign(
        List<Event__c> newEvents,
        Map<Id, Event__c> oldMap
    ) {
        if (newEvents == null || newEvents.isEmpty()) {
            return;
        }

        Id eventRecordTypeId = Schema.SObjectType.Event__c
            .getRecordTypeInfosByDeveloperName()
            .get('event')
            .getRecordTypeId();

        List<Campaign> campaignsToUpsert = new List<Campaign>();
        Map<Id, Campaign> newCampaignByEventId = new Map<Id, Campaign>();
        List<Event__c> eventsWithCreatedCampaign = new List<Event__c>();

        // Traite uniquement les Events pouvant être liés à une Campaign.
        for (Event__c newEvent : newEvents) {
            if (
                newEvent == null ||
                newEvent.Id == null ||
                newEvent.RecordTypeId != eventRecordTypeId
            ) {
                continue;
            }

            Event__c oldEvent =
                oldMap == null ? null : oldMap.get(newEvent.Id);

            Boolean becameFullyApproved =
                newEvent.Status__c == 'FullyApproved' &&
                (
                    oldEvent == null ||
                    oldEvent.Status__c != 'FullyApproved'
                );

            Boolean mappedFieldChanged =
                oldEvent != null &&
                hasCampaignMappedFieldChanged(newEvent, oldEvent);

            Boolean leftFullyApproved =
                oldEvent != null &&
                oldEvent.Status__c == 'FullyApproved' &&
                newEvent.Status__c != 'FullyApproved';

            // Détecte le passage explicite de l'Event au statut Cancelled.
            Boolean becameCancelled =
                newEvent.Status__c == 'Cancelled' &&
                (
                    oldEvent == null ||
                    oldEvent.Status__c != 'Cancelled'
                );

            // Crée la Campaign uniquement lors de la première validation.
            if (newEvent.Campaign__c == null) {
                if (!becameFullyApproved) {
                    continue;
                }

                Campaign campaignRecord = buildCampaignFromEvent(newEvent);
                campaignsToUpsert.add(campaignRecord);
                newCampaignByEventId.put(newEvent.Id, campaignRecord);
                eventsWithCreatedCampaign.add(newEvent);
                continue;
            }

            // Synchronise la Campaign lors d'une modification utile de l'Event.
            if (
                !mappedFieldChanged &&
                !becameFullyApproved &&
                !leftFullyApproved &&
                !becameCancelled
            ) {
                continue;
            }

            // Reconstruit toutes les valeurs mappées de la Campaign existante.
            Campaign campaignRecord = buildCampaignFromEvent(newEvent);
            campaignRecord.Id = newEvent.Campaign__c;
            // Aligne le statut Campaign sur le cycle de vie de l'Event.
            campaignRecord.Status =
                newEvent.Status__c == 'Cancelled'
                    ? 'Cancelled'
                    : newEvent.Status__c == 'FullyApproved'
                        ? 'Event Validated'
                        : 'BooklyRevalidationRequired';

            campaignsToUpsert.add(campaignRecord);
        }

        if (campaignsToUpsert.isEmpty()) {
            return;
        }

        // L'Id provoque un update ; son absence provoque un insert.
        upsert campaignsToUpsert;

        // Lie uniquement les nouvelles Campaigns à leur Event.
        if (!newCampaignByEventId.isEmpty()) {
            linkCampaignsToEvents(
                newCampaignByEventId,
                eventsWithCreatedCampaign
            );

            customEventNotificationManager.notifyCampaignCreated(
                eventsWithCreatedCampaign
            );
        }
    }
    // Détecte chaque nouveau passage à FullyApproved.
    @TestVisible
    private static List<Event__c> detectBecameFullyApproved(
        List<Event__c> newEvents,
        Map<Id, Event__c> oldMap
    ) {
        List<Event__c> eligibleEvents = new List<Event__c>();

        for (Event__c eventRecord : newEvents) {
            if (eventRecord == null) {
                continue;
            }

            Event__c oldEvent =
                oldMap != null ? oldMap.get(eventRecord.Id) : null;

            Boolean becameFullyApproved =
                eventRecord.Status__c == 'FullyApproved' &&
                (oldEvent == null || oldEvent.Status__c != 'FullyApproved');

            if (becameFullyApproved) {
                eligibleEvents.add(eventRecord);
            }
        }

        return eligibleEvents;
    }

    // Build a Campaign record from an Event__c
    public static Campaign buildCampaignFromEvent(Event__c e) {
        Campaign c = new Campaign();

        // Record Type
        c.RecordTypeId = Schema.SObjectType.Campaign
            .getRecordTypeInfosByDeveloperName()
            .get('Event_and_Meeting')
            .getRecordTypeId();

        // Name construction (time + country + title + format)
        c.Name = e.name;

        // Dates mapping
        c.StartDate = e.startDate__c;
        c.EndDate   = (e.endDate__c != null) ? e.endDate__c : e.startDate__c;

        // Type + Status mapping
        c.Type   = e.category__c;
        c.Status = 'Event Validated';
        c.Event__c = e.Id;
        // Datetime mapping from text time
        Datetime startDt = buildDatetimeFromDateAndTextTime(e.startDate__c, e.startTime__c);
        Datetime endDt   = buildDatetimeFromDateAndTextTime(
            (e.endDate__c != null) ? e.endDate__c : e.startDate__c,
            e.endTime__c
        );
        if (startDt != null) c.Start_Date_Time__c = startDt;
        if (endDt   != null) c.End_Date_Time__c   = endDt;
        // Format local datetime into String for Campaign fields
        if (startDt != null) {
            c.Event_Local_Start_Time__c =
            startDt.format('yyyy/MM/dd HH:mm');
        }

        if (endDt != null) {
            c.Event_Local_End_Time__c =
            endDt.format('yyyy/MM/dd HH:mm');
        }
        // Location mapping
        c.Address_1__c     = e.LocationAddress__c;
        c.City__c          = e.city__c;
        c.Country__c       = e.country__c;
        c.Post_Code__c     = e.LocationPostCode__c;
        c.Location_name__c = e.LocationName__c;

        // Business mapping
        c.Company__c       = e.Company__c;
        // SalesTeam mapping        
        c.Sales_Team__c = salesTeamToCode(e.SalesTeam__c);
        c.Participants_number__c = e.targetedAttendees__c;
        c.Local_zone__c   = e.timezone__c;

        if (!String.isBlank(e.Language__c)) {
            c.Language__c = e.Language__c;
        }
        // CRM User => Organizer
        c.CRM_User__c = e.Organizer__c;

        // Campaign owner => sales owner (not possible at creation)
        if (e.SalesOwner__c != null) {
             c.OwnerId = e.SalesOwner__c;
        }
        // Description composition
        String descr = '';
        if (!String.isBlank(e.MeetingGoal__c)) {
            descr += 'Goal:\n' + e.MeetingGoal__c + '\n\n';
        }
        if (!String.isBlank(e.MeetingBackground__c)) {
            descr += 'Background:\n' + e.MeetingBackground__c + '\n\n';
        }
        if (!String.isBlank(e.Description__c)) {
            descr += 'Rationale:\n' + e.Description__c + '\n\n';
        }
        c.Description = String.isBlank(descr) ? null : descr.trim();

        // Default flags
        c.Product__c            = true;
        c.Professionnal_only__c = true;
         // Type mapping (Event -> Campaign)
        if (e.AudienceCompany__c == 'One Company') {
            c.Event_Type__c = 'OCO';
        } else if (e.AudienceCompany__c == 'Several Companies') {
            c.Event_Type__c = 'SCO';
        } 

        c.Status = 'Event Validated';
        return c;
    }

    // Link created campaigns back to Event__c records
    private static void linkCampaignsToEvents(Map<Id, Campaign> eventIdToCampaign, List<Event__c> eligibleEvents) {
        List<Event__c> eventsToUpdate = new List<Event__c>();
        for (Event__c e : eligibleEvents) {
            Campaign created = eventIdToCampaign.get(e.Id);
            if (created == null) continue;
            eventsToUpdate.add(new Event__c(
                Id = e.Id,
                Campaign__c = created.Id
            ));
        }
        if (!eventsToUpdate.isEmpty()) update eventsToUpdate;
    }

    // ---------------------------
    // Datetime builder
    // ---------------------------

    // Build Datetime from Date and "HH:MM" or "HH:MM:SS" text
    private static Datetime buildDatetimeFromDateAndTextTime(Date d, String timeTxt) {
        if (d == null || String.isBlank(timeTxt)) return null;
        List<Integer> parts = parseTimeParts(timeTxt);
        if (parts == null || parts.size() < 2) return null;

        Integer hh = parts[0];
        Integer mm = parts[1];
        Integer ss = (parts.size() >= 3 && parts[2] != null) ? parts[2] : 0;

        if (hh == null || mm == null) return null;
        if (hh < 0 || hh > 23) return null;
        if (mm < 0 || mm > 59) return null;
        if (ss < 0 || ss > 59) return null;

        Time t = Time.newInstance(hh, mm, ss, 0);
        return Datetime.newInstance(d, t);
    }

  

    // set automatic location for digital events, and remove it if format is changed from digital to something else
    public static void setDigitalLocation(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        newEvents =  newEvents  ;
        for (Event__c ev : newEvents) {

            if (oldMap == null) {
                if (ev.Format__c == 'Digital') {
                    ev.country__c = 'Digital';
                    ev.City__c = 'Digital';
                }
            } else {
                Event__c oldEv = oldMap.get(ev.Id);
                if (oldEv == null) continue;
                Boolean formatChanged = oldEv.Format__c != ev.Format__c;

                if (formatChanged && ev.City__c == 'Digital') {
                    ev.City__c = null;
                    ev.country__c = null;
                }
            }
        }
    }

    public static Map<Id, String> getSpeakers(List<Event__c> events) {
        Set<Id> eventIds = new Set<Id>();
        for (Event__c e : events) {
            if (e.Id != null) eventIds.add(e.Id);
        }

        Map<Id, Set<String>> tmp = new Map<Id, Set<String>>();

        for (SessionSpeakerProduct__c s : [
            SELECT Session__c, SpeakerContact__r.Name
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :eventIds
            AND SpeakerContact__c != null
        ]) {
            if (!tmp.containsKey(s.Session__c)) {
                tmp.put(s.Session__c, new Set<String>());
            }
            tmp.get(s.Session__c).add(getSpeakerInitials(s.SpeakerContact__r.Name));
        }

        Map<Id, String> res = new Map<Id, String>();
        for (Id eid : tmp.keySet()) {
            List<String> vals = new List<String>(tmp.get(eid));
            vals.sort();
            res.put(eid, String.join(vals, ','));
        }
        return res;
    }

    public static String getSpeakerInitials(String fullName) {
        if (String.isBlank(fullName)) {
            return null;
        }

        List<String> p = fullName.trim().split('\\s+');
        if (p.size() < 2) {
            return null;
        }

        String firstInitial = p[0].substring(0, 1);
        String lastInitial  = p[p.size() - 1].substring(0, 1);

        return (firstInitial + lastInitial).toUpperCase();
    }

    public static void updateName(Map<Id, Event__c> oldMap, Map<Id, Event__c> newMap) {
        List<Event__c> toUpdate = new List<Event__c>();

        for (Event__c e : newMap.values()) {
            Event__c oldE = oldMap.get(e.Id);
            if (oldE == null) continue;

            if (
                e.startDate__c != oldE.startDate__c ||
                e.SalesTeam__c != oldE.SalesTeam__c ||
                e.Title__c     != oldE.Title__c
            ) {
                toUpdate.add(e);
            }
        }

        if (!toUpdate.isEmpty()) {
            setEventName(toUpdate, false);
        }
    }

    /**
     * Generic validation method for Event__c records.
     * Used in before insert/update to enforce business rules.
     */
    public static void validateEvents(List<Event__c> records, Map<Id, Event__c> oldMap) {
        if (records == null || records.isEmpty()) return;

        for (Event__c rec : records) {
            // Ensure Organizer is always populated
            if (rec.Organizer__c == null) {
                rec.addError('Organizer is required.');
            }
        }
    }

    // ---------------------------
    // Timezone via LocationTimezoneResolver
    // ---------------------------
    public static void setTimeZone(List<Event__c> events) {
        system.debug('====setTimeZone==='+events);
        if (events == null || events.isEmpty()) return;

        for (Event__c ev : events) {
            if (ev == null) continue;
            system.debug('=====ev.TimeZone__c='+ev.TimeZone__c);
            //  ne rien faire si déjà renseigné
            if (!String.isBlank(ev.TimeZone__c)) continue;

            // skip si pas de données
            if (String.isBlank(ev.country__c) && String.isBlank(ev.city__c)) continue;

            LocationTimezoneResolver.Result res =
                LocationTimezoneResolver.resolve(ev.country__c, ev.city__c);

            if (res != null && !String.isBlank(res.timezoneId)) {
                ev.TimeZone__c = res.timezoneId;
            }
        }
    }

    // Set the Event status according to the required Organizer approval
    public static void setWaitingForOrganizerApproval(
    List<Event__c> newEvents,
    Map<Id, Event__c> oldMap
) {
    if (newEvents == null || newEvents.isEmpty() || oldMap == null) return;

    Id currentUserId = UserInfo.getUserId();
    Set<Id> eventsModifiedByOrganizer = new Set<Id>();

    for (Event__c ev : newEvents) {
        if (ev == null || ev.Id == null) continue;

        Event__c oldEv = oldMap.get(ev.Id);
        if (oldEv == null) continue;

        // Detect a location change requiring new Organizer and Speaker approvals.
        Boolean locationChanged =
            ev.City__c != oldEv.City__c ||
            ev.Country__c != oldEv.Country__c;

        // Detect modifications requiring a refreshed Organizer decision.
        Boolean relevantModification =
            ev.Organizer__c != oldEv.Organizer__c ||
            ev.StartDate__c != oldEv.StartDate__c ||
            ev.EndDate__c != oldEv.EndDate__c ||
            ev.StartTime__c != oldEv.StartTime__c ||
            ev.EndTime__c != oldEv.EndTime__c ||
            ev.TimeZone__c != oldEv.TimeZone__c ||
            locationChanged;

        if (!relevantModification) continue;

        // Tant que l'Event Team n'a pas encore terminé son approval,
        // une modification ne doit jamais faire passer l'Event à FullyApproved.
        if (
            oldEv.Status__c == customEventConstants.STATUS_SUBMITTED_TO_EVENT_TEAM
        ) {
            ev.Status__c =
                customEventConstants.STATUS_SUBMITTED_TO_EVENT_TEAM;

            continue;
        }

        // Request Organizer approval only when the modification was made by another user.
        if (ev.Organizer__c != currentUserId) {
            ev.OrganizerDecision__c = null;
            ev.Status__c =
                customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS;
            continue;
        }

        // The current Organizer made the change:
        // only speaker approvals remain.
        eventsModifiedByOrganizer.add(ev.Id);
    }

    if (eventsModifiedByOrganizer.isEmpty()) return;

    Map<Id, String> statusesByEvent =
        customEventSpeakerApprovalService.calculateEventStatusFromApprovals(
            eventsModifiedByOrganizer
        );

    for (Event__c ev : newEvents) {
        if (!eventsModifiedByOrganizer.contains(ev.Id)) continue;

        String calculatedStatus = statusesByEvent.get(ev.Id);

        ev.Status__c =
            calculatedStatus == null
                ? customEventConstants.STATUS_FULLY_APPROVED
                : calculatedStatus;
    }
}

    // Submit or restart organizer approval when required
    public static void submitOrganizerApproval(List<Event__c> newEvents, Map<Id, Event__c> oldMap) {
        if (newEvents == null || newEvents.isEmpty() || oldMap == null) return;

        Set<Id> eventsToSubmit = new Set<Id>();
        Set<Id> eventsToRestart = new Set<Id>();
        Id currentUserId = UserInfo.getUserId();

        for (Event__c ev : newEvents) {
            if (ev == null || ev.Id == null) continue;

            Event__c oldEv = oldMap.get(ev.Id);
            if (oldEv == null) continue;

            // Initial request remains controlled by the formula
            Boolean initialOrganizerApproval =
                oldEv.Status__c == 'SubmittedToEventTeam' &&
                ev.Status__c == 'WaitingForSpeakerApprovals' &&
                ev.OrganizerApprovalRequired__c == true;

            // Detect modifications requiring a refreshed approval
            Boolean organizerChanged =
                ev.Organizer__c != oldEv.Organizer__c;

            Boolean schedulingChanged =
                ev.StartDate__c != oldEv.StartDate__c ||
                ev.EndDate__c != oldEv.EndDate__c ||
                ev.StartTime__c != oldEv.StartTime__c ||
                ev.EndTime__c != oldEv.EndTime__c ||
                ev.TimeZone__c != oldEv.TimeZone__c;
            // Location changes require a new approval only after the initial Event Team cycle.
            Boolean locationChanged =
                ev.City__c != oldEv.City__c ||
                ev.Country__c != oldEv.Country__c;

            // Restrict modification restarts to Events already in the approval lifecycle.
            Boolean canRestartApproval =
                oldEv.Status__c == customEventConstants.STATUS_FULLY_APPROVED ||
                oldEv.Status__c == customEventConstants.STATUS_WAITING_FOR_SPEAKER_APPROVALS ||
                oldEv.Status__c == customEventConstants.STATUS_PARTIALLY_APPROVED;

            Boolean relevantModification =
                canRestartApproval &&
                (organizerChanged || schedulingChanged || locationChanged);

            // Remove any existing approval based on obsolete values
            if (relevantModification) {
                eventsToRestart.add(ev.Id);
            }
            // Bypass Organizer approval when the current Organizer made the modification.
            if (
                initialOrganizerApproval ||
                (
                    relevantModification &&
                    ev.Organizer__c != currentUserId
                )
            ) {
                eventsToSubmit.add(ev.Id);
            }
        }

        if (eventsToRestart.isEmpty() && eventsToSubmit.isEmpty()) return;

        List<Approval.ProcessWorkitemRequest> removalRequests =
            new List<Approval.ProcessWorkitemRequest>();

        // Find pending organizer approvals that must be restarted
        if (!eventsToRestart.isEmpty()) {
            for (ProcessInstanceWorkitem workitem : [
                SELECT Id, ProcessInstance.TargetObjectId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId IN :eventsToRestart
                AND ProcessInstance.ProcessDefinition.DeveloperName =
                    'OrganizerApprovalProcess'
            ]) {
                Approval.ProcessWorkitemRequest removalRequest =
                    new Approval.ProcessWorkitemRequest();

                removalRequest.setWorkitemId(workitem.Id);
                removalRequest.setAction('Removed');
                removalRequest.setComments(
                    'Event modified. Organizer approval restarted.'
                );

                removalRequests.add(removalRequest);
            }
        }

        // Remove requests containing obsolete organizer or schedule values
        if (!removalRequests.isEmpty()) {
            Approval.process(removalRequests);
        }

        Set<Id> eventsStillPending = new Set<Id>();

        // Prevent duplicate submissions when an approval is still pending
        if (!eventsToSubmit.isEmpty()) {
            for (ProcessInstance processInstance : [
                SELECT TargetObjectId
                FROM ProcessInstance
                WHERE TargetObjectId IN :eventsToSubmit
                AND Status = 'Pending'
                AND ProcessDefinition.DeveloperName =
                    'OrganizerApprovalProcess'
            ]) {
                eventsStillPending.add(processInstance.TargetObjectId);
            }
        }

        List<Approval.ProcessRequest> submissionRequests =
            new List<Approval.ProcessRequest>();

        // Keep Event records available to retrieve the authorized submitter.
        Map<Id, Event__c> eventsById =
            new Map<Id, Event__c>(newEvents);

        for (Id eventId : eventsToSubmit) {
            if (eventsStillPending.contains(eventId)) continue;

            // Submit the Organizer approval using the Event owner.
            Approval.ProcessSubmitRequest submissionRequest =
                new Approval.ProcessSubmitRequest();

            submissionRequest.setObjectId(eventId);
            submissionRequest.setSubmitterId(
                eventsById.get(eventId).OwnerId
            );
            submissionRequest.setProcessDefinitionNameOrId(
                'OrganizerApprovalProcess'
            );
            submissionRequest.setSkipEntryCriteria(true);

            submissionRequests.add(submissionRequest);
        }

        // Submit only approvals requiring another Organizer
        if (!submissionRequests.isEmpty()) {
            Approval.process(submissionRequests);
        }
    }

    // Submit organizer approval when an SSP date or time is modified
    public static void submitOrganizerApprovalFromSSPChanges(
        Map<Id, SessionSpeakerProduct__c> newSsps,
        Map<Id, SessionSpeakerProduct__c> oldSsps
    ) {
        if (newSsps == null || newSsps.isEmpty() || oldSsps == null) return;

        Set<Id> changedEventIds = new Set<Id>();

        for (SessionSpeakerProduct__c newSsp : newSsps.values()) {
            if (newSsp == null || newSsp.Id == null) continue;

            SessionSpeakerProduct__c oldSsp = oldSsps.get(newSsp.Id);
            if (oldSsp == null || newSsp.Session__c == null) continue;

            // Detect only SSP scheduling modifications
            Boolean schedulingChanged =
                newSsp.Date__c != oldSsp.Date__c ||
                newSsp.StartTime__c != oldSsp.StartTime__c ||
                newSsp.EndTime__c != oldSsp.EndTime__c;

            if (schedulingChanged) {
                changedEventIds.add(newSsp.Session__c);
            }
        }

        if (changedEventIds.isEmpty()) return;

        // Construit les détails avant de relancer les approbations Organizer concernées.
        Map<Id, String> detailsByEventId =
            NotificationTitleGenerator.buildSspScheduleDetails(newSsps, oldSsps);

        Map<Id, Event__c> eventsById = new Map<Id, Event__c>([
            SELECT Id, Organizer__c, OwnerId
            FROM Event__c
            WHERE Id IN :changedEventIds
        ]);

        List<Approval.ProcessWorkitemRequest> removalRequests =
            new List<Approval.ProcessWorkitemRequest>();

        // Remove approvals based on the previous SSP schedule
        for (ProcessInstanceWorkitem workitem : [
            SELECT Id, ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId IN :changedEventIds
            AND ProcessInstance.ProcessDefinition.DeveloperName =
                'OrganizerApprovalProcess'
        ]) {
            Approval.ProcessWorkitemRequest removalRequest =
                new Approval.ProcessWorkitemRequest();

            removalRequest.setWorkitemId(workitem.Id);
            removalRequest.setAction('Removed');
            removalRequest.setComments(
                'SSP schedule modified. Organizer approval refreshed.'
            );

            removalRequests.add(removalRequest);
        }

        if (!removalRequests.isEmpty()) {
            Approval.process(removalRequests);
        }

        Set<Id> eventsWithPendingApproval = new Set<Id>();
        for (ProcessInstance processInstance : [
            SELECT TargetObjectId
            FROM ProcessInstance
            WHERE TargetObjectId IN :changedEventIds
            AND Status = 'Pending'
        ]) {
            eventsWithPendingApproval.add(processInstance.TargetObjectId);
        }

        List<Approval.ProcessRequest> submissionRequests =
            new List<Approval.ProcessRequest>();
        List<Event__c> eventTitlesToUpdate = new List<Event__c>();

        for (Id eventId : changedEventIds) {
            Event__c eventRecord = eventsById.get(eventId);
            if (eventRecord == null) continue;

            // Un processus Event déjà actif interdit toute nouvelle soumission Organizer.
            if (eventsWithPendingApproval.contains(eventId)) continue;

            // The Organizer does not approve their own SSP modification
            if (eventRecord.Organizer__c == UserInfo.getUserId()) {
                continue;
            }

            // Enregistre le sujet et le détail avant l'appel à Approval.process().
            eventTitlesToUpdate.add(new Event__c(
                Id = eventId,
                NotificationTitle__c = NotificationTitleGenerator.getUpdatedApprovalTitle(),
                NotificationDetails__c = detailsByEventId.get(eventId),
                OrganizerDecision__c = null
            ));

            Approval.ProcessSubmitRequest submissionRequest =
                new Approval.ProcessSubmitRequest();

            // Submit with the Event owner instead of the SSP modification user.
            submissionRequest.setObjectId(eventId);
            submissionRequest.setSubmitterId(eventRecord.OwnerId);
            submissionRequest.setProcessDefinitionNameOrId(
                'OrganizerApprovalProcess'
            );

            // The restart must not depend on the process entry criteria.
            submissionRequest.setSkipEntryCriteria(true);

            submissionRequests.add(submissionRequest);
        }

        // Le template Organizer lit la valeur persistée sur l'Event.
        if (!eventTitlesToUpdate.isEmpty()) {
            update eventTitlesToUpdate;
        }

        // Submit one request per Event modified by another user
        if (!submissionRequests.isEmpty()) {
            Approval.process(submissionRequests);
        }
    }


    /**
     * Send SSP presentation notifications when Event SSP HTML is updated
     */
    public static void notifyProductTeam(
        Map<Id, Event__c> newMap,
        Map<Id, Event__c> oldMap
    ) {

        Set<Id> eventIds = new Set<Id>();

        // Keep only Events where SSP HTML changed
        for (Event__c newEvt : newMap.values()) {
            Event__c oldEvt = oldMap.get(newEvt.Id);

            if (newEvt.speakersHTML__c != oldEvt.speakersHTML__c) {
                eventIds.add(newEvt.Id);
            }
        }

        if (eventIds.isEmpty()) {
            return;
        }

        List<SessionSpeakerProduct__c> ssps = [
            SELECT Id, session__c, strategy__c, PresentationStatus__c
            FROM SessionSpeakerProduct__c
            WHERE session__c IN :eventIds
            AND PresentationStatus__c = 'required'
        ];

        // Skip the generic email when the SSP modification already sent an update notification.
        if (
            !ssps.isEmpty() &&
            !BooklyModificationsManagement.shouldSkipGenericPresentationRequest(ssps)
        ) {
            customEventNotificationManager.requestPresentation(ssps);
        }
    }

        // Détecte les modifications des champs Event mappés vers Campaign.
    private static Boolean hasCampaignMappedFieldChanged(
        Event__c newEvent,
        Event__c oldEvent
    ) {
        if (newEvent == null || oldEvent == null) {
            return false;
        }

        return newEvent.Name != oldEvent.Name
            || newEvent.StartDate__c != oldEvent.StartDate__c
            || newEvent.EndDate__c != oldEvent.EndDate__c
            || newEvent.StartTime__c != oldEvent.StartTime__c
            || newEvent.EndTime__c != oldEvent.EndTime__c
            || newEvent.Category__c != oldEvent.Category__c
            || newEvent.LocationAddress__c != oldEvent.LocationAddress__c
            || newEvent.City__c != oldEvent.City__c
            || newEvent.Country__c != oldEvent.Country__c
            || newEvent.LocationPostCode__c != oldEvent.LocationPostCode__c
            || newEvent.LocationName__c != oldEvent.LocationName__c
            || newEvent.Company__c != oldEvent.Company__c
            || newEvent.SalesTeam__c != oldEvent.SalesTeam__c
            || newEvent.TargetedAttendees__c != oldEvent.TargetedAttendees__c
            || newEvent.TimeZone__c != oldEvent.TimeZone__c
            || newEvent.Language__c != oldEvent.Language__c
            || newEvent.Organizer__c != oldEvent.Organizer__c
            || newEvent.SalesOwner__c != oldEvent.SalesOwner__c
            || newEvent.MeetingGoal__c != oldEvent.MeetingGoal__c
            || newEvent.MeetingBackground__c != oldEvent.MeetingBackground__c
            || newEvent.Description__c != oldEvent.Description__c
            || newEvent.AudienceCompany__c != oldEvent.AudienceCompany__c;
    }


    /**
     * Sets required presentations to not required when an Event is cancelled.
     */
    public static void cancelRequiredPresentations(
        Map<Id, Event__c> newMap,
        Map<Id, Event__c> oldMap
    ) {
        Set<Id> cancelledEventIds = new Set<Id>();

        // Keep only Events that have just been cancelled.
        for (Event__c newEvent : newMap.values()) {
            Event__c oldEvent = oldMap.get(newEvent.Id);

            if (
                newEvent.Status__c == 'Cancelled' &&
                oldEvent.Status__c != 'Cancelled'
            ) {
                cancelledEventIds.add(newEvent.Id);
            }
        }

        if (cancelledEventIds.isEmpty()) {
            return;
        }

        List<SessionSpeakerProduct__c> ssps = [
            SELECT Id, PresentationStatus__c
            FROM SessionSpeakerProduct__c
            WHERE Session__c IN :cancelledEventIds
            AND PresentationStatus__c = 'required'
        ];

        // Preserve SSP history while removing presentations from the Product workflow.
        for (SessionSpeakerProduct__c ssp : ssps) {
            ssp.PresentationStatus__c = 'not required';
        }

        if (!ssps.isEmpty()) {
            update ssps;
        }
    }
}