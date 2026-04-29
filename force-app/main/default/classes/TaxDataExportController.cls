public with sharing class TaxDataExportController {

    public class ExportResult {
        @AuraEnabled public String fileName;
        @AuraEnabled public String content;
    }

    @AuraEnabled
    public static ExportResult exportBETISHistory(Id shareClassId) {
        if (shareClassId == null) {
            throw new AuraHandledException('Missing Share Class Id.');
        }

        Share_Class__c sc = [
            SELECT Id, Name
            FROM Share_Class__c
            WHERE Id = :shareClassId
            LIMIT 1
        ];

        List<TaxData__c> taxDataList = [
            SELECT Id
            FROM TaxData__c
            WHERE ShareClass__c = :shareClassId
              AND Type__c = 'BE TIS'
        ];

        if (taxDataList.isEmpty()) {
            throw new AuraHandledException('No BE TIS Tax Data found for this Share Class.');
        }

        Set<Id> taxDataIds = new Set<Id>();
        for (TaxData__c td : taxDataList) {
            taxDataIds.add(td.Id);
        }

        List<TaxDataHistory__c> historyList = [
            SELECT Value__c,
                   NAV_Date__c,
                   ArchivedOn__c,
                   ArchivedBy__r.Name,
                   TaxData__c,
                   TaxData__r.ISIN__c
            FROM TaxDataHistory__c
            WHERE TaxData__c IN :taxDataIds
            ORDER BY NAV_Date__c DESC, ArchivedOn__c DESC
        ];

        String content = buildExcelHtml(sc.Name, historyList);

        ExportResult result = new ExportResult();
        result.fileName = 'BE_TIS_' + sanitizeFileName(sc.Name) + '.xls';
        result.content = content;
        return result;
    }

    private static String buildExcelHtml(
        String shareClassName,
        List<TaxDataHistory__c> historyList
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
        html += '.subtitle {'
             + 'font-size: 10pt;'
             + 'margin-bottom: 12px;'
             + 'color: #666666;'
             + '}';
        html += '</style>';
        html += '</head>';
        html += '<body>';


        html += '<table>';
        html += '<tr>';
        html += '<th>ISIN</th>';
        html += '<th>Share Class</th>';
        html += '<th>Nav Date</th>';
        html += '<th>BE TIS Value</th>';
        
        
        //html += '<th>Archived On</th>';
        //html += '<th>Archived By</th>';
        html += '</tr>';

        Integer rowIndex = 0;
        for (TaxDataHistory__c h : historyList) {
            String rowClass = Math.mod(rowIndex, 2) == 0 ? 'row-odd' : 'row-even';

            html += '<tr class="' + rowClass + '">';
            html += '<td>' + htmlEscape(h.TaxData__r != null ? h.TaxData__r.ISIN__c : '') + '</td>';
            html += '<td>' + htmlEscape(shareClassName) + '</td>';
            html += '<td style="mso-number-format:\'@\';">'
                    + htmlEscape(formatDate(h.NAV_Date__c))
                    + '</td>';
            html += '<td>' + htmlEscape(formatDecimal(h.Value__c)) + '</td>';
            
            
            //html += '<td>' + htmlEscape(formatDateTime(h.ArchivedOn__c)) + '</td>';
            //html += '<td>' + htmlEscape(h.ArchivedBy__r != null ? h.ArchivedBy__r.Name : '') + '</td>';
            html += '</tr>';

            rowIndex++;
        }

        html += '</table>';
        html += '</body></html>';

        return html;
    }

    private static String formatDate(Date d) {
        if (d == null) return '';
        return String.valueOf(d.year()) + '-'
            + String.valueOf(d.month()).leftPad(2, '0') + '-'
            + String.valueOf(d.day()).leftPad(2, '0');
    }

    private static String formatDateTime(Datetime dt) {
        if (dt == null) return '';
        return dt.format('dd/MM/yyyy HH:mm');
    }

    private static String formatDecimal(Decimal value) {
        if (value == null) return '';
        return String.valueOf(value);
    }

    private static String htmlEscape(String input) {
        if (input == null) return '';
        String result = input;
        result = result.replace('&', '&amp;');
        result = result.replace('<', '&lt;');
        result = result.replace('>', '&gt;');
        result = result.replace('"', '&quot;');
        return result;
    }

    private static String sanitizeFileName(String input) {
        if (String.isBlank(input)) return 'ShareClass';
        return input.replaceAll('[\\\\/:*?"<>|]', '_');
    }
}