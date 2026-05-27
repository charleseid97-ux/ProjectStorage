public with sharing class TaxEmailService {

    private static final String COUNTRY_AT = 'AT';
    private static final String COUNTRY_CH = 'CH';
    private static final String COUNTRY_UK = 'UK';
    private static final String COUNTRY_GB = 'GB';

    private static final String SOURCE_PMT = 'PMT';

    private static final String SCENARIO_TRANSPARENCY = 'Transparency';
    private static final String SCENARIO_TRANSPARENCY_QUARTERLY = 'TransparencyQuarterly';
    private static final String SCENARIO_MERGER_LIQUIDATION = 'MergerLiquidation';

    private static final String STATUS_REQUESTED = 'Requested';
    private static final String STATUS_YES = 'Yes';

    private static final String TYPE_TRANSPARENCY = 'Transparency';

    private static final String SC_STATUS_CLOSED_LIQUIDATED = 'Closed - liquidated';
    private static final String SC_STATUS_CLOSED_MERGED = 'Closed - merged';

    public static void sendATTransparencyEmails(List<TaxData__c> newList) {
        sendTransparencyEmailsByCountry(newList, COUNTRY_AT);
    }

    public static void sendCHTransparencyEmails(List<TaxData__c> newList) {
        sendTransparencyEmailsByCountry(newList, COUNTRY_CH);
    }

    public static void sendUKQuarterlyTransparencyEmails() {
        TaxEmailConfiguration__mdt config = getConfiguration(COUNTRY_UK, SCENARIO_TRANSPARENCY_QUARTERLY);
        if (!isValidConfiguration(config)) {
            return;
        }

        EmailTemplate template = getTemplateByDeveloperName(config.TemplateDeveloperName__c);
        if (template == null) {
            return;
        }

        Date quarterStartDate = getCurrentQuarterStartDate();
        Date quarterEndDate = getCurrentQuarterEndDate();

        Datetime quarterStart = Datetime.newInstance(
            quarterStartDate.year(),
            quarterStartDate.month(),
            quarterStartDate.day()
        );

        Date nextDay = quarterEndDate.addDays(1);
        Datetime quarterEndExclusive = Datetime.newInstance(
            nextDay.year(),
            nextDay.month(),
            nextDay.day()
        );

        List<TaxData__c> recordsToProcess = [
            SELECT Id,
                Country__c,
                Type__c,
                Status__c,
                ISIN__c,
                Source__c,
                ProjectShareclass__c,
                ProjectShareclass__r.Share_Class_Name__c,
                ShareClass__c,
                ShareClass__r.Name,
                ShareClass__r.LaunchDate__c,
                ShareClass__r.Fund__r.ProductName__c,
                ProjectShareclass__r.ISIN__c,
                CreatedDate
            FROM TaxData__c
            WHERE Country__c = :COUNTRY_UK
            AND Type__c = :TYPE_TRANSPARENCY
            AND Status__c = :STATUS_REQUESTED
            AND CreatedDate >= :quarterStart
            AND CreatedDate < :quarterEndExclusive
        ];

        if (recordsToProcess.isEmpty()) {
            return;
        }

        Map<Id, Date> shareClassToUkRegistrationDate =
            fetchRegistrationDatesByCountryCode(recordsToProcess, COUNTRY_GB);

        Messaging.SingleEmailMessage email = buildUKQuarterlySummaryEmail(
            recordsToProcess,
            config,
            template,
            shareClassToUkRegistrationDate,
            quarterStartDate,
            quarterEndDate
        );

        if (email == null) {
            return;
        }

        sendEmails(new List<Messaging.SingleEmailMessage>{ email });
    }

    public static void sendATMergerLiquidationEmails(List<Share_Class__c> newList, Map<Id, Share_Class__c> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null) {
            return;
        }

        Set<Id> shareClassIds = new Set<Id>();

        for (Share_Class__c sc : newList) {
            Share_Class__c oldSc = oldMap.get(sc.Id);
            if (oldSc == null) {
                continue;
            }

            if (isEligibleForATMergerLiquidation(sc, oldSc)) {
                shareClassIds.add(sc.Id);
            }
        }

        if (shareClassIds.isEmpty()) {
            return;
        }

        TaxEmailConfiguration__mdt config = getConfiguration(COUNTRY_AT, SCENARIO_MERGER_LIQUIDATION);
        if (!isValidConfiguration(config)) {
            return;
        }

        EmailTemplate template = getTemplateByDeveloperName(config.TemplateDeveloperName__c);
        if (template == null) {
            return;
        }

        List<TaxData__c> recordsToProcess = fetchATMergerLiquidationTaxData(shareClassIds);
        if (recordsToProcess.isEmpty()) {
            return;
        }

        List<Messaging.SingleEmailMessage> emails = buildEmails(
            recordsToProcess,
            config,
            template,
            COUNTRY_AT,
            new Map<Id, Date>()
        );

        if (emails.isEmpty()) {
            return;
        }

        sendEmails(emails);
    }

    private static void sendTransparencyEmailsByCountry(List<TaxData__c> newList, String country) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        Set<Id> taxDataIds = collectEligibleTaxDataIds(newList, country);
        if (taxDataIds.isEmpty()) {
            return;
        }

        TaxEmailConfiguration__mdt config = getConfiguration(country, SCENARIO_TRANSPARENCY);
        if (!isValidConfiguration(config)) {
            return;
        }

        EmailTemplate template = getTemplateByDeveloperName(config.TemplateDeveloperName__c);
        if (template == null) {
            return;
        }

        List<TaxData__c> recordsToProcess = fetchTaxData(taxDataIds);
        if (recordsToProcess.isEmpty()) {
            return;
        }

        Map<Id, Date> shareClassToRegistrationDate = new Map<Id, Date>();
        if (country == COUNTRY_CH) {
            shareClassToRegistrationDate =
                fetchRegistrationDatesByCountryCode(recordsToProcess, COUNTRY_CH);
        }

        List<Messaging.SingleEmailMessage> emails = buildEmails(
            recordsToProcess,
            config,
            template,
            country,
            shareClassToRegistrationDate
        );

        if (emails.isEmpty()) {
            return;
        }

        sendEmails(emails);
    }

    private static Set<Id> collectEligibleTaxDataIds(List<TaxData__c> newList, String country) {
        Set<Id> taxDataIds = new Set<Id>();

        for (TaxData__c td : newList) {
            if (isEligibleForTransparency(td, country)) {
                taxDataIds.add(td.Id);
            }
        }

        return taxDataIds;
    }

    private static Boolean isEligibleForTransparency(TaxData__c td, String country) {
        return td != null
            && td.Id != null
            && td.Country__c == country
            && td.Type__c == TYPE_TRANSPARENCY
            && td.Status__c == STATUS_REQUESTED;
    }

    private static Boolean isEligibleForATMergerLiquidation(Share_Class__c sc, Share_Class__c oldSc) {
        if (sc == null || oldSc == null) {
            return false;
        }

        Boolean statusChanged = sc.Status__c != oldSc.Status__c;
        Boolean targetStatus =
            sc.Status__c == SC_STATUS_CLOSED_LIQUIDATED
            || sc.Status__c == SC_STATUS_CLOSED_MERGED;

        return statusChanged && targetStatus;
    }

    private static List<TaxData__c> fetchTaxData(Set<Id> taxDataIds) {
        return [
            SELECT Id,
                Country__c,
                Type__c,
                Status__c,
                Source__c,
                ISIN__c,
                StartDate__c,

                ShareClass__c,
                ShareClass__r.LaunchDate__c,
                ShareClass__r.Fund__r.ProductName__c,
                ShareClass__r.Name,

                ProjectShareclass__c,
                ProjectShareclass__r.Share_Class_Name__c,
                ProjectShareclass__r.ProjectProduct__r.Name,
                ProjectShareclass__r.ProjectProduct__r.InternalShortName__c,
                ProjectShareclass__r.ISIN__c

            FROM TaxData__c
            WHERE Id IN :taxDataIds
        ];
    }

    private static List<TaxData__c> fetchATMergerLiquidationTaxData(Set<Id> shareClassIds) {
        return [
            SELECT Id,
                   Country__c,
                   Type__c,
                   Status__c,
                   ISIN__c,
                   StartDate__c,
                   ShareClass__c,
                   ShareClass__r.LaunchDate__c,
                   ShareClass__r.Fund__r.ProductName__c,
                   ShareClass__r.Name,

                   Source__c,

                    ProjectShareclass__c,
                    ProjectShareclass__r.Share_Class_Name__c,
                    ProjectShareclass__r.ProjectProduct__r.Name,
                    ProjectShareclass__r.ProjectProduct__r.InternalShortName__c,
                    ProjectShareclass__r.ISIN__c
            FROM TaxData__c
            WHERE ShareClass__c IN :shareClassIds
              AND Country__c = :COUNTRY_AT
              AND Status__c = :STATUS_YES
        ];
    }

    private static Map<Id, Date> fetchRegistrationDatesByCountryCode(List<TaxData__c> taxDataList, String countryCode) {
        Set<Id> shareClassIds = new Set<Id>();

        for (TaxData__c td : taxDataList) {
            if (td.ShareClass__c != null) {
                shareClassIds.add(td.ShareClass__c);
            }
        }

        Map<Id, Date> result = new Map<Id, Date>();
        if (shareClassIds.isEmpty()) {
            return result;
        }

        for (Country__c countryRecord : [
            SELECT ShareClass__c, RegistrationDate__c
            FROM Country__c
            WHERE ShareClass__c IN :shareClassIds
              AND Country__c = :countryCode
        ]) {
            result.put(countryRecord.ShareClass__c, countryRecord.RegistrationDate__c);
        }

        return result;
    }

    private static TaxEmailConfiguration__mdt getConfiguration(String country, String scenario) {
        List<TaxEmailConfiguration__mdt> configs = [
            SELECT Country__c,
                   Scenario__c,
                   ToAddresses__c,
                   CcAddresses__c,
                   TemplateDeveloperName__c,
                   IsActive__c
            FROM TaxEmailConfiguration__mdt
            WHERE Country__c = :country
              AND Scenario__c = :scenario
            LIMIT 1
        ];

        return configs.isEmpty() ? null : configs[0];
    }

    private static Boolean isValidConfiguration(TaxEmailConfiguration__mdt config) {
        return config != null
            && config.IsActive__c
            && !String.isBlank(config.TemplateDeveloperName__c)
            && !splitEmails(config.ToAddresses__c).isEmpty();
    }

    private static EmailTemplate getTemplateByDeveloperName(String developerName) {
        List<EmailTemplate> templates = [
            SELECT Id, DeveloperName, Subject, HtmlValue, Body, TemplateType
            FROM EmailTemplate
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];

        return templates.isEmpty() ? null : templates[0];
    }

    private static List<Messaging.SingleEmailMessage> buildEmails(
        List<TaxData__c> recordsToProcess,
        TaxEmailConfiguration__mdt config,
        EmailTemplate template,
        String country,
        Map<Id, Date> shareClassToRegistrationDate
    ) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<String> toAddresses = splitEmails(config.ToAddresses__c);
        List<String> ccAddresses = splitEmails(config.CcAddresses__c);

        for (TaxData__c td : recordsToProcess) {
            Messaging.SingleEmailMessage email = buildSingleEmail(
                td,
                template,
                toAddresses,
                ccAddresses,
                country,
                shareClassToRegistrationDate
            );
            if (email != null) {
                emails.add(email);
            }
        }

        return emails;
    }

    private static Messaging.SingleEmailMessage buildUKQuarterlySummaryEmail(
        List<TaxData__c> recordsToProcess,
        TaxEmailConfiguration__mdt config,
        EmailTemplate template,
        Map<Id, Date> shareClassToUkRegistrationDate,
        Date quarterStartDate,
        Date quarterEndDate
    ) {
        List<String> toAddresses = splitEmails(config.ToAddresses__c);
        List<String> ccAddresses = splitEmails(config.CcAddresses__c);

        if (toAddresses.isEmpty()) {
            return null;
        }

        String subject = cleanTemplateContent(template.Subject);
        String htmlBody = cleanTemplateContent(template.HtmlValue);
        String textBody = cleanTemplateContent(template.Body);

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(toAddresses);

        if (!ccAddresses.isEmpty()) {
            email.setCcAddresses(ccAddresses);
        }

        email.setSubject(subject);

        if (!String.isBlank(htmlBody)) {
            email.setHtmlBody(htmlBody);
        } else {
            email.setPlainTextBody(textBody);
        }

        Id oweaId = getOrgWideEmailAddressId('salesforcesupport@carmignac.com');

        if (oweaId != null) {
            email.setOrgWideEmailAddressId(oweaId);
        }

        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(buildUkQuarterlyFileName(quarterStartDate, quarterEndDate));
        attachment.setBody(
            Blob.valueOf(
                buildUkQuarterlyExcelContent(recordsToProcess, shareClassToUkRegistrationDate)
            )
        );
        attachment.setContentType('application/vnd.ms-excel');

        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });

        return email;
    }

    private static String buildUkQuarterlyExcelContent(
        List<TaxData__c> recordsToProcess,
        Map<Id, Date> shareClassToUkRegistrationDate
    ) {
        String html = '<html xmlns:x="urn:schemas-microsoft-com:office:excel">';
        html += '<head>';
        html += '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>';
        html += '<style>';
        html += 'body { font-family: Calibri, Arial, sans-serif; }';
        html += 'table { border-collapse: collapse; width: 100%; }';
        html += 'th {'
            + 'background-color: #6E6E6E;'
            + 'color: white;'
            + 'font-weight: bold;'
            + 'text-align: left;'
            + 'padding: 8px;'
            + 'border: 1px solid #BFBFBF;'
            + '}';
        html += 'td {'
            + 'padding: 6px 8px;'
            + 'border: 1px solid #D9D9D9;'
            + 'text-align: left;'
            + '}';
        html += '.row-even { background-color: #F2F2F2; }';
        html += '.row-odd { background-color: #FFFFFF; }';
        html += '.title {'
            + 'font-size: 14pt;'
            + 'font-weight: bold;'
            + 'margin-bottom: 12px;'
            + 'color: #404040;'
            + '}';
        html += '</style>';
        html += '</head>';
        html += '<body>';

        html += '<div class="title">UK Tax Reporting - Quarterly Submission</div>';

        html += '<table>';
        html += '<tr>';
        //html += '<th>Fund Name</th>';
        html += '<th>ISIN</th>';
        html += '<th>Share Class</th>';
        html += '<th>Inception Date</th>';
        html += '<th>UK Registration Date</th>';
        html += '</tr>';

        Integer rowIndex = 0;
        for (TaxData__c td : recordsToProcess) {
            String rowClass = Math.mod(rowIndex, 2) == 0 ? 'row-odd' : 'row-even';

            html += '<tr class="' + rowClass + '">';
            //html += '<td>' + htmlEscape(getFundName(td)) + '</td>';
            html += '<td>' + htmlEscape(getIsin(td)) + '</td>';
            html += '<td>' + htmlEscape(getShareClassName(td)) + '</td>';
            html += '<td style="mso-number-format:\'@\';">' + htmlEscape(getInceptionDate(td)) + '</td>';
            html += '<td style="mso-number-format:\'@\';">' + htmlEscape(getUkRegistrationDate(td, shareClassToUkRegistrationDate)) + '</td>';
            html += '</tr>';

            rowIndex++;
        }

        html += '</table>';
        html += '</body></html>';

        return html;
    }

    private static String htmlEscape(String input) {
        if (input == null) {
            return '';
        }

        String result = input;
        result = result.replace('&', '&amp;');
        result = result.replace('<', '&lt;');
        result = result.replace('>', '&gt;');
        result = result.replace('"', '&quot;');

        return result;
    }

    private static String buildUkQuarterlyFileName(Date quarterStartDate, Date quarterEndDate) {
        return 'UK_Tax_Reporting_'
            + formatDate(quarterStartDate)
            + '_to_'
            + formatDate(quarterEndDate)
            + '.xls';
    }

    private static Messaging.SingleEmailMessage buildSingleEmail(
        TaxData__c td,
        EmailTemplate template,
        List<String> toAddresses,
        List<String> ccAddresses,
        String country,
        Map<Id, Date> shareClassToRegistrationDate
    ) {
        //String fundName = getFundName(td);
        String shareClassName = getShareClassName(td);
        String isin = getIsin(td);
        String registrationDate = getRegistrationDate(td, country, shareClassToRegistrationDate);

        String subject = applyTokens(
            cleanTemplateContent(template.Subject),
            shareClassName,
            isin,
            registrationDate
        );

        String htmlBody = applyTokens(
            cleanTemplateContent(template.HtmlValue),
            shareClassName,
            isin,
            registrationDate
        );

        String textBody = applyTokens(
            cleanTemplateContent(template.Body),
            shareClassName,
            isin,
            registrationDate
        );

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(toAddresses);

        if (!ccAddresses.isEmpty()) {
            email.setCcAddresses(ccAddresses);
        }

        email.setSubject(subject);

        if (!String.isBlank(htmlBody)) {
            email.setHtmlBody(htmlBody);
        } else {
            email.setPlainTextBody(textBody);
        }

        Id oweaId = getOrgWideEmailAddressId('salesforcesupport@carmignac.com');

        if (oweaId != null) {
            email.setOrgWideEmailAddressId(oweaId);
        }

        return email;
    }

    /*private static String getFundName(TaxData__c td) {
        if (td == null) {
            return '';
        }

        if (td.ShareClass__r != null && td.ShareClass__r.Fund__r != null) {
            return td.ShareClass__r.Fund__r.ProductName__c;
        }

        return '';
    }*/

    private static String getShareClassName(TaxData__c td) {
        if (td == null) {
            return '';
        }

        if (td.Source__c == SOURCE_PMT && td.ProjectShareclass__r != null) {
            return td.ProjectShareclass__r.Share_Class_Name__c;
        }

        if (td.ShareClass__r != null) {
            return td.ShareClass__r.Name;
        }

        return '';
    }

    private static String getIsin(TaxData__c td) {
        
        if (td == null) {
            return '';
        }

        if (td.Source__c == SOURCE_PMT && td.ProjectShareclass__r != null) {
            return td.ProjectShareclass__r.ISIN__c;
        }

        if (td.ISIN__c != null) {
            return td.ISIN__c;
        }

        return '';
    }

    private static String getInceptionDate(TaxData__c td) {
        if (td == null || td.ShareClass__r == null || td.ShareClass__r.LaunchDate__c == null) {
            return '';
        }

        return formatDate(td.ShareClass__r.LaunchDate__c);
    }

    private static String getUkRegistrationDate(TaxData__c td, Map<Id, Date> shareClassToUkRegistrationDate) {
        if (td == null || td.ShareClass__c == null || !shareClassToUkRegistrationDate.containsKey(td.ShareClass__c)) {
            return '';
        }

        Date registrationDate = shareClassToUkRegistrationDate.get(td.ShareClass__c);
        return registrationDate != null ? formatDate(registrationDate) : '';
    }

    private static String getRegistrationDate(
        TaxData__c td,
        String country,
        Map<Id, Date> shareClassToRegistrationDate
    ) {
        if (td == null || td.ShareClass__c == null || shareClassToRegistrationDate == null) {
            return '';
        }

        if ((country == COUNTRY_CH || country == COUNTRY_UK)
            && shareClassToRegistrationDate.containsKey(td.ShareClass__c)) {
            Date registrationDate = shareClassToRegistrationDate.get(td.ShareClass__c);
            return registrationDate != null ? formatDate(registrationDate) : '';
        }

        return '';
    }

    private static Date getCurrentQuarterStartDate() {
        Date today = Date.today();
        Integer month = today.month();
        Integer quarterStartMonth;

        if (month <= 3) {
            quarterStartMonth = 1;
        } else if (month <= 6) {
            quarterStartMonth = 4;
        } else if (month <= 9) {
            quarterStartMonth = 7;
        } else {
            quarterStartMonth = 10;
        }

        return Date.newInstance(today.year(), quarterStartMonth, 1);
    }

    private static Date getCurrentQuarterEndDate() {
        Date quarterStart = getCurrentQuarterStartDate();
        return quarterStart.addMonths(3).addDays(-1);
    }

    private static String formatDate(Date d) {
        if (d == null) {
            return '';
        }

        return String.valueOf(d.year()) + '-'
            + String.valueOf(d.month()).leftPad(2, '0') + '-'
            + String.valueOf(d.day()).leftPad(2, '0');
    }

    private static void sendEmails(List<Messaging.SingleEmailMessage> emails) {
        try {
            Messaging.sendEmail(emails);
        } catch (EmailException e) {
            // Intentionally ignored to avoid blocking business process
        }
    }

    private static List<String> splitEmails(String rawEmails) {
        List<String> results = new List<String>();

        if (String.isBlank(rawEmails)) {
            return results;
        }

        String normalized = rawEmails.replace(',', ';');
        for (String email : normalized.split(';')) {
            String trimmedEmail = email != null ? email.trim() : null;
            if (!String.isBlank(trimmedEmail)) {
                results.add(trimmedEmail);
            }
        }

        return results;
    }

    private static String applyTokens(
        String templateContent,
        String shareClassName,
        String isin,
        String registrationDate
    ) {
        String output = String.isBlank(templateContent) ? '' : templateContent;
        //output = output.replace('{FundName}', fundName != null ? fundName : '');
        output = output.replace('{ShareClassName}', shareClassName != null ? shareClassName : '');
        output = output.replace('{ISIN}', isin != null ? isin : '');
        output = output.replace('{CHRegistrationDate}', registrationDate != null ? registrationDate : '');
        return output;
    }

    private static String cleanTemplateContent(String content) {
        if (String.isBlank(content)) {
            return '';
        }

        String cleaned = content.trim();
        cleaned = cleaned.replace('<![CDATA[', '');
        cleaned = cleaned.replace(']]>', '');

        return cleaned.trim();
    }

    private static Id getOrgWideEmailAddressId(String address) {
        List<OrgWideEmailAddress> results = [
            SELECT Id, Address
            FROM OrgWideEmailAddress
            WHERE Address = :address
            LIMIT 1
        ];

        return results.isEmpty() ? null : results[0].Id;
    }
}