public with sharing class GridCriteriaExpressionParser {

    private static final Map<String, TokenMapping> TOKEN_MAP = buildTokenMap();

    public static ParseResult parse(String includeExpr, String excludeExpr) {
        ParseResult result = new ParseResult();

        Integer index = 1;
        SegmentResult includeSegment = parseSegment(includeExpr, false, index, result);
        index += includeSegment.count;
        SegmentResult excludeSegment = parseSegment(excludeExpr, true, index, result);

        if (includeSegment.count == 0 && excludeSegment.count == 0) {
            result.errors.add('Include and Exclude are both empty. At least one condition is required.');
            return result;
        }

        if (result.hasErrors()) {
            return result;
        }

        String includeExprBuilt = includeSegment.count > 0 ? includeSegment.expression : null;
        String excludeExprBuilt = excludeSegment.count > 0 ? excludeSegment.expression : null;

        if (String.isNotBlank(includeExprBuilt) && String.isNotBlank(excludeExprBuilt)) {
            result.filterLogicExpression = '(' + includeExprBuilt + ') AND (' + excludeExprBuilt + ')';
        } else if (String.isNotBlank(includeExprBuilt)) {
            result.filterLogicExpression = includeSegment.count > 1 ? '(' + includeExprBuilt + ')' : includeExprBuilt;
        } else {
            result.filterLogicExpression = excludeSegment.count > 1 ? '(' + excludeExprBuilt + ')' : excludeExprBuilt;
        }

        return result;
    }

    private static SegmentResult parseSegment(String expr, Boolean isExclude, Integer startIndex, ParseResult result) {
        SegmentResult segment = new SegmentResult();
        if (String.isBlank(expr)) {
            return segment;
        }

        String working = expr.trim();
        Pattern splitter = Pattern.compile('(?i)\\s+(AND|OR)\\s+');
        Matcher matcher = splitter.matcher(working);
        List<String> conditions = new List<String>();
        Integer lastIdx = 0;

        while (matcher.find()) {
            conditions.add(working.substring(lastIdx, matcher.start()).trim());
            segment.operators.add(matcher.group(1).toUpperCase());
            lastIdx = matcher.end();
        }
        conditions.add(working.substring(lastIdx).trim());

        for (Integer i = 0; i < conditions.size(); i++) {
            String rawCondition = conditions[i];
            if (String.isBlank(rawCondition)) {
                result.errors.add('Blank condition found in criteria: "' + expr + '".');
                return segment;
            }
            ParsedCondition parsed = parseCondition(rawCondition, isExclude, startIndex + i, result);
            if (parsed == null) {
                return segment;
            }
            result.conditions.add(parsed);
        }

        segment.count = conditions.size();
        segment.expression = buildExpression(segment.operators, startIndex, segment.count);
        return segment;
    }

    private static ParsedCondition parseCondition(String rawCondition, Boolean isExclude, Integer filterNumber, ParseResult result) {
        String working = rawCondition.trim();
        String upper = working.toUpperCase();
        Matcher opMatcher = Pattern.compile('\\s+(NOT IN|IN)\\s+|!=|<>|=').matcher(upper);
        if (!opMatcher.find()) {
            result.errors.add('Unsupported operator in condition: "' + rawCondition + '".');
            return null;
        }

        String opToken = opMatcher.group(1) != null ? opMatcher.group(1) : opMatcher.group(0);
        if (opToken == '<>') {
            opToken = '!=';
        }
        String opPattern = opMatcher.group(0);
        Integer opIndex = opMatcher.start();
        String token = working.substring(0, opIndex).trim();
        String right = working.substring(opIndex + opPattern.length()).trim();

        if (String.isBlank(token) || String.isBlank(right)) {
            result.errors.add('Invalid condition format: "' + rawCondition + '".');
            return null;
        }

        TokenMapping mapping = TOKEN_MAP.get(token.toLowerCase());
        if (mapping == null) {
            result.errors.add('Unknown token "' + token + '". Add it to the token mapping.');
            return null;
        }

        String logic = opToken;
        if (isExclude) {
            logic = (logic == '=')? '!=' : (logic == 'IN')? 'NOT IN' : logic;
        }

        String value;
        if (logic == 'IN' || logic == 'NOT IN') {
            if (!right.startsWith('(') || !right.endsWith(')')) {
                result.errors.add('IN/NOT IN values must be wrapped in parentheses in: "' + rawCondition + '".');
                return null;
            }
            String innerValues = right.substring(1, right.length() - 1).trim();
            List<String> values = splitValues(innerValues);
            if (values.isEmpty()) {
                result.errors.add('IN/NOT IN values are empty in: "' + rawCondition + '".');
                return null;
            }
            value = String.join(values, ';');
        } 
        else {
            value = stripQuotes(right);
            if (String.isBlank(value)) {
                result.errors.add('Value is blank in condition: "' + rawCondition + '".');
                return null;
            }
        }

        return new ParsedCondition(filterNumber, token, logic, value, mapping.objectApiName, mapping.fieldApiName);
    }

    private static String buildExpression(List<String> operators, Integer startIndex, Integer count) {
        String expression = '';
        for (Integer i = 0; i < count; i++) {
            if (i > 0) {
                expression += ' ' + operators[i - 1] + ' ';
            }
            expression += String.valueOf(startIndex + i);
        }
        return expression;
    }

    private static List<String> splitValues(String raw) {
        List<String> values = new List<String>();
        if (String.isBlank(raw)) {
            return values;
        }
        for (String part : raw.split('\\s*[,;]\\s*')) {
            String cleaned = stripQuotes(part);
            if (String.isNotBlank(cleaned)) {
                values.add(cleaned);
            }
        }
        return values;
    }

    private static String stripQuotes(String value) {
        if (value == null) {
            return null;
        }
        String cleaned = value.trim();
        if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
            (cleaned.startsWith('\'') && cleaned.endsWith('\''))) {
            cleaned = cleaned.substring(1, cleaned.length() - 1).trim();
        }
        return cleaned;
    }

    private static Map<String, TokenMapping> buildTokenMap() {
        Map<String, TokenMapping> mapping = new Map<String, TokenMapping>();
        // TODO: Update field API names if the org uses different ones.
        mapping.put('legalstatus', new TokenMapping('Product__c', 'Legal_Status__c'));
        mapping.put('shctype', new TokenMapping('Share_Class__c', 'Type__c'));
        mapping.put('ptfcode', new TokenMapping('Product__c', 'InternalShortName__c'));
        mapping.put('pfcode', new TokenMapping('Product__c', 'InternalShortName__c'));
        mapping.put('isin', new TokenMapping('Share_Class__c', 'ISIN__c'));
        return mapping;
    }

    // ------------------------------------ WRAPPERS ------------------------------------
    public class TokenMapping {
        public String objectApiName;
        public String fieldApiName;
        public TokenMapping(String objectApiName, String fieldApiName) {
            this.objectApiName = objectApiName;
            this.fieldApiName = fieldApiName;
        }
    }

    public class ParsedCondition {
        public Integer filterNumber;
        public String token;
        public String logic;
        public String value;
        public String objectApiName;
        public String fieldApiName;
        public ParsedCondition(Integer filterNumber, String token, String logic, String value, String objectApiName, String fieldApiName) {
            this.filterNumber   =   filterNumber;
            this.token          =   token;
            this.logic          =   logic;
            this.value          =   value;
            this.objectApiName  =   objectApiName;
            this.fieldApiName   =   fieldApiName;
        }
    }

    public class ParseResult {
        public List<ParsedCondition> conditions = new List<ParsedCondition>();
        public String filterLogicExpression;
        public List<String> errors = new List<String>();
        public Boolean hasErrors() {
            return !errors.isEmpty();
        }
    }

    private class SegmentResult {
        public Integer count = 0;
        public String expression;
        public List<String> operators = new List<String>();
    }
}