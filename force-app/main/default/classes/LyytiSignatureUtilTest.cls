@isTest
public class LyytiSignatureUtilTest {

    private static final String PUBLIC_KEY = 'pub';
    private static final String PRIVATE_KEY = 'priv';
    private static final Long TIMESTAMP = 1234567890L;
    private static final String CALL_STRING = 'events/1/participants';
    private static final String OTHER_CALL_STRING = 'participant_types/1';

    private static final String KNOWN_PUBLIC_KEY = 'testpub';
    private static final String KNOWN_PRIVATE_KEY = 'testpriv';
    private static final Long KNOWN_TIMESTAMP = 1700000000L;
    private static final String KNOWN_CALL_STRING = 'participant_types/12345';
    // Independently computed (HMAC-SHA256 of base64(publicKey,timestamp,callString), keyed by privateKey)
    private static final String KNOWN_SIGNATURE = 'd6c7d3ba2d53f147d286ba632ebcaa8428db26e91a2eb6e96694860e799b674e';

    @isTest
    static void sign_matchesKnownAnswerVector() {
        Test.startTest();

        String signature = LyytiSignatureUtil.sign(KNOWN_PUBLIC_KEY, KNOWN_PRIVATE_KEY, KNOWN_TIMESTAMP, KNOWN_CALL_STRING);
        
        Test.stopTest();

        System.assertEquals(KNOWN_SIGNATURE, signature, 'Signature must match the independently computed HMAC-SHA256 vector');
    }

    @isTest
    static void sign_isDeterministicForSameInputs() {
        String signature1 = LyytiSignatureUtil.sign(PUBLIC_KEY, PRIVATE_KEY, TIMESTAMP, CALL_STRING);
        String signature2 = LyytiSignatureUtil.sign(PUBLIC_KEY, PRIVATE_KEY, TIMESTAMP, CALL_STRING);

        System.assertEquals(signature1, signature2, 'Same inputs must produce the same signature');
        System.assertEquals(64, signature1.length(), 'HMAC-SHA256 hex digest must be 64 characters');
    }

    @isTest
    static void sign_differsWhenCallStringDiffers() {
        String signature1 = LyytiSignatureUtil.sign(PUBLIC_KEY, PRIVATE_KEY, TIMESTAMP, CALL_STRING);
        String signature2 = LyytiSignatureUtil.sign(PUBLIC_KEY, PRIVATE_KEY, TIMESTAMP, OTHER_CALL_STRING);

        System.assertNotEquals(signature1, signature2, 'Different call strings must produce different signatures');
    }

    @isTest
    static void buildAuthorizationHeader_matchesExpectedFormat() {
        String header = LyytiSignatureUtil.buildAuthorizationHeader(KNOWN_PUBLIC_KEY, KNOWN_PRIVATE_KEY, KNOWN_TIMESTAMP, KNOWN_CALL_STRING);

        String expectedHeader = 'LYYTI-API-V2 public_key=' + KNOWN_PUBLIC_KEY + ', timestamp=' + KNOWN_TIMESTAMP + ', signature=' + KNOWN_SIGNATURE;

        System.assertEquals(expectedHeader, header);
    }
}