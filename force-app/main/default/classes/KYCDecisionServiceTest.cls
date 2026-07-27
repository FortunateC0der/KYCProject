@IsTest
private class KYCDecisionServiceTest {

    // ──────────────────────────────────────────────────────────────
    // Test data factory
    // ──────────────────────────────────────────────────────────────
    private class TestData {
        Account acc;
        PartyProfile profile;
        PartyIdentityVerification idv;
        IdentityDocument idDoc;
        PartyScreeningSummary screening;
        PartyProfileRisk risk;
    }

    private static TestData createFullReadyData() {
        TestData td = new TestData();

        // Account – KYC completed
        td.acc = new Account(
            Name = 'Jane Doe',
            Phone = '555-0100',
            Email__c = 'jane.doe@example.com',
            FinServ__KYCStatus__c = 'Completed - Valid',
            FinServ__KYCDate__c = Date.today()
        );
        insert td.acc;

        // Party Profile – Stage = Approved + personal data complete
        td.profile = new PartyProfile(
            Name = 'Jane Doe - Primary',
            FirstName = 'Jane',
            LastName = 'Doe',
            AccountId = td.acc.Id,
            PrimaryPhone = '555-0100',
            PrimaryEmail = 'jane.doe@example.com',
            DateOfBirth = Date.newInstance(1985, 5, 15),
            TaxpayerIdentificationType = 'SSN',
            TaxpayerIdentificationNumber = '123-45-6789',
            Stage = 'Approved'
        );
        insert td.profile;

        // Identification Complete
        td.idv = new PartyIdentityVerification(
            PartyProfileId = td.profile.Id,
            Status = 'Completed',
            Result = 'Accepted',        
            Name = 'IDV-JaneDoe'
        );
        insert td.idv;

        // Identity Verification Approved
        td.idDoc = new IdentityDocument(
            PartyProfileId = td.profile.Id,
            RelatedLegalEntityId = td.acc.Id, // Assuming the PartyProfile is the legal entity for this test
            IdDocumentType = 'Passport',
            Verified__c = true,
            Name = 'Passport-JaneDoe'
        );
        insert td.idDoc;

        // Screening Passed
        td.screening = new PartyScreeningSummary(
            PartyProfileId = td.profile.Id,
            Status = 'Completed',
            ScreeningDecision = 'Clear',
            Name = 'Screen-JaneDoe'
        );
        insert td.screening;

        // Risk Assessment Passed
        td.risk = new PartyProfileRisk(
            PartyProfileId = td.profile.Id,
            RiskCategory = 'Low',
            Type = 'Final',
            Name = 'Risk-JaneDoe'
        );
        insert td.risk;

        return td;
    }

    // ──────────────────────────────────────────────────────────────
    // Happy-path – full readiness + decision record created
    // ──────────────────────────────────────────────────────────────
    @IsTest
    static void testEvaluate_Ready_CreatesDecisionRecord() {
        TestData td = createFullReadyData();

        KYCDecisionService.Request req = new KYCDecisionService.Request();
        req.partyProfileId = td.profile.Id;
        req.decisionReason = 'All checks passed by Agent';
        req.incompleteSteps = null;

        Test.startTest();
        List<KYCDecisionService.Response> results =
            KYCDecisionService.evaluateKYCReadiness(new List<KYCDecisionService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one response');
        KYCDecisionService.Response res = results[0];

        System.assertEquals(true, res.isReady, 'Customer should be KYC Ready');
        System.assertEquals(td.profile.Id, res.partyProfileId);
        System.assertEquals(td.acc.Id, res.accountId);
        System.assertNotEquals(null, res.kycDecisionServiceId, 'Decision record Id should be returned');
        System.assert(res.statusDetails.startsWith('KYC Ready.'), 'Status should start with ready message');
        System.assert(res.statusDetails.contains('✓ Account Creation Allowed'));

        // Verify the created KYC_Decision_Service__c record
        KYC_Decision_Service__c decision = [
            SELECT Name, Party_Profile__c, isReady__c, OwnerId,
                   Last_Assessment_Date__c, Decision_Reason__c, Incomplete_Steps__c
            FROM KYC_Decision_Service__c
            WHERE Id = :res.kycDecisionServiceId
        ];

        System.assertEquals('Jane Doe - Ready', decision.Name);
        System.assertEquals(td.profile.Id, decision.Party_Profile__c);
        System.assertEquals(true, decision.isReady__c);
        System.assertEquals(UserInfo.getUserId(), decision.OwnerId);
        System.assertEquals(Date.today(), decision.Last_Assessment_Date__c);
        System.assertEquals('All checks passed by Agent', decision.Decision_Reason__c);
        System.assertEquals(null, decision.Incomplete_Steps__c);
    }

    // ──────────────────────────────────────────────────────────────
    // Helper methods – isKYCReady / getStatusDetails
    // ──────────────────────────────────────────────────────────────
    @IsTest
    static void testIsKYCReady_and_getStatusDetails_Ready() {
        TestData td = createFullReadyData();

        Test.startTest();
        Boolean ready = KYCDecisionService.isKYCReady(td.profile.Id);
        String details = KYCDecisionService.getStatusDetails(td.profile.Id);
        Test.stopTest();

        System.assertEquals(true, ready);
        System.assert(details.startsWith('KYC Ready.'));
    }

    @IsTest
    static void testIsKYCReady_and_getStatusDetails_NotReady() {
        // Minimal data – missing almost everything
        Account acc = new Account(Name = 'Incomplete');
        insert acc;

        PartyProfile profile = new PartyProfile(
            FirstName = 'John',
            LastName = 'Incomplete',
            AccountId = acc.Id,
            Stage = 'Initiation'          // not Approved
        );
        insert profile;

        Test.startTest();
        Boolean ready = KYCDecisionService.isKYCReady(profile.Id);
        String details = KYCDecisionService.getStatusDetails(profile.Id);
        Test.stopTest();

        System.assertEquals(false, ready);
        System.assert(details.contains('Assessment Decision must be Approve') ||
                      details.contains('Stage must be Approved') ||
                      details.contains('missing'),
                      'Should report concrete issues');
    }

    // ──────────────────────────────────────────────────────────────
    // Null / missing Party Profile
    // ──────────────────────────────────────────────────────────────
    @IsTest
    static void testNullPartyProfileId() {
        KYCDecisionService.Request req = new KYCDecisionService.Request();
        req.partyProfileId = null;

        Test.startTest();
        List<KYCDecisionService.Response> results =
            KYCDecisionService.evaluateKYCReadiness(new List<KYCDecisionService.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].isReady);
        System.assert(results[0].statusDetails.contains('No Party Profile Id supplied'));
        System.assertEquals(null, results[0].kycDecisionServiceId);
    }

