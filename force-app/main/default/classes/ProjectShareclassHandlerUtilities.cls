public class ProjectShareclassHandlerUtilities {
    static public Map<Id, ProjectProduct__c> getMapProjectProductByProjectProductId(List<ProjectShareclass__c> projectShareclasses) {
        Map<Id, ProjectProduct__c> mapProjectProductByProjectProductId = new Map<Id, ProjectProduct__c>();
        Set<Id> projectProductIds = getProjectProductIdFromShareclasses(projectShareclasses);

        for (ProjectProduct__c projectProduct : [SELECT Id, Name, ProductName__c FROM ProjectProduct__c WHERE Id IN :projectProductIds]) {
            mapProjectProductByProjectProductId.put(projectProduct.Id, projectProduct);
        }

        if (!mapProjectProductByProjectProductId.isEmpty()) {
            return mapProjectProductByProjectProductId;
        }

        return null;
    }

    //CurrencyHedging__c TRUE Ajouter  "Hdg" à la fin  SINON FALSE Ne rien ajouter
    static public String getCurrencyHedging(ProjectShareclass__c projectShareclass) {
        if (projectShareclass.CurrencyHedging__c == 'True') {
            return 'Hdg';
        }
        return '';
    }

    static public String getDistributionCode(ProjectShareclass__c projectShareclass) {
        if (projectShareclass.DividendPolicy__c == 'Accumulating') {
            return 'Acc';
        } else if (projectShareclass.DividendPolicy__c == 'Distributing') {
            switch on projectShareclass.DividendFrequency__c {
                when 'Monthly' {
                    return 'Mdis';
                }
                when 'Quarterly' {
                return 'Qdis';
                }
                when 'SemiAnnually' {
                    return 'Sdis';
                }
                when 'Annually' {
                    return 'Ydis';
                }
            }
        } 
        return '';
    }

    public static List<ProjectShareclass__c> getProjectShareclassWithUpdatedNamingField(Map<Id, ProjectShareclass__c> newProjectShareclass, Map<Id, ProjectShareclass__c> oldProjectShareclass) {
        List<ProjectShareclass__c> projectShareclassToUpdate = new List<ProjectShareclass__c>();
    
        for (ProjectShareclass__c projectShareclass : newProjectShareclass.values()) {
            if (projectShareclass.Type__c != oldProjectShareclass.get(projectShareclass.Id).Type__c ||
                projectShareclass.CurrencyIsoCode != oldProjectShareclass.get(projectShareclass.Id).CurrencyIsoCode ||
                projectShareclass.DividendPolicy__c != oldProjectShareclass.get(projectShareclass.Id).DividendPolicy__c ||
                projectShareclass.DividendFrequency__c != oldProjectShareclass.get(projectShareclass.Id).DividendFrequency__c ||
                projectShareclass.CurrencyHedging__c != oldProjectShareclass.get(projectShareclass.Id).CurrencyHedging__c)
            {
                projectShareclassToUpdate.add(projectShareclass); 
            }
        }

        if (!projectShareclassToUpdate.isEmpty()) {
            return projectShareclassToUpdate;
        }
        return null;
    }

    public static List<ProjectShareclass__c> getProjectShareclasses(List<ProjectShareclass__c> projectShareclasses) {
        List<ProjectShareclass__c> projectShareclassCopy = [SELECT Id, Type__c, CurrencyIsoCode, DividendPolicy__c, DividendFrequency__c, CurrencyHedging__c, ProjectProduct__c
                                                            FROM ProjectShareclass__c 
                                                            WHERE Id IN :projectShareclasses];
        if (projectShareclassCopy.isEmpty()) {
            return null;
        }
        return projectShareclassCopy;
    }

    /*************/
    /** PRIVATE **/
    /*************/
    static private Set<Id> getProjectProductIdFromShareclasses(List<ProjectShareclass__c> projectShareclasses) {
        Set<Id> setProjectProductId = new Set<Id>();

        for (ProjectShareclass__c projectShareclass : projectShareclasses) {
            setProjectProductId.add(projectShareclass.ProjectProduct__c);
        }

        if (!setProjectProductId.isEmpty()) {
             return setProjectProductId;
        }
        return null;
    }
}