/**
 * Selector for Product2 records.
 */
public inherited sharing class ProductsSelector implements fflib_ISObjectSelector {
    public Schema.SObjectType sObjectType() {
        return Product2.SObjectType;
    }

    public List<SObject> selectSObjectsById(Set<Id> idSet) {
        if (idSet == null || idSet.isEmpty()) {
            return new List<SObject>();
        }

        List<SObject> records = new List<SObject>();
        records.addAll([
            SELECT Id, Name, External_Id__c, Biedronka_Name__c
            FROM Product2
            WHERE Id IN :idSet
        ]);
        return records;
    }
}
