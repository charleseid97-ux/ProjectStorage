/*************************************************************************************************************************
Class Name      :   AccountHierarchyCtrl
Class Desc.     :   Class used for Account Hierarchy Viewer widget  
Author          :   Alpha FMC
Description     :   This class is used to populate the hierarchy viewer VF component, displaying related Organisation, Legal Entity, 
                    Agreement, Portfolio, Relationship and Opportunity records with relevant information.

History
-------
//1.0 RR - Initial build of class on 30/9/2016
//1.1 OO - Modifications to fit in Org Relationships on 15/11/2016
//1.2 OO - Modifications to create folders for Agreements and link up Agreement Roles 15/02/2018
***************************************************************************************************************************/

global with sharing class AccountHierarchyCtrl{

    //Declare public variables +get and set methods for currentId String variable
    public String currentId {get;set;}
    public List<structureItem> asm;
    public Map<String, structureItem> masm;
    public List<Integer> maxLevel;
    set<ID> allAccounts = new set<ID>{};


    //Create a map for object field sets
    private map<Schema.SObjectType, Schema.Fieldset> fieldsets = new map<Schema.SObjectType, Schema.Fieldset>{
        Account.SObjectType => SObjectType.Account.FieldSets.HierarchyAccount
        ,Opportunity.SObjectType => SObjectType.Opportunity.FieldSets.HierarchyOpps
        ,Convention__c.SObjectType => SObjectType.Convention__c.FieldSets.HierarchyAgreement
        ,RelatedCompany__c.SObjectType => SObjectType.RelatedCompany__c.FieldSets.HierarchyRelationship
        //,Portfolio__c.SObjectType => SObjectType.Portfolio__c.FieldSets.HierarchyPortfolio
        ,Agreement_Role__c.SObjectType => SObjectType.Agreement_Role__c.FieldSets.HierarchyAgreementRole
    };


    //Create a map for object queries
    private map<Schema.SObjectType, String> queryWhereClauseMap = new map<Schema.SObjectType, String>
    {
        Account.SObjectType => ' WHERE ParentId IN :currentParent ORDER BY Name'
        ,Opportunity.SObjectType => ' WHERE AccountId IN :currentParent AND IsClosed != true AND IsWon != true ORDER BY Name'
        ,Convention__c.SObjectType => ' WHERE Company__c IN :currentParent AND Status__c != \'Expired\' AND Status__c != \'Terminated\' ORDER BY Name'
        ,RelatedCompany__c.SObjectType => ' WHERE (Company__c IN :currentParent OR ThirdParty__c IN :currentParent) ORDER BY Name'
        //,Portfolio__c.SObjectType => ' WHERE Agreement__c IN :currentParent ORDER BY Name'
        ,Agreement_Role__c.SObjectType => ' WHERE Agreement__c IN :currentParent ORDER BY Role__c'
    };

    /**
    * Constructor for Controller class
    **/
    public AccountHierarchyCtrl() {
        this.asm = new List<structureItem>{};
        this.masm = new Map<String, structureItem>{};
        this.maxLevel = new List<Integer>{};
    }


    /**
    * Declare method for returning hierarchical structure as JSON
    * @param String of the id to build hierarcy for
    * @return serialized JSON of hierarchy structure.
    **/
    @RemoteAction
    @AuraEnabled
    global static string getStructureAsJSON(string currentId)
    {
        //Instantiate the class, set the currentId and run the method
        AccountHierarchyCtrl hierarchy = new AccountHierarchyCtrl();
        hierarchy.setCurrentId(currentId);
        
        //Store object structure in List
        List<structureItem> ObjStrucList = hierarchy.getObjectStructure();
        return JSON.serialize(ObjStrucList[0]);
    }


    /**
    * Method allowing page to set value of currentId variable
    **/
    public void setcurrentId( String cid ){
        currentId = cid;
    }


    /**
    * Method for getting object and returning it's hierarchical structure
    * @return asm
    */
    public List<structureItem> getObjectStructure(){
        asm.clear();

        //If currentId is null, get Id from page
        if ( currentId == null ) {
            currentId = System.currentPageReference().getParameters().get( 'id' );
        }

        //Check if currentId is populated
        System.assertNotEquals( currentId, null, 'sObject ID must be provided' );

        //Get the ID from the page and then get the Account ID from that
        if (currentId != null) {
            String objectPrefix = currentId.substring(0,3);
        }

        if (currentId != null) asm = formatObjectStructure( currentId );

        return asm;
    }


    /**
    * Method for getting parent of objects in hierarchy
    * @return id
    **/
    private String getParent(sObject record)
    {
        //Declare String variable to store parent's id in
        String id = null;

        if (record.getSObjectType() == Account.sObjectType)
        {
            //If Object is Account, store it's parent Id in variable
            id = ((Account)record).ParentId;
        }
        else if (record.getSObjectType() == Convention__c.sObjectType)
        {
            //If Object is Agreement, store it's parent Id in variable
            id = ((Convention__c)record).Company__c;
        }
        else if (record.getSObjectType() == Agreement_Role__c.sObjectType)
        {
            //If Object is Agreement Role, store it's parent Id in variable
            id = ((Agreement_Role__c)record).Agreement__c;
        }
        //else if (record.getSObjectType() == Portfolio__c.sObjectType)
        //{
            //If Object is Portfolio, store it's parent Id in variable
        //    id = ((Portfolio__c)record).Agreement__c;
        //}
        else if (record.getSObjectType() == RelatedCompany__c.sObjectType)
        {
            //If Object is Relationship, store it's parent Id in variable
            //check if it came from an organisation or service provider
            if(allAccounts.contains(((RelatedCompany__c)record).Company__c))
            {
                id = ((RelatedCompany__c)record).Company__c;
            }
            else id = ((RelatedCompany__c)record).ThirdParty__c;
        }
        else if (record.getSObjectType() == Opportunity.sObjectType)
        {
            //If Object is Opportunity, store it's parent Id in variable
            id = ((Opportunity)record).AccountId;
        }

        //if (record.getSObjectType() != Portfolio__c.sObjectType)
            //record.getSObjectType() != Agreement_Role__c.sObjectType)
        //{
            id += record.getSObjectType().getDescribe().getLabel();
        //}
        return id;
    }

    /**
    * Method for dynamically quering objects
    * @return queryS
    **/
    public String buildQuery(SObjectType sObjType) 
    {
          //Create list of field set members
          List <FieldSetMember> fields = fieldsets.get(sObjType).getFields();
          String queryS = 'SELECT ';
          Integer fieldCnt = 0;
              for(Schema.FieldSetMember fieldSetMember : fields) {
                  fieldCnt++;
                  queryS = queryS + fieldSetMember.getFieldPath();

                  if(fieldCnt < fields.size()) {
                      queryS = queryS + ', ';
                  }
              }

          // Return the query, adding on the FROM
          return queryS + ' FROM ' + String.valueOf(sObjType);
    }
      

    /**
    * Query Account from top down to build the structureItem
    * @param currentId
    * @return masm.values()
    */
    public structureItem[] formatObjectStructure( String currentId ){

        //Declare public variables
        List<sObject> sol            = new List<sObject>{};
        List<sObject> sol2           = new List<sObject>{}; //this is for EXTERNAL COMP RELS or Agreement Roles
        List<sObject> sol3           = new List<sObject>{}; //this is for OPPORTUNITIES
        List<Account> al             = new List<Account>{};
        List<ID> currentParent       = new List<ID>{};
        Map<String, String> nodeList = new Map<String, String>{};
        String nodeId                = '0';
        Integer count                = 0;
        Boolean endOfStructure       = false;
        Integer level                = 0;

        //Create map for grouping records
        Map<String, String> relgroups = new Map<String, String>
        {
            'Agreement' => 'Agreements',
            'Related Company' => 'Related Third Party',
            'Opportunity' => 'Open Opportunities'
        };

        // Map to group child folders
        Map<String, String> childrelgroups = new Map<String, String>
        {
            'Agreement_Role__c' => 'Agreement Role'
        };

        //Create map for order of groupings
        map<string, integer> relgrouporders = new map<string, integer>
        {
            'Agreement' => 3,
            'Related Company' => 1,
            'Opportunity' => 2
        };


        //Find highest level obejct in the structure
        currentParent.add( GetTopElement( currentId ) );

        // Part 1 - get all the accounts
        sObject lastObject = null;

        //Loop through all the children of object
        while (!endOfStructure)
        {
            if(level == 0)
            {
                //Query for Account and store in List
                al = Database.query(buildQuery(Account.SObjectType) + ' WHERE Id IN : CurrentParent ORDER BY Name');
            }
            else
            {
                //Query for Account and store in List
                al = Database.query(buildQuery(Account.SObjectType) + queryWhereClauseMap.get(Account.SObjectType));
            }

            //If Account list size is 0, then that's the end of hierarchical structure
            if(al.size() == 0)
            {
                endOfStructure = true;
            }
            else
            {
                allAccounts.addAll(currentParent);
                currentParent.clear();

                for (Integer i = 0; i < al.size(); i++)
                {
                    Account a = al[i];
                    if(a.CompanyStatus__c == 'Active') {
                        
                    nodeId = (level > 0) ? nodeList.get(a.ParentId)+'.'+String.valueOf(i) : String.valueOf(i);

                    structureItem osm = new structureItem(a);
                    
                    masm.put(NodeID,  osm);

                    //Here we add the children to the parent, creating hierarchical structure
                    if (masm.get(nodeList.get( a.ParentId )) != null)
                    {
                        masm.get(nodeList.get( a.ParentId )).children.add(osm);
                    }

                    system.debug('NodeID:' + NodeID);
                    
                    currentParent.add( a.id );
                    nodeList.put( a.id,nodeId );
    
                    count++;
                    integer j = 0;

                    //if ( a.RecordType.DeveloperName != 'Account_GlobalAccount') 
                    for (string relgroup : relgroups.keyset() )
                    {
                        if (relgroup == 'Agreement' && 
                            a.RecordType.DeveloperName == 'Advisor_Consultant')
                        {
                            continue;
                        }

                        j++;

                        //Create new Account
                        Account b = new Account(Name = relgroups.get(relgroup));



                        /*
                        * these are the dummy entries that group LOB Rels, Comp Comp rels and Comp Cont rels
                        * they are prefixed 1, 2, 3 4 so they sort before accounts whose node nums are prefixed 9
                        */
                        nodeId = ( level > 0 )
                               ? nodeList.get( a.Id ) + '.' + String.valueOf( i ) + String.valueOf( relgrouporders.get(relgroup) )
                               : String.valueOf( i ) + String.valueOf( relgrouporders.get(relgroup) ) ;

                       osm = new structureItem( b );
                       masm.put( NodeID,  osm);

                        //Here we add the children to the parent, creating hierarchical structure
                       if (masm.get(nodeList.get( a.Id  )) != null)
                       {
                            //osm.parent = nodeList.get( a.Id );
                            masm.get(nodeList.get( a.Id  )).children.add(osm);
                        }

                        nodeList.put( a.id + relgroup,nodeId );
                        system.debug('P1 nodeList.put( '+a.id+relgroup+', '+nodeId+' )' );

                    }
                    }
                    lastObject = a;
                        
                }

                maxLevel.add(level);
                level++;
            }
        }
        allAccounts.addAll( currentParent );
        //Part 2 - get all object records below Account
        system.debug('PART 2 ');

        currentParent.addAll(allAccounts);
        endOfStructure  = false;

        /** Loop though all children of parent
        * @return masm.values
        **/
        while (!endOfStructure)
        {
            //If object is Account then query all objects below it in hierarchy
            if (lastObject!=null && lastObject.getSObjectType() == Account.SObjectType )
            {
                sol = Database.query(buildQuery(Convention__c.SObjectType) + queryWhereClauseMap.get(Convention__c.SObjectType) );
                sol2 = Database.query(buildQuery(RelatedCompany__c.SObjectType) + queryWhereClauseMap.get(RelatedCompany__c.SObjectType));
                sol3 = Database.query(buildQuery(Opportunity.SObjectType) + queryWhereClauseMap.get(Opportunity.SObjectType));
            }
            else if ( lastObject!=null && lastObject.getSObjectType() == Convention__c.sObjectType )
           {
                //If object is Agreement then query object Portfolio + Agreement Roles below it in hierarchy
                //sol = Database.query(buildQuery(Portfolio__c.sObjectType) + queryWhereClauseMap.get(Portfolio__c.sObjectType));
                sol2 = Database.query(buildQuery(Agreement_Role__c.sObjectType) + queryWhereClauseMap.get(Agreement_Role__c.sObjectType));
            }
            //else if ( lastObject!=null && lastObject.getSObjectType() == Portfolio__c.sObjectType )
            //{
            //    sol.clear();
            //}

            if(sol.size() == 0 && sol2.size() == 0 && sol3.size() == 0)
            {
                endOfStructure = true;
            }
            else
            {
                currentParent.clear();
                Integer countOverAllObjects = 0;
                for (Integer i=0; i<sol.size(); i++)
                {
                    countOverAllObjects = countOverAllObjects + i;
                    sObject o = sol[i];

                    structureItem osm = new structureItem( o );

                    lastObject = o;
                    string pid = getParent( o );

                    nodeId =  nodeList.get( pid );
                    system.debug ('BP node Id? ' + nodeId);

                    if (nodeId == null)
                        continue;

                    nodeId += '.' + String.valueOf( countOverAllObjects );
                    
                    osm = new structureItem( o );
                    masm.put( NodeID,  osm);

                    //Here we add the children to the parent, creating hierarchical structure
                    if (masm.get(nodeList.get( pid  )) != null)
                    {
                        masm.get(nodeList.get( pid  )).children.add(osm);
                    }

                    currentParent.add( o.id );
                    nodeList.put( o.id  ,nodeId );
                }

                if (countOverAllObjects != 0)
                    countOverAllObjects++;

                if (!sol2.isEmpty())
                {
                    //If sobjectType is in childrelgroup, then get its parent
                    String sObjectType = String.valueOf(sol2[0].getSObjectType());
                    String crg = childrelgroups.get(sObjectType);
                    if (crg != null)
                    {
                        //Get the unique parents and convert it to a list
                        Set<String> parents = new Set<String>();
                        for(sObject o : sol2)
                        {
                            String parentId = getParent(o);
                            parents.add(parentId);
                        }
                        List<String> parentsIter = new List<String>(parents);

                        // For each parent, create a child under it with the folder
                        for (Integer i=0; i<parentsIter.size(); i++)
                       {
                            countOverAllObjects = countOverAllObjects + i;

                            //Get the parent Id and select the node that it is attached to
                            String pid = parentsIter[i];
                            String truncated = pid.left(pid.length()-crg.length());
                            nodeId = nodeList.get(truncated);

                            Account a = new Account(Name='Related Legal Entities');

                            //Append to the node
                            nodeId += '.' + String.valueOf(countOverAllObjects);

                            structureItem osm = new structureItem(a);

                            masm.put(nodeId, osm);

                            if (masm.get(nodeList.get(truncated)) != null)
                            {
                                masm.get(nodeList.get(truncated)).children.add(osm);
                            }
                            nodeList.put(pid, nodeId);
                        }
                    }

                    for ( Integer i = 0 ; i < sol2.size(); i++ )
                    {
                        countOverAllObjects = countOverAllObjects + i;

                        
                        sObject o = sol2[i];

                        System.debug(o);
                        string pid = getParent(o);
                        system.debug('YYY 888    The pId    ' +pid);
                        system.debug('YYY 777    nodeListValues    ' +nodeList.keyset());
                        nodeId = nodeList.get( pid );
                        system.debug('YYY 999    The NodeId is: ' + nodeId + 'The Object is :   ' + o);
                        
                        /**
                        * Object has no parent, probably an UltimateParent 
                        * with a record it shouldnt have 
                        * eg LOB Comp-Cpnt, Comp-Comp
                        **/
                        if (nodeId == null)
                            continue;

                        nodeId += '.' + String.valueOf( countOverAllObjects );

                        structureItem osm = new structureItem( o );
                        masm.put( NodeID, osm );

                        //Here we add the children to the parent, creating hierarchical structure
                        if (masm.get(nodeList.get( pid  )) != null)
                        {
                            masm.get(nodeList.get( pid  )).children.add(osm);
                        }

                        nodeList.put( o.id,nodeId );
                    }
                }

                if (countOverAllObjects != 0)
                    countOverAllObjects++;

                if (!sol3.isEmpty())
                {
                    for ( Integer i = 0 ; i < sol3.size(); i++ )
                    {
                        countOverAllObjects = countOverAllObjects + i;

                        sObject o = sol3[i];
                        system.debug(o);
                        string pid = getParent( o );
                        nodeId = nodeList.get( pid );

                        /**
                        * Object has no parent, 
                        * probably an UltimateParent 
                        * with a record it shouldnt 
                        * have eg LOB Comp-Cpnt, Comp-Comp
                        **/
                        if (nodeId == null)
                            continue;

                        nodeId += '.' + String.valueOf( countOverAllObjects );

                        structureItem osm = new structureItem( o );
                        masm.put( NodeID, osm );

                        if (masm.get(nodeList.get( pid  )) != null)
                        {
                            masm.get(nodeList.get( pid  )).children.add(osm);
                        }

                        system.debug(o);
                        nodeList.put( o.id,nodeId );
                        system.debug('P2 nodeList.put( '+o.id+', '+nodeId+' )' );
                    }
                }

                maxLevel.add( level );
                level++;

                sol.clear();
                sol2.clear();
                sol3.clear();

            }
        }

        system.debug('end PART 2 masm.size()='+masm.size()+' nodeList.size()='+nodeList.size());

        return masm.values();
    }


    /**
    * Find the top most element in Hierarchy by 
    * dynamically query out until it reaches the top
    * @return objId
    */
    public String GetTopElement( String objId ){

        string objectPrefix = objId.substring(0,3);

        if (objectPrefix == Schema.Sobjecttype.Convention__c.getKeyPrefix())
        {
            try
            {
                Convention__c m = [SELECT Company__c FROM Convention__c WHERE Id = :objId]; 
                objId = m.Company__c;
            }
            catch (Exception e)
            {
                objId = null;
            }
        }

        Boolean top = false;
        while (!top)
        {
            Account a = [ Select a.Id, a.ParentId From Account a where a.Id =: objId limit 1 ];

            if ( a.ParentID != null )
            {
                objId = a.ParentID;
            }
            else
            {
                top = true;
            }
        }
        return objId;
    }


    /**
    * Wrapper class to store sObject
    */
    public with sharing class structureItem
    {
        public void setsobject( sObject o ) { this.Record = o; }
        public sObject Record {get; set;}
        public List <structureItem> children = new List<structureItem>();

        // Constructor
        public structureItem(  sObject o )
        {
            this.Record = o;
        }
    }

}