public with sharing class customEventAttendeeService {

    // Guard in case the framework (or other automations) cause indirect re-entry
    private static Boolean isRunning = false;

    // Log literals (avoid duplication)
    private static final String LOG_PREFIX = '[EventAttendeeAddress] ';
    private static final String LOG_SKIP_ATTENDEE_PREFIX = LOG_PREFIX + 'Skip attendee Id=';
    private static final String LOG_COUNTRY_LABEL = 'Country=';

    /**
     * When EventAttendee__c is created, if Event__c.CopyAddress__c = true
     * and the Event location fields are still empty, copy the Contact's Account Billing address into Event location fields.
     */
    public static void copyAddressToEventsFromAttendees(List<EventAttendee__c> attendees) {

        System.debug(LOG_PREFIX + 'START copyAddressToEventsFromAttendees');
        System.debug(LOG_PREFIX + 'Incoming attendees size=' + (attendees == null ? 0 : attendees.size()));

        if (isRunning) {
            System.debug(LOG_PREFIX + 'STOP recursion guard isRunning=true');
            return;
        }
        isRunning = true;

        try {
            if (attendees == null || attendees.isEmpty()) {
                System.debug(LOG_PREFIX + 'STOP no attendees provided');
                return;
            }

            AttendeeInput input = extractInputIds(attendees);
            if (input.isEmpty()) {
                System.debug(LOG_PREFIX + 'STOP eventIds or contactIds empty (nothing to process)');
                return;
            }

            Map<Id, Event__c> eventsById = queryEvents(input.eventIds);
            System.debug(LOG_PREFIX + 'Step 1: events queried=' + eventsById.size());

            Set<Id> eligibleEventIds = filterEligibleEventIds(eventsById);
            System.debug(LOG_PREFIX + 'Step 2: eligibleEventIds=' + eligibleEventIds);

            if (eligibleEventIds.isEmpty()) {
                System.debug(LOG_PREFIX + 'STOP no eligible events (CopyAddress__c not true or location not empty)');
                return;
            }

            Map<Id, Contact> contactsById = queryContacts(input.contactIds);
            System.debug(LOG_PREFIX + 'Step 3: contacts queried=' + contactsById.size());

            Map<Id, Account> chosenAccountByEventId = chooseFirstValidAccountPerEvent(
                attendees,
                eligibleEventIds,
                contactsById
            );
            System.debug(LOG_PREFIX + 'Step 4: chosenAccountByEventId size=' + chosenAccountByEventId.size());

            if (chosenAccountByEventId.isEmpty()) {
                System.debug(LOG_PREFIX + 'STOP no account chosen (no attendee had contact.account with billing)');
                return;
            }

            List<Event__c> toUpdate = buildEventUpdates(eventsById, chosenAccountByEventId);
            System.debug(LOG_PREFIX + 'Step 5: toUpdate size=' + toUpdate.size());

            updateIfNeeded(toUpdate);

        } catch (Exception ex) {
            System.debug(LOG_PREFIX + 'ERROR ' + ex.getTypeName() + ': ' + ex.getMessage());
            System.debug(LOG_PREFIX + 'STACK ' + ex.getStackTraceString());
            throw ex; // keep existing behavior
        } finally {
            isRunning = false;
            System.debug(LOG_PREFIX + 'END copyAddressToEventsFromAttendees');
        }
    }

    // ---------------------------------------------------------------------
    // Helper DTOs (keep logic readable + reduce cognitive complexity)
    // ---------------------------------------------------------------------
    private class AttendeeInput {
        Set<Id> eventIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();

        Boolean isEmpty() {
            return eventIds.isEmpty() || contactIds.isEmpty();
        }
    }

    // ---------------------------------------------------------------------
    // Extraction / Queries
    // ---------------------------------------------------------------------
    private static AttendeeInput extractInputIds(List<EventAttendee__c> attendees) {
        AttendeeInput input = new AttendeeInput();

        for (EventAttendee__c ea : attendees) {
            System.debug(LOG_PREFIX + 'Attendee Id=' + ea.Id + ' Event__c=' + ea.Event__c + ' Contact__c=' + ea.Contact__c);

            if (ea.Event__c == null || ea.Contact__c == null) continue;

            input.eventIds.add(ea.Event__c);
            input.contactIds.add(ea.Contact__c);
        }

        System.debug(LOG_PREFIX + 'Collected eventIds=' + input.eventIds);
        System.debug(LOG_PREFIX + 'Collected contactIds=' + input.contactIds);

        return input;
    }

    private static Map<Id, Event__c> queryEvents(Set<Id> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) return new Map<Id, Event__c>();

        return new Map<Id, Event__c>([
            SELECT Id, CopyAddress__c,
                   LocationAddress__c, city__c, country__c, LocationPostCode__c, LocationName__c
            FROM Event__c
            WHERE Id IN :eventIds
        ]);
    }

    private static Map<Id, Contact> queryContacts(Set<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) return new Map<Id, Contact>();

        return new Map<Id, Contact>([
            SELECT Id, AccountId,
                   Account.Name,
                   Account.BillingStreet,
                   Account.BillingCity,
                   Account.BillingPostalCode,
                   Account.BillingCountry
            FROM Contact
            WHERE Id IN :contactIds
        ]);
    }

    // ---------------------------------------------------------------------
    // Eligibility / Choice
    // ---------------------------------------------------------------------
    private static Set<Id> filterEligibleEventIds(Map<Id, Event__c> eventsById) {
        Set<Id> eligibleEventIds = new Set<Id>();
        if (eventsById == null || eventsById.isEmpty()) return eligibleEventIds;

        for (Event__c ev : eventsById.values()) {
            Boolean empty = isEventLocationEmpty(ev);

            System.debug(LOG_PREFIX + 'Event Id=' + ev.Id
                + ' CopyAddress__c=' + ev.CopyAddress__c
                + ' isLocationEmpty=' + empty
                + ' currentLocation=['
                    + 'Address=' + ev.LocationAddress__c + ', '
                    + 'City=' + ev.city__c + ', '
                    + 'PostCode=' + ev.LocationPostCode__c + ', '
                    + LOG_COUNTRY_LABEL + ev.country__c + ', '
                    + 'Name=' + ev.LocationName__c
                + ']'
            );

            if (ev.CopyAddress__c == true && empty) {
                eligibleEventIds.add(ev.Id);
            }
        }

        return eligibleEventIds;
    }

   /**
     * Chooses the first valid Account per eligible Event from the attendees list.
     */
    private static Map<Id, Account> chooseFirstValidAccountPerEvent(
        List<EventAttendee__c> attendees,
        Set<Id> eligibleEventIds,
        Map<Id, Contact> contactsById
    ) {
        Map<Id, Account> chosenAccountByEventId = new Map<Id, Account>();

        if (attendees == null || attendees.isEmpty()) return chosenAccountByEventId;
        if (eligibleEventIds == null || eligibleEventIds.isEmpty()) return chosenAccountByEventId;
        if (contactsById == null || contactsById.isEmpty()) return chosenAccountByEventId;

        for (EventAttendee__c ea : attendees) {
            if (ea == null) {
                continue;
            }

            if (!isAttendeeEligibleForAccountChoice(ea, eligibleEventIds, chosenAccountByEventId)) {
                continue;
            }

            Account candidate = findValidAccountForAttendee(ea, contactsById);
            if (candidate == null) {
                continue;
            }

            chosenAccountByEventId.put(ea.Event__c, candidate);
            System.debug(LOG_PREFIX + 'CHOSEN account for Event=' + ea.Event__c + ' AccountId=' + candidate.Id);
        }

        return chosenAccountByEventId;
    }

    /**
     * Basic eligibility checks on the attendee and the event, with logging.
     */
    private static Boolean isAttendeeEligibleForAccountChoice(
        EventAttendee__c ea,
        Set<Id> eligibleEventIds,
        Map<Id, Account> chosenAccountByEventId
    ) {
        if (ea.Event__c == null || ea.Contact__c == null) {
            System.debug(LOG_SKIP_ATTENDEE_PREFIX + ea.Id + ' missing Event__c or Contact__c');
            return false;
        }

        if (!eligibleEventIds.contains(ea.Event__c)) {
            System.debug(LOG_SKIP_ATTENDEE_PREFIX + ea.Id + ' Event not eligible=' + ea.Event__c);
            return false;
        }

        if (chosenAccountByEventId.containsKey(ea.Event__c)) {
            System.debug(LOG_SKIP_ATTENDEE_PREFIX + ea.Id + ' Event already has chosen account=' + ea.Event__c);
            return false;
        }

        return true;
    }

    /**
     * Resolves and validates the Account for an attendee's Contact, including billing checks.
     */
    private static Account findValidAccountForAttendee(
        EventAttendee__c ea,
        Map<Id, Contact> contactsById
    ) {
        Contact c = contactsById.get(ea.Contact__c);
        if (c == null) {
            System.debug(LOG_SKIP_ATTENDEE_PREFIX + ea.Id + ' Contact not found in query=' + ea.Contact__c);
            return null;
        }

        if (c.AccountId == null) {
            System.debug(LOG_SKIP_ATTENDEE_PREFIX + ea.Id + ' Contact has no AccountId Contact=' + c.Id);
            return null;
        }

        Account a = c.Account; // relationship fields already loaded
        if (a == null) {
            System.debug(LOG_SKIP_ATTENDEE_PREFIX + ea.Id + ' Contact.Account is null (unexpected) Contact=' + c.Id);
            return null;
        }

        System.debug(
            LOG_PREFIX + 'Candidate account for Event=' + ea.Event__c
            + ' from Contact=' + c.Id
            + ' AccountId=' + c.AccountId
            + ' Billing=['
                + 'Street=' + a.BillingStreet + ', '
                + 'City=' + a.BillingCity + ', '
                + 'PostalCode=' + a.BillingPostalCode + ', '
                + LOG_COUNTRY_LABEL + a.BillingCountry
            + ']'
            + ' AccountName=' + a.Name
        );

        // Require at least one Billing field to be non-empty (avoid copying blanks)
        if (isAccountBillingEmpty(a)) {
            System.debug(LOG_PREFIX + 'Skip account (billing empty) AccountId=' + c.AccountId);
            return null;
        }

        return a;
    }


    // ---------------------------------------------------------------------
    // Updates
    // ---------------------------------------------------------------------
    private static List<Event__c> buildEventUpdates(
        Map<Id, Event__c> eventsById,
        Map<Id, Account> chosenAccountByEventId
    ) {
        List<Event__c> toUpdate = new List<Event__c>();
        if (eventsById == null || eventsById.isEmpty()) return toUpdate;
        if (chosenAccountByEventId == null || chosenAccountByEventId.isEmpty()) return toUpdate;

        for (Id evId : chosenAccountByEventId.keySet()) {
            Event__c current = eventsById.get(evId);
            if (current == null) {
                System.debug(LOG_PREFIX + 'Skip evId=' + evId + ' not found in eventsById');
                continue;
            }

            // Safety re-check (in case another automation filled it earlier in the transaction)
            if (!isEventLocationEmpty(current)) {
                System.debug(LOG_PREFIX + 'Skip evId=' + evId + ' location no longer empty (changed during transaction)');
                continue;
            }

            Account a = chosenAccountByEventId.get(evId);

            Event__c upd = new Event__c(
                Id = evId,
                LocationAddress__c  = a.BillingStreet,
                city__c     = a.BillingCity,
                LocationPostCode__c = a.BillingPostalCode,
                country__c  = a.BillingCountry,
                LocationName__c     = a.Name
            );

            System.debug(LOG_PREFIX + 'Prepared update for Event=' + evId
                + ' => Location=['
                    + 'Address=' + upd.LocationAddress__c + ', '
                    + 'City=' + upd.city__c + ', '
                    + 'PostCode=' + upd.LocationPostCode__c + ', '
                    + LOG_COUNTRY_LABEL + upd.country__c + ', '
                    + 'Name=' + upd.LocationName__c
                + ']'
            );

            toUpdate.add(upd);
        }

        return toUpdate;
    }

    private static void updateIfNeeded(List<Event__c> toUpdate) {
        if (toUpdate == null || toUpdate.isEmpty()) {
            System.debug(LOG_PREFIX + 'No updates to perform');
            return;
        }

        System.debug(LOG_PREFIX + 'Updating events...');
        update toUpdate;
        System.debug(LOG_PREFIX + 'DONE update success');
    }

    // ---------------------------------------------------------------------
    // Existing helpers
    // ---------------------------------------------------------------------
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
}