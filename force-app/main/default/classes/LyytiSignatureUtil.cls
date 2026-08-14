public inherited sharing class LyytiSignatureUtil {

    public static String sign(String publicKey, String privateKey, Long timestamp, String callString) {
        String msg = String.join(new List<String>{ publicKey, String.valueOf(timestamp), callString }, ',');

        String msgBase64 = EncodingUtil.base64Encode(Blob.valueOf(msg));

        Blob macKey = Blob.valueOf(privateKey);
        Blob input = Blob.valueOf(msgBase64);
        Blob hmac = Crypto.generateMac('hmacSHA256', input, macKey);

        return EncodingUtil.convertToHex(hmac);
    }

    public static String buildAuthorizationHeader(String publicKey, String privateKey, Long timestamp, String callString) {
        return 'LYYTI-API-V2 public_key=' + publicKey + ', timestamp=' + timestamp + ', signature=' + sign(publicKey, privateKey, timestamp, callString);
    }
}