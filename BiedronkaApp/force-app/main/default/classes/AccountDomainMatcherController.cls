public with sharing class AccountDomainMatcherController {

    // List of public domains to ignore (Best Practice)
    private static final Set<String> PUBLIC_DOMAINS = new Set<String>{
        'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com'
    };

    @AuraEnabled(cacheable=true)
    public static List<Account> getRelatedAccountsByDomain(Id currentAccountId) {
        // Validation check
        if (String.isBlank(currentAccountId)) {
            return new List<Account>();
        }

        // STEP 1: Get current Account contacts and ParentId (for hierarchy exclusion)
        Account currentAccount = [
            SELECT Id, ParentId, 
                   (SELECT Email FROM Contacts WHERE Email != null) 
            FROM Account 
            WHERE Id = :currentAccountId 
            LIMIT 1
        ];

        // STEP 2: Extract unique domains from contacts
        Set<String> searchDomains = new Set<String>();
        for (Contact con : currentAccount.Contacts) {
            String domain = extractDomain(con.Email);
            // Only add if it's not a generic public domain
            if (domain != null && !PUBLIC_DOMAINS.contains(domain.toLowerCase())) {
                searchDomains.add(domain);
            }
        }

        if (searchDomains.isEmpty()) {
            return new List<Account>();
        }

        // STEP 3: Find OTHER contacts with these domains
        // We filter out contacts belonging to the current account
        List<Contact> matchingContacts = [
            SELECT AccountId 
            FROM Contact 
            WHERE Email_Domain__c IN :searchDomains // Assuming a Formula Field for performance
            AND AccountId != :currentAccountId
            LIMIT 1000
        ];

        Set<Id> potentialAccountIds = new Set<Id>();
        for (Contact con : matchingContacts) {
            potentialAccountIds.add(con.AccountId);
        }

        if (potentialAccountIds.isEmpty()) {
            return new List<Account>();
        }

        // STEP 4: Query final Accounts and exclude Hierarchy (Parent/Children)
        return [
            SELECT Id, Name, Industry, Phone, Owner.Name
            FROM Account
            WHERE Id IN :potentialAccountIds
            AND Id != :currentAccount.ParentId // Exclude Parent
            AND ParentId != :currentAccountId // Exclude Direct Children
        ];
    }

    // Helper method
    private static String extractDomain(String email) {
        if (String.isBlank(email) || !email.contains('@')) {
            return null;
        }
        return email.split('@')[1];
    }
}