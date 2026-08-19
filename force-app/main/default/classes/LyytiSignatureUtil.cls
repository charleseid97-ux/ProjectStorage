/** ──────────────────────────────────────
 * @description Builds the LYYTI-API-V2 request signature and Authorization header used by all Lyyti
 *              callouts (HMAC-SHA256 of the base64-encoded public key/timestamp/call string, keyed by
 *              the private key).
 * @author Charles EID
 * @testClass LyytiSignatureUtilTest
 * @coverage 100%   [19-08-26]
────────────────────────────────────── */
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