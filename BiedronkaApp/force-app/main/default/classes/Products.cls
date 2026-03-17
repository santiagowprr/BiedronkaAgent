/**
 * Domain Layer for Product2.
 * Encapsulates behavior and logic for Product records.
 */
public inherited sharing class Products extends fflib_SObjectDomain {
    public Products(List<Product2> sObjectList) {
        super(sObjectList);
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new Products((List<Product2>) sObjectList);
        }
    }

    public static Map<String, Product2> resolveProductsByName(
        fflib_ISObjectUnitOfWork uow,
        Set<String> productNames
    ) {
        Map<String, Product2> result = new Map<String, Product2>();
        if (productNames == null || productNames.isEmpty()) {
            return result;
        }

        Set<String> normalizedNames = new Set<String>();
        for (String name : productNames) {
            if (String.isNotBlank(name)) {
                normalizedNames.add(name);
            }
        }
        if (normalizedNames.isEmpty()) {
            return result;
        }

        List<Product2> existingProducts = [
            SELECT Id, Name, External_Id__c
            FROM Product2
            WHERE Name IN :normalizedNames
        ];

        for (Product2 p : existingProducts) {
            result.put(p.Name, p);
        }

        for (String name : normalizedNames) {
            if (!result.containsKey(name)) {
                Product2 newProduct = new Product2(
                    Name = name,
                    External_Id__c = name,
                    Biedronka_Name__c = name
                );
                uow.registerNew(newProduct);
                result.put(name, newProduct);
            }
        }

        return result;
    }
}
