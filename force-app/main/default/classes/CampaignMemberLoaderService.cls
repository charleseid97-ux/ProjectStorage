/**
 * @description       : 
 * @author            : SILA Nicolas
 * @group             : 
 * @last modified on  : 20-12-2023
 * @last modified by  : Thanina YAYA
**/
public class CampaignMemberLoaderService extends ObjectLoaderService
{
    private enum IdentityField {
        FirstName,
        LastName,
        Email
    }

    private enum RowAction {
        NewLead,
        ExistingLead,
        ExistingContact,
        ExistingMember,
        InvalidEmail
    }

    private class RowInfos {
        private final Boolean ALLOW_INCOMPLETE_ROWS = true;

        Integer index { get; set; }
        Id recordId { get; set; }
        String status { get; set; }
        String firstName { get; set; }
        String lastName { get; set; }
        String email { get; set; }
        String company { get; set; }
        String phone { get; set; }
        String jobTitle { get; set; }
        String country { get; set; }
        String mailingCountry { get; set; }
        String city { get; set; }
        String postalCode { get; set; }
        String street { get; set; }
        String attendanceRate { get; set; }
        String attendanceDuration { get; set; }
        String ipCity { get; set; }
        Boolean recordPhone { get; set; }
        Boolean recordMobilePhone { get; set; }
        Boolean recordAddress { get; set; }
        Boolean recordJobTitle { get; set; }
        
        List<SObject> objectRefs { get; set; }
        RowAction action { get; set; }
        Boolean isValid { get; private set; }

        String identity {
            get {
                return email.toLowerCase();
            }
        }

        public RowInfos(String rawData, String separator, Integer index, ImportResult result) {
            this.init(rawData, separator, index, result);
        }

        public RowInfos(String rawData, String separator, ImportResult result) {
            this.init(rawData, separator, null, result);
        }

        public RowInfos(String rawData, String separator) {
            this.init(rawData, separator, null, null);
        }

        public List<SObject> updateStatus(ImportResult result) {
            List<SObject> dirtyObjects = new List<SObject>();

            for (SObject objectRef: objectRefs)
            {
                if (objectRef == null) {
                    continue;
                }
                if (!objectRef.getSObjectType().getDescribe().fields.getMap().keySet().contains('status')) {
                    continue;
                }
                if (objectRef.get('status') == status) {
                    continue;
                }
                if (String.isBlank(String.valueOf(objectRef.get('status')))) {
                    result.addError('Line ' + index + '][INVALID_STATUS', String.valueOf(objectRef.get('status')));
                    continue;
                }

                objectRef.put('status', status);
                if (String.isNotBlank(ipCity)) {
                    objectRef.put('IP_City__c', ipCity);
                }
                if (String.isNotBlank(attendanceDuration)) {
                    objectRef.put('Attendance_duration__c', Decimal.valueOf(attendanceDuration));
                }
                if (String.isNotBlank(attendanceRate)) {
                    objectRef.put('Attendance_rate__c', Decimal.valueOf(attendanceRate));
                }
                dirtyObjects.add(objectRef);
            }

            return dirtyObjects;
        }

        public String toRow(String fieldsSeparator) {
            return status +
                    fieldsSeparator +
                    firstName +
                    fieldsSeparator +
                    lastName +
                    fieldsSeparator +
                    email +
                    fieldsSeparator +
                    phone +
                    fieldsSeparator +
                    company +
                    fieldsSeparator +
                    jobTitle +
                    fieldsSeparator +
                    country +
                    fieldsSeparator +
                    mailingCountry +
                    fieldsSeparator +
                    city +
                    fieldsSeparator +
                    postalCode +
                    fieldsSeparator +
                    street +
                    fieldsSeparator +
                    attendanceRate +
                    fieldsSeparator +
                    attendanceDuration +
                    fieldsSeparator +
                    ipCity +
                    fieldsSeparator +
                    action.name();
        }

