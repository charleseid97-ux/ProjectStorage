({
	init : function(component, event, helper) {
        var tier = component.get("v.GAMTier");
        if(tier == 'Titanium (Tier 0)'){
            component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier0_noinfo.png");
        }else if(tier == 'Platinum (Tier 1)'){
            component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier1_noinfo.png");
        }else if(tier == 'Gold (Tier 2)'){
            component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier2_noinfo.png");
        }else if(tier == 'Silver (Tier 3)'){
            component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier3_noinfo.png");
        }else if(tier == 'Bronze (Tier 4)'){
            component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier4_noinfo.png");
        }

	},
	closeComponent : function(component, event, helper) {
		component.set('v.viewTieringComponent', false);
	}
})