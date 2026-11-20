/** ──────────────────────────────────────
 * @description Tests of FormulaEvaluatorService: compilation in a context (prefixes rewritten outside literals and comments, fields read per prefix, cache),
 *                  evaluation on one record, on the records of several prefixes and in bulk (order, any / every short-circuit), return types,
 *                  rejected contexts and formulas (syntax, missing prefix, too many lookups, polymorphic lookup), and the parents loaded by withParents
 *                  (one query, cache, records already carrying their parents, a lookup changed or emptied before save).
 *              The engine is tested on standard objects in memory, and on Product__c (self-lookup ParentProduct__c) for the queries.
 * @covers FormulaEvaluatorService   100%   [19-11-26]
 * @author Charles EID
 * @lastModifiedBy Charles EID   [19-11-26]
 ────────────────────────────────────── */
@IsTest
private class FormulaEvaluatorServiceTest {

    @IsTest
    static void testCompileAndEvaluate() {
        // Contact is the host itself, Account is read through Contact.Account; a prefix inside a literal or a comment is not rewritten
        FormulaEvaluatorService.Context contactContext = new FormulaEvaluatorService.Context(Contact.SObjectType).withPrefix('Contact', null).withPrefix('account', 'account');
        String text = 'Contact.LastName = \'Contact.Doe\' /* Contact.Comment */ && Account.Parent.Name = "Account.Parent" && account.NumberOfEmployees > 10';
        Account parent = new Account(Name = 'Account.Parent');
        Account child = new Account(Name = 'Child', NumberOfEmployees = 20);
        child.putSObject('Parent', parent);
        Contact doe = new Contact(LastName = 'Contact.Doe');
        List<Account> accounts = new List<Account>{ child, new Account(NumberOfEmployees = 5), new Account(NumberOfEmployees = 30) };

        Test.startTest();

        FormulaEvaluatorService formula = FormulaEvaluatorService.compile(contactContext, text);
        FormulaEvaluatorService hostFormula = FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Account.SObjectType), 'Parent.Name = "Account.Parent" && NumberOfEmployees > 10');
        FormulaEvaluatorService label = FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Account.SObjectType).withPrefix('Account', null).withReturnType(FormulaEval.FormulaReturnType.STRING), 'Account.Name & " - " & Account.Parent.Name');
        FormulaEvaluatorService doubled = FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Account.SObjectType).withPrefix('Account', null).withReturnType(FormulaEval.FormulaReturnType.DECIMAL), 'Account.NumberOfEmployees * 2');
        FormulaEvaluatorService accountOnContact = FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Contact.SObjectType).withPrefix('Account', 'Account'), 'Account.NumberOfEmployees > 10');
        FormulaEvaluatorService accountOnContactFiveHops = FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Contact.SObjectType).withPrefix('Account', 'Account').withMaxRelationshipHops(5), 'Account.NumberOfEmployees > 10');

        Test.stopTest();

        // Several prefixes: one record per prefix, a missing one reads blank fields
        Assert.isTrue(formula.evaluateBoolean(new Map<String, SObject>{ 'contact' => doe, 'Account' => child }), 'Contact and Account read through the host');
        Assert.isFalse(formula.evaluateBoolean(new Map<String, SObject>{ 'Contact' => doe }), 'Missing Account: blank fields');
        Assert.isFalse(formula.evaluateBoolean(new Map<String, SObject>{ 'Contact' => new Contact(LastName = 'Doe'), 'Account' => child }), 'The literal Contact.Doe is not rewritten');
        Assert.areEqual(new List<Object>{ true, false }, formula.evaluateAll(new List<Map<String, SObject>>{ new Map<String, SObject>{ 'Contact' => doe, 'Account' => child }, new Map<String, SObject>{ 'Account' => child } }), 'Results in order');
        Assert.areEqual(new Set<String>{ 'LastName' }, formula.getPaths('Contact'), 'Host fields read');
        Assert.areEqual(new Set<String>{ 'Parent.Name', 'NumberOfEmployees' }, formula.getPaths('Account'), 'Account paths, as written after the prefix');
        Assert.areEqual(new Set<String>{ 'ParentId', 'NumberOfEmployees' }, formula.getTriggerFields('Account'), 'A path changes with its lookup');
        Assert.areEqual(new Set<String>{ 'Parent.Name', 'NumberOfEmployees', 'ParentId', 'Parent.Id' }, formula.getQueryFields('Account'), 'Query fields: paths, lookups and parent Ids');
        Assert.isTrue(formula.reads('Contact') && accountOnContact.reads('Account'), 'Reads the object of each prefix');
        Assert.isTrue(formula === FormulaEvaluatorService.compile(contactContext, text), 'Compiled once per transaction');
        Assert.isFalse(accountOnContact === accountOnContactFiveHops, 'One compilation per context');
        Assert.isNull(FormulaEvaluatorService.compile(contactContext, '  '), 'A blank text has no formula');

        // No prefix: fields written on the host, the host name is accepted as prefix
        Assert.isTrue(hostFormula.evaluateBoolean(child), 'Evaluated on the record itself');
        Assert.areEqual(new Set<String>{ 'Parent.Name', 'NumberOfEmployees' }, hostFormula.getPaths(null), 'Paths of a context without prefix');
        Assert.areEqual(hostFormula.getPaths(null), hostFormula.getPaths('Account'), 'The host name is accepted as prefix');
        Assert.isTrue(hostFormula.getReferencedFields().contains('Parent.Name'), 'Referenced fields as the engine reads them');

        // Return types
        Assert.areEqual('Child - Account.Parent', label.evaluate(child), 'Text formula across a lookup');
        Assert.areEqual(FormulaEval.FormulaReturnType.STRING, label.getReturnType(), 'Return type of the context');
        Assert.areEqual(40, ((Decimal) doubled.evaluate(child)).intValue(), 'Number formula');
        FormulaEvaluatorService.Context dateContext = new FormulaEvaluatorService.Context(Account.SObjectType).withReturnType(FormulaEval.FormulaReturnType.DATE);
        Assert.areEqual(Date.newInstance(2026, 3, 2), (Date) FormulaEvaluatorService.compile(dateContext, 'DATE(2026, 1, 31) + 30').evaluate(child), 'A DATE formula gives a Date (Formula Eval returns a Datetime)');
        Assert.isNull(FormulaEvaluatorService.compile(dateContext, 'IF(ISBLANK(Name), DATE(2026, 1, 1), NULL)').evaluate(child), 'A blank DATE stays null');
        Assert.isFalse(FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Account.SObjectType).withPrefix('Account', null), 'Account.Name = "Child"').evaluateBoolean((SObject) null), 'No record: blank host');

        // Bulk: order, short-circuit, never passes on nothing
        Assert.areEqual(new List<Object>{ true, false, true }, accountOnContact.evaluateAll(accounts), 'Results in order');
        FormulaEvaluatorService.evaluationCount = 0;
        Assert.isTrue(accountOnContact.evaluateAny(accounts), 'At least one passes');
        Assert.areEqual(1, FormulaEvaluatorService.evaluationCount, 'Any stops at the first true');
        FormulaEvaluatorService.evaluationCount = 0;
        Assert.isFalse(accountOnContact.evaluateEvery(new List<Account>{ accounts[1], accounts[0] }), 'One fails');
        Assert.areEqual(1, FormulaEvaluatorService.evaluationCount, 'Every stops at the first false');
        Assert.isTrue(accountOnContact.evaluateEvery(new List<Account>{ accounts[0], accounts[2] }), 'All pass');
        Assert.isFalse(accountOnContact.evaluateAny(new List<Account>{ accounts[1] }), 'None passes');
        Assert.isFalse(accountOnContact.evaluateAny(null) || accountOnContact.evaluateAny(new List<SObject>()) || accountOnContact.evaluateEvery(new List<SObject>()), 'A condition never passes on nothing');

        // Helpers
        Set<String> accountFields = FormulaEvaluatorService.getQueryFields(new List<FormulaEvaluatorService>{ formula, accountOnContact, label, null }, 'Account');
        Assert.isTrue(accountFields.containsAll(new Set<String>{ 'Parent.Name', 'NumberOfEmployees', 'ParentId', 'Parent.Id', 'Name' }), 'Union of the query fields of the formulas: ' + accountFields);
        Assert.isTrue(FormulaEvaluatorService.getQueryFields(new List<FormulaEvaluatorService>{ hostFormula }, 'Contact').isEmpty(), 'A formula without that prefix is ignored');
        Assert.areEqual(2, FormulaEvaluatorService.buildSelectList(new List<String>{ 'Id' }, new Set<String>{ 'id', 'Name', 'name ', ' ' }).size(), 'No duplicate, whatever the case');
    }

    @IsTest
    static void testInvalidFormulas() {
        FormulaEvaluatorService.Context accountContext = new FormulaEvaluatorService.Context(Account.SObjectType).withPrefix('Account', null);
        FormulaEvaluatorService.Context contactContext = new FormulaEvaluatorService.Context(Contact.SObjectType).withPrefix('Contact', null).withPrefix('Account', 'Account');
        String fiveHops = 'Account.Parent.Parent.Parent.Parent.Parent.Name = "Root"';
        String sixHops = 'Account.Parent.Parent.Parent.Parent.Parent.Parent.Name = "Root"';
        FormulaEvaluatorService text = FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Account.SObjectType).withReturnType(FormulaEval.FormulaReturnType.STRING), 'Name');
        FormulaEvaluatorService both = FormulaEvaluatorService.compile(contactContext, 'Contact.LastName = Account.Name');
        List<String> expectedMessages = new List<String>{
            'needs a host object', 'is not an object', 'must be the host', 'is not a lookup to Account only', 'declared twice', 'needs a return type', 'between 1 and 5',
            'no formula context', '"Account.Name = "', 'prefix LastName', 'more than the 4 allowed', 'Parent.Parent.Parent.Parent.Parent.Parent.Name', 'Owner',
            'reads several objects', 'is not one of its prefixes', 'not a BOOLEAN', 'a Account was given for Contact', 'cannot be loaded'
        };

        Test.startTest();

        FormulaEvaluatorService fiveHopsFormula = FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Account.SObjectType).withPrefix('Account', null).withMaxRelationshipHops(5), fiveHops);
        List<String> messages = new List<String>();
        for (Integer i = 0; i < expectedMessages.size(); i++) {
            String message;
            try {
                switch on i {
                    when 0 { new FormulaEvaluatorService.Context(null); }
                    when 1 { new FormulaEvaluatorService.Context(Account.SObjectType).withPrefix('NotAnObject__x', null); }
                    when 2 { new FormulaEvaluatorService.Context(Contact.SObjectType).withPrefix('Account', null); }
                    when 3 { new FormulaEvaluatorService.Context(Contact.SObjectType).withPrefix('Account', 'Owner'); }
                    when 4 { new FormulaEvaluatorService.Context(Contact.SObjectType).withPrefix('Account', 'Account').withPrefix('account', 'Account'); }
                    when 5 { new FormulaEvaluatorService.Context(Account.SObjectType).withReturnType(null); }
                    when 6 { new FormulaEvaluatorService.Context(Account.SObjectType).withMaxRelationshipHops(6); }
                    when 7 { FormulaEvaluatorService.compile(null, 'Name = "x"'); }
                    when 8 { FormulaEvaluatorService.compile(accountContext, 'Account.Name = '); }
                    when 9 { FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Contact.SObjectType).withPrefix('Account', 'Account'), 'LastName = "Doe"'); }
                    when 10 { FormulaEvaluatorService.compile(accountContext, fiveHops); }
                    when 11 { FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Account.SObjectType).withPrefix('Account', null).withMaxRelationshipHops(5), sixHops); }
                    when 12 { FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Case.SObjectType), 'Owner:User.Email = "a@b.c"'); }
                    when 13 { both.evaluate(new Contact()); }
                    when 14 { both.getPaths('Product__c'); }
                    when 15 { text.evaluateBoolean(new Account()); }
                    when 16 { both.evaluate(new Map<String, SObject>{ 'Contact' => new Account() }); }
                    when 17 { FormulaEvaluatorService.withParents(new List<Case>{ new Case() }, new Set<String>{ 'Owner.Name' }, AccessLevel.SYSTEM_MODE); }
                }
            }
            catch (FormulaEvaluatorService.FormulaEvaluatorException e) {
                message = e.getMessage();
            }
            messages.add(message);
        }

        Test.stopTest();

        for (Integer i = 0; i < expectedMessages.size(); i++) {
            Assert.isTrue(messages[i] != null && messages[i].contains(expectedMessages[i]), 'Case ' + i + ' rejected with "' + expectedMessages[i] + '": ' + messages[i]);
        }
        Assert.isNotNull(fiveHopsFormula, 'Up to 5 lookups when the context allows them');
    }

    @IsTest
    static void testWithParents() {
        Product__c root = product('TSTROOT', 'SICAV', null);
        insert root;
        Product__c parent = product('TSTPARENT', 'FCP', root.Id);
        Product__c other = product('TSTOTHER', 'FCP', null);
        insert new List<Product__c>{ parent, other };
        FormulaEvaluatorService formula = FormulaEvaluatorService.compile(new FormulaEvaluatorService.Context(Product__c.SObjectType).withPrefix('Product__c', null),
                                                                          'ISPICKVAL(Product__c.ParentProduct__r.ParentProduct__r.LegalForm__c, "SICAV")');
        Set<String> paths = formula.getQueryFields('Product__c');
        // Records not saved (like Trigger.new): their lookups only
        List<Product__c> drafts = new List<Product__c>{ new Product__c(ParentProduct__c = parent.Id), new Product__c(ParentProduct__c = other.Id), new Product__c() };

        Test.startTest();

        Integer queries = Limits.getQueries();
        List<SObject> loaded = FormulaEvaluatorService.withParents(drafts, paths, AccessLevel.SYSTEM_MODE);
        Integer loadQueries = Limits.getQueries() - queries;
        FormulaEvaluatorService.withParents(drafts, paths, AccessLevel.SYSTEM_MODE);
        Integer cachedQueries = Limits.getQueries() - queries - loadQueries;

        // A queried record carries its parents; moved or emptied before save, it follows its lookup
        List<SObject> queried = FormulaEvaluatorService.queryRecords(Product__c.SObjectType, new Set<Id>{ parent.Id }, paths, AccessLevel.SYSTEM_MODE);
        Product__c moved = (Product__c) queried[0].clone(true, false, true, true);
        moved.ParentProduct__c = parent.Id;
        Product__c emptied = (Product__c) queried[0].clone(true, false, true, true);
        emptied.ParentProduct__c = null;
        queries = Limits.getQueries();
        List<SObject> attached = FormulaEvaluatorService.withParents(new List<SObject>{ queried[0], moved, emptied }, paths, AccessLevel.SYSTEM_MODE);
        Integer attachedQueries = Limits.getQueries() - queries;

        FormulaEvaluatorService.clearCaches();
        queries = Limits.getQueries();
        FormulaEvaluatorService.withParents(drafts, paths, AccessLevel.SYSTEM_MODE);
        Integer clearedQueries = Limits.getQueries() - queries;

        Test.stopTest();

        Assert.areEqual(new Set<String>{ 'ParentProduct__r.ParentProduct__r.LegalForm__c', 'ParentProduct__c', 'ParentProduct__r.Id' }, paths, 'Query fields of the formula');
        Assert.areEqual(1, loadQueries, 'One query per relationship for all the records');
        Assert.areEqual(0, cachedQueries, 'Parents cached per transaction');
        Assert.isTrue(formula.evaluateBoolean(loaded[0]), 'Parent then grand-parent read: SICAV');
        Assert.isFalse(formula.evaluateBoolean(loaded[1]) || formula.evaluateBoolean(loaded[2]), 'No grand-parent, no parent');
        Assert.isFalse(drafts[0].getPopulatedFieldsAsMap().containsKey('ParentProduct__r'), 'A clone carries the parents, the record is unchanged');
        Assert.isTrue(loaded[2] === drafts[2], 'Nothing to attach: the record itself');

        Assert.areEqual(0, attachedQueries, 'Parents attached or cached: no query');
        Assert.isTrue(attached[0] === queried[0], 'A queried record already carries its parents');
        Assert.isFalse(formula.evaluateBoolean(attached[0]), 'TSTPARENT: its parent has no parent');
        Assert.isTrue(formula.evaluateBoolean(attached[1]), 'Moved under TSTPARENT before save: the new parent is read');
        Assert.isNull(attached[2].getSObject('ParentProduct__r'), 'Lookup emptied before save: no parent');
        Assert.areEqual(1, clearedQueries, 'Parents read again once the caches are cleared');

        Assert.isNull(FormulaEvaluatorService.withParents(null, paths, AccessLevel.SYSTEM_MODE), 'No record');
        Assert.isTrue(FormulaEvaluatorService.withParents(drafts, new Set<String>{ 'Name' }, AccessLevel.SYSTEM_MODE) === drafts, 'No path through a lookup: the records themselves');
        Assert.isTrue(FormulaEvaluatorService.queryRecords(Product__c.SObjectType, new Set<Id>(), paths, AccessLevel.SYSTEM_MODE).isEmpty(), 'No Id, no query');
        Assert.areEqual(1, FormulaEvaluatorService.queryRecords(Product__c.SObjectType, new Set<String>{ 'Name', 'name' }, 'InternalShortName__c IN :names',
                                                                 new Map<String, Object>{ 'names' => new List<String>{ 'TSTROOT' } }, AccessLevel.SYSTEM_MODE).size(), 'Query with a WHERE clause and binds');
    }

    private static Product__c product(String name, String legalForm, Id parentId) {
        return new Product__c(Name = name, InternalShortName__c = name, ProductName__c = name, LegalForm__c = legalForm, Validity__c = true, ParentProduct__c = parentId);
    }
}
