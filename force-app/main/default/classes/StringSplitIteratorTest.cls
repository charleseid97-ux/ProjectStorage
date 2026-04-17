@IsTest
private class StringSplitIteratorTest
{
    @IsTest
    static void testStringSplitting()
    {
        Test.startTest();

        String sample = 'field1~field2~field3';
        StringSplitIterator iterator = new StringSplitIterator(sample, '~');
        System.assert(iterator.hasNext());
        System.assertEquals('field1', iterator.next());
        System.assert(iterator.hasNext());
        List<String> fields = iterator.next(2);
        System.assertEquals(2, fields.size());
        System.assert(!iterator.hasNext());
        System.assertEquals('field2', fields[0]);
        System.assertEquals('field3', fields[1]);

        sample = 'field1,field2,field3';
        Iterator<String> innerIterator = new StringSplitIterator(sample).iterator();
        while (innerIterator.hasNext()) innerIterator.next();
        System.assert(!innerIterator.hasNext());

        Test.stopTest();
    }
}