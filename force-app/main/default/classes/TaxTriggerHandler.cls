public with sharing class TaxTriggerHandler {
    
    private static final Set<String> BLOCKING_STATUSES = new Set<String>{'Requested','Yes'};
        private static final Set<String> BE_TYPES = new Set<String>{'BE Asset Test', 'BE TIS'};
            
            public static void preventDuplicates(List<TaxData__c> newList, Map<Id, TaxData__c> oldMap) {
                if (newList == null || newList.isEmpty()) return;
                
                Set<String> incomingTypes = new Set<String>();
                Set<String> incomingCountries = new Set<String>();
                Set<Id> incomingEffectiveShareClassIds = new Set<Id>();
                Map<String, List<TaxData__c>> incomingByKey = new Map<String, List<TaxData__c>>();
                Set<TaxData__c> recordsToValidate = new Set<TaxData__c>();
                
                // 1) Build incoming sets & keys using effectiveShareClassId (ShareClass__c or ProjectShareclass__c)
                for (TaxData__c t : newList) {
                    String newStatus = t.Status__c;
                    Boolean shouldValidate = false;
                    
                    if (oldMap == null || !oldMap.containsKey(t.Id)) {
                        // INSERT
                        shouldValidate = true;
                    } else {
                        TaxData__c oldT = oldMap.get(t.Id);
                        
                        // Closed -> Requested/Available (reopen)
                        if (!BLOCKING_STATUSES.contains(oldT.Status__c)
                            && BLOCKING_STATUSES.contains(newStatus)) {
                                shouldValidate = true;
                            }
                        // Still Requested/Available and key changed
                        else if (BLOCKING_STATUSES.contains(oldT.Status__c)
                                 && BLOCKING_STATUSES.contains(newStatus)) {
                                     if ((String.valueOf(t.Type__c) != String.valueOf(oldT.Type__c))
                                         || (String.valueOf(t.Country__c) != String.valueOf(oldT.Country__c))
                                         || (String.valueOf(t.ShareClass__c) != String.valueOf(oldT.ShareClass__c))
                                         || (String.valueOf(t.ProjectShareclass__c) != String.valueOf(oldT.ProjectShareclass__c))) {
                                             shouldValidate = true;
                                         }
                                 }
                    }
                    
                    if (!shouldValidate) continue;
                    
                    // effective shareclass id: prefer ShareClass__c, fallback to ProjectShareclass__c
                    Id effScId = (t.ShareClass__c != null) ? t.ShareClass__c : t.ProjectShareclass__c;
                    
                    String key = buildKey(t, effScId);
                    if (!incomingByKey.containsKey(key)) incomingByKey.put(key, new List<TaxData__c>());
                    incomingByKey.get(key).add(t);
                    
                    if (t.Type__c != null) incomingTypes.add(normalize(t.Type__c));
                    if (t.Country__c != null) incomingCountries.add(normalize(t.Country__c));
                    if (effScId != null) incomingEffectiveShareClassIds.add(effScId);
                    
                    recordsToValidate.add(t);
                }
                
                if (incomingByKey.isEmpty()) return;
                
                // 2) Query existing TaxData__c that could conflict:
                // filter by Type, Country and (ShareClass__c IN :ids OR ProjectShareclass__c IN :ids)
                List<TaxData__c> existing = new List<TaxData__c>();
                if (!incomingTypes.isEmpty() && !incomingCountries.isEmpty() && !incomingEffectiveShareClassIds.isEmpty()) {
                    existing = [
                        SELECT Id, Type__c, Country__c, ShareClass__c, ProjectShareclass__c, Status__c
                        FROM TaxData__c
                        WHERE Type__c IN :incomingTypes
                        AND Country__c IN :incomingCountries
                        AND Status__c IN :BLOCKING_STATUSES
                        AND (ShareClass__c IN :incomingEffectiveShareClassIds OR ProjectShareclass__c IN :incomingEffectiveShareClassIds)
                    ];
                }
                
                // 3) Build existingByKey using effective id
                Map<String, List<TaxData__c>> existingByKey = new Map<String, List<TaxData__c>>();
                for (TaxData__c e : existing) {
                    Id eEff = (e.ShareClass__c != null) ? e.ShareClass__c : e.ProjectShareclass__c;
                    String k = buildKey(e, eEff);
                    if (!existingByKey.containsKey(k)) existingByKey.put(k, new List<TaxData__c>());
                    existingByKey.get(k).add(e);
                }
                
                // 4) Duplicates inside same transaction
                for (String k : incomingByKey.keySet()) {
                    List<TaxData__c> listForKey = incomingByKey.get(k);
                    if (listForKey.size() > 1) {
                        for (TaxData__c t : listForKey) {
                            t.addError(
                                'Multiple Tax records with the same Type, Country and Share Class are being created in the same transaction. This is not allowed.'
                            );
                        }
                    }
                }
                
                // 5) Prepare maps to resolve names for error messages
                Set<Id> shareClassIdsToQuery = new Set<Id>();
                Set<Id> projShareClassIdsToQuery = new Set<Id>();
                for (TaxData__c t : recordsToValidate) {
                    if (t.ShareClass__c != null) shareClassIdsToQuery.add(t.ShareClass__c);
                    if (t.ProjectShareclass__c != null) projShareClassIdsToQuery.add(t.ProjectShareclass__c);
                }
                
                Map<Id, String> shareClassNameMap = new Map<Id, String>();
                if (!shareClassIdsToQuery.isEmpty()) {
                    for (Share_Class__c sc : [SELECT Id, Name FROM Share_Class__c WHERE Id IN :shareClassIdsToQuery]) {
                        shareClassNameMap.put(sc.Id, sc.Name);
                    }
                }
                
                Map<Id, String> projShareClassNameMap = new Map<Id, String>();
                if (!projShareClassIdsToQuery.isEmpty()) {
                    for (ProjectShareclass__c psc : [
                        SELECT Id, Name
                        FROM ProjectShareclass__c
                        WHERE Id IN :projShareClassIdsToQuery
                    ]) {
                        projShareClassNameMap.put(psc.Id, psc.Name);
                    }
                }
                
                // 6) Check against existing persisted records and add errors with sensible name fallback
                for (String k : incomingByKey.keySet()) {
                    if (!existingByKey.containsKey(k)) continue;
                    List<TaxData__c> incomingRecs = incomingByKey.get(k);
                    List<TaxData__c> existingRecs = existingByKey.get(k);
                    
                    for (TaxData__c t : incomingRecs) {
                        Boolean conflict = false;
                        for (TaxData__c e : existingRecs) {
                            if (t.Id != null && t.Id == e.Id) continue;
                            conflict = true;
                            break;
                        }
                        if (conflict) {
                            // choose name: prefer Share_Class Name, else ProjectShareclass name, else Unknown
                            Id effId = (t.ShareClass__c != null) ? t.ShareClass__c : t.ProjectShareclass__c;
                            String nameToShow = 'Unknown';
                            if (t.ShareClass__c != null && shareClassNameMap.containsKey(t.ShareClass__c)) {
                                nameToShow = shareClassNameMap.get(t.ShareClass__c);
                            } else if (t.ProjectShareclass__c != null && projShareClassNameMap.containsKey(t.ProjectShareclass__c)) {
                                nameToShow = projShareClassNameMap.get(t.ProjectShareclass__c);
                            }
                            
                            t.addError(
                                'A Tax record already exists for Share Class "' + nameToShow +
                                '" with Type "' + (t.Type__c == null ? '' : t.Type__c) +
                                '" and Country "' + (t.Country__c == null ? '' : t.Country__c) +
                                '" in Requested or Yes status. Duplicate records are not allowed.'
                            );
                        }
                    }
                }
            }
    
    public static void validateBelgiumSimulator(List<TaxData__c> newList, Map<Id, TaxData__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        List<TaxData__c> recordsToValidate = new List<TaxData__c>();
        Set<Id> shareClassIds = new Set<Id>();

        for (TaxData__c t : newList) {
            Boolean shouldValidate = false;

            // insert
            if (oldMap == null || !oldMap.containsKey(t.Id)) {
                shouldValidate = true;
            }

            if (!shouldValidate) continue;

            if (t.Type__c == 'Belgium Simulator' && t.Country__c == 'BE') {
                recordsToValidate.add(t);
                if (t.ShareClass__c != null) {
                    shareClassIds.add(t.ShareClass__c);
                }
            }
        }

        if (recordsToValidate.isEmpty()) return;

        // Query Share Classes
        Map<Id, Share_Class__c> shareClassMap = new Map<Id, Share_Class__c>();
        if (!shareClassIds.isEmpty()) {
            shareClassMap = new Map<Id, Share_Class__c>([
                SELECT Id,
                    Name,
                    DividendPolicy__c,
                    Fund__r.LegalForm__c
                FROM Share_Class__c
                WHERE Id IN :shareClassIds
            ]);
        }

        // Query BE registrations
        Set<Id> beRegisteredShareClassIds = new Set<Id>();
        if (!shareClassIds.isEmpty()) {
            for (Country__c c : [
                SELECT Id, ShareClass__c, Country__c
                FROM Country__c
                WHERE ShareClass__c IN :shareClassIds
                AND Country__c = 'BE'
            ]) {
                beRegisteredShareClassIds.add(c.ShareClass__c);
            }
        }

        // Validation
        for (TaxData__c t : recordsToValidate) {

            // ShareClass mandatory for this validation
            if (t.ShareClass__c == null) {
                //t.addError('Belgium Simulator can only be created when a Share Class is defined.');
                continue;
            }

            Share_Class__c sc = shareClassMap.get(t.ShareClass__c);

            Boolean isAccumulating = sc.DividendPolicy__c == 'Accumulating';
            Boolean isFcp = sc.Fund__r != null && sc.Fund__r.LegalForm__c == 'FCP';
            Boolean isRegisteredInBe = beRegisteredShareClassIds.contains(sc.Id);

            if (!(isAccumulating && isFcp && isRegisteredInBe)) {
                t.addError(
                    'Belgium Simulator can only be created for Acc share classes of FCP funds registered in Belgium.'
                );
            }
        }
    }

    public static void handleDates(List<TaxData__c> newList, Map<Id, TaxData__c> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null) return;
        
        for (TaxData__c t : newList) {
            TaxData__c oldT = oldMap.get(t.Id);
            if (oldT == null) continue;
            
            // Rule 1: non-BE TIS / non-BE Asset Test
            // StartDate changed -> Available
            // EndDate changed -> Closed
            if (t.Type__c != 'BE Asset Test'
                && t.Type__c != 'BE TIS') {
                
                if (t.StartDate__c != oldT.StartDate__c
                    && t.StartDate__c != null) {
                    t.Status__c = 'Yes';
                }
                
                if (t.EndDate__c != oldT.EndDate__c
                    && t.EndDate__c != null) {
                    t.Status__c = 'No';
                }
            }
            
            // Rule 2: BE Asset Test → Available → fiscal dates
            if (t.Type__c == 'BE Asset Test'
                && t.Value__c != null
                && t.Value__c != oldT.Value__c) {
                    
                    Date today = Date.today();
                    Integer fiscalYearStart = today.year();
                    
                    t.Status__c = 'Yes';
                    t.StartDate__c = Date.newInstance(fiscalYearStart, 5, 1);
                    t.EndDate__c = Date.newInstance(fiscalYearStart + 1, 4, 30);
                }
            
            // ✅ Rule 3: BE TIS → Value changed → StartDate & EndDate = today
            if (t.Type__c == 'BE TIS'
                && t.Value__c != null
                && t.Value__c != oldT.Value__c) {
                    
                    t.Status__c = 'Yes';
                    //t.StartDate__c = Date.today();
                    //t.EndDate__c = Date.today();
                }
        }
    }
    
    public static void archiveHistory(List<TaxData__c> newList, Map<Id, TaxData__c> oldMap) {
        system.debug('archive');
        if (newList == null || newList.isEmpty() || oldMap == null) return;
        
        List<TaxDataHistory__c> historiesToInsert = new List<TaxDataHistory__c>();
        
        for (TaxData__c newRec : newList) {
            TaxData__c oldRec = oldMap.get(newRec.Id);
            if (oldRec == null) continue;
            system.debug('old exist');
            system.debug('newRec.Value__c : '+newRec.Value__c);
            system.debug('oldRec.Value__c : '+oldRec.Value__c);
            system.debug('newRec.Type__c : '+newRec.Type__c);
            // ✅ Conditions complètes
            if (newRec.Value__c != oldRec.Value__c
                && oldRec.Value__c != null
                && (newRec.Type__c == 'BE TIS' || newRec.Type__c == 'BE Asset Test')) {
                    
                    TaxDataHistory__c hist = new TaxDataHistory__c();
                    hist.TaxData__c = oldRec.Id;
                    hist.Value__c = oldRec.Value__c;
                    hist.StartDate__c = newRec.Type__c == 'BE Asset Test' ? oldRec.StartDate__c : null;
                    hist.EndDate__c = newRec.Type__c == 'BE Asset Test' ? oldRec.EndDate__c : null;
                    hist.NAV_Date__c = newRec.Type__c == 'BE TIS' ? oldRec.NAV_Date__c : null;
                    hist.ArchivedOn__c = System.now();
                    hist.ArchivedBy__c = UserInfo.getUserId();
                    
                    historiesToInsert.add(hist);
                }
        }
        
        if (!historiesToInsert.isEmpty()) {
            insert historiesToInsert;
        }
    }
    
    // helper: build key using normalized type/country and the effective shareclass id passed in
    private static String buildKey(TaxData__c t, Id effectiveShareClassId) {
        String typePart = (t.Type__c == null) ? '' : normalize(t.Type__c);
        String countryPart = (t.Country__c == null) ? '' : normalize(t.Country__c);
        String scPart = (effectiveShareClassId == null) ? '' : String.valueOf(effectiveShareClassId);
        return typePart + '|' + countryPart + '|' + scPart;
    }
    
    private static String normalize(String s) {
        if (s == null) return '';
        return s.trim().toLowerCase();
    }

    public static void populateTaxDataName(List<TaxData__c> newList) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        Set<Id> shareClassIds = new Set<Id>();
        Set<Id> projectShareclassIds = new Set<Id>();

        for (TaxData__c rec : newList) {
            if (rec.ShareClass__c != null) {
                shareClassIds.add(rec.ShareClass__c);
            } else if (rec.ProjectShareclass__c != null) {
                projectShareclassIds.add(rec.ProjectShareclass__c);
            }
        }

        Map<Id, Share_Class__c> shareClassMap = new Map<Id, Share_Class__c>();
        if (!shareClassIds.isEmpty()) {
            shareClassMap = new Map<Id, Share_Class__c>([
                SELECT Id, Name__c, Fund__r.Name
                FROM Share_Class__c
                WHERE Id IN :shareClassIds
            ]);
        }

        Map<Id, ProjectShareclass__c> projectShareclassMap = new Map<Id, ProjectShareclass__c>();
        if (!projectShareclassIds.isEmpty()) {
            projectShareclassMap = new Map<Id, ProjectShareclass__c>([
                SELECT Id, Name__c, ProjectProduct__r.InternalShortName__c
                FROM ProjectShareclass__c
                WHERE Id IN :projectShareclassIds
            ]);
        }

        for (TaxData__c rec : newList) {
            String fundName = '';
            String shareClassName = '';

            // Cas Product Catalog
            if (rec.ShareClass__c != null && shareClassMap.containsKey(rec.ShareClass__c)) {
                Share_Class__c sc = shareClassMap.get(rec.ShareClass__c);
                shareClassName = sc.Name__c;
                fundName = (sc.Fund__r != null) ? sc.Fund__r.Name : '';
            }
            // Cas Project
            else if (rec.ProjectShareclass__c != null && projectShareclassMap.containsKey(rec.ProjectShareclass__c)) {
                ProjectShareclass__c psc = projectShareclassMap.get(rec.ProjectShareclass__c);
                shareClassName = psc.Name__c;
                fundName = (psc.ProjectProduct__r != null) ? psc.ProjectProduct__r.InternalShortName__c : '';
            }

            rec.Name = buildRequestName(
                rec.Type__c,
                rec.Country__c,
                fundName,
                shareClassName
            );
        }
    }

    public static String buildRequestName(
        String typeValue,
        String country,
        String fundName,
        String shareClassName
    ) {
        String namePart = '';

        if (!String.isBlank(fundName) && !String.isBlank(shareClassName)) {
            namePart = fundName + ' ' + shareClassName;
        } else if (!String.isBlank(shareClassName)) {
            namePart = shareClassName;
        } else if (!String.isBlank(fundName)) {
            namePart = fundName;
        }

        List<String> parts = new List<String>();

        if (country == 'BE') {
            String typeLabel = normalizeBEType(typeValue);
            if (!String.isBlank(typeLabel)) {
                parts.add(typeLabel);
            }
        } else if (typeValue == 'Transparency') {
            parts.add('Transparency');
        }

        if (!String.isBlank(country)) {
            parts.add(country);
        }

        String prefix = String.join(parts, ' - ') + ' - ';

        // 👉 Date (format court ISO)
        Date d = Date.today();
        String dateStr =
            String.valueOf(d.year()) + '-' +
            String.valueOf(d.month()).leftPad(2, '0') + '-' +
            String.valueOf(d.day()).leftPad(2, '0');

        String suffix = namePart;

        if (!String.isBlank(dateStr)) {
            suffix = suffix + ' – ' + dateStr;
        }

        Integer maxLength = 80;
        Integer remaining = maxLength - prefix.length();

        if (remaining <= 0) {
            return prefix.substring(0, maxLength);
        }

        // 👉 Si trop long, on coupe d'abord le namePart (pas la date)
        if (suffix.length() > remaining) {
            Integer dateLength = dateStr.length() + 3; // " – " + date
            Integer maxNameLength = remaining - dateLength;

            if (maxNameLength > 0) {
                String trimmedName = namePart;
                if (trimmedName.length() > maxNameLength) {
                    trimmedName = trimmedName.substring(0, maxNameLength);
                }
                suffix = trimmedName + ' – ' + dateStr;
            } else {
                // cas extrême → on garde au moins la date
                suffix = dateStr;
            }
        }

        return prefix + suffix;
    }

    public static String normalizeBEType(String typeValue) {
        if (typeValue == 'BE TIS') return 'TIS';
        if (typeValue == 'BE Asset Test') return 'Asset Test';
        if (typeValue == 'Belgium Simulator') return 'Simulator';
        return '';
    }

    /*public static void sendDeletionRequestedNotification(List<TaxData__c> newList, Map<Id, TaxData__c> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null) return;

        List<TaxData__c> recordsToNotify = new List<TaxData__c>();
        Set<Id> shareClassIds = new Set<Id>();

        for (TaxData__c t : newList) {
            TaxData__c oldT = oldMap.get(t.Id);
            if (oldT == null) continue;

            if (t.Status__c == 'De-Registered Requested'
                && oldT.Status__c != 'De-Registered Requested') {
                recordsToNotify.add(t);

                if (t.ShareClass__c != null) {
                    shareClassIds.add(t.ShareClass__c);
                }
            }
        }

        if (recordsToNotify.isEmpty()) return;

        Map<Id, Share_Class__c> shareClassMap = new Map<Id, Share_Class__c>();
        if (!shareClassIds.isEmpty()) {
            shareClassMap = new Map<Id, Share_Class__c>([
                SELECT Id, Name__c, Fund__r.Name
                FROM Share_Class__c
                WHERE Id IN :shareClassIds
            ]);
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        String taxDl = 'khadija.el-gdaouni.external@carmignac.com';

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();

        for (TaxData__c t : recordsToNotify) {
            String shareClassName = '';
            String fundName = '';

            if (t.ShareClass__c != null && shareClassMap.containsKey(t.ShareClass__c)) {
                Share_Class__c sc = shareClassMap.get(t.ShareClass__c);
                shareClassName = sc.Name__c;
                fundName = sc.Fund__r != null ? sc.Fund__r.Name : '';
            }

            String recordUrl = baseUrl + '/' + t.Id;
            String scUrl = t.ShareClass__c != null ? baseUrl + '/' + t.ShareClass__c : '';

            String subject = '[Tax Transparency] Deletion request - ' + shareClassName;

            String htmlBody =
                '<p>Hello Tax Team,</p>' +
                '<p>A Tax Transparency deletion request has been submitted.</p>' +
                '<ul>' +
                '<li><b>Fund:</b> ' + fundName + '</li>' +
                '<li><b>Share Class:</b> ' + shareClassName + '</li>' +
                '<li><b>Country:</b> ' + t.Country__c + '</li>' +
                '<li><b>Type:</b> ' + t.Type__c + '</li>' +
                '<li><b>Tax Data:</b> <a href="' + recordUrl + '">Open Tax Request</a></li>' +
                '<li><b>Share Class:</b> <a href="' + scUrl + '">Open Share Class</a></li>' +
                '</ul>' +
                '<p>Thanks,</p>';

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ taxDl });
            email.setSubject(subject);
            email.setHtmlBody(htmlBody);

            emails.add(email);
        }

        if (!emails.isEmpty()) {
            system.debug('send email');
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);

            for (Messaging.SendEmailResult r : results) {
                if (!r.isSuccess()) {
                    for (Messaging.SendEmailError err : r.getErrors()) {
                        System.debug('Email error: ' + err.getMessage());
                    }
                } else {
                    System.debug('Email sent successfully');
                }
            }
        }
    }*/
}