public without sharing class KYCDecisionService {

    // Called from Flow & receives Account Ids and returns whether each Account is KYC Ready.
    @InvocableMethod(
        label='Evaluate KYC Readiness'
        description='Checks whether an Account is KYC Ready.'
    )
    public static List<Response> evaluateKYCReadiness(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests.isEmpty()) {
            return responses;
        }

        // Bulkify: Collect unique Account Ids
        Set<Id> accountIds = new Set<Id>();
        for (Request req : requests) {
            if (req.accountId != null) {
                accountIds.add(req.accountId);
            }
        }

        // Bulk queries - using your org's field API names
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Name, Email__c, PersonEmail, IsPersonAccount, Phone, 
                   FinServ__KYCStatus__c, FinServ__KYCDate__c
            FROM Account 
            WHERE Id IN :accountIds
        ]);

        Map<Id, PartyProfile> profileMap = new Map<Id, PartyProfile>([
            SELECT AccountId, FirstName, LastName, PrimaryPhone, 
                   PrimaryEmail, DateOfBirth, TaxpayerIdentificationType, 
                   TaxpayerIdentificationNumber, Stage
            FROM PartyProfile 
            WHERE AccountId IN :accountIds
        ]);

        // Process each request
        for (Request req : requests) {
            Response res = new Response();
            res.accountId = req.accountId;

            List<String> issues = getValidationIssues(req.accountId, accountMap, profileMap);
            
            res.isReady = issues.isEmpty();
            res.statusDetails = issues.isEmpty() 
                ? 'Customer is KYC Ready.' 
                : String.join(issues, ' ');

            responses.add(res);
        }

        return responses;
    }

    // Core validation logic - bulk-aware + aligned with your Party Profile fields
    private static List<String> getValidationIssues(
        Id accountId, 
        Map<Id, Account> accountMap, 
        Map<Id, PartyProfile> profileMap
    ) {
        List<String> issues = new List<String>();

        if (accountId == null) {
            issues.add('No Account Id supplied.');
            return issues;
        }

        Account acc = accountMap.get(accountId);
        if (acc == null) {
            issues.add('Account not found.');
            return issues;
        }

        // Account Validation
        if (String.isBlank(acc.Name)) {
            issues.add('Account Name is missing.');
        }
        String accountEmail = getAccountEmail(acc);
        if (String.isBlank(accountEmail)) {
            issues.add('Email is missing.');
        }
        if (String.isBlank(acc.Phone)) {
            issues.add('Phone is missing.');
        }
        if (acc.FinServ__KYCStatus__c != 'Completed - Valid') {
            issues.add('KYC Status must be Completed - Valid.');
        }
        if (acc.FinServ__KYCDate__c == null) {
            issues.add('KYC Date is missing.');
        }

        // Party Profile Validation (using your org's API names)
        PartyProfile pp = profileMap.get(accountId);
        if (pp == null) {
            issues.add('Party Profile not found.');
            return issues;
        }

        if (pp.AccountId == null) {
            issues.add('Related Account is missing.');
        }
        if (String.isBlank(pp.FirstName)) {
            issues.add('First Name is missing.');
        }
        if (String.isBlank(pp.LastName)) {
            issues.add('Last Name is missing.');
        }
        if (String.isBlank(pp.PrimaryPhone)) {
            issues.add('Primary Phone is missing.');
        }
        if (String.isBlank(pp.PrimaryEmail)) {
            issues.add('Primary Email is missing.');
        }
        if (pp.DateOfBirth == null) {
            issues.add('Date of Birth is missing.');
        }
        if (String.isBlank(pp.TaxpayerIdentificationType)) {
            issues.add('Taxpayer Identification Type is missing.');
        }
        if (String.isBlank(pp.TaxpayerIdentificationNumber)) {
            issues.add('Taxpayer Identification Number is missing.');
        }
        if (pp.Stage != 'Approved') {
            issues.add('Party Profile Stage must be Approved.');
        }

        return issues;
    }

    // Legacy single-account methods (kept for compatibility)
    public static Boolean isKYCReady(Id accountId) {
        if (accountId == null) {
            return false;
        }
        Map<Id, Account> accMap = new Map<Id, Account>([
            SELECT Id, Name, Email__c, Phone, FinServ__KYCStatus__c, FinServ__KYCDate__c 
            FROM Account WHERE Id = :accountId
        ]);
        Map<Id, PartyProfile> ppMap = new Map<Id, PartyProfile>([
            SELECT AccountId, FirstName, LastName, PrimaryPhone, PrimaryEmail, 
                   DateOfBirth, TaxpayerIdentificationType, TaxpayerIdentificationNumber, Stage 
            FROM PartyProfile WHERE AccountId = :accountId
        ]);

        List<String> issues = getValidationIssues(accountId, accMap, ppMap);
        return issues.isEmpty();
    }

    public static String getStatusDetails(Id accountId) {
        if (accountId == null) {
            return 'No Account Id supplied.';
        }
        Map<Id, Account> accMap = new Map<Id, Account>([
            SELECT Id, Name, Email__c, Phone, FinServ__KYCStatus__c, FinServ__KYCDate__c 
            FROM Account WHERE Id = :accountId
        ]);
        Map<Id, PartyProfile> ppMap = new Map<Id, PartyProfile>([
            SELECT AccountId, FirstName, LastName, PrimaryPhone, PrimaryEmail, 
                   DateOfBirth, TaxpayerIdentificationType, TaxpayerIdentificationNumber, Stage 
            FROM PartyProfile WHERE AccountId = :accountId
        ]);

        List<String> issues = getValidationIssues(accountId, accMap, ppMap);
        return issues.isEmpty() 
            ? 'Customer is KYC Ready.' 
            : String.join(issues, ' ');
    }

    // Input from Flow
    public class Request {
        @InvocableVariable(required=true)
        public Id accountId;
    }

    // Output back to Flow
    public class Response {
        @InvocableVariable
        public Id accountId;

        @InvocableVariable
        public Boolean isReady;

        @InvocableVariable
        public String statusDetails;
    }

    private static String getAccountEmail(Account acc) {
        if (!String.isBlank(acc.Email__c)) {
            return acc.Email__c;
        }
        Object personEmail = acc.get('PersonEmail');
        return personEmail != null ? String.valueOf(personEmail) : null;
    }
}