        private void init(String rawData, String separator, Integer index, ImportResult result) {
            this.isValid = true;

            objectRefs = new List<SObject>();

            this.index = index;

            if (String.isBlank(rawData)) {
                if (result != null)
                {
                    result.addError('Line ' + index + '][INVALID CSV Row', 'Empty row.');
                }
                result.invalidRowCount++;
                this.isValid = false;
                return;
            }

            String[] fields = rawData.split('\\' + separator);

            if (!ALLOW_INCOMPLETE_ROWS && fields.size() < 15) {
                if (result != null) {
                    result.addError(
                            'Line ' + index + '][INCOMPLETE_CSV_ROW', 'Missing CSV columns (' + fields.size() + '/15)'
                    );
                    result.invalidRowCount++;
                }
                this.isValid = false;
            }

            this.status = fields.size() > 0 ? fields[0] : '';
            this.firstName = fields.size() > 1 ? fields[1] : '';
            this.lastName = fields.size() > 2 ? fields[2] : '';
            this.email = fields.size() > 3 ? fields[3] : '';
            this.phone = fields.size() > 4 ? fields[4] : '';
            this.company = fields.size() > 5 ? fields[5] : '';
            this.jobTitle = fields.size() > 6 ? fields[6] : '';
            this.country = fields.size() > 7 ? fields[7] : '';
            this.mailingCountry = fields.size() > 8 ? fields[8] : '';
            this.city = fields.size() > 9 ? fields[9] : '';
            this.postalCode = fields.size() > 10 ? fields[10] : '';
            this.street = fields.size() > 11 ? fields[11] : '';
            this.attendanceRate = fields.size() > 12 ? fields[12] : '';
            this.attendanceDuration = fields.size() > 13 ? fields[13] : '';
            this.ipCity = fields.size() > 14 ? fields[14] : '';
            System.debug('Status: ' + this.status + '\nfirstName: ' + this.firstName + '\nlastName: ' + this.lastName + '\nEmail: ' + this.email + '\nPhone: ' + this.phone + '\nCompany: ' + this.company + '\njobTitle: ' + this.jobTitle);
            System.debug('Country: ' + this.country + '\nmailingCountry: ' + this.mailingCountry + '\nCity: ' + this.city + '\nPostalCode :' + this.postalCode + '\nStreet: ' + this.street + '\nRate: ' + this.attendanceRate + '\nDuration: ' + this.attendanceDuration + '\nipCity: ' + this.ipCity);
        }
    }

    private class ImportResult
    {
        private final String SUMMARY_EMAIL_SUBJECT = 'Campaign Members Import Summary';
        private final String SUMMARY_ERROR_LOG_NAME = 'error_logs.txt';

        public Integer newLeadsCount { get; set; }
        public Integer existingLeadsCount { get; set; }
        public Integer existingContactsCount { get; set; }
        public Integer existingMembersCount { get; set; }
        public Integer statusUpdates { get; set; }
        public Integer failedLeadCreation { get; set; }
        public Integer failedMemberInsertion { get; set; }
        public Integer failedStatusUpdates { get; set; }
        public Integer invalidEmailCount { get; set; }
        public Integer invalidRowCount { get; set; }
        public Integer newMembersCount { get; set; }
        public Integer leadContactUpdates { get; set; }
        public Integer failedLeadContactUpdates { get; set; }

        public Integer totalFailures {
            get
            {
                return failedLeadCreation + failedMemberInsertion + invalidEmailCount + invalidRowCount + failedLeadContactUpdates;
            }
        }
        public List<String> errorLogs { get; private set; }

        public ImportResult()
        {
            newLeadsCount = 0;
            existingLeadsCount = 0;
            existingContactsCount = 0;
            existingMembersCount = 0;
            statusUpdates = 0;
            failedLeadCreation = 0;
            failedMemberInsertion = 0;
            failedStatusUpdates = 0;
            invalidEmailCount = 0;
            invalidRowCount = 0;
            newMembersCount = 0;
            leadContactUpdates = 0;
            failedLeadContactUpdates = 0;
            errorLogs = new List<String>();
        }

