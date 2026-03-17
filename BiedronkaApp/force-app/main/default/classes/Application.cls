/**
 * Application configuration for fflib Enterprise Patterns.
 */
public inherited sharing class Application {
    public static final fflib_Application.UnitOfWorkFactory UnitOfWork =
        new fflib_Application.UnitOfWorkFactory(
            new List<SObjectType> {
                Account.SObjectType,
                Product2.SObjectType,
                Shopping_Transaction__c.SObjectType,
                Price_Observation__c.SObjectType
            }
        );

    public static final fflib_Application.ServiceFactory Service =
        new fflib_Application.ServiceFactory(
            new Map<Type, Type> {
                IReceiptService.class => ReceiptService.class
            }
        );

    public static final fflib_Application.SelectorFactory Selector =
        new fflib_Application.SelectorFactory(
            new Map<SObjectType, Type> {
                Product2.SObjectType => ProductsSelector.class
            }
        );

    public static final fflib_Application.DomainFactory Domain =
        new fflib_Application.DomainFactory(
            Selector,
            new Map<SObjectType, Type> {
                Product2.SObjectType => Products.Constructor.class
            }
        );
}
