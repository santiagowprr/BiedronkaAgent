@RestResource(urlMapping='/receipts/*')
global inherited sharing class ReceiptAPI {

    @HttpPost
    global static void createReceipt() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // 1. Pobieramy JSONa, którego przysłał iPhone
            String jsonBody = req.requestBody.toString();

            ReceiptDTO envelope = (ReceiptDTO) JSON.deserialize(jsonBody, ReceiptDTO.class);
            if (envelope == null || String.isBlank(envelope.data)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"status": "Error", "message": "Missing data payload"}');
                return;
            }

            String decodedJson = decodeEnvelopeData(envelope.data);

            // 2. Wołamy serwis aplikacyjny z odszyfrowanym payloadem
            // Używamy Application factory zgodnie z Twoją konfiguracją
            IReceiptService service = (IReceiptService) Application.Service.newInstance(IReceiptService.class);
            service.importReceipt(decodedJson);

            // 3. Odsyłamy sukces do telefonu
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status": "Success", "message": "Receipt processed successfully"}');

        } catch (Exception e) {
            // 4. W razie błędu odsyłamy info do telefonu
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"status": "Error", "message": "' + e.getMessage() + '"}');
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