        public void sendSummaryEmail(String addressTo)
        {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            mail.setToAddresses(new List<String> { addressTo });
            mail.setSubject(SUMMARY_EMAIL_SUBJECT);
            mail.setHtmlBody(createSummaryEmailBody());

            if (errorLogs.size() > 0)
            {
                mail.setFileAttachments(createErrorsLogAttachments());
            }

            if (!Test.isRunningTest())
            {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
        }

        public void addError(String errorSource, String errorMessage)
        {
            this.errorLogs.add('[ERROR][' + errorSource + '] ' + errorMessage);
        }

        private List<Messaging.EmailFileAttachment> createErrorsLogAttachments()
        {
            Blob content = Blob.valueOf(String.join(errorLogs, '\n'));

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();

            attachment.setFileName(SUMMARY_ERROR_LOG_NAME);
            attachment.setBody(content);

            return new List<Messaging.EmailFileAttachment>{attachment};
        }

        private String createSummaryEmailBody()
        {
            return '' +
                    '<h3>Campaign Members Import Results</h3>' +
                    '<p>' +
                    '   <b>Existing matching Members: </b>' +
                    '   <span>' + existingMembersCount + '</span>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Existing matching contacts: </b>' +
                    '   <span>' + existingContactsCount + '</span>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Existing matching Leads: </b>' +
                    '   <span>' + existingLeadsCount + '</span>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Updated Leads and Contacts: </b>' +
                    '   <span>' + leadContactUpdates + '</span>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Updated statuses: </b>' +
                    '   <b style="color: #00AB66;">' + statusUpdates + '</b>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Newly created Leads: </b>' +
                    '   <b style="color: #00AB66;">' + newLeadsCount + '</b>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Total new members: </b>' +
                    '   <b style="color: #00AB66;">' + newMembersCount + '</b>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Leads failed to be created: </b>' +
                    '   <b style="color: red;">' + failedLeadCreation + '</b>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Members failed to be added: </b>' +
                    '   <b style="color: red;">' + failedMemberInsertion + '</b>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Failed status updates: </b>' +
                    '   <b style="color: red;">' + failedStatusUpdates + '</b>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Failed leads and contact updates: </b>' +
                    '   <b style="color: red;">' + failedLeadContactUpdates + '</b>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Invalid emails: </b>' +
                    '   <b style="color: red;">' + invalidEmailCount + '</b>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Invalid CSV rows: </b>' +
                    '   <b style="color: red;">' + invalidRowCount + '</b>' +
                    '</p>' +
                    '<p>' +
                    '   <b>Total Failures: </b>' +
                    '   <b style="color: red;">' + totalFailures + '</b>' +
                    '</p>';
        }
    }

    private static final Boolean IS_DEBUG = false;
    private static final String DEBUG_EMAIL_ADDRESS = 's.lozzi@kanelservices.com';
    private static String summaryEmailAddress
    {
        get
        {
            if (IS_DEBUG)
            {
                return DEBUG_EMAIL_ADDRESS;
            }
            return UserInfo.getUserEmail();
        }
    }

    private final String EMAIL_VALIDATION_REGEX = '.*@.*\\..*';
    private final Pattern EMAIL_ADDRESS_PATTERN = Pattern.compile(EMAIL_VALIDATION_REGEX);

    public Campaign currentCampaign
    {
        get
        {
            if (m_currentCampaign == null)
            {
                getCampaign();
            }
            return m_currentCampaign;
        }
    }

    private Campaign m_currentCampaign;

    public CampaignMemberLoaderService()
    {
        super();
    }

    public CampaignMemberLoaderService(Id documentId, Id recordId, String fieldsSeparator, Boolean skipFirstRow)
    {
        super(documentId, recordId, fieldsSeparator, skipFirstRow);
    }


    public override List<String> getPreviewRecords()
    {
        String fileContent = getFileContent();

        StringSplitIterator iterator = new StringSplitIterator(fileContent);

        if (skipFirstRow && iterator.hasNext())
        {
            iterator.next();
        }

        List<String> records = iterator.next(IMPORT_PREVIEW_SIZE);

        List<RowInfos> rowsInfos = parseRows(records);

        updateRowsActions(rowsInfos);

        return infosToRows(rowsInfos);
    }

    public override void insertRecords()
    {
        if (recordId == null) return;

        checkForRunningJobs();

        String fileContent = this.getFileContent();

        Database.delete(documentId);

        StringSplitIterator iterator = new StringSplitIterator(fileContent);

        if (skipFirstRow && iterator.hasNext()) {
            iterator.next();
        }

        List<String> rowsToProcess = iterator.next(MAX_PROCESSING_RECORDS);

        if (iterator.hasNext())
        {
            throw new ImportException('Too many rows to process. Maximum allowed is ' + MAX_PROCESSING_RECORDS + '.');
        }

        CampaignMemberLoaderService.processRows(rowsToProcess, recordId, fieldsSeparator);
    }

