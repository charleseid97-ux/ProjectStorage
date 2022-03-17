({
    //helpter load data 
    loadData : function(component, firstTry) {
        //load action
        var action = firstTry ? component.get("c.loadGlobalBuyList") : component.get("c.loadIndependentBuyList");
        //set parameters action
   
        var VFRec = component.get('v.VFRecordId');
        
        if(component.get('v.VFRecordId') != null && component.get('v.VFRecordId') != '')
            component.set('v.recordId', component.get('v.VFRecordId'));
       
        var objName = component.get("v.objectName");
        var pName = component.get("v.parentId");
        var recId = component.get("v.recordId");
        var sObjectType = component.get("v.sObjectType");
        var recordIdOverride = component.get("v.recordIdOverride");
   
        action.setParams({ objectName : component.get("v.objectName"), parentName : component.get("v.parentId"),
                          recordId : component.get("v.recordId"),sObjectType : sObjectType, recordIdOverride : recordIdOverride});
        
        var that = this;
        //set callback action
    
	        action.setCallback(this, function(response) {
            //test if state is seccess
            if(component.isValid() && response.getState() === "SUCCESS") {
                //get server data

                var result = response.getReturnValue();
                var data = result.data;
                var editAccess = result.editAccess;
                var deleteAccess = result.deleteAccess;
                var allData = result.allData;
                var allEditAccess = result.allEditAccess;
                var allDeleteAccess = result.allDeleteAccess;
                
                if(allData.length != 0) {
                    //parsing data
                    for(var i = 0; i < data.length; i ++) {
                        data[i].editAccess = (editAccess.indexOf(data[i].Id) > -1 ? true: false);
                        data[i].deleteAccess = (deleteAccess.indexOf(data[i].Id) > -1 ? true: false);
                        //get field name
                        var keys = Object.keys(data[i]);
                        for(var j = 0; j < keys.length; j ++) {
                            try {
                                //test if field is object (relationship)
                                if(data[i][keys[j]] instanceof Object) {
                                    //update data to be showing in table
                                    data[i][keys[j]+'NameLabel'] = data[i][keys[j]].Name;
                                    data[i][keys[j]+'Name'] = '/' + data[i][keys[j]].Id;
                                }
                            }catch(e){}
                        }
                    }
                    
                    //parsing allData
                    for(var i = 0; i < allData.length; i ++) {
                        allData[i].allEditAccess = (allEditAccess.indexOf(allData[i].Id) > -1 ? true: false);
                        allData[i].allDeleteAccess = (allDeleteAccess.indexOf(allData[i].Id) > -1 ? true: false);
                        //get field name
                        var keys = Object.keys(allData[i]);
                        for(var j = 0; j < keys.length; j ++) {
                            try {
                                //test if field is object (relationship)
                                if(allData[i][keys[j]] instanceof Object) {
                                    //update allData to be showing in table
                                    allData[i][keys[j]+'NameLabel'] = allData[i][keys[j]].Name;
                                    allData[i][keys[j]+'Name'] = '/' + allData[i][keys[j]].Id;
                                }
                            }catch(e){}
                        }
                    }
                    
                    var columns = result.columns;
                    //Boolean is not supported by datatable component that why we transform it on yes no
                    for(var i = 0; i < columns.length; i ++) {
                        if(columns[i].type == 'boolean') {
                            for(var j = 0; j < data.length; j ++) {
                                
                                data[j][columns[i].fieldName] = (data[j][columns[i].fieldName] ? 'YES' :'NO');
                                columns[i].type = 'text';
                            }
                        }
                    }
                    
                    var columnsAll = result.columnsAll;
                    //Boolean is not supported by datatable component that why we transform it on yes no
                    for(var i = 0; i < columnsAll.length; i ++) {
                        if(columnsAll[i].type == 'boolean') {
                            for(var j = 0; j < allData.length; j ++) {
                                
                                allData[j][columnsAll[i].fieldName] = (allData[j][columnsAll[i].fieldName] ? 'YES' :'');
                                columnsAll[i].type = 'text';
                            }
                        }
                    }
                    
                    //set data in component
                    component.set("v.dataResult", data);
                    component.set("v.dataDisplay", allData);
                    component.set("v.deleteAccess",  deleteAccess);
                    component.set("v.editAccess", editAccess);
                    component.set("v.allDeleteAccess",  allDeleteAccess);
                    component.set("v.allEditAccess", allEditAccess);
                    
                    
                    var actions = that.getRowActions.bind(this, component);
                    result.columns.push({ type: 'action', typeAttributes: { rowActions: actions } });
                    result.columnsAll.push({ type: 'action', typeAttributes: { rowActions: actions } });
                    
                    component.set("v.columnsResult", result.columns);
                    component.set("v.columnsResultAll", result.columnsAll);
                    that.loadFormaterData(component);
                } else {
                    component.set("v.probablyIndependent", true);
                    if(firstTry) 
                   		this.loadData(component, false);
                }
                
            }
        });
        //invoke request 
        $A.enqueueAction(action);
    },
    //Helper sort data
    sortData: function (cmp, fieldName, sortDirection, dataKey) {
        //get data from component
        var data = cmp.get("v." + dataKey);
        //define direction sort
        var reverse = sortDirection !== 'asc';
        //sort data
        data.sort(this.sortBy(fieldName, reverse));
        //set data in component
        cmp.set("v." + dataKey, data);
    },
    //define condition sorting
    sortBy: function (field, reverse, primer) {
        //get sorting field
        var key = primer ? function(x) {return primer(x[field])} : function(x) {return x[field]};
        //reverse direction sort
        reverse = !reverse ? 1 : -1;
        //Condition defined by sorting
        return function (a, b) {
            var a1 = key(a);
            var b1 = key(b);
            return reverse * ((a1 > b1) - (b1 > a1));
        }
    },
    //Helper filter data
    filterData : function(cmp) {
        //get data
        var data =  cmp.get("v.dataResult");
        //get text rearching
        var searchtext =  cmp.get("v.textSearch");
        var resultFilter = [];
        //Parsing data
        for(var i = 0; i < data.length; i ++) {
            //get fields name
            var keys = Object.keys(data[i]);
            for(var j = 0; j < keys.length; j ++) {
                try {
                    //test if serching text in data
                    if(data[i][keys[j]].toString().toLowerCase().indexOf(searchtext.toLowerCase()) >= 0) {
                        //Add row in result
                        resultFilter.push(data[i]);
                        break;
                    }
                }catch(e){}
            }
        }
        //set data in component
        cmp.set("v.dataDisplay",resultFilter);
    },
    
    //Load data section from all data
    loadFormaterData : function(component) {
		var dataList = [];
        var data = component.get('v.dataResult');
        var columns = component.get('v.columnsResult');
        var maxdefined = (component.get('v.maxItemDisplay') != null ? component.get('v.maxItemDisplay'): 2);
        var maxItem = (data.length > maxdefined ? maxdefined : data.length);
        for(var i = 0; i < maxItem; i ++) {
        	
            var currentObject = {editAccess :data[i].editAccess , deleteAccess : data[i].deleteAccess, Id : data[i].Id, hasLocal : data[i].Local_Buy_List_Items__c};
            currentObject.data = [];
            for(var j = 0; j < columns.length; j ++) {
            	if( columns[j].type == 'action') {
	        		continue;
	            }
                try {
                // if it is lookup
                if(columns[j].type == 'url'){
                	currentObject.data.push({label : columns[j].label, link : data[i][columns[j].fieldName], value : data[i][columns[j].fieldName + 'Label'], type : columns[j].type});
                }else{
                	currentObject.data.push({label : columns[j].label, value : data[i][columns[j].fieldName], type : columns[j].type});
                }
                    
                } catch(e) {}
                
            }
            dataList.push(currentObject);
        }
       
        component.set('v.dataFormatter', dataList);
        
        
	},
	//get dynamic menu list
	 getRowActions: function (cmp, row, doneCallback) {
        var actions = [];
         if(row.allEditAccess)   {
             actions.push({
                 'label': 'Edit',
                 'name': 'Edit'
             });
         }
         if(row.allDeleteAccess)   {
             actions.push({
                 'label': 'Delete',
                 'name': 'Delete'
             });
         }
         if(row.Local_Buy_List_Items__c == "YES") {
             actions.push({
                 'label': 'View Local Status',
                 'name': 'ViewLocal'
             });
         }
        setTimeout($A.getCallback(function () {
            doneCallback(actions);
        }), 1);
    },
    //edit record 
    editRecord : function(component, recordId) {
        if( component.get("v.customCreationManagement")) {
            this.loadCustomCreationManager(component, "EDIT", recordId);
            return;
        }
    	var editRecordEvent = $A.get("e.force:editRecord");
    	editRecordEvent.setParams({
    		"recordId": recordId
    	});
    	editRecordEvent.fire();
    },
    //delete record
    deleteRecord : function(cmp, recordId) {
	    if (!confirm('Are you sure you want to delete this record ?')) {
	    	return;
	    }
    	var action = cmp.get("c.deleteGlobalCtrl");
	    action.setParams({ 
	        "recordId": recordId,
	        "objectName" : cmp.get("v.objectName")
	    });
	    var that = this;
	    action.setCallback(this, function(response) {
	        var state = response.getState();
	        if (state === "SUCCESS") {
	           var toastEvent = $A.get("e.force:showToast");
			    toastEvent.setParams({
			        "title": "Success!",
			        "message": "The record has been deleted successfully."
			    });
			    toastEvent.fire();
			    
			      $A.get('e.force:refreshView').fire();
	        }
	    });
	    $A.enqueueAction(action);
    },
    viewRecord : function(cmp, recordId){
    var sObejctEvent = $A.get("e.force:navigateToSObject");
        sObejctEvent .setParams({
        "recordId": recordId
      });
      sObejctEvent.fire();   
    },
    loadCustomCreationManager : function(component, mode, objectId) {
        $A.createComponent(
            "c:" + component.get('v.creationComponentName'),
            {
                parentObjectId: component.get('v.recordId'),
                sObjectType: component.get("v.sObjectType"),
                mode : mode,
                currentObjectId: objectId,
                viewCustomObjectManagement : true,
                
                "parentId": component.get('v.parentId')
            },
            function(creationComponent, status, errorMessage){
                if (status === "SUCCESS") {
                    
                    component.set("v.creationComponent", creationComponent);
                    component.set('v.preview', true);
                }
                else if (status === "INCOMPLETE") {
                    console.log("No response from server or client is offline.")
                    // Show offline error
                }
                    else if (status === "ERROR") {
                        console.log("Error: " + errorMessage);
                        // Show error message
                    }
            }
        );
    },
    loadCustomView : function(component,mode, objectId) {
        $A.createComponent(
            "c:" + component.get('v.viewComponentName'),
            {
                parentObjectId: component.get('v.recordId'),
                sObjectType: component.get("v.sObjectType"),
                mode : 'EDIT',
                currentObjectId: objectId,
                viewCustomObjectManagement : true,
                "parentId": component.get('v.parentId')
            },
            function(viewComponent, status, errorMessage){
                if (status === "SUCCESS") {
                    component.set("v.viewComponent", viewComponent);
                    component.set('v.preview', true);
                }
                else if (status === "INCOMPLETE") {
                    console.log("No response from server or client is offline.")
                    // Show offline error
                }
                    else if (status === "ERROR") {
                        console.log("Error: " + errorMessage);
                        // Show error message
                    }
            }
        );
    },
    //manager event
    eventManager : function(cmp, event, recordId) {
        switch (event) { 
            case 'Edit':
                this.editRecord(cmp, recordId);
                break;
            case 'Delete':
                this.deleteRecord(cmp, recordId);
                break;
            case 'View':
                this.viewRecord(cmp, recordId);
                break;
            case 'ViewLocal':
                this.loadCustomView(cmp, 'EDIT', recordId);
        }
    }
})