@isTest
public class KYCDecisionServiceTest {

    // /*
    //  * Helper method to create a Party Profile
    //  */
    // private static void createPartyProfile(Id accountId, String stage){

    //     PartyProfile profile = new PartyProfile(
    //         AccountId = accountId,
    //         Stage = stage
    //     );

    //     insert profile;
    // }

    // /*
    //  * Test: KYC Ready
    //  */
    // @isTest
    // static void testKYCReady(){

    //     Account acc = new Account(
    //         Name = 'John Doe',
    //         FinServ__KYCStatus__c = 'Completed - Valid',
    //         FinServ__KYCDate__c = Date.today()
    //     );

    //     insert acc;

    //     createPartyProfile(acc.Id, 'Approved');

    //     Test.startTest();

    //     Boolean result = KYCDecisionService.isKYCReady(acc.Id);

    //     Test.stopTest();

    //     System.assertEquals(true, result);
    // }

    // /*
    //  * Test: Missing KYC Status
    //  */
    // @isTest
    // static void testMissingStatus(){

    //     Account acc = new Account(
    //         Name = 'Jane Doe',
    //         FinServ__KYCDate__c = Date.today()
    //     );

    //     insert acc;

    //     createPartyProfile(acc.Id, 'Approved');

    //     Boolean result = KYCDecisionService.isKYCReady(acc.Id);

    //     System.assertEquals(false, result);
    // }

    // /*
    //  * Test: Missing KYC Date
    //  */
    // @isTest
    // static void testMissingDate(){

    //     Account acc = new Account(
    //         Name = 'Peter Smith',
    //         FinServ__KYCStatus__c = 'Completed - Valid'
    //     );

    //     insert acc;

    //     createPartyProfile(acc.Id, 'Approved');

    //     Boolean result = KYCDecisionService.isKYCReady(acc.Id);

    //     System.assertEquals(false, result);
    // }

    // /*
    //  * Test: Party Profile is NOT Approved
    //  */
    // @isTest
    // static void testPartyProfileNotApproved(){

    //     Account acc = new Account(
    //         Name = 'Mbappe',
    //         FinServ__KYCStatus__c = 'Completed - Valid',
    //         FinServ__KYCDate__c = Date.today()
    //     );

    //     insert acc;

    //     createPartyProfile(acc.Id, 'Pending');

    //     Boolean result = KYCDecisionService.isKYCReady(acc.Id);

    //     System.assertEquals(false, result);
    // }

    // /*
    //  * Test: No Party Profile
    //  */
    // @isTest
    // static void testNoPartyProfile(){

    //     Account acc = new Account(
    //         Name = 'No Profile',
    //         FinServ__KYCStatus__c = 'Completed - Valid',
    //         FinServ__KYCDate__c = Date.today()
    //     );

    //     insert acc;

    //     Boolean result = KYCDecisionService.isKYCReady(acc.Id);

    //     System.assertEquals(false, result);
    // }

    // /*
    //  * Test: Flow Invocable Method
    //  */
    // @isTest
    // static void testInvocableMethod(){

    //     Account acc = new Account(
    //         Name = 'Flow Test',
    //         FinServ__KYCStatus__c = 'Completed - Valid',
    //         FinServ__KYCDate__c = Date.today()
    //     );

    //     insert acc;

    //     createPartyProfile(acc.Id, 'Approved');

    //     KYCDecisionService.Request req = new KYCDecisionService.Request();
    //     req.accountId = acc.Id;

    //     Test.startTest();

    //     List<KYCDecisionService.Response> results =
    //         KYCDecisionService.evaluateKYCReadiness(
    //             new List<KYCDecisionService.Request>{ req }
    //         );

    //     Test.stopTest();

    //     System.assertEquals(1, results.size());
    //     System.assertEquals(true, results[0].isReady);
    //     System.assertEquals(acc.Id, results[0].accountId);
    //     System.assertEquals('KYC Approved.', results[0].statusDetails);
    // }

    // /*
    //  * Test: Null Account Id
    //  */
    // @isTest
    // static void testNullAccountId(){

    //     Boolean result = KYCDecisionService.isKYCReady(null);

    //     System.assertEquals(false, result);
    // }
}