    @Future
    public static void processRows(List<String> rows, Id recordId, String fieldsSeparator)
    {
        CampaignMemberLoaderService service = new CampaignMemberLoaderService();

        service.recordId = recordId;
        service.fieldsSeparator = fieldsSeparator;

        try
        {
            ImportResult result = new ImportResult();

            List<RowInfos> rowsInfos = service.parseRows(rows, false, result);

            service.updateRowsActions(rowsInfos);

            service.processObjects(rowsInfos, result);

            result.sendSummaryEmail(summaryEmailAddress);
        }
        catch (Exception ex)
        {
            service.sendErrorEmail(ex.getMessage(), summaryEmailAddress);
            throw ex;
        }
    }

    private void checkForRunningJobs()
    {
        List<AsyncApexJob> runningJobs = [
                SELECT
                        Id
                FROM
                        AsyncApexJob
                WHERE
                ApexClass.Name = 'CampaignMemberLoaderService' AND
                MethodName = 'processRows' AND
                Status IN ('Queued', 'Preparing', 'Processing')
        ];

        if (runningJobs.size() > 0) {
            throw new ImportException('Please wait for the previous import to finish first.');
        }
    }

    private ImportResult processObjects(List<RowInfos> rowsInfos, ImportResult result)
    {
        Map<Integer, CampaignMember> newMembers = new Map<Integer, CampaignMember>();
        Map<Integer, List<SObject>> dirtyObjects = new Map<Integer, List<SObject>>();
        Map<Integer, Lead> newLeads = new Map<Integer, Lead>();
        Map<Integer, RowInfos> leadCMInfos = new Map<Integer, RowInfos>();
        Map<Integer, Lead> leadToUpdate = new Map<Integer, Lead>();
        Map<Integer, Contact> contactToUpdate = new Map<Integer, Contact>();

        for (RowInfos infos: rowsInfos)
        {
            if (infos.action == RowAction.InvalidEmail) {
                handleInvalidEmail(infos, result);
            }
            else if (infos.action == RowAction.ExistingMember) {
                handleExistingMember(infos, dirtyObjects, result);
            }
            else if (infos.action == RowAction.NewLead) {
                handleNewLead(infos, newLeads, result);
                leadCMInfos.put(infos.index, infos);
            }
            else if (infos.action == RowAction.ExistingContact) {
                handleExistingContact(infos, newMembers, dirtyObjects, result, contactToUpdate);
            }
            else if (infos.action == RowAction.ExistingLead) {
                handleExistingLead(infos, newMembers, dirtyObjects, result, leadToUpdate);
            }
        }

        createObjects(newLeads, dirtyObjects, newMembers, result, leadCMInfos);
        updateRecords((Map<Integer, SObject>) contactToUpdate, result);
        updateRecords((Map<Integer, SObject>) leadToUpdate, result);

        return result;
    }

    private void handleInvalidEmail(RowInfos infos, ImportResult result) {
        result.invalidEmailCount++;
        result.addError('Line ' + infos.index + '][INVALID_EMAIL', '"' + infos.email + '"');
    }

    private void handleExistingMember(RowInfos infos, Map<Integer, List<SObject>> dirtyObjects, ImportResult result) {
        result.existingMembersCount++;
        updateStatus(infos, dirtyObjects, result);
    }

    private void handleExistingContact(
            RowInfos infos,
            Map<Integer, CampaignMember> newMembers,
            Map<Integer, List<SObject>> dirtyObjects,
            ImportResult  result,
            Map<Integer, Contact> contactToUpdate
    )
    {
        result.existingContactsCount++;
        result.newMembersCount++;

        newMembers.put(infos.index, createContactMember(infos.recordId, infos.status, infos.attendanceRate, infos.attendanceDuration, infos.ipCity));
        updateStatus(infos, dirtyObjects, result);
        updateContact(infos, contactToUpdate, result);
    }

