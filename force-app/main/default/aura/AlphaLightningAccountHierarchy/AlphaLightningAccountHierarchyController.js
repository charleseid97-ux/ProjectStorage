/**************************************************************************************
*  @Author Ragnar Rahuoja
*
*   Date 13/01/2018
*
* Account Hierarchy Lightning Component Controller class
*
* First build
* 07/02/18 RR - DRAWN_ACCOUNTS now instantiated in init function
*
**************************************************************************************/

({

  init : function(component, event, helper) {
      var action = component.get("c.getStructureAsJSON");
        var sldsPath = $A.get('$Resource.SLDSATS');

      	var recordId = component.get("v.recordId");
      	var GAMId = component.get("v.GAMId");
        if(recordId == null)
            recordId = GAMId
            
      action.setParams({
            currentId : recordId
        });
        action.setCallback(this, function(a) {

            var result = JSON.parse(a.getReturnValue());
            var $j = jQuery.noConflict();

            //Need to store all drawn accounts to determine the direction of the Org Relationship
            var DRAWN_ACCOUNTS = [ ];

            document.getElementById("treeContainer").innerHTML = helper.buildList(result, DRAWN_ACCOUNTS, component);

            var onclickHandler = component.getReference("c.navigateToSObjectRecord");

            $j(".anchorNode").click(function(event){
            var sObjectEvent = $A.get("e.force:navigateToSObject");

            var targetEvent = event.target;

            var targetId = $j(targetEvent).attr("data-recordId");

            sObjectEvent.setParams({
                "recordId": targetId
            });
            sObjectEvent.fire();
            });
            //expand to show the current sobject in the tree
            $j("#" + recordId).parents("ul").show();
            // OPTION 1 expand the current node to show its children
            $j("#" + recordId).children("ul").show();
            var temp = $j("#" + recordId);

            // OPTION 2 expand the current node's descendants to show its children, grandchildren, yada yada
            //COMMENTED OUT FOR GAM CONTRACTION
            //$j("#" + recordId).find("ul").show();

            //highlight the current node...
            $j("#" + recordId).children("span.displayLine").addClass("currentRecord");

            //scroll to it...

            //set up an action to highlight a section of the list when you mouse over its leader
            $j(".control").hover(function(){
                $j(this).closest("li").toggleClass("hierarchyHighlightHover");
            });

            //set up the click action
            $j(".control").click(function(){
                $j(this).closest("span.displayLine").siblings("ul").slideToggle();
            });
        });

      $A.enqueueAction(action);
   },
    
    expandAll : function(component, event, helper) {
        var recordId = component.get("v.recordId");
        var $j = jQuery.noConflict();
        $j("#" + recordId).find("ul").show();
        component.set("v.expanded", true);
    },

    collapseAll : function(component, event, helper) {
        var recordId = component.get("v.recordId");
        var $j = jQuery.noConflict();
        
        $j("#" + recordId).find("ul").hide();
        
        //expand to show the current sobject in the tree
        $j("#" + recordId).parents("ul").show();
        // OPTION 1 expand the current node to show its children
        $j("#" + recordId).children("ul").show();
        var temp = $j("#" + recordId);
        component.set("v.expanded", false);
    },

   // deletes the component from DOM so it can be re-rendered after navigation
   destroyCmp : function (component, event, helper) {
       component.destroy();
   },

   onJqueryLoad : function(component, event, helper) {
       debugger;
       var recordId = component.get("v.recordId");

   }
})