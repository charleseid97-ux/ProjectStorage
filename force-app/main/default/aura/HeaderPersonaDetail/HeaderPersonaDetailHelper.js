({
    checkPersona: function(component) {
        var contactId = component.get("v.recordId");
        var personaAction = component.get("c.getContactPersona");
        personaAction.setParams({
            "contactId": contactId            
        });

        personaAction.setCallback(this, function(response){
            var status = response.getState();
            if (status === 'SUCCESS') {
               
                var persona = response.getReturnValue();

                if (persona != null){
                    component.set("v.personaExists", "true");
                    component.set("v.personaName", persona);
                    
                    if(persona == 'B2B Buyer'){
                        component.set("v.personaImage", "/resource/Personas/b2b_buyer.png");
                        component.set("v.personaDetail", "Distribution Partner: Fund Selector, Other Wealth Managers and Execution & Advisory Platform");
                    }else if(persona == 'Front Line Adviser'){
                        component.set("v.personaImage", "/resource/Personas/fl_adviser.png");
                        component.set("v.personaDetail", "Distribution Partner: IFA, Network (IFA, Bank, Insurance), Bank (Private, Retail, Online), Robo-Advisor");
                    }else if(persona == 'Institutional'){
                        component.set("v.personaImage", "/resource/Personas/i_buyer.png");
                        component.set("v.personaDetail", "Proprietary Desk, Single Family Office, Other Institutions, Institutional Consultant");
                    }else if(persona == 'Support Function'){
                        component.set("v.personaImage", "/resource/Personas/s_function.png");
                        component.set("v.personaDetail", "Funds / Partnership Coordination: Legal/Finance, Investor services, Marketing and Comms, Execution-Only Platform, Reporting/MI, Regulatory/Compliance, Client Delivery (RFI).");
                    }else if(persona == 'End Investor'){
                        component.set("v.personaImage", "/resource/Personas/e_investor.png");
                        component.set("v.personaDetail", "Retail, Pension scheme member, Investor in wrapped product ");
                    }else if(persona == 'Private Investor'){
                        component.set("v.personaImage", "/resource/Personas/p_investor.png");
                        component.set("v.personaDetail", "HNWI (High Net Worth Individuals), UHNWI (Ultra High Net Worth Individuals) ");
                    }
                }
            }
        });
        $A.enqueueAction(personaAction);
    }
})