    private void updateContact(RowInfos infos, Map<Integer, Contact> contactToUpdate, ImportResult result) {
        if (!infos.recordPhone || !infos.recordMobilePhone || !infos.recordAddress || !infos.recordJobTitle) {
            Contact c = new Contact (Id = infos.recordId);
            if (!infos.recordPhone) {
                c.Phone = infos.phone;
            }
            else if (!infos.recordMobilePhone) {
                c.MobilePhone = infos.Phone;
            }
            if (!infos.recordAddress) {
                c.MailingCountry = infos.MailingCountry;
                c.MailingCity = infos.City;
                c.MailingStreet = infos.Street;
                c.MailingPostalCode = infos.PostalCode;
            }
            if (!infos.recordJobTitle) {
                c.JobTitle__c = infos.jobTitle;
            }
            contactToUpdate.put(infos.index, c);
            result.leadContactUpdates++;
        }
    }

    private void handleExistingLead(
            RowInfos infos,
            Map<Integer, CampaignMember> newMembers,
            Map<Integer, List<SObject>> dirtyObjects,
            ImportResult  result,
            Map<Integer, Lead> leadToUpdate
    )
    {
        result.existingLeadsCount++;
        result.newMembersCount++;

        newMembers.put(infos.index, createLeadMember(infos.recordId, infos.status, infos.attendanceRate, infos.attendanceDuration, infos.ipCity));
        updateStatus(infos, dirtyObjects, result);
        updateLead(infos, leadToUpdate, result);
    }

    private void updateLead(RowInfos infos, Map<Integer, Lead> leadToUpdate, ImportResult result) {
        if (!infos.recordPhone || !infos.recordMobilePhone || !infos.recordAddress) {
            Lead l = new Lead(Id = infos.recordId);
            if (!infos.recordPhone) {
                l.Phone = infos.phone;
            }
            else if (!infos.recordMobilePhone) {
                l.MobilePhone = infos.Phone;
            }
            if (!infos.recordAddress) {
                l.Country = infos.MailingCountry;
                l.City = infos.City;
                l.Street = infos.Street;
                l.PostalCode = infos.PostalCode;
            }
            if (!infos.recordJobTitle) {
                l.Job_Title__c = infos.jobTitle;
            }
            leadToUpdate.put(infos.index, l);
            result.leadContactUpdates++;
        }
    }

    private void handleNewLead(RowInfos infos, Map<Integer, Lead> newLeads, ImportResult result) {
        result.newLeadsCount++;
        result.newMembersCount++;

        newLeads.put(infos.index, createLead(infos));
    }

    private void updateStatus(RowInfos infos, Map<Integer, List<SObject>> dirtyObjects, ImportResult result) {
        SObject[] newDirtyObjects = infos.updateStatus(result);
        dirtyObjects.put(infos.index, newDirtyObjects);
        result.statusUpdates += newDirtyObjects.size();
    }

    private void createObjects(
            Map<Integer, Lead> newLeads,
            Map<Integer, List<SObject>> dirtyObjects,
            Map<Integer, CampaignMember> newMembers,
            ImportResult result,
            Map<Integer, RowInfos> leadCMInfos
    )
    {
        handleNewLeadsDML(newLeads, result);
        newMembers.putAll(createMembersFromLeads(newLeads, leadCMInfos));
        handleNewMembersDML(newMembers, result);
        separateAndUpdateObjects(dirtyObjects, result);
    }

    private void updateRecords(Map<Integer, SObject> records, ImportResult result) {
        if (records.size() > 0) {
            List<Integer> indices = new List<Integer>(records.keySet());
            List<Database.SaveResult> dmlResults = Database.update(records.values(), false);

            for (Integer i = 0; i < dmlResults.size(); i++) {
                if (dmlResults[i].success) {
                    continue;
                }
                result.leadContactUpdates--;
                result.failedLeadContactUpdates++;
                for (Database.Error err: dmlResults[i].errors) {
                    result.addError('Line ' + indices[i] + '][' + err.statusCode, err.message);
                }
            }
        }
    }

