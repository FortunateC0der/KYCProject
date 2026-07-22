public with sharing class PartyScreeningSummaryTriggerHandler {

    public static void handle(List<PartyScreeningSummary> newRecords, Map<Id, PartyScreeningSummary> oldMap) {
        List<SObject> risksToInsert = new List<SObject>();
        List<Case> casesToInsert = new List<Case>();
        Map<Id, PartyProfile> partyProfilesById = new Map<Id, PartyProfile>();

        // Fetch Compliance Queue once (outside any loops)
        Id complianceQueueId = getComplianceQueueId();

        Set<Id> partyProfileIds = new Set<Id>();
        for (PartyScreeningSummary screening : newRecords) {
            PartyScreeningSummary oldScreening = oldMap != null ? oldMap.get(screening.Id) : null;

            Object screeningDecision = screening.get('ScreeningDecision');
            Object oldScreeningDecision = oldScreening != null ? oldScreening.get('ScreeningDecision') : null;
            Boolean isRejected = screeningDecision != null && String.valueOf(screeningDecision) == 'Rejected';
            Boolean wasRejected = oldScreeningDecision != null && String.valueOf(oldScreeningDecision) == 'Rejected';

            if (!isRejected || wasRejected) {
                continue;
            }

            Id partyProfileId = getPartyProfileId(screening);
            if (partyProfileId == null) {
                continue;
            }

            partyProfileIds.add(partyProfileId);
        }

        if (!partyProfileIds.isEmpty()) {
            for (PartyProfile profile : [
                SELECT Id, Stage
                FROM PartyProfile
                WHERE Id IN :partyProfileIds
            ]) {
                partyProfilesById.put(profile.Id, profile);
            }
        }

        for (PartyScreeningSummary screening : newRecords) {
            PartyScreeningSummary oldScreening = oldMap != null ? oldMap.get(screening.Id) : null;
            Object screeningDecision = screening.get('ScreeningDecision');
            Object oldScreeningDecision = oldScreening != null ? oldScreening.get('ScreeningDecision') : null;
            Boolean isRejected = screeningDecision != null && String.valueOf(screeningDecision) == 'Rejected';
            Boolean wasRejected = oldScreeningDecision != null && String.valueOf(oldScreeningDecision) == 'Rejected';

            if (!isRejected || wasRejected) {
                continue;
            }

            Id partyProfileId = getPartyProfileId(screening);
            if (partyProfileId == null) {
                continue;
            }

            PartyProfile partyProfile = partyProfilesById.get(partyProfileId);
            if (partyProfile == null || partyProfile.Stage != 'Risk screening') {
                continue;
            }

            Object riskCategory = screening.get('RiskCategory');
            SObject riskRecord = createPartyProfileRiskRecord(
                partyProfileId,
                partyProfile.Stage,
                riskCategory,
                screeningDecision
            );
            if (riskRecord != null) {
                risksToInsert.add(riskRecord);
            }

            if (riskCategory != null && String.valueOf(riskCategory) == 'High') {
                casesToInsert.add(createComplianceCase(complianceQueueId));
            }
        }

        if (!risksToInsert.isEmpty()) {
            insert risksToInsert;
        }

        if (!casesToInsert.isEmpty()) {
            insert casesToInsert;
        }
    }

    private static Id getComplianceQueueId() {
        try {
            Group complianceQueue = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND DeveloperName = 'Compliance_Queue'
                LIMIT 1
            ];
            return complianceQueue.Id;
        } catch (QueryException e) {
            // Queue not found or insufficient permissions - log or handle gracefully
            System.debug(LoggingLevel.WARN, 'Compliance_Queue not found or inaccessible. Cases will be owned by running user.');
            return UserInfo.getUserId(); // fallback to current user
        }
    }

    private static Case createComplianceCase(Id queueId) {
        return new Case(
            Subject = 'Compliance Review Required for High Risk Screening',
            Priority = 'High',
            Status = 'New',
            Origin = 'Agentforce',
            OwnerId = queueId,
            Description = 'A Party Screening Summary was rejected and flagged as High Risk. Compliance review is required.'
        );
    }

    private static Id getPartyProfileId(PartyScreeningSummary screening) {
        Object partyProfileId = screening.get('PartyProfileId');
        if (partyProfileId == null) {
            return null;
        }
        return (Id) partyProfileId;
    }

    private static SObject createPartyProfileRiskRecord(Id partyProfileId, String partyProfileStage, Object riskCategory, Object screeningDecision) {
        Schema.SObjectType riskType = Schema.getGlobalDescribe().get('PartyProfileRisk');
        if (riskType == null) {
            return null;
        }

        SObject riskRecord = riskType.newSObject();
        Map<String, Schema.SObjectField> fields = riskRecord.getSObjectType().getDescribe().fields.getMap();

        if (fields.containsKey('PartyProfileId')) {
            riskRecord.put('PartyProfileId', partyProfileId);
        }

        if (fields.containsKey('Stage')) {
            riskRecord.put('Stage', partyProfileStage);
        }

        if (fields.containsKey('ScreeningDecision')) {
            riskRecord.put('ScreeningDecision', screeningDecision);
        }

        if (fields.containsKey('RiskCategory')) {
            riskRecord.put('RiskCategory', riskCategory);
        }

        return riskRecord;
    }
}