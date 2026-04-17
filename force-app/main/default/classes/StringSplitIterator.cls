public class StringSplitIterator implements Iterator<String>, Iterable<String>
{
    private String data;
    private Integer index = 0;
    private String separator = '\n';

    public StringSplitIterator(String data)
    {
        this.data = data;
    }

    public StringSplitIterator(String data, String separator)
    {
        this.separator = separator;
        this.data = data;
    }

    public Boolean hasNext()
    {
        return this.index < data.length();
    }

    public String next()
    {
        Integer nextSeparatorIndex = this.data.indexOf(this.separator, index);

        if (nextSeparatorIndex == -1)
        {
            nextSeparatorIndex = this.data.length();
        }

        String substring = data.substring(this.index, nextSeparatorIndex);
        this.index = nextSeparatorIndex + separator.length();

        return substring;
    }

    public List<String> next(Integer count)
    {
        String[] output = new List<String>();

        for (Integer i = 0; i < count && this.hasNext(); i++)
        {
            output.add(this.next());
        }

        return output;
    }

    public void reset()
    {
        this.index = 0;
    }

    public void clear()
    {
        this.data = null;
        reset();
    }

    public Iterator<String> iterator()
    {
        return this;
    }
}