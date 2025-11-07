@isTest
public class TextParserTest {
    @isTest
    static void testSearchFieldValue() {
        // Create test data
        String inputText = 'Document Name: Commentaires Trimestriels GSM_Mandat Dynamique_DCP_fr_20230630\n'
            + 'Pages Sent: 2\n'
            + 'Pages Viewed: 2\n'
            + 'Duration: 76s\n'
            + 'Downloaded: No\n'
            + 'LiveSend Link: https://content.carmignac.com/i/SAPOCptnl3Ln443hLBynJ1fPLUSSIGNKhVzevIgQsQES680zILcBFJ___lSVF7qAPVlLQj5qHrf2O___qQSISHxULdXsGEaVVlbecBkbe8I1MwaYbmX___1kXngSsVgCrHsMFDtJjl20LwAh7XQthkTYCzYu0twFNiM___8tEpPLUSSIGNmtg8avLgViRGFcMEQUALSIGN?noTrack=true\n'
            + 'Session Summary Link: https://carmignac.seismic.com/app#/engagementcenter/detail/2293e1c6-35c4-4e7e-9b3e-a81cc98d7313';

        TextParser.InputParameter inputParameter = new TextParser.InputParameter();
        inputParameter.textToParse = inputText;
        inputParameter.fieldName = 'Duration';

        Test.startTest();
        List<TextParser.OutputParameter> result = TextParser.searchFieldValue(new List<TextParser.InputParameter>{inputParameter});
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Result list should have one entry');
        System.assertEquals('76s', result[0].varExtractedValue, 'Extracted value should be "76s"');
    }
}