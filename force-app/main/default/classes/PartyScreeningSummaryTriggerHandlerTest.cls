@isTest
private class PartyScreeningSummaryTriggerHandlerTest {

    @isTest
    static void testRejectedHighRiskCreatesRiskAndCase() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        PartyProfile profile = new PartyProfile(AccountId = acc.Id, Stage = 'Risk screening');
        insert profile;

        PartyScreeningSummary screening = new PartyScreeningSummary(
            PartyProfileId = profile.Id,
            ScreeningDecision = 'Rejected',
            RiskCategory = 'High'
        );

        Test.startTest();
        insert screening;
        Test.stopTest();

        List<SObject> risks = Database.query(
            'SELECT Id, PartyProfileId, Stage, ScreeningDecision, RiskCategory FROM PartyProfileRisk WHERE PartyProfileId = :profileId'
        );
        List<Case> cases = [
            SELECT Id, Subject, Priority, Status
            FROM Case
            WHERE Subject = 'Compliance Review Required for High Risk Screening'
        ];

        System.assertEquals(1, risks.size());
        System.assertEquals(1, cases.size());
        System.assertEquals('High', cases[0].Priority);
    }
}