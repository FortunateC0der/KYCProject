public without sharing class KYCDecisionService {

    /*
     * Called from Flow.
     * Receives one or more Account Ids and returns
     * whether each Account is KYC Ready.
     */
    @InvocableMethod(
        label='Evaluate KYC Readiness'
        description='Checks whether an Account is KYC Ready.'
    )
    public static List<Response> evaluateKYCReadiness(List<Request> requests){

        List<Response> responses = new List<Response>();

        for(Request req : requests){

            Response res = new Response();

            res.accountId = req.accountId;
            res.isReady = isKYCReady(req.accountId);
            res.statusDetails = getStatusDetails(req.accountId);

            responses.add(res);
        }

        return responses;
    }

    /*
     * Returns TRUE only if:
     * 1. KYC Status = Completed - Valid
     * 2. KYC Date exists
     * 3. Party Profile exists
     * 4. Party Profile Stage = Approved
     */
    public static Boolean isKYCReady(Id accountId){

        if(accountId == null){
            return false;
        }

        // Get Account
        List<Account> accounts = [
            SELECT FinServ__KYCStatus__c,
                   FinServ__KYCDate__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if(accounts.isEmpty()){
            return false;
        }

        Account acc = accounts[0];

        // Check Status
        if(acc.FinServ__KYCStatus__c != 'Completed - Valid'){
            return false;
        }

        // Check Date
        if(acc.FinServ__KYCDate__c == null){
            return false;
        }

        // Get Party Profile
        List<PartyProfile> profiles = [
            SELECT Stage
            FROM PartyProfile
            WHERE AccountId = :accountId
            LIMIT 1
        ];

        if(profiles.isEmpty()){
            return false;
        }

        // Check Stage
        if(profiles[0].Stage != 'Approved'){
            return false;
        }

        return true;
    }

    /*
     * Returns a user-friendly explanation.
     */
    public static String getStatusDetails(Id accountId){

        if(accountId == null){
            return 'No Account Id supplied.';
        }

        List<Account> accounts = [
            SELECT FinServ__KYCStatus__c,
                   FinServ__KYCDate__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if(accounts.isEmpty()){
            return 'Account not found.';
        }

        Account acc = accounts[0];

        if(acc.FinServ__KYCStatus__c == null){
            return 'KYC Status is missing.';
        }

        if(acc.FinServ__KYCStatus__c != 'Completed - Valid'){
            return 'KYC Status must be Completed - Valid.';
        }

        if(acc.FinServ__KYCDate__c == null){
            return 'KYC Date is missing.';
        }

        List<PartyProfile> profiles = [
            SELECT Stage
            FROM PartyProfile
            WHERE AccountId = :accountId
            LIMIT 1
        ];

        if(profiles.isEmpty()){
            return 'Party Profile not found.';
        }

        if(profiles[0].Stage != 'Approved'){
            return 'Party Profile is not Approved.';
        }

        return 'KYC Approved.';
    }

    // Input from Flow
    public class Request{

        @InvocableVariable(required=true)
        public Id accountId;

    }

    // Output back to Flow
    public class Response{

        @InvocableVariable
        public Id accountId;

        @InvocableVariable
        public Boolean isReady;

        @InvocableVariable
        public String statusDetails;

    }

}