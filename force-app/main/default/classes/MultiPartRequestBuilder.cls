/**
 * @author  Saad LOZZI
 * @date    23/07/2021
 * @details ...
 *
 * -- History
 * -- Date        Name                       Version  Remarks
 * -- ----------- -------------------------  -------  ---------------------------------------
 * -- 23/07/2021  Saad LOZZI                  1.0      Create
 */

public class MultiPartRequestBuilder
{
    private final static String Boundary = '1ff13444ed8140c7a32fc4e6451aa76d';

    public static String GetContentType()
    {
        return 'multipart/form-data; charset="UTF-8"; boundary="' + Boundary + '"';
    }

    private static String SafelyPad(String value, String valueCrLf64,String lineBreaks)
    {
        String valueCrLf = '';
        Blob valueCrLfBlob = null;

        while (valueCrLf64.endsWith('='))
        {
            value += ' ';
            valueCrLf = value + lineBreaks;
            valueCrLfBlob = Blob.valueOf(valueCrLf);
            valueCrLf64 = EncodingUtil.base64Encode(valueCrLfBlob);
        }

        return valueCrLf64;
    }

    public static String WriteBoundary()
    {
        String value = '--' + Boundary + '\r\n';
        Blob valueBlob = Blob.valueOf(value);

        return EncodingUtil.base64Encode(valueBlob);
    }

    public static String WriteBodyParameter(String key, String value)
    {
        String contentDisposition = 'Content-Disposition: form-data; name="' + key + '"';

        String contentDispositionCrLf = contentDisposition + '\r\n\r\n';

        Blob contentDispositionCrLfBlob = Blob.valueOf(contentDispositionCrLf);

        String contentDispositionCrLf64 = EncodingUtil.base64Encode(contentDispositionCrLfBlob);

        String content = SafelyPad(contentDisposition, contentDispositionCrLf64, '\r\n\r\n');

        String valueCrLf = value + '\r\n';

        Blob valueCrLfBlob = Blob.valueOf(valueCrLf);

        String valueCrLf64 = EncodingUtil.base64Encode(valueCrLfBlob);

        content += SafelyPad(value, valueCrLf64, '\r\n');

        return content;
    }

    public static String append(String key , String value )
    {
        return MultiPartRequestBuilder.WriteBoundary() + WriteBodyParameter(key, value);
    }

    public static Blob makeBlobWithFile(String key ,Blob attachBody, String filename, String otherParamsEncoded)
    {
        String header = '--' + Boundary + '\r\n' +
            + 'Content-Type: application/octet-stream\r\n'+
            + 'Content-Disposition: form-data; name="'+key+'";filename="' + filename +'"';

        String headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\r\n\r\n'));

        while(headerEncoded.endsWith('='))
        {
            header += ' ';
            headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header+'\r\n\r\n'));
        }

        String footer = '--' + Boundary + '--';
        String bodyEncoded = EncodingUtil.base64Encode(attachBody);
        Blob formBlob = null;
        String last4Bytes = bodyEncoded .substring(bodyEncoded.length()-4,bodyEncoded.length());

        if(last4Bytes.endsWith('=='))
        {
            last4Bytes = last4Bytes.substring(0,2) + '0K';
            bodyEncoded = bodyEncoded.substring(0,bodyEncoded.length()-4) + last4Bytes;
            String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
            formBlob = EncodingUtil.base64Decode(otherParamsEncoded+headerEncoded+bodyEncoded+footerEncoded);
        }
        else if(last4Bytes.endsWith('='))
        {
            last4Bytes = last4Bytes.substring(0,3) + 'N';
            bodyEncoded = bodyEncoded.substring(0,bodyEncoded.length()-4) + last4Bytes;
            footer = '\n' + footer;
            String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
            formBlob = EncodingUtil.base64Decode(otherParamsEncoded+headerEncoded+bodyEncoded+footerEncoded);
        }
        else
        {
            footer = '\r\n' + footer;
            String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
            formBlob = EncodingUtil.base64Decode(otherParamsEncoded+headerEncoded+bodyEncoded+footerEncoded);
        }

        return formBlob;
    }
}