@IsTest
private class CTL_MeetingNotes_AIOrchestratorTest {

    // Fake runner qui renvoie des valeurs maîtrisées
    private class FakeFlowRunner implements CTL_MeetingNotes_AIOrchestrator.FlowRunner {
        String sum;
        String interestsJson;
        FakeFlowRunner(String s, String j) { sum = s; interestsJson = j; }
        public Map<String, Object> run(VideoCall vc) {
            return new Map<String, Object>{
                CTL_MeetingNotes_AIOrchestrator.FLOW_OUT_SUMMARY   => sum,
                CTL_MeetingNotes_AIOrchestrator.FLOW_OUT_INTERESTS => interestsJson
            };
        }
    }

    private static VideoCall makeVC() {
        Account client = TestDataFactory.getAccount('Client Test', TestDataFactory.ACCOUNT_DISTRIBUTOR_RECID);
        insert client;
        Contact cc = TestDataFactory.getContact(client, 'Client-test', 'Contact','true',TestDataFactory.CONTACT_DISTRIBUTION_RECID);
        insert cc;
        VideoCall vc = new VideoCall();
        vc.put('Name','VC Mock Flow');
        vc.put('StartDateTime', System.now().addHours(-1));
        vc.put('EndDateTime',   System.now());
        vc.put('RelatedRecordId',  cc.Id );
        vc.put('VendorMeetingKey',   'testTeams123');
        insert vc;
        Contact cc1 = TestDataFactory.getContact(client, 'Client-test', 'Contact','true',TestDataFactory.CONTACT_DISTRIBUTION_RECID);
        insert cc1;
        VideoCallParticipant vcp = new VideoCallParticipant();
        vcp.put('VideoCallId', vc.Id);
        vcp.put('RelatedPersonId', cc1.Id);
        insert vcp;
        return vc;

    }
    

    private static Strategy__c makeStrategy(String code, String name) {
        Strategy__c strat = new Strategy__c();
        strat.Code__c = code;     // External ID / unique
        strat.Name    = name;     // Nom visible
        insert strat;
        return strat;
    }

    @IsTest
    static void test_withMockedFlowOutputs() {
        // 1) Prépare les valeurs mockées
        Strategy__c s1 = makeStrategy('UCITS', 'Inflation Plus');
        Strategy__c s2 = makeStrategy('ESG', 'EU ESG Equity');

        // Tu récupères les vrais Ids
        Id stratId1 = s1.Id;
        Id stratId2 = s2.Id;
        String mockSummary = 'Résumé mocké: discussion inflation et ESG.';
        String mockCis =
        '[{"productId":"' + stratId1 + '","productName":"Inflation Plus","rating":5,"why":"Hedge inflation"},' +
        ' {"productId":"' + stratId2 + '","productName":"ESG","rating":4,"why":"Policy mandate"}]';
    
        // 2) Injecte le fake
        CTL_MeetingNotes_AIOrchestrator.flowRunner =
            new FakeFlowRunner(mockSummary, mockCis);

        // 3) Données
        VideoCall vc = makeVC();

        Test.startTest();
        Id mnId = CTL_MeetingNotes_AIOrchestrator.createMeetingNoteFromVideoCall(vc.Id);
        
        CTL_MeetingNotes_AIOrchestrator.FlowInput fi = new CTL_MeetingNotes_AIOrchestrator.FlowInput(); 
        fi.videoCallId = makeVC().Id;
        List<CTL_MeetingNotes_AIOrchestrator.FlowResult> res = CTL_MeetingNotes_AIOrchestrator.createMeetingNotes(new List<CTL_MeetingNotes_AIOrchestrator.FlowInput>{ fi });

        Test.stopTest();

        System.assertNotEquals(null, mnId, 'Meeting Note créée');

        // 4) Vérifie que le résumé mocké a été persisté (si le champ existe)
        if (Schema.getGlobalDescribe().get('Meeting_Note__c')
            .getDescribe().fields.getMap().containsKey('Note__c')) {
            Meeting_Note__c mn = [SELECT Note__c FROM Meeting_Note__c WHERE Id=:mnId];
            System.assert(mn.Note__c != null && mn.Note__c.contains('Résumé mocké'),
                'Le résumé du Flow doit refléter le mock');
        }

        // 5) Vérifie que les ClientInterest__c ont été créés à partir du JSON mocké
        if (Schema.getGlobalDescribe().containsKey('ClientInterest__c')) {
            List<SObject> cis = Database.query(
                'SELECT Id FROM ClientInterest__c WHERE MeetingNote__c = :mnId'
            );
            System.assertEquals(2, cis.size(),
                'Deux intérêts doivent être créés depuis le JSON mocké');
        }

        // (optionnel) réinitialise le runner pour éviter des effets de bord
        CTL_MeetingNotes_AIOrchestrator.flowRunner =
            (CTL_MeetingNotes_AIOrchestrator.FlowRunner) null;
    }
}