    private void separateAndUpdateObjects(Map<Integer, List<SObject>> dirtyObjects, ImportResult result) {
        Map<SObjectType, Map<Integer, SObject>> dirtyObjectsMap = new Map<SObjectType, Map<Integer, SObject>>();

        for (Integer index: dirtyObjects.keySet()) {
            for (SObject dirtyObject: dirtyObjects.get(index)) {
                SObjectType oType = dirtyObject.getSObjectType();
                if (!dirtyObjectsMap.containsKey(oType)) {
                    dirtyObjectsMap.put(oType, new Map<Integer, SObject>());
                }
                dirtyObjectsMap.get(oType).put(index, dirtyObject);
            }
        }

        for (Map<Integer, SObject> dirtyObjectsByType: dirtyObjectsMap.values()) {
            handleUpdateStatusesDML(dirtyObjectsByType, result);
        }
    }

    private Map<Integer, CampaignMember> createMembersFromLeads(Map<Integer, Lead> leads, Map<Integer, RowInfos> leadCMInfos) {
        Map<Integer, CampaignMember> newMembers = new Map<Integer, CampaignMember>();

        for (Integer index: leads.keySet()) {
            Lead aLead = leads.get(index);
            RowInfos infos = leadCMInfos.get(index);
            if (aLead.Id != null) {
                newMembers.put(index, createLeadMember(aLead.Id, aLead.Status, infos.attendanceRate, infos.attendanceDuration, infos.ipCity));
            }
        }

        return newMembers;
    }

    private void handleNewLeadsDML(Map<Integer, Lead> newLeads, ImportResult result) {
        List<Integer> indices = new List<Integer>();
        List<Lead> leads = new List<Lead>();
        for (Integer index: newLeads.keySet()) {
            indices.add(index);
            leads.add(newLeads.get(index));
        }
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.assignmentRuleHeader.useDefaultRule= true;

        for(Lead aLead : leads) {
            aLead.setOptions(dmlOpts);
        }

        List<Database.SaveResult> dmlResults = Database.insert(leads, false);

        for (Integer i = 0; i < dmlResults.size(); i++) {
            if (dmlResults[i].success)
            {
                continue;
            }

            result.newLeadsCount--;
            result.newMembersCount--;
            result.failedLeadCreation++;
            for (Database.Error err: dmlResults[i].errors)
            {
                result.addError('Line ' + indices[i] + '][' + err.statusCode, err.message);
            }
        }
    }

    private void handleNewMembersDML(Map<Integer, CampaignMember> newMembers, ImportResult result) {
        List<Integer> indices = new List<Integer>();
        List<CampaignMember> members = new List<CampaignMember>();
        for (Integer index: newMembers.keySet()) {
            indices.add(index);
            members.add(newMembers.get(index));
        }

        List<Database.SaveResult> dmlResults = Database.insert(members, false);

        for (Integer i = 0; i < dmlResults.size(); i++) {
            if (dmlResults[i].success) {
                continue;
            }
            result.newMembersCount--;
            result.failedMemberInsertion++;
            for (Database.Error err: dmlResults[i].errors) {
                result.addError('Line ' + indices[i] + '][' + err.statusCode, err.message);
            }
        }
    }

    private void handleUpdateStatusesDML(Map<Integer, SObject> dirtyObjects, ImportResult result) {
        List<Integer> indices = new List<Integer>();
        List<SObject> objects = new List<SObject>();
        for (Integer index: dirtyObjects.keySet()) {
            indices.add(index);
            objects.add(dirtyObjects.get(index));
        }

        List<Database.SaveResult> dmlResults = Database.update(objects, false);

        for (Integer i = 0; i < dmlResults.size(); i++) {
            if (dmlResults[i].success) {
                continue;
            }
            result.statusUpdates--;
            result.failedStatusUpdates++;
            for (Database.Error err: dmlResults[i].errors) {
                result.addError('Line ' + indices[i] + '][' + err.statusCode, err.message);
            }
        }
    }

    private List<String> infosToRows(List<RowInfos> rowsInfos) {
        List<String> output = new List<String>();
        for (RowInfos info: rowsInfos) {
            output.add(info.toRow(fieldsSeparator));
        }
        return output;
    }

