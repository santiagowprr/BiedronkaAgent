@RestResource(urlMapping='/receipts/v2/*')
global inherited sharing class REST_ReceiptService {

    @HttpPost
    global static void createReceipt() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String jsonBody = req.requestBody.toString();
            if (String.isBlank(jsonBody)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"status": "Error", "message": "Empty request body"}');
                return;
            }

            ReceiptDTO receipt = resolveReceipt(jsonBody);
            if (receipt == null || receipt.dokument == null) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"status": "Error", "message": "Invalid payload"}');
                return;
            }

            processReceipt(receipt);

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status": "Success", "message": "Receipt processed successfully"}');
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"status": "Error", "message": "' + e.getMessage() + '"}');
        }
    }

    private static ReceiptDTO resolveReceipt(String jsonBody) {
        ReceiptDTO dto = (ReceiptDTO) JSON.deserialize(jsonBody, ReceiptDTO.class);
        if (dto != null && dto.dokument != null) {
            return dto;
        }
        if (dto != null && String.isNotBlank(dto.data)) {
            String decoded = decodeEnvelopeData(dto.data);
            return (ReceiptDTO) JSON.deserialize(decoded, ReceiptDTO.class);
        }
        return null;
    }

    private static void processReceipt(ReceiptDTO receipt) {
        ReceiptDTO.DokumentWrapper dokument = receipt.dokument;
        Account accountRecord = upsertAccount(dokument.podmiot1);

            Shopping_Transaction__c receiptRecord = upsertReceipt(dokument, accountRecord);

        Integer itemsFound = 0;
        Integer itemsProcessed = 0;
        List<Price_Observation__c> itemsToInsert = new List<Price_Observation__c>();
        Price_Observation__c lastItem = null;

        List<ReceiptDTO.PozycjaWrapper> items = dokument.paragon?.pozycja;
        if (items != null) {
            itemsFound = items.size();
            Map<String, Product2> productsByCode = resolveProducts(items);

            for (ReceiptDTO.PozycjaWrapper item : items) {
                if (item?.towar == null || String.isBlank(item.towar.nazwa)) {
                    if (item?.discountLine != null && lastItem != null) {
                        lastItem.Is_Promo__c = true;
                    }
                    continue;
                }

                String cleanName = cleanProductName(item.towar.nazwa);
                if (String.isBlank(cleanName)) {
                    lastItem = null;
                    continue;
                }

                String productCode = buildProductCode(cleanName);
                Product2 product = productsByCode.get(productCode);
                if (product == null) {
                    lastItem = null;
                    continue;
                }

                Decimal quantity = parseQuantity(item.towar.ilosc);
                Decimal regularUnitPrice = item.towar.getDecimalPrice();
                Decimal finalLinePrice = null;
                if (item.towar.brutto != null) {
                    finalLinePrice = Decimal.valueOf(item.towar.brutto).divide(100, 2);
                }
                Decimal discountAmount = null;
                if (item.towar.rabat != null && item.towar.rabat.wart != null) {
                    discountAmount = Decimal.valueOf(Math.abs(item.towar.rabat.wart)).divide(100, 2);
                }
                Decimal discountPercent = null;
                Decimal regularLineTotal = null;
                if (regularUnitPrice != null && quantity != null) {
                    regularLineTotal = regularUnitPrice * quantity;
                }
                if (discountAmount != null && regularLineTotal != null && regularLineTotal != 0) {
                    discountPercent = (discountAmount / regularLineTotal) * 100;
                }

                Price_Observation__c receiptItem = new Price_Observation__c(
                    Shopping_Transaction__c = receiptRecord.Id,
                    Product__c = product.Id,
                    Price__c = regularUnitPrice,
                    Regular_Unit_Price__c = regularUnitPrice,
                    Final_Line_Price__c = finalLinePrice,
                    Discount_Amount__c = discountAmount,
                    Discount_Percent__c = discountPercent,
                    Observation_Date__c = receiptRecord.Transaction_Date__c,
                    Is_Promo__c = (item.towar.rabat != null)
                );
                itemsToInsert.add(receiptItem);
                itemsProcessed++;
                lastItem = receiptItem;
            }
        }

        if (!itemsToInsert.isEmpty()) {
            insert itemsToInsert;
        }

        System.debug('Receipt items found: ' + itemsFound + ', processed: ' + itemsProcessed);
    }

    private static Account upsertAccount(ReceiptDTO.PodmiotWrapper podmiot) {
        if (podmiot == null || String.isBlank(podmiot.NIP)) {
            return null;
        }

        List<Account> existing = [
            SELECT Id, Name, AccountNumber, BillingCity, BillingStreet
            FROM Account
            WHERE AccountNumber = :podmiot.NIP
            LIMIT 1
        ];

        Account accountRecord;
        String city = podmiot.adresPod?.miejsc;
        String street = podmiot.adresPod?.ulica;

        if (!existing.isEmpty()) {
            accountRecord = existing[0];
            accountRecord.Name = podmiot.nazwaPod;
            accountRecord.BillingCity = city;
            accountRecord.BillingStreet = street;
            update accountRecord;
            return accountRecord;
        }

        accountRecord = new Account(
            Name = podmiot.nazwaPod,
            AccountNumber = podmiot.NIP,
            BillingCity = city,
            BillingStreet = street
        );
        insert accountRecord;
        return accountRecord;
    }

    private static Shopping_Transaction__c upsertReceipt(
        ReceiptDTO.DokumentWrapper dokument,
        Account accountRecord
    ) {
        String externalId = dokument?.paragon?.nrUnik;
        Datetime transactionDate = ReceiptDTO.parseDataJPK(dokument?.naglowek?.dataJPK);
        Decimal totalAmount = null;
        if (dokument?.paragon?.total?.zaplZwrot != null) {
            totalAmount = Decimal.valueOf(dokument.paragon.total.zaplZwrot).divide(100, 2);
        }

        Shopping_Transaction__c receiptRecord = new Shopping_Transaction__c(
            External_ID__c = externalId,
            Transaction_Date__c = transactionDate,
            Total_Amount__c = totalAmount
        );
        if (accountRecord != null) {
            receiptRecord.Account__c = accountRecord.Id;
        }

        upsert receiptRecord External_ID__c;
        return receiptRecord;
    }

    private static Map<String, Product2> resolveProducts(List<ReceiptDTO.PozycjaWrapper> items) {
        Set<String> codes = new Set<String>();
        Map<String, String> nameByCode = new Map<String, String>();

        for (ReceiptDTO.PozycjaWrapper item : items) {
            if (item?.towar == null || String.isBlank(item.towar.nazwa)) {
                continue;
            }

            String cleanName = cleanProductName(item.towar.nazwa);
            if (String.isBlank(cleanName)) {
                continue;
            }

            String code = buildProductCode(cleanName);
            codes.add(code);
            nameByCode.put(code, cleanName);
        }

        Map<String, Product2> existingByCode = new Map<String, Product2>();
        if (!codes.isEmpty()) {
            for (Product2 product : [
                SELECT Id, Name, ProductCode, External_Id__c, Biedronka_Name__c
                FROM Product2
                WHERE External_Id__c IN :codes
            ]) {
                existingByCode.put(product.External_Id__c, product);
            }
        }

        List<Product2> toInsert = new List<Product2>();
        for (String code : codes) {
            if (!existingByCode.containsKey(code)) {
                Product2 product = new Product2(
                    Name = nameByCode.get(code),
                    ProductCode = code,
                    External_Id__c = code,
                    Biedronka_Name__c = nameByCode.get(code)
                );
                toInsert.add(product);
                existingByCode.put(code, product);
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        return existingByCode;
    }

    private static String cleanProductName(String rawName) {
        if (String.isBlank(rawName)) {
            return null;
        }

        String cleaned = rawName.replaceAll('\\s+', ' ').trim();
        cleaned = cleaned.replaceAll('\\s+[A-Za-z]$', '').trim();
        return cleaned;
    }

    private static String buildProductCode(String cleanedName) {
        if (String.isBlank(cleanedName)) {
            return null;
        }
        return cleanedName.replace(' ', '_');
    }

    private static Decimal parseQuantity(String quantityRaw) {
        if (String.isBlank(quantityRaw)) {
            return null;
        }
        try {
            return Decimal.valueOf(quantityRaw.replace(',', '.'));
        } catch (Exception e) {
            return null;
        }
    }

    private static String decodeEnvelopeData(String dataValue) {
        String payload = dataValue;
        if (dataValue.contains('.')) {
            List<String> parts = dataValue.split('\\.');
            if (parts.size() > 1) {
                payload = parts[1];
            }
        }

        payload = payload.replace('-', '+').replace('_', '/');
        while (Math.mod(payload.length(), 4) != 0) {
            payload += '=';
        }

        return EncodingUtil.base64Decode(payload).toString();
    }
}
