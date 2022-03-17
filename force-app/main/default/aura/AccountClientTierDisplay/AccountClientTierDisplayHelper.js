({
    checkClientTier: function(component) {
        var accId = component.get("v.recordId");
        var checkClientTierAction = component.get("c.confirmClientTier");
        checkClientTierAction.setParams({
            "accId": accId            
        });

        checkClientTierAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
                debugger;
                var result = response.getReturnValue();
                var clientTier = result.Client_Tier__c;
                var UPTier = result.Ultimate_Parent_Tier__c;
                component.set('v.tierLevel', UPTier);
                if(result.Ultimate_Parent_Tier__c != null){
                    component.set("v.clientTierExists", "true");
                    if(result.Ultimate_Parent_Tier__c == 'Titanium (Tier 0)'){
                        component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier0_noinfo.png");
                    }else if(result.Ultimate_Parent_Tier__c == 'Platinum (Tier 1)'){
                        component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier1_noinfo.png");
                    }else if(result.Ultimate_Parent_Tier__c == 'Gold (Tier 2)'){
                        component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier2_noinfo.png");
                    }else if(result.Ultimate_Parent_Tier__c == 'Silver (Tier 3)'){
                        component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier3_noinfo.png");
                    }else if(result.Ultimate_Parent_Tier__c == 'Bronze (Tier 4)'){
                        component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier4_noinfo.png");
                    }
                } else if (result.Client_Tier__c != null){
                    component.set("v.clientTierExists", "true");
                    if(result.Client_Tier__c == 'Titanium (Tier 0)'){
                        component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier0_noinfo.png");
                    }else if(result.Client_Tier__c == 'Platinum (Tier 1)'){
                        component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier1_noinfo.png");
                    }else if(result.Client_Tier__c == 'Gold (Tier 2)'){
                        component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier2_noinfo.png");
                    }else if(result.Client_Tier__c == 'Silver (Tier 3)'){
                        component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier3_noinfo.png");
                    }else if(result.Client_Tier__c == 'Bronze (Tier 4)'){
                        component.set("v.clientTierImage", "/resource/ClientTiers/ClientTier4_noinfo.png");
                    }
                }
            }
        });
        $A.enqueueAction(checkClientTierAction);
    }
})