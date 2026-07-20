@isTest
private class KYCDecisionServiceTest {
    @isTest
    static void testReadyWhenApprovedStatusAndDatePresent() {
        FinServ__PartyProfile__c profile = new FinServ__PartyProfile__c(
            FinServ__KYCStatus__c = 'Approved',
            FinServ__KYCDate__c = Date.today()
        );
        insert profile;

        Test.startTest();
        Boolean isReady = KYCDecisionService.isKYCReady(profile.Id);
        String details = KYCDecisionService.getStatusDetails(profile.Id);
        Test.stopTest();

        System.assertEquals(true, isReady, 'Approved status with a KYC date should be ready.');
        System.assert(details.contains('KYC is ready'), 'Status details should explain that KYC is ready.');
    }

    @isTest
    static void testNotReadyWhenKycDateIsMissing() {
        FinServ__PartyProfile__c profile = new FinServ__PartyProfile__c(
            FinServ__KYCStatus__c = 'Approved',
            FinServ__KYCDate__c = null
        );
        insert profile;

        Test.startTest();
        Boolean isReady = KYCDecisionService.isKYCReady(profile.Id);
        String details = KYCDecisionService.getStatusDetails(profile.Id);
        Test.stopTest();

        System.assertEquals(false, isReady, 'A missing KYC date should keep the record from being marked ready.');
        System.assert(details.contains('KYC date'), 'Status details should mention the missing KYC date.');
    }

    @isTest
    static void testReturnsHelpfulMessageWhenNoPartyProfileExists() {
        Id missingProfileId = 'a1A000000000001AAA';

        Test.startTest();
        Boolean isReady = KYCDecisionService.isKYCReady(missingProfileId);
        String details = KYCDecisionService.getStatusDetails(missingProfileId);
        Test.stopTest();

        System.assertEquals(false, isReady, 'Missing profiles should not be treated as ready.');
        System.assert(details.contains('No Party Profile'), 'Status details should explain that no Party Profile exists.');
    }
}
