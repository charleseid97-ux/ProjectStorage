/**************************************************************************************
*  @Author Ragnar Rahuoja
*
*   Date 13/01/2018
*
*   Account Hierarchy Lightning Component Helper class
*
*   First build
*   07/02/18 RR - org rels fix. moving DRAWN_ACCOUNTS inst. to controller init function
*   15/03/18 OO - Additions to show Agreement Roles
**************************************************************************************/

({
    dig: function(obj,path) {
        path=path.split('.');
        var result=obj;
        for (var i=0;i<path.length;i++) result=result[path[i]];
        return result;
    },
    buildList: function(data, DRAWN_ACCOUNTS, component) {
        if(data!=null) {
            var html = "";
    
            //map of fake objects that are there as folders. these are Account objects in the data (necessarily because of the way the hierarchy is built)
            //but we want them to display as what object type they are, without a link to the account id
            var FOLDER_MAP = {
                "Open Opportunities" : "Opportunity",
                "Related Third Party" : "RelatedCompany__c",
                "Agreements" : "Convention__c",
                "Related Legal Entities" : "Agreement_Role__c"
            };
            //this is not strictly necessary but it is quicker
            var FOLDER_MAP_KEYS = [ "Open Opportunities", "Related Third Party",  "Agreements", "Related Legal Entities"];
    
            //is it a folder?
            var isAFolder = FOLDER_MAP_KEYS.indexOf(data.Record.Name) > -1;
            var whichFolder = "";
            var recordId = data.Record.Id;
            
            var topId = component.get("v.topId");
            if(topId == "tmp") {
                component.set("v.topId", recordId);
            }
            
            if (isAFolder)
            {
                whichFolder = FOLDER_MAP[data.Record.Name];
                recordId = "";
            }
            //if it is a folder node ie a grouping and not an object at all, then don't display it if it has no children
            if (!isAFolder || (data.children && data.children.length != 0))
            {
                html += '<li id="' +  recordId  + '">';
    
                html += this.htmlForNode(data, whichFolder, FOLDER_MAP, FOLDER_MAP_KEYS, DRAWN_ACCOUNTS);
    
                if(typeof(data.children) === 'object'){ // An array will return 'object'
                    var count = data.children.length;
    
                    html += '<ul class="hid">';
    
                    for (var i = 0; i < count; i++) {
                        html += this.buildList(data.children[i], DRAWN_ACCOUNTS, component); 
                    }
    
                    html += '</ul>';
                 }
                html += '</li>';
            }
            return html;
        }
    },
    htmlForNode : function(nodeData, folderType, folderMap, folderMapKeys, DRAWN_ACCOUNTS) {
        var sldsPath = $A.get('$Resource.SLDSATS');
        var strHTML = '<span class="displayLine">';
        var ICON_MAP = {
            "Account": {"icon":"SLDSATS/assets/icons/standard/account.svg","color":"#7f8de1"},
            "Opportunity": {"icon":"standard/opportunity.svg","color":"#fcb95b"},
            "Agreement_Role__c": {"icon":"custom/custom90.svg","color":"#22a48a"},
            "Convention__c": {"icon":"custom/custom14.svg","color":"#3cc2b3"},
            //"Portfolio__c": {"icon":"standard/investment_account.svg","color":"#4bc076"},
            "RelatedCompany__c": {"icon":"standard/social.svg","color":"#ea74a2"}
        };

        // use the PNG and for displaying the right names and Ids
        var MAP_RESOURCE = {
            "Account": {"icon": sldsPath + "/SLDSATS/assets/icons/standard/account_60.png","color":"slds-icon-standard-account"
                        ,"targetId":"Id","targetName":"Name", "targetAtRisk":"Agreements_At_Risk__c"},
            "Opportunity": {"icon": sldsPath + "/SLDSATS/assets/icons/standard/opportunity_60.png","color":"slds-icon-standard-opportunity"
                        ,"targetId":"Id","targetName":"Name"},
            "Agreement_Role__c": {"icon": sldsPath + "/SLDSATS/assets/icons/custom/custom90_60.png","color":"slds-icon-custom-custom90"
                        ,"targetId":"Legal_Entity__c","targetName":"Legal_Entity__r.Name"},
            "Convention__c": {"icon": sldsPath + "/SLDSATS/assets/icons/custom/custom14_60.png","color":"slds-icon-custom-custom14"
                        ,"targetId":"Id","targetName":"Name"},
            //"Portfolio__c": {"icon": sldsPath + "/SLDSATS/assets/icons/standard/investment_account_60.png","color":"slds-icon-standard-investment-account"
            //            ,"targetId":"Id","targetName":"Name", "targetAtRisk":"At_Risk__c"},
            "RelatedCompany__c": {"icon": sldsPath + "/SLDSATS/assets/icons/standard/social_60.png","color":"slds-icon-standard-social"
                        ,"targetId":["Company__c","ThirdParty__c"],"targetName":["Company__r.Name","ThirdParty__r.Name",]},
            "AtRisk" :  {"icon": sldsPath + "/SLDSATS/assets/icons/custom/custom101.png","color":"slds-icon-custom-custom68"}
        };

        //map to display currency symbols from CurrencyIsoCode
        var MAP_CURRENCY = { "USD": "$", "GBP": "£", "AUD":"AU$", "CAD":"C$", "HKD":"HK$"
                            , "EUR":"€","JPY":"¥", "NZD":"NZ$", "SEK":"kr" };

            //has children
            //an account has children if it has children that are NOT folders wth no children
            //everything else just has children...
            var hasChildren = false;

            if (nodeData.Record.attributes.type == "Account")
            {
                //add to the array of it has an Id
                if(nodeData.Record.Id) DRAWN_ACCOUNTS.push(nodeData.Record.Id);

                if(typeof(nodeData.children) === 'object' && nodeData.children.length > 0)
                {
                    for (var i = 0; i < nodeData.children.length; i++)
                    {
                        //if it's a folder, it needs to have children too...
                        if (folderMapKeys.indexOf(nodeData.children[i].Record.Name) > -1)
                        {
                            if (typeof(nodeData.children[i].children) === 'object'
                                && nodeData.children[i].children.length > 0)
                            hasChildren = true;

                        }

                        //otherwise it just needs to exist
                        else hasChildren = true;

                    }
                }   
            }
            else if (typeof(nodeData.children) === 'object' && nodeData.children.length > 0)
                hasChildren = true;
            //only need a control where things have children
            if(hasChildren) strHTML += '<span class="control" > + </span>';
            else strHTML += '<span class="nocontrol" > + </span>';

            // ICON HTML
            var iconpath = (MAP_RESOURCE[nodeData.Record.attributes.type] ? MAP_RESOURCE[nodeData.Record.attributes.type].icon : '' );
            var colorclass = (MAP_RESOURCE[nodeData.Record.attributes.type] ? MAP_RESOURCE[nodeData.Record.attributes.type].color : '' );

        	//swap out the folder icons for the things we really want them to show as
            if (folderMapKeys.indexOf(nodeData.Record.Name) > -1)
            {
                colorclass = MAP_RESOURCE[folderMap[nodeData.Record.Name]].color;
            }

	        if(nodeData.Record.RecordType != null) {
                if(nodeData.Record.RecordType.Name == 'Grouping Entity')
                    colorclass = "slds-icon-standard-avatar-loading";
                if(nodeData.Record.RecordType.Name == 'Fund Selection Unit')
                    colorclass = "slds-icon-custom-custom14";
            }
        
            //Get the fields to be displayed for all objects along with the 'At Risk' field
            //if it's an Organisation_Relationship__c record, the name is an additional level down and need to get the right direction
            if (nodeData.Record.attributes.type == "RelatedCompany__c") {
                if(!(DRAWN_ACCOUNTS.indexOf(this.dig(nodeData.Record,MAP_RESOURCE[nodeData.Record.attributes.type].targetId[0])) > -1)) {
                    var targetId = (this.dig(nodeData.Record,MAP_RESOURCE[nodeData.Record.attributes.type].targetId[0]));
                    var targetName = (this.dig(nodeData.Record,MAP_RESOURCE[nodeData.Record.attributes.type].targetName[0]));
                }
                else  {
                    var targetId = (this.dig(nodeData.Record,MAP_RESOURCE[nodeData.Record.attributes.type].targetId[1]));
                    var targetName = (this.dig(nodeData.Record,MAP_RESOURCE[nodeData.Record.attributes.type].targetName[1]));
                }
            }
            else {
                var targetId = (this.dig(nodeData.Record,MAP_RESOURCE[nodeData.Record.attributes.type].targetId));
                var targetName = (this.dig(nodeData.Record,MAP_RESOURCE[nodeData.Record.attributes.type].targetName));
            }

            var atRisk = nodeData.Record[MAP_RESOURCE[nodeData.Record.attributes.type].targetAtRisk];

            strHTML += '<span class="slds-icon_container ' +  colorclass  + ' title="' + targetName + '">'
                        + '<img class="atsIcon" src="' + iconpath + '" style="height:20px;width:20px"/>'

                        +  '  <span class="slds-assistive-text">' + targetName + '</span>'
                    +  '</span>' + " ";

           // if we have an atRisk field and it's true, display the icon 
            if(atRisk) strHTML += '<span class="slds-icon_container' +  MAP_RESOURCE.AtRisk.color + ' '  + 'title="' + targetName + '">'
                        + '<img class="atsIcon" src="' + MAP_RESOURCE.AtRisk.icon  + '" style="height:20px;width:20px"/>'
                        +  '  <span class="slds-assistive-text">At Risk</span>'
                    +  '</span>';  


            // Name with or without LINK
            if (folderType != "") 
            {
                strHTML += ' ' + targetName;
                if (nodeData.children) strHTML += " (" + nodeData.children.length + ") ";
            }
            else {
                    // not recommended in Lightning but as a result were compensating in the helper 
                if(nodeData.Record.RecordType!=null) {
                    if(nodeData.Record.RecordType.Name != 'Grouping Entity')
						strHTML += ' <a href="/lightning/r/'+nodeData.Record.attributes.type+'/'+ targetId + '/view" target="_top" >';
                        //strHTML += ' <a id="recordId' + targetId + '" class="anchorNode" target="_top" data-recordId="' + targetId + '">';
                } else {
                    strHTML += ' <a href="/lightning/r/'+nodeData.Record.attributes.type+'/'+ targetId + '/view" target="_top" >';
                }
                strHTML += targetName;

                if(nodeData.Record.RecordType!=null) {
                    if(nodeData.Record.RecordType.Name != 'Grouping Entity')
                        strHTML += "</a>";
                } else {
                    strHTML += "</a>";
                }

                switch(nodeData.Record.attributes.type)
                {
                       case "Account":
                           if (nodeData.Record.Client_Tier__c) strHTML += " - " + nodeData.Record.Client_Tier__c;
                           strHTML += " [" + nodeData.Record.Owner.Name +"] ";
                           if (nodeData.Record.BillingCity) strHTML += "| " + nodeData.Record.BillingCity + " ";
                           if (nodeData.Record.AUMToDate__c) strHTML += "| " 
                           + MAP_CURRENCY[nodeData.Record.CurrencyIsoCode]  
                           + numeral(nodeData.Record.AUMToDate__c).format('0.0a') + " ";
                           break;
                       case "Opportunity":
                           strHTML += " (" + nodeData.Record.RecordType.Name + ") " 
                                    + "[" + nodeData.Record.StageName +"] | " + moment(nodeData.Record.CloseDate).format("MMM Do YYYY");
                           if (nodeData.Record.Amount)strHTML += " | Est. Amount: "   + numeral(nodeData.Record.Amount).format('0.0a') + " " ;
                           if (nodeData.Record.Revenue__c)strHTML += " | Est. Y1 Revenue: "  + numeral(nodeData.Record.Revenue__c).format('0.0a') + " " ; 
                           break;
                       case "Agreement_Role__c":
                           if (nodeData.Record.Role__c) strHTML += " (" + nodeData.Record.Role__c + ") ";
                           break;
                       case "Convention__c":
                           if (nodeData.Record.AUM__c) strHTML += " | " + numeral(nodeData.Record.AUM__c).format('0.0a') + " ";
                           break;
                       //case "Portfolio__c":
                       //    if (nodeData.Record.AUM__c) strHTML += " | " + numeral(nodeData.Record.AUM__c).format('0.0a') + " ";
                       //    break;
                       case "RelatedCompany__c":
                           if (nodeData.Record.Role__c) strHTML += " (" +nodeData.Record.Role__c + ") " ;
                           if (nodeData.Record.ThirdParty__r.BillingCity) strHTML += " | " +nodeData.Record.ThirdParty__r.BillingCity + " " ;
                           break;

                }

            }
            strHTML += " </span>";

            return strHTML;
    }
})