public without sharing class KYCDecisionService {

    // Called from Flow / Agent to evaluate KYC readiness.
    @InvocableMethod(
        label = 'Evaluate KYC Readiness'
        description = 'Validates the full KYC journey and, when ready, creates a KYC_Decision_Service__c record signalling Account Creation Allowed.'
    )
    public static List<Response> evaluateKYCReadiness(List<Request> requests) {

        List<Response> responses = new List<Response>();
        List<KYC_Decision_Service__c> decisionsToInsert = new List<KYC_Decision_Service__c>();

        for (Request req : requests) {
            Response res = new Response();
            res.partyProfileId = req.partyProfileId;

            PartyProfile profile = getPartyProfile(req.partyProfileId);

            if (profile != null) {
                res.accountId = profile.AccountId;
            }

            List<String> issues = getValidationIssues(req.partyProfileId, profile);
            res.isReady = issues.isEmpty();
            res.statusDetails = issues.isEmpty()
                ? buildReadyMessage()
                : String.join(issues, ' ');

            // When ready → create the decision record that allows Account creation
            if (res.isReady && profile != null) {
                KYC_Decision_Service__c decision = new KYC_Decision_Service__c();
                decision.Name = buildDecisionName(profile);
                decision.Party_Profile__c = req.partyProfileId;
                decision.isReady__c = true;
                decision.OwnerId = UserInfo.getUserId();          // Agent user running the Flow
                decision.Last_Assessment_Date__c = Date.today();
                decision.Decision_Reason__c = req.decisionReason;
                decision.Incomplete_Steps__c = req.incompleteSteps;

                decisionsToInsert.add(decision);
            }

            responses.add(res);
        }

        // Bulk insert for performance & governor safety
        if (!decisionsToInsert.isEmpty()) {
            insert decisionsToInsert;

            // Map created Ids back to responses (order is preserved)
            Integer decisionIdx = 0;
            for (Response res : responses) {
                if (res.isReady) {
                    res.kycDecisionServiceId = decisionsToInsert[decisionIdx].Id;
                    decisionIdx++;
                }
            }
        }

        return responses;
    }

    // Returns true when there are no validation issues.
    public static Boolean isKYCReady(Id partyProfileId) {
        return getValidationIssues(partyProfileId, null).isEmpty();
    }

    // Returns validation results as a readable message.
    public static String getStatusDetails(Id partyProfileId) {
        List<String> issues = getValidationIssues(partyProfileId, null);
        return issues.isEmpty() ? buildReadyMessage() : String.join(issues, ' ');
    }

    // Structured success message the Agent can read directly.
    private static String buildReadyMessage() {
        return String.join(new List<String>{
            'KYC Ready.',
            '✓ Identification Complete',
            '✓ Identity Verification Approved',
            '✓ Screening Passed',
            '✓ Risk Assessment Passed',
            '✓ Assessment Decision = Approve',
            '✓ Account KYC Status Completed - Valid',
            '✓ KYC Date populated',
            '✓ Account Creation Allowed'
        }, ' ');
    }

    private static String buildDecisionName(PartyProfile profile) {
        String customerName = '';
        if (String.isNotBlank(profile.FirstName)) {
            customerName += profile.FirstName;
        }
        if (String.isNotBlank(profile.LastName)) {
            if (String.isNotBlank(customerName)) {
                customerName += ' ';
            }
            customerName += profile.LastName;
        }
        if (String.isBlank(customerName)) {
            customerName = 'Customer';
        }
        return customerName + ' - Ready';
    }

    // Retrieves Party Profile (core fields + Stage).
    private static PartyProfile getPartyProfile(Id partyProfileId) {
        if (partyProfileId == null) {
            return null;
        }

        List<PartyProfile> profiles = [
            SELECT
                Id,
                AccountId,
                FirstName,
                LastName,
                PrimaryPhone,
                PrimaryEmail,
                DateOfBirth,
                TaxpayerIdentificationType,
                TaxpayerIdentificationNumber,
                Stage
            FROM PartyProfile
            WHERE Id = :partyProfileId
            LIMIT 1
        ];

        return profiles.isEmpty() ? null : profiles[0];
    }

    // Core validation logic – mirrors the business process exactly.
    private static List<String> getValidationIssues(Id partyProfileId, PartyProfile profile) {
        List<String> issues = new List<String>();

        if (partyProfileId == null) {
            issues.add('No Party Profile Id supplied.');
            return issues;
        }

        // Re-query if caller did not pass the profile
        if (profile == null) {
            profile = getPartyProfile(partyProfileId);
        }

        // ── 1. Party Profile exists ──────────────────────────────────────────
        if (profile == null) {
            issues.add('Party Profile not found.');
            return issues;
        }

        // ── 2. Related Account exists ────────────────────────────────────────
        if (profile.AccountId == null) {
            issues.add('Related Account is missing.');
            return issues;
        }

        // ── 3. Personal information (supporting Identification) ──────────────
        if (String.isBlank(profile.FirstName)) {
            issues.add('First Name is missing.');
        }
        if (String.isBlank(profile.LastName)) {
            issues.add('Last Name is missing.');
        }
        if (String.isBlank(profile.PrimaryPhone)) {
            issues.add('Primary Phone is missing.');
        }
        if (String.isBlank(profile.PrimaryEmail)) {
            issues.add('Primary Email is missing.');
        }
        if (profile.DateOfBirth == null) {
            issues.add('Date of Birth is missing.');
        }
        if (String.isBlank(profile.TaxpayerIdentificationType)) {
            issues.add('Taxpayer Identification Type is missing.');
        }
        if (String.isBlank(profile.TaxpayerIdentificationNumber)) {
            issues.add('Taxpayer Identification Number is missing.');
        }

        // ── 4. Assessment Decision = Approve  →  Stage = 'Approved' ──────────
        if (String.isBlank(profile.Stage)) {
            issues.add('Party Profile Stage is missing.');
        } else if (profile.Stage != 'Approved') {
            issues.add('Assessment Decision must be Approve (Stage must be Approved).');
        }

        // ── 5. Account-level KYC fields ──────────────────────────────────────
        List<Account> accounts = [
            SELECT
                Name,
                Phone,
                Email__c,
                PersonEmail,
                FinServ__KYCStatus__c,
                FinServ__KYCDate__c
            FROM Account
            WHERE Id = :profile.AccountId
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            issues.add('Account not found.');
            return issues;
        }

        Account acc = accounts[0];

        if (String.isBlank(acc.Name)) {
            issues.add('Account Name is missing.');
        }
        if (String.isBlank(acc.Phone)) {
            issues.add('Phone is missing.');
        }

        Boolean hasEmail =
            !String.isBlank(acc.Email__c) ||
            !String.isBlank(acc.PersonEmail);

        if (!hasEmail) {
            issues.add('Email is missing.');
        }

        if (String.isBlank(acc.FinServ__KYCStatus__c)) {
            issues.add('KYC Status is missing.');
        } else if (acc.FinServ__KYCStatus__c != 'Completed - Valid') {
            issues.add('KYC Status must be Completed - Valid.');
        }

        if (acc.FinServ__KYCDate__c == null) {
            issues.add('KYC Date is missing.');
        }

        // ── 6. Identification Complete  →  PartyIdentityVerification.Status = 'Completed'
        List<PartyIdentityVerification> idvRecords = [
            SELECT Status
            FROM PartyIdentityVerification
            WHERE PartyProfileId = :partyProfileId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (idvRecords.isEmpty()) {
            issues.add('Identity Verification record is missing.');
        } else if (idvRecords[0].Status != 'Completed') {
            issues.add('Identification is not Complete (PartyIdentityVerification.Status must be Completed).');
        }

        // ── 7. Identity Verification Approved  →  IdentityDocument.Verified__c = true
        // Adjust the relationship field if your schema differs
        // (e.g. PartyProfileId, PartyIdentityVerificationId, etc.)
        List<IdentityDocument> documents = [
            SELECT Verified__c
            FROM IdentityDocument
            WHERE PartyProfileId = :partyProfileId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (documents.isEmpty()) {
            issues.add('Identity Document is missing.');
        } else if (documents[0].Verified__c != true) {
            issues.add('Identity Verification is not Approved (IdentityDocument.Verified__c must be true).');
        }

        // ── 8. Screening Passed  →  Status = 'Completed' AND ScreeningDecision = 'Clear'
        List<PartyScreeningSummary> screeningSummaries = [
            SELECT Status, ScreeningDecision
            FROM PartyScreeningSummary
            WHERE PartyProfileId = :partyProfileId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (screeningSummaries.isEmpty()) {
            issues.add('Party Screening Summary is missing.');
        } else {
            PartyScreeningSummary screening = screeningSummaries[0];
            if (screening.Status != 'Completed') {
                issues.add('Screening is not Complete (PartyScreeningSummary.Status must be Completed).');
            }
            if (screening.ScreeningDecision != 'Clear') {
                issues.add('Screening Decision must be Clear.');
            }
        }

        // ── 9. Risk Assessment Passed  →  RiskCategory = Low/Medium AND Type = 'Final'
        List<PartyProfileRisk> riskRecords = [
            SELECT RiskCategory, Type
            FROM PartyProfileRisk
            WHERE PartyProfileId = :partyProfileId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        if (riskRecords.isEmpty()) {
            issues.add('Party Profile Risk record is missing.');
        } else {
            PartyProfileRisk risk = riskRecords[0];
            Boolean acceptableRisk =
                risk.RiskCategory == 'Low' || risk.RiskCategory == 'Medium';

            if (!acceptableRisk) {
                issues.add('Risk Category must be Low or Medium (High Risk is not allowed).');
            }
            if (risk.Type != 'Final') {
                issues.add('Risk Assessment Type must be Final.');
            }
        }

        return issues;
    }

    // ── Flow / Agent input ───────────────────────────────────────────────────
    public class Request {
        @InvocableVariable(required = true)
        public Id partyProfileId;

        @InvocableVariable(
            label = 'Decision Reason'
            description = 'Reason supplied by the Agent (stored on KYC_Decision_Service__c.Decision_Reason__c)'
        )
        public String decisionReason;

        @InvocableVariable(
            label = 'Incomplete Steps'
            description = 'Any incomplete steps noted by the Agent (stored on KYC_Decision_Service__c.Incomplete_Steps__c)'
        )
        public String incompleteSteps;
    }

    // ── Flow / Agent output ──────────────────────────────────────────────────
    public class Response {
        @InvocableVariable
        public Id partyProfileId;

        @InvocableVariable
        public Id accountId;

        @InvocableVariable
        public Boolean isReady;

        @InvocableVariable
        public String statusDetails;

        @InvocableVariable(
            label = 'KYC Decision Service Id'
            description = 'Id of the KYC_Decision_Service__c record created when the customer is ready'
        )
        public Id kycDecisionServiceId;
    }
}