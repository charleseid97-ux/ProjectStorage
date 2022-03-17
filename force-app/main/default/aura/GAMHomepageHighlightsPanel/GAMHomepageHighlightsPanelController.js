({
	init : function(component, event, helper) {
        var currGAMHomepage = ({"Name":""});
        component.set("v.GAMHomepage", currGAMHomepage);
        var currGAMAccount = ({"Name":"", "Id":""});
        component.set("v.GAMAccount", currGAMAccount);
        var currGAMStrategicNews = ({"Name":"", "Id":""});
        component.set("v.GAMStrategicNews", currGAMStrategicNews);
        
        helper.getCurrentGAMHomepage(component);
        helper.getCurrentGAMAccount(component);
	}
})