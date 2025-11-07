public class ProjectMatriceUtilities {
          public static List<ProductProjectSettings__c> getAllMatrice(){
          List<ProductProjectSettings__c> matriceRecords =[SELECT Id ,Name,  ProjectType__c,Stage__c, Order__c , Team__c  ,OrderTeam__c , RequiredFields__c , RequiredFieldsShareClass__c , NonRequiredFieldsFund__c , NonRequiredFieldsShareClass__c  FROM ProductProjectSettings__c where  ProjectType__c ='Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20) order by Order__c,OrderTeam__c   Asc  ];
          return matriceRecords;
          } 
          public static List<ProductProjectSettings__c> getmatriceByTeam(String teamName){
               List<ProductProjectSettings__c> matriceRecords =[SELECT Id , Team__c , RequiredFields__c , RequiredFieldsShareClass__c , NonRequiredFieldsFund__c , NonRequiredFieldsShareClass__c  FROM ProductProjectSettings__c   where  ProjectType__c ='Creation'  and Team__c= :teamName ];
               return matriceRecords;
          } 
          public static List<ProductProjectSettings__c> getmatriceByStep(String stepName){
          List<ProductProjectSettings__c> matriceRecords =[SELECT Id ,Name,  ProjectType__c,Stage__c, Order__c , Team__c  ,OrderTeam__c , RequiredFields__c , RequiredFieldsShareClass__c , NonRequiredFieldsFund__c , NonRequiredFieldsShareClass__c  FROM ProductProjectSettings__c where  ProjectType__c ='Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20) and  Stage__c = :stepName order by Order__c,OrderTeam__c   Asc  ];
          return matriceRecords;
          } 
          public static ProductProjectSettings__c getmatriceByTeamStep(String teamName , String stepName){
               ProductProjectSettings__c matriceRecord =[SELECT Id , Team__c ,Stage__c , RequiredFields__c , RequiredFieldsShareClass__c , NonRequiredFieldsFund__c , NonRequiredFieldsShareClass__c  FROM ProductProjectSettings__c   where  ProjectType__c ='Creation'  and Team__c= :teamName and Stage__c = :stepName limit 1];
               return matriceRecord;
          } 
          public static Map<String , List<String>> getAllRequiredFieldsSHCByStep(){
               Map<String, List<String>> stageToRequiredFields = new Map<String, List<String>>();
               for(ProductProjectSettings__c setting :[SELECT Stage__c, Order__c , Team__c , RequiredFieldsShareClass__c FROM ProductProjectSettings__c  where ProjectType__c ='Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20)  ORDER BY Order__c ASC]){
                    
                         String stage = setting.Stage__c; 
                         String requiredFieldsStr = setting.RequiredFieldsShareClass__c; 
                         // Initialiser la liste si le stage n'existe pas encore dans la map 
                         if (!stageToRequiredFields.containsKey(stage)) { stageToRequiredFields.put(stage, new List<String>()); } 
                         // Vérifier si RequiredFields__c n'est pas vide 
                         if (String.isNotBlank(requiredFieldsStr)) { 
                         // Convertir la chaîne de champs requis en liste 
                         List<String> requiredFieldsList = requiredFieldsStr.split(';'); 
                         // Ajouter chaque champ à la liste associée au stage en évitant les doublons 
                         for (String field : requiredFieldsList) { 
                              field = field.trim(); 
                              // Supprimer les espaces inutiles 
                              if (!stageToRequiredFields.get(stage).contains(field)) { 
                                   stageToRequiredFields.get(stage).add(field); 
                              } } } 
               }
               return stageToRequiredFields;
          } 
          public static Map<String , List<String>> getAllRequiredFieldsByStep(){
               Map<String, List<String>> stageToRequiredFields = new Map<String, List<String>>();
               for(ProductProjectSettings__c setting :[SELECT Stage__c, Order__c , Team__c , RequiredFields__c FROM ProductProjectSettings__c  where ProjectType__c ='Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20)  ORDER BY Order__c ASC]){ 
                    String stage = setting.Stage__c; 
                    String requiredFieldsStr = setting.RequiredFields__c; 
                    if (!stageToRequiredFields.containsKey(stage)) {
                         stageToRequiredFields.put(stage, new List<String>());
                    } 
                    if (String.isNotBlank(requiredFieldsStr)) { 
                         List<String> requiredFieldsList = requiredFieldsStr.split(';'); 
                         for (String field : requiredFieldsList) { 
                              field = field.trim(); 
                              if (!stageToRequiredFields.get(stage).contains(field)) { 
                                   stageToRequiredFields.get(stage).add(field); 
                              } 
                         } 
                    } 
               }
               return stageToRequiredFields;
          }

          public static Map<String , List<String>> getAllRequiredFieldsByStepShareclass(){
               Map<String, List<String>> stageToRequiredFields = new Map<String, List<String>>();
               for(ProductProjectSettings__c setting :[SELECT Stage__c, Order__c , Team__c , RequiredFieldsShareClass__c FROM ProductProjectSettings__c  where ProjectType__c = 'Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20)  ORDER BY Order__c ASC]){ 
                    String stage = setting.Stage__c; 
                    String requiredFieldsStr = setting.RequiredFieldsShareClass__c; 
                    if (!stageToRequiredFields.containsKey(stage)) {
                         stageToRequiredFields.put(stage, new List<String>());
                    } 
                    if (String.isNotBlank(requiredFieldsStr)) { 
                         List<String> requiredFieldsList = requiredFieldsStr.split(';'); 
                         for (String field : requiredFieldsList) { 
                              field = field.trim(); 
                              if (!stageToRequiredFields.get(stage).contains(field)) { 
                                   stageToRequiredFields.get(stage).add(field); 
                              } 
                         } 
                    } 
               }
               return stageToRequiredFields;
          }

          public static Map<String , String> getMapStepByField(String teamName){
               System.debug('teamName: ' + teamName);
               Map<String, String> stageToRequiredFields = new Map<String, String>();
               Sensitive_field__mdt fieldFund = Sensitive_field__mdt.getInstance('Fund');
               Sensitive_field__mdt fieldShareclass = Sensitive_field__mdt.getInstance('Share_Class');

               for(ProductProjectSettings__c setting :[SELECT Stage__c, Team__c, 
                                                       NonRequiredFieldsFund__c, RequiredFields__c, 
                                                       NonRequiredFieldsShareClass__c, RequiredFieldsShareClass__c 
                                                       FROM ProductProjectSettings__c  WHERE ProjectType__c = 'Creation' AND Team__c = :teamName ORDER BY Order__c ASC]){ 
                    String stage = setting.Stage__c;
                    String requiredFieldsStr;
                   
                    requiredFieldsStr = setting.RequiredFields__c + ';' + setting.RequiredFieldsShareClass__c + ';' + setting.NonRequiredFieldsShareClass__c +';'+ setting.NonRequiredFieldsFund__c;

                    System.debug('Team__c: ' + setting.Team__c);
                    if (String.isNotBlank(requiredFieldsStr)) { 
                         List<String> requiredFieldsList = requiredFieldsStr.split(';'); 
                         for (String field : requiredFieldsList) { 
                              field = field.trim();
                              stageToRequiredFields.put(field, stage);
                         } 
                    } 
               }
               return stageToRequiredFields;
          }

          
          public static Map<String , List<String>> getTeamwithNorequiredFieldsByStep (){
               Map<String, List<String>> teamNoRequiredFieldsByStep = new Map<String, List<String>>();
               for(ProductProjectSettings__c setting :[SELECT Stage__c, Order__c , Team__c , RequiredFields__c ,RequiredFieldsShareClass__c ,NonRequiredFieldsFund__c , NonRequiredFieldsShareClass__c  FROM ProductProjectSettings__c  where ProjectType__c ='Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20)  ORDER BY Order__c ASC]){
                    if(setting.RequiredFields__c == null && setting.RequiredFieldsShareClass__c == null && setting.NonRequiredFieldsFund__c == null && setting.NonRequiredFieldsShareClass__c == null) {
                         String stage = setting.Stage__c; 
                         if (!teamNoRequiredFieldsByStep.containsKey(stage)) { teamNoRequiredFieldsByStep.put(stage, new List<String>()); } 
                         if (!teamNoRequiredFieldsByStep.get(stage).contains(setting.Team__c)) { 
                              teamNoRequiredFieldsByStep.get(stage).add(setting.Team__c); 
                         }
                    }
               }
            return teamNoRequiredFieldsByStep;
          }


          public static Map<String , String> getAllRequiredAndNonRequiredFieldsByStepShareClass(){
               Map<String , String> stageToRequiredFields = new Map<String , String>();
               for(ProductProjectSettings__c setting :[SELECT Stage__c, Order__c , Team__c , RequiredFieldsShareClass__c , NonRequiredFieldsShareClass__c  
                                                       FROM ProductProjectSettings__c  where ProjectType__c ='Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20) ORDER BY Order__c ASC]){
                    
                    String stage = setting.Stage__c; 
                    String team = setting.Team__c; 
                    String requiredFieldsStr = setting.RequiredFieldsShareClass__c; 
                    String nonrequiredFieldsStr = setting.NonRequiredFieldsShareClass__c; 
                    // Initialiser la liste si le stage n'existe pas encore dans la map 
                    if (String.isNotBlank(requiredFieldsStr)) { 

                         for(String reqField : requiredFieldsStr.split(';')){
                              reqField = reqField.trim();
                              stageToRequiredFields.put(reqField,stage);
                         }
                    }
                    if (String.isNotBlank(nonrequiredFieldsStr)) { 

                         for(String reqField : nonrequiredFieldsStr.split(';')){
                              reqField = reqField.trim();
                              stageToRequiredFields.put(reqField,stage);
                         }
                    }
               }
               return stageToRequiredFields;
          }

          public static Map<String , String> getAllRequiredAndNonRequiredFieldsByTeamShareClass(){
               Map<String , String> stageToRequiredFields = new Map<String , String>();
               for(ProductProjectSettings__c setting :[SELECT Stage__c, Order__c , Team__c , RequiredFieldsShareClass__c , NonRequiredFieldsShareClass__c  
               FROM ProductProjectSettings__c  where ProjectType__c ='Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20) ORDER BY Order__c ASC]){
                    
                         String stage = setting.Stage__c; 
                         String team = setting.Team__c; 
                         String requiredFieldsStr = setting.RequiredFieldsShareClass__c; 
                         String nonrequiredFieldsStr = setting.NonRequiredFieldsShareClass__c; 
                         // Initialiser la liste si le stage n'existe pas encore dans la map 
                         if (String.isNotBlank(requiredFieldsStr)) { 
                              for(String reqField : requiredFieldsStr.split(';')){
                                   reqField = reqField.trim();
                                   stageToRequiredFields.put(reqField,team );
                              }

                         }
                         if (String.isNotBlank(nonrequiredFieldsStr)) { 

                              for(String reqField : nonrequiredFieldsStr.split(';')){
                                   reqField = reqField.trim();
                                   stageToRequiredFields.put(reqField,team );
                              }
                         }
               }
               return stageToRequiredFields;
          }

          public static Map<String , String> getAllRequiredAndNonRequiredFieldsByStepFund(){
               Map<String , String> stageToRequiredFields = new Map<String , String>();
               for(ProductProjectSettings__c setting :[SELECT Stage__c, Order__c , Team__c , RequiredFields__c , NonRequiredFieldsFund__c 
                                                       FROM ProductProjectSettings__c  where ProjectType__c ='Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20) ORDER BY Order__c ASC]){
                    
                    String stage = setting.Stage__c; 
                    String team = setting.Team__c; 
                    String requiredFieldsStr = setting.RequiredFields__c; 
                    String nonrequiredFieldsStr = setting.NonRequiredFieldsFund__c; 
                    // Initialiser la liste si le stage n'existe pas encore dans la map 
                    if (String.isNotBlank(requiredFieldsStr)) { 

                         for(String reqField : requiredFieldsStr.split(';')){
                              reqField = reqField.trim();
                              stageToRequiredFields.put(reqField,stage);
                         }
                    }
                    if (String.isNotBlank(nonrequiredFieldsStr)) { 

                         for(String reqField : nonrequiredFieldsStr.split(';')){
                              reqField = reqField.trim();
                              stageToRequiredFields.put(reqField,stage);
                         }
                    }
               }
               return stageToRequiredFields;
          }

          

          public static Map<String , String> getAllRequiredAndNonRequiredFieldsByTeamFund(){
               Map<String , String> stageToRequiredFields = new Map<String , String>();
               for(ProductProjectSettings__c setting :[SELECT Stage__c, Order__c , Team__c , RequiredFields__c , NonRequiredFieldsFund__c  
               FROM ProductProjectSettings__c  where ProjectType__c ='Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20) ORDER BY Order__c ASC]){
                    
                         String stage = setting.Stage__c; 
                         String team = setting.Team__c; 
                         String requiredFieldsStr = setting.RequiredFields__c; 
                         String nonrequiredFieldsStr = setting.NonRequiredFieldsFund__c; 
                         // Initialiser la liste si le stage n'existe pas encore dans la map 
                         if (String.isNotBlank(requiredFieldsStr)) { 
                              for(String reqField : requiredFieldsStr.split(';')){
                                   reqField = reqField.trim();
                                   stageToRequiredFields.put(reqField,team );
                              }

                         }
                         if (String.isNotBlank(nonrequiredFieldsStr)) { 

                              for(String reqField : nonrequiredFieldsStr.split(';')){
                                   reqField = reqField.trim();
                                   stageToRequiredFields.put(reqField,team );
                              }
                         }
               }
               return stageToRequiredFields;
          }

     public static Map<String , Map<String , List<String>>> getAllRequiredAndNonRequiredFieldsByStepandTeam(){
          Map<String , Map<String , List<String>>> stageToRequiredFields = new Map<String , Map<String , List<String>>>();
          for(ProductProjectSettings__c setting :[SELECT Stage__c, Order__c , Team__c , RequiredFields__c , NonRequiredFieldsFund__c 
          FROM ProductProjectSettings__c  where ProjectType__c ='Creation' AND OrderTeam__c NOT IN (15, 16, 17, 18, 19, 20)  ORDER BY Order__c ASC]){
               
                    String stage = setting.Stage__c; 
                    String team = setting.Team__c; 
                    String requiredFieldsStr = setting.RequiredFields__c; 
                    String nonrequiredFieldsStr = setting.NonRequiredFieldsFund__c; 
                    // Initialiser la liste si le stage n'existe pas encore dans la map 
                    if (!stageToRequiredFields.containsKey(stage)) { stageToRequiredFields.put(stage, new Map<String , List<String>>()); } 
                    if (!stageToRequiredFields.get(stage).containsKey(team)) { stageToRequiredFields.get(stage).put(team, new List<String>()); }
              List<String> requiredFieldsList=new List<String>();  
               List<String> nonrequiredFieldsList=new List<String>(); 
              // Vérifier si RequiredFields__c n'est pas vide 
                    if (String.isNotBlank(requiredFieldsStr)) { 
                        // Convertir la chaîne de champs requis en liste 
                        requiredFieldsList = requiredFieldsStr.split(';'); }
              if(String.isNotBlank(nonrequiredFieldsStr)){
                  nonrequiredFieldsList = nonrequiredFieldsStr.split(';'); }
                        List<String> allFields= new List<String>();
                        allFields.addAll(requiredFieldsList);
                        allFields.addAll(nonrequiredFieldsList);
                        // Ajouter chaque champ à la liste associée au stage en évitant les doublons 
                        for (String field : allFields) { 
                             field = field.trim(); 
                             // Supprimer les espaces inutiles 
                             if (!stageToRequiredFields.get(stage).get(team).contains(field)) { 
                                  stageToRequiredFields.get(stage).get(team).add(field); 
                             } }  
          }
          return stageToRequiredFields;
     }
}