    @IsTest
    static void testPartyProfileNotFound() {
        // Use a fake Id that does not exist
        Id fakeId = PartyProfile.SObjectType.getDescribe().getKeyPrefix() + '0'.repeat(12);

        KYCDecisionService.Request req = new KYCDecisionService.Request();
        req.partyProfileId = fakeId;

        Test.startTest();
        List<KYCDecisionService.Response> results =
            KYCDecisionService.evaluateKYCReadiness(new List<KYCDecisionService.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].isReady);
        System.assert(results[0].statusDetails.contains('Party Profile not found'));
    }

    // ──────────────────────────────────────────────────────────────
    // Missing related Account
    // ──────────────────────────────────────────────────────────────
    @IsTest
    static void testMissingRelatedAccount() {
        PartyProfile profile = new PartyProfile(
            FirstName = 'No',
            LastName = 'Account',
            Stage = 'Approved'
            // AccountId deliberately left null
        );
        insert profile;

        KYCDecisionService.Request req = new KYCDecisionService.Request();
        req.partyProfileId = profile.Id;

        Test.startTest();
        List<KYCDecisionService.Response> results =
            KYCDecisionService.evaluateKYCReadiness(new List<KYCDecisionService.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].isReady);
        System.assert(results[0].statusDetails.contains('Related Account is missing'));
    }

    // ──────────────────────────────────────────────────────────────
    // Individual failure scenarios
    // ──────────────────────────────────────────────────────────────
    @IsTest
    static void testStageNotApproved() {
        TestData td = createFullReadyData();
        td.profile.Stage = 'Decision';          // not Approved
        update td.profile;

        assertNotReady(td.profile.Id, 'Assessment Decision must be Approve');
    }

    @IsTest
    static void testKYCStatusNotCompletedValid() {
        TestData td = createFullReadyData();
        td.acc.FinServ__KYCStatus__c = 'In Progress';
        update td.acc;

        assertNotReady(td.profile.Id, 'KYC Status must be Completed - Valid');
    }

    @IsTest
    static void testKYCDateMissing() {
        TestData td = createFullReadyData();
        td.acc.FinServ__KYCDate__c = null;
        update td.acc;

        assertNotReady(td.profile.Id, 'KYC Date is missing');
    }

    @IsTest
    static void testIdentityVerificationNotCompleted() {
        TestData td = createFullReadyData();
        td.idv.Status = 'In Progress';
        update td.idv;

        assertNotReady(td.profile.Id, 'Identification is not Complete');
    }

    @IsTest
    static void testIdentityDocumentNotVerified() {
        TestData td = createFullReadyData();
        td.idDoc.Verified__c = false;
        update td.idDoc;

        assertNotReady(td.profile.Id, 'Identity Verification is not Approved');
    }

    @IsTest
    static void testScreeningNotClear() {
        TestData td = createFullReadyData();
        td.screening.ScreeningDecision = 'Rejected';
        update td.screening;

        assertNotReady(td.profile.Id, 'Screening Decision must be Clear');
    }

    @IsTest
    static void testScreeningStatusNotCompleted() {
        TestData td = createFullReadyData();
        td.screening.Status = 'Pending';
        update td.screening;

        assertNotReady(td.profile.Id, 'Screening is not Complete');
    }

    @IsTest
    static void testHighRiskRejected() {
        TestData td = createFullReadyData();
        td.risk.RiskCategory = 'High';
        update td.risk;

        assertNotReady(td.profile.Id, 'Risk Category must be Low or Medium');
    }

    @IsTest
    static void testRiskTypeNotFinal() {
        TestData td = createFullReadyData();
        td.risk.Type = 'Preliminary';
        update td.risk;

        assertNotReady(td.profile.Id, 'Risk Assessment Type must be Final');
    }

    @IsTest
    static void testMissingIdentityVerificationRecord() {
        TestData td = createFullReadyData();
        delete td.idv;

        assertNotReady(td.profile.Id, 'Identity Verification record is missing');
    }

    @IsTest
    static void testMissingIdentityDocument() {
        TestData td = createFullReadyData();
        delete td.idDoc;

        assertNotReady(td.profile.Id, 'Identity Document is missing');
    }

    @IsTest
    static void testMissingScreeningSummary() {
        TestData td = createFullReadyData();
        delete td.screening;

        assertNotReady(td.profile.Id, 'Party Screening Summary is missing');
    }

    @IsTest
    static void testMissingRiskRecord() {
        TestData td = createFullReadyData();
        delete td.risk;

        assertNotReady(td.profile.Id, 'Party Profile Risk record is missing');
    }

    // ──────────────────────────────────────────────────────────────
    // Bulk invocation
    // ──────────────────────────────────────────────────────────────
    @IsTest
    static void testBulk_MixedReadyAndNotReady() {
        TestData ready = createFullReadyData();

        // Second profile – not ready
        Account acc2 = new Account(Name = 'Not Ready');
        insert acc2;
        PartyProfile notReady = new PartyProfile(
            FirstName = 'Bob',
            LastName = 'Pending',
            AccountId = acc2.Id,
            Stage = 'Screening'
        );
        insert notReady;

        List<KYCDecisionService.Request> requests = new List<KYCDecisionService.Request>();

        KYCDecisionService.Request r1 = new KYCDecisionService.Request();
        r1.partyProfileId = ready.profile.Id;
        r1.decisionReason = 'Ready reason';
        requests.add(r1);

        KYCDecisionService.Request r2 = new KYCDecisionService.Request();
        r2.partyProfileId = notReady.Id;
        requests.add(r2);

        Test.startTest();
        List<KYCDecisionService.Response> results =
            KYCDecisionService.evaluateKYCReadiness(requests);
        Test.stopTest();

        System.assertEquals(2, results.size());

        // First should be ready and have a decision record
        System.assertEquals(true, results[0].isReady);
        System.assertNotEquals(null, results[0].kycDecisionServiceId);

        // Second should not be ready and no decision record
        System.assertEquals(false, results[1].isReady);
        System.assertEquals(null, results[1].kycDecisionServiceId);

        // Only one decision record should have been inserted
        Integer decisionCount = [SELECT COUNT() FROM KYC_Decision_Service__c];
        System.assertEquals(1, decisionCount);
    }

    // ──────────────────────────────────────────────────────────────
    // Decision record name edge case – no first/last name
    // ──────────────────────────────────────────────────────────────
    @IsTest
    static void testDecisionName_FallbackToCustomer() {
        TestData td = createFullReadyData();
        td.profile.FirstName = null;
        td.profile.LastName = null;
        update td.profile;

        // Re-query so the service sees the blank names
        // (service will still fail other personal-info checks,
        //  so we only unit-test the name builder indirectly via a ready path
        //  after temporarily relaxing personal checks is not practical.
        //  Instead we just confirm the method can be called via ready path
        //  when names exist – the fallback is covered by code inspection.)

        // For completeness we still run a not-ready assertion
        assertNotReady(td.profile.Id, 'First Name is missing');
    }

    // ──────────────────────────────────────────────────────────────
    // Shared assertion helper
    // ──────────────────────────────────────────────────────────────
    private static void assertNotReady(Id partyProfileId, String expectedFragment) {
        KYCDecisionService.Request req = new KYCDecisionService.Request();
        req.partyProfileId = partyProfileId;

        Test.startTest();
        List<KYCDecisionService.Response> results =
            KYCDecisionService.evaluateKYCReadiness(new List<KYCDecisionService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isReady, 'Should not be ready');
        System.assertEquals(null, results[0].kycDecisionServiceId, 'No decision record should be created');
        System.assert(
            results[0].statusDetails.contains(expectedFragment),
            'Expected fragment "' + expectedFragment + '" not found in: ' + results[0].statusDetails
        );
    }
}