    private void updateRowsActions(List<RowInfos> rowsInfos) {
        Map<String, Set<Object>> filter = createFilter(rowsInfos);
        List<String> CampaignIdFilter = new List<String> {'CampaignId = \'' + String.valueOf(recordId) + '\''};
        List<String> LeadFilter = new List<String> {'IsConverted = FALSE'};

        Map<String, SObject> leads = getIndexedMatchingRecords('Lead', filter, LeadFilter);
        Map<String, SObject> contacts = getIndexedMatchingRecords('Contact', filter, null);
        Map<String, SObject> members = getIndexedMatchingRecords('CampaignMember', filter, CampaignIdFilter);

        for (RowInfos info: rowsInfos)
        {
            String identity = info.identity;
            if (!isValidEmailAddress(info.email)) {
                info.action = RowAction.InvalidEmail;
            }
            else {
                if (leads.containsKey(identity)) {
                    Lead l = (Lead) leads.get(identity);
                    info.action = RowAction.ExistingLead;
                    info.objectRefs.add(members.get(identity));
                    info.recordId = l.Id;
                    info.recordAddress = l.Country != null || l.City != null || l.Street != null || l.PostalCode != null;
                    info.recordPhone = l.Phone != null;
                    info.recordMobilePhone = l.MobilePhone != null || l.Phone == info.Phone;
                    info.recordJobTitle = l.Job_Title__c != null;
                }
                if (contacts.containsKey(identity)) {
                    Contact c = (Contact) contacts.get(identity);
                    info.action = RowAction.ExistingContact;
                    info.objectRefs.add(members.get(identity));
                    info.recordId = c.Id;
                    info.recordAddress = c.MailingCountry != null || c.MailingCity != null || c.MailingStreet != null || c.MailingPostalCode != null;
                    info.recordPhone = c.Phone != null;
                    info.recordMobilePhone = c.MobilePhone != null || c.Phone == info.Phone;
                    info.recordJobTitle = c.JobTitle__c != null;
                }
                if (members.containsKey(identity)) {
                    CampaignMember cm = (CampaignMember) members.get(identity);
                    info.action = RowAction.ExistingMember;
                    info.objectRefs.add(cm);
                    info.recordId = cm.Id;
                }
                if (info.action == null) {
                    info.action = RowAction.NewLead;
                }
            }
        }
    }

    private Map<String, SObject> getIndexedMatchingRecords(
            String targetType, Map<String, Set<Object>> filter, List<String> queryFilters
    )
    {
        return indexRecords(getMatchingRecords(targetType, filter, queryFilters).values());
    }

    private List<RowInfos> parseRows(List<String> rows, Boolean keepInvalidRows, ImportResult result) {
        List<RowInfos> rowsInfos = new List<RowInfos>();
        Integer index = skipFirstRow ? 1 : 0;

        for (String row: rows) {
            index++;
            RowInfos info = new RowInfos(row, fieldsSeparator, index, result);
            if (info.isValid || keepInvalidRows) {
                rowsInfos.add(info);
            }
        }

        return rowsInfos;
    }

    private List<RowInfos> parseRows(List<String> rows) {
        return parseRows(rows, true, null);
    }

    private Map<String, Set<Object>> createFilter(List<RowInfos> infos) {
        Map<String, Set<Object>> filter = new Map<String, Set<Object>>();
        for (IdentityField field: IdentityField.values())
        {
            filter.put(field.name(), new Set<Object>());
        }
        for (RowInfos info: infos)
        {
            filter.get(IdentityField.FirstName.name()).add(info.firstName.toLowerCase());
            filter.get(IdentityField.LastName.name()).add(info.lastName.toLowerCase());
            filter.get(IdentityField.Email.name()).add(info.email.toLowerCase());
        }
        return filter;
    }

    private Map<String, SObject> indexRecords(List<SObject> records)
    {
        Map<String, SObject> output = new Map<String, SObject>();

        for (SObject record: records)
        {
            //Can't use containsKey method for SObject recod
            Map<String, Object> fieldsToValue = record.getPopulatedFieldsAsMap();
            String email = (String)record.get(IdentityField.Email.name());
            String personalEmail =(fieldsToValue.containsKey('PersonalEmail__c'))?(String)record.get('PersonalEmail__c'):null;

            if (personalEmail != null)
            {
                output.put(personalEmail, record);
            }
            if (email != null)
            {
                output.put(email, record);
            }
        }

        return output;
    }

    private Map<Id, SObject> getMatchingRecords(
            String targetType, Map<String, Set<Object>> filter, List<String> queryFilters
    )
    {
        String emailField = IdentityField.Email.name();
        List<String> emailAddresses = stringifyObjects(filter.get(emailField));
        Map<Id, SObject> matches = queryEmailMatches(targetType, emailAddresses, queryFilters);
        return matches;
    }

    //noinspection ApexUnusedDeclaration
    private Map<Id, SObject> queryEmailMatches(
            String targetType, List<String> emailAddresses, List<String> filters
    )
    {
        Boolean hasPersonalEmail = true;
        String additionalFields = '';
        if (targetType == 'Lead') {
            additionalFields = ', PersonalEmail__c, Job_Title__c, Country, City, Street, PostalCode';
        }
        else if (targetType == 'Contact') {
            additionalFields = ', PersonalEmail__c, JobTitle__c, MailingCountry, MailingCity, MailingStreet, MailingPostalCode';
        }
        else {
            hasPersonalEmail = false;
            additionalFields = ', Status, Attendance_rate__c, Attendance_duration__c, IP_City__c';
        }

        List<String> binaryExpressions = new List<String>();
        String emailFilterClause = '(Email != \'\' AND Email IN :emailAddresses)';

        if (filters != null)
        {
            binaryExpressions.addAll(filters);
        }

        if (hasPersonalEmail)
        {
            String personalEmailFilterClause = '(PersonalEmail__c != \'\' AND PersonalEmail__c IN :emailAddresses)';
            emailFilterClause = '(' + emailFilterClause + ' OR ' + personalEmailFilterClause + ')';
        }

        binaryExpressions.add(emailFilterClause);

        String query = '' +
                'SELECT Id, FirstName, LastName, Email, Phone, MobilePhone' + additionalFields + 
                ' FROM ' + targetType +
                ' WHERE ' + String.join(binaryExpressions, ' AND ');

        System.debug(query);

        return new Map<Id, SObject>(Database.query(query));
    }

    private Lead createLead(RowInfos info)
    {
        return new Lead(
                Status = info.status,
                FirstName = info.firstName,
                LastName = info.lastName,
                Email = info.email,
                Phone = info.phone,
                Company = info.company,
                Job_Title__c = info.jobTitle,
                Country__c = info.country,
                Country = info.mailingCountry,
                City = info.city,
                PostalCode = info.postalCode,
                Street = info.Street,
                LeadSource = 'Event'
        );
    }

    private CampaignMember createLeadMember(Id leadId, String status, String attendanceRate, String attendanceDuration, String ipCity)
    {
        return new CampaignMember(
                CampaignId = recordId,
                LeadId = leadId,
                Status = status,
                Attendance_rate__c = attendanceRate != '' ? Decimal.valueOf(attendanceRate) : 0,
                Attendance_duration__c = attendanceDuration != '' ? Decimal.valueOf(attendanceDuration) : 0,
                IP_City__c = ipCity
        );
    }

    private CampaignMember createContactMember(Id contactId, String status, String attendanceRate, String attendanceDuration, String ipCity)
    {
        return new CampaignMember(
                CampaignId = recordId,
                ContactId = contactId,
                Status = status,
                Attendance_rate__c = attendanceRate != '' ? Decimal.valueOf(attendanceRate) : 0,
                Attendance_duration__c = attendanceDuration != '' ? Decimal.valueOf(attendanceDuration) : 0,
                IP_City__c = ipCity
        );
    }

    private Boolean isValidEmailAddress(String emailAddress)
    {
        if (emailAddress == null)
        {
            return false;
        }
        return EMAIL_ADDRESS_PATTERN.matcher(emailAddress).matches();
    }

    private static List<String> stringifyObjects(Set<Object> objs)
    {
        List<String> output = new List<String>();

        for (Object obj: objs)
        {
            output.add(obj.toString());
        }

        return output;
    }

    private void getCampaign()
    {
        m_currentCampaign = [
                SELECT
                        Id,
                        CVent_Counter__c
                FROM
                        Campaign
                WHERE
                        Id = :recordId
        ];
    }
}