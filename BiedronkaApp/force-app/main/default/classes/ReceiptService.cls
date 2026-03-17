/**
 * Service Layer Implementation.
 * Orchestrates business logic, transaction management, and delegates to Domain.
 */
public inherited sharing class ReceiptService implements IReceiptService {
    public void importReceipt(String jsonBody) {
        if (String.isBlank(jsonBody)) {
            return;
        }

        ReceiptDTO payload = (ReceiptDTO) JSON.deserialize(jsonBody, ReceiptDTO.class);
        if (payload == null || payload.dokument == null) {
            return;
        }

        fflib_ISObjectUnitOfWork uow = Application.UnitOfWork.newInstance(
            new List<SObjectType> {
                Account.SObjectType,
                Product2.SObjectType,
                Shopping_Transaction__c.SObjectType,
                Price_Observation__c.SObjectType
            }
        );

        String txnExternalId = payload.dokument?.paragon?.nrUnik;
        Shopping_Transaction__c transactionRecord = getExistingTransaction(txnExternalId);

        Datetime transactionDate = ReceiptDTO.parseDataJPK(payload.dokument?.naglowek?.dataJPK);

        if (transactionRecord == null) {
            transactionRecord = new Shopping_Transaction__c(
                External_Id__c = txnExternalId,
                Transaction_Date__c = transactionDate,
                Raw_JSON__c = jsonBody
            );
            uow.registerNew(transactionRecord);
        } else {
            transactionRecord.Transaction_Date__c = transactionDate;
            transactionRecord.Raw_JSON__c = jsonBody;
            uow.registerDirty(transactionRecord);
        }

        List<ReceiptDTO.PozycjaWrapper> items = payload.dokument?.paragon?.pozycja;
        Set<String> productNames = new Set<String>();
        if (items != null) {
            for (ReceiptDTO.PozycjaWrapper item : items) {
                if (item?.towar != null && String.isNotBlank(item.towar.nazwa)) {
                    productNames.add(item.towar.nazwa);
                }
            }
        }

        Map<String, Product2> productsByName = Products.resolveProductsByName(uow, productNames);

        if (items != null) {
            for (ReceiptDTO.PozycjaWrapper item : items) {
                if (item?.towar == null || String.isBlank(item.towar.nazwa)) {
                    continue;
                }

                Product2 relatedProduct = productsByName.get(item.towar.nazwa);
                if (relatedProduct == null) {
                    continue;
                }

                Price_Observation__c obs = new Price_Observation__c(
                    Price__c = item.towar.getDecimalPrice(),
                    Observation_Date__c = transactionDate,
                    Is_Promo__c = false
                );

                uow.registerNew(obs);
                uow.registerRelationship(obs, Price_Observation__c.Shopping_Transaction__c, transactionRecord);
                uow.registerRelationship(obs, Price_Observation__c.Product__c, relatedProduct);
            }
        }

        uow.commitWork();
    }

    private Shopping_Transaction__c getExistingTransaction(String externalId) {
        if (String.isBlank(externalId)) {
            return null;
        }

        List<Shopping_Transaction__c> existing = [
            SELECT Id, External_Id__c
            FROM Shopping_Transaction__c
            WHERE External_Id__c = :externalId
            LIMIT 1
        ];
        return existing.isEmpty() ? null : existing[0];
    }
}
