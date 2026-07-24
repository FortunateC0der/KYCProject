public without sharing class KYCDecisionService {

    // Called from Flow to evaluate KYC readiness.
    @InvocableMethod(
        label='Evaluate KYC Readiness'
        description='Checks whether a Party Profile is KYC Ready.'
    )
    public static List<Response> evaluateKYCReadiness(List<Request> requests){

        List<Response> responses = new List<Response>();

        for(Request req : requests){

            Response res = new Response();

            res.partyProfileId = req.partyProfileId;

            // Get Party Profile once so we can expose AccountId.
            PartyProfile profile = getPartyProfile(req.partyProfileId);

            if(profile != null){
                res.accountId = profile.AccountId;
            }

            res.isReady = isKYCReady(req.partyProfileId);
            res.statusDetails = getStatusDetails(req.partyProfileId);

            responses.add(res);
        }

        return responses;
    }

    // Returns true when there are no validation issues.
    public static Boolean isKYCReady(Id partyProfileId){

        return getValidationIssues(partyProfileId).isEmpty();

    }

    // Returns validation results as a readable message.
    public static String getStatusDetails(Id partyProfileId){

        List<String> issues = getValidationIssues(partyProfileId);

        if(issues.isEmpty()){
            return 'Customer is KYC Ready.';
        }

        return String.join(issues, ' ');
    }

    // Retrieves Party Profile.
    private static PartyProfile getPartyProfile(Id partyProfileId){

        List<PartyProfile> profiles = [

            SELECT
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

    // Validates Party Profile and related Account.
    private static List<String> getValidationIssues(Id partyProfileId){

        List<String> issues = new List<String>();

        if(partyProfileId == null){

            issues.add('No Party Profile Id supplied.');
            return issues;

        }

        // Get Party Profile.
        PartyProfile profile = getPartyProfile(partyProfileId);

        if(profile == null){

            issues.add('Party Profile not found.');
            return issues;

        }

        // Check Related Account.
        if(profile.AccountId == null){

            issues.add('Related Account is missing.');
            return issues;

        }

        // Check First Name.
        if(String.isBlank(profile.FirstName)){
            issues.add('First Name is missing.');
        }

        // Check Last Name.
        if(String.isBlank(profile.LastName)){
            issues.add('Last Name is missing.');
        }

        // Check Primary Phone.
        if(String.isBlank(profile.PrimaryPhone)){
            issues.add('Primary Phone is missing.');
        }

        // Check Primary Email.
        if(String.isBlank(profile.PrimaryEmail)){
            issues.add('Primary Email is missing.');
        }

        // Check Date of Birth.
        if(profile.DateOfBirth == null){
            issues.add('Date of Birth is missing.');
        }

        // Check Taxpayer Identification Type.
        if(String.isBlank(profile.TaxpayerIdentificationType)){
            issues.add('Taxpayer Identification Type is missing.');
        }

        // Check Taxpayer Identification Number.
        if(String.isBlank(profile.TaxpayerIdentificationNumber)){
            issues.add('Taxpayer Identification Number is missing.');
        }

        // Check Stage.
        if(String.isBlank(profile.Stage)){
            issues.add('Party Profile Stage is missing.');
        }
        else if(profile.Stage != 'Approved'){
            issues.add('Party Profile Stage must be Approved.');
        }

        // Get Account.
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

        if(accounts.isEmpty()){

            issues.add('Account not found.');
            return issues;

        }

        Account acc = accounts[0];

        // Check Account Name.
        if(String.isBlank(acc.Name)){
            issues.add('Account Name is missing.');
        }

        // Check Phone.
        if(String.isBlank(acc.Phone)){
            issues.add('Phone is missing.');
        }

        // Check Email.
        Boolean hasEmail =
            !String.isBlank(acc.Email__c) ||
            !String.isBlank(acc.PersonEmail);

        if(!hasEmail){
            issues.add('Email is missing.');
        }

        // Check KYC Status.
        if(String.isBlank(acc.FinServ__KYCStatus__c)){
            issues.add('KYC Status is missing.');
        }
        else if(acc.FinServ__KYCStatus__c != 'Completed - Valid'){
            issues.add('KYC Status must be Completed - Valid.');
        }

        // Check KYC Date.
        if(acc.FinServ__KYCDate__c == null){
            issues.add('KYC Date is missing.');
        }

        return issues;
    }

    // Flow input.
    public class Request{

        @InvocableVariable(required=true)
        public Id partyProfileId;

    }

    // Flow output.
    public class Response{

        @InvocableVariable
        public Id partyProfileId;

        @InvocableVariable
        public Id accountId;

        @InvocableVariable
        public Boolean isReady;

        @InvocableVariable
        public String statusDetails;

    }

}