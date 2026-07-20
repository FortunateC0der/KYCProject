public without sharing class KYCDecisionService {
    public static Boolean isKYCReady(Id partyId) {
        try {
            if (partyId == null) {
                return false;
            }

            FinServ__PartyProfile__c partyProfile = queryPartyProfile(partyId);
            if (partyProfile == null) {
                return false;
            }

            String normalizedStatus = normalizeStatus(partyProfile.FinServ__KYCStatus__c);
            Date kycDate = partyProfile.FinServ__KYCDate__c;

            if (String.isBlank(normalizedStatus) || kycDate == null) {
                return false;
            }

            return isApprovedStatus(normalizedStatus);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'KYCDecisionService.isKYCReady failed: ' + ex.getMessage());
            return false;
        }
    }

    public static String getStatusDetails(Id partyId) {
        try {
            if (partyId == null) {
                return 'KYC readiness could not be evaluated because no party profile ID was provided.';
            }

            FinServ__PartyProfile__c partyProfile = queryPartyProfile(partyId);
            if (partyProfile == null) {
                return 'No Party Profile was found for the supplied party. Create or link a Party Profile before running the KYC readiness check.';
            }

            String status = normalizeStatus(partyProfile.FinServ__KYCStatus__c);
            Date kycDate = partyProfile.FinServ__KYCDate__c;

            if (String.isBlank(status)) {
                return 'The party profile is missing a KYC status. Update the KYC status to a completed or approved value before proceeding.';
            }

            if (kycDate == null) {
                return 'The party profile has a KYC status of ' + status + ', but no KYC date is recorded. Capture the KYC date to mark the party as ready.';
            }

            if (isApprovedStatus(status)) {
                return 'KYC is ready for this party. Status is ' + status + ' and the KYC date is ' + kycDate.format() + '.';
            }

            return 'KYC is not ready yet. Current status is ' + status + ' and the KYC date is ' + kycDate.format() + '. Complete the required onboarding steps and update the status.';
        } catch (Exception ex) {
            return 'Unable to evaluate KYC readiness because the service encountered an error: ' + ex.getMessage();
        }
    }

    private static FinServ__PartyProfile__c queryPartyProfile(Id partyId) {
        List<FinServ__PartyProfile__c> profiles = [
            SELECT Id, FinServ__KYCStatus__c, FinServ__KYCDate__c
            FROM FinServ__PartyProfile__c
            WHERE Id = :partyId
            LIMIT 1
        ];

        return profiles.isEmpty() ? null : profiles[0];
    }

    private static String normalizeStatus(String status) {
        return String.isBlank(status) ? '' : status.trim();
    }

    private static Boolean isApprovedStatus(String status) {
        Set<String> approvedStatuses = new Set<String>{'approved', 'complete', 'completed', 'ready', 'verified', 'pass', 'passed', 'clear'};
        return approvedStatuses.contains(status.toLowerCase());
    }
}
