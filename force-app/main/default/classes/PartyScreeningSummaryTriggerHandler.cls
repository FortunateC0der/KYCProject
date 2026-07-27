public with sharing class PartyScreeningSummaryTriggerHandler {

    // ---------- Constants ----------
    private static final String SCREENING_REJECTED = 'Rejected';
    private static final String HIGH_RISK          = 'High';
    private static final String RISK_TYPE_FINAL    = 'Final';
    private static final String RISK_SCREENING     = 'Risk screening';

    public static void handle(List<PartyScreeningSummary> newRecords, Map<Id, PartyScreeningSummary> oldMap) {

        // 1. Collect only the records that just became Rejected
        Set<Id> partyProfileIds = new Set<Id>();
        Map<Id, PartyScreeningSummary> rejectedScreeningsByProfile = new Map<Id, PartyScreeningSummary>();

        for (PartyScreeningSummary screening : newRecords) {
            PartyScreeningSummary oldScreening = oldMap != null ? oldMap.get(screening.Id) : null;

            Boolean isNowRejected     = screening.ScreeningDecision == SCREENING_REJECTED;
            Boolean wasAlreadyRejected = oldScreening != null && oldScreening.ScreeningDecision == SCREENING_REJECTED;

            // Only act on the transition TO Rejected
            if (!isNowRejected || wasAlreadyRejected) {
                continue;
            }

            if (screening.PartyProfileId == null) {
                continue;
            }

            partyProfileIds.add(screening.PartyProfileId);
            rejectedScreeningsByProfile.put(screening.PartyProfileId, screening);
        }

        if (partyProfileIds.isEmpty()) {
            return;
        }

        // 2. Load Party Profiles (now includes AccountId + Stage)
        Map<Id, PartyProfile> profilesById = new Map<Id, PartyProfile>([
            SELECT Id, Name, Stage, AccountId
            FROM PartyProfile
            WHERE Id IN :partyProfileIds
        ]);

        // 3. Find profiles that already have a High Risk record
        Set<Id> profilesThatAlreadyHaveHighRisk = new Set<Id>();
        for (PartyProfileRisk existingRisk : [
            SELECT PartyProfileId
            FROM PartyProfileRisk
            WHERE PartyProfileId IN :partyProfileIds
            AND RiskCategory = :HIGH_RISK
        ]) {
            profilesThatAlreadyHaveHighRisk.add(existingRisk.PartyProfileId);
        }

        // 4. Find profiles that already have an open High-Risk Case (prevents duplicate Cases)
        Set<Id> accountIds = new Set<Id>();
        for (PartyProfile p : profilesById.values()) {
            if (p.AccountId != null) {
                accountIds.add(p.AccountId);
            }
        }

        Set<Id> accountsThatAlreadyHaveOpenCase = new Set<Id>();
        if (!accountIds.isEmpty()) {
            for (Case existingCase : [
                SELECT AccountId
                FROM Case
                WHERE AccountId IN :accountIds
                AND Status != 'Closed'
                AND Subject LIKE 'High Risk%'
            ]) {
                accountsThatAlreadyHaveOpenCase.add(existingCase.AccountId);
            }
        }

        // 5. Prepare records to insert
        List<PartyProfileRisk> risksToInsert = new List<PartyProfileRisk>();
        List<Case> casesToInsert = new List<Case>();
        Id complianceQueueId = getComplianceQueueId();

        for (Id partyProfileId : partyProfileIds) {
            PartyProfile profile = profilesById.get(partyProfileId);
            PartyScreeningSummary screening = rejectedScreeningsByProfile.get(partyProfileId);

            if (profile == null) {
                continue;
            }

            // Only proceed when Stage is "Risk screening"
            if (profile.Stage != RISK_SCREENING) {
                continue;
            }

            // Only create High Risk + Case when no High Risk already exists
            if (profilesThatAlreadyHaveHighRisk.contains(partyProfileId)) {
                continue;
            }

            // --- Create Party Profile Risk (High) ---
            PartyProfileRisk risk = new PartyProfileRisk();
            risk.PartyProfileId         = partyProfileId;
            risk.Name                   = 'High Risk - Rejected Screening';
            risk.RiskCategory           = HIGH_RISK;
            risk.IsRiskOverridden       = true;
            risk.Type                   = RISK_TYPE_FINAL;
            risk.OverridenRiskCategory  = HIGH_RISK;
            risk.RiskOverrideReason     = 'This risk was automatically created because the Party Screening Summary was set to Rejected. '
                                        + 'Manual review by a Compliance Officer is required before any Account can be opened.';
            risk.RiskOverriddenById     = UserInfo.getUserId();

            risksToInsert.add(risk);

            // --- Create Compliance Case (only when we also create the Risk) ---
            // Extra guard against duplicate open Cases
            if (profile.AccountId != null && accountsThatAlreadyHaveOpenCase.contains(profile.AccountId)) {
                continue;
            }

            Case c = new Case();
            c.AccountId   = profile.AccountId;
            c.Subject     = 'High Risk / Rejected Screening – Compliance Review Required';
            c.Priority    = 'High';
            c.Status      = 'Escalated';
            c.Origin      = 'Automated Escalation';
            c.OwnerId     = complianceQueueId;
            c.Reason      = 'Complex functionality';
            c.Description = 'A Party Screening Summary was set to Rejected.\n\n'
                          + 'Party Profile: ' + profile.Name + ' (' + profile.Id + ')\n'
                          + 'Screening Summary Id: ' + screening.Id + '\n\n'
                          + 'This case was created automatically by the Party Screening Summary trigger. '
                          + 'Manual review by a Compliance Officer is required before any Account can be opened.';

            casesToInsert.add(c);
        }

        // 6. Perform DML
        if (!risksToInsert.isEmpty()) {
            insert risksToInsert;
        }
        if (!casesToInsert.isEmpty()) {
            insert casesToInsert;
        }
    }

    // ---------- Helper methods ----------
    private static Id getComplianceQueueId() {
        try {
            return [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName = 'Compliance_Queue'
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Compliance_Queue not found. Falling back to current user. ' + e.getMessage());
            return UserInfo.getUserId();
        }
    }
}