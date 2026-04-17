public class ChatterGroupService {
    
        public static List<Id> createGroupWithMembers(Map<String, List<Id>> groupsMap, String description) {
            List<CollaborationGroup> groupsToInsert = new List<CollaborationGroup>();
            Map<String, List<Id>> groupNameToMembers = new Map<String, List<Id>>();
            
            for (String groupName : groupsMap.keySet()) {
            if (String.isBlank(groupName) || groupsMap.get(groupName).isEmpty()) continue;
            
            CollaborationGroup newGroup = new CollaborationGroup();
            newGroup.Name = groupName;
            newGroup.CollaborationType = 'Public';
            newGroup.Description = description;
            // newGroup.MemberVisibility = 'AllUsers'; // optionnel
            groupsToInsert.add(newGroup);
            
            groupNameToMembers.put(groupName, groupsMap.get(groupName));
            }
            
            // DML pour tous les groupes d’un coup
            insert groupsToInsert;
            
            // Associer les IDs des groupes aux noms
            Map<String, Id> nameToGroupId = new Map<String, Id>();
            List<Id> groupsId= new List<Id>();
            for (CollaborationGroup g : groupsToInsert) {
            nameToGroupId.put(g.Name, g.Id);
                groupsId.add(g.Id);
            }
            
            // Construction des membres à insérer
            List<CollaborationGroupMember> membersToInsert = new List<CollaborationGroupMember>();
            for (String name : groupNameToMembers.keySet()) {
            Id groupId = nameToGroupId.get(name);
            for (Id userId : groupNameToMembers.get(name)) {
            CollaborationGroupMember m = new CollaborationGroupMember();
            m.CollaborationGroupId = groupId;
            m.MemberId = userId;
            membersToInsert.add(m);
            }
            }
            
            // DML bulk pour tous les membres
            insert membersToInsert;
            return groupsId;
        }

    
    /**
     * Méthode pour créer un groupe Chatter public et ajouter des membres
     * @param groupName Nom du groupe
     * @param description Description du groupe
     * @param memberIds Liste des IDs des utilisateurs à ajouter comme membres
     * @return ID du groupe créé
     */
    /*
    public static void createGroupWithMembersT(String groupName, String description, List<Id> memberIds) {
        try {
            // Vérifie si un groupe avec le même nom existe déjà
            List<CollaborationGroup> existingGroups = [SELECT Id FROM CollaborationGroup WHERE Name = :groupName LIMIT 1];
            if (!existingGroups.isEmpty()) {
                //throw new Exception('Un groupe avec ce nom existe déjà.');
            }
            // Création du groupe Chatter
            CollaborationGroup newGroup = new CollaborationGroup();
            newGroup.Name = groupName;
            newGroup.CollaborationType = 'Public'; // Groupe public
            newGroup.Description = description;
            //newGroup.MemberVisibility = 'AllUsers'; // Visible pour tous
            insert newGroup;

            // Ajout des membres au groupe
            if (memberIds != null && !memberIds.isEmpty()) {
                List<CollaborationGroupMember> groupMembers = new List<CollaborationGroupMember>();
                for (Id memberId : memberIds) {
                    CollaborationGroupMember member = new CollaborationGroupMember();
                    member.CollaborationGroupId = newGroup.Id;
                    member.MemberId = memberId;
                    member.NotificationFrequency = 'P';
                    groupMembers.add(member);
                }
                insert groupMembers; // Insère tous les membres en une seule opération
            }

            // Retourner l'ID du groupe créé
            //return newGroup.Id;

        } catch (Exception e) {
            // Gestion des erreurs
            System.debug('Erreur lors de la création du groupe ou de l\'ajout des membres : ' + e.getMessage());
            throw new AuraHandledException('Erreur : ' + e.getMessage());
        }
    }*/
    
    public static void updateGroupMemberNotifications(List<Id> groupsId, String notificationFrequency) { 
        try { // Vérification des paramètres 
            List<CollaborationGroupMember> groupMembers = [ SELECT Id, MemberId, CollaborationGroupId, NotificationFrequency FROM CollaborationGroupMember WHERE CollaborationGroupId IN :groupsId ]; 
            // Mettre à jour la fréquence des notifications pour chaque membre 
            for (CollaborationGroupMember member : groupMembers) { 
                member.NotificationFrequency = notificationFrequency;
            } // Effectuer la mise à jour en base
            if (!groupMembers.isEmpty()) { 
                update groupMembers; 
            } else { 
                System.debug('Aucun membre trouvé dans le groupe avec l\'ID : ' + groupsId);
            } 
            System.debug('Notifications mises à jour pour le groupe : ' + groupsId);
        } catch (IllegalArgumentException e) { 
            System.debug('Erreur de paramètre : ' + e.getMessage());
            throw new AuraHandledException('Erreur de paramètre : ' + e.getMessage()); 
        } catch (Exception e) {
           System.debug('Erreur générale lors de la mise à jour : ' + e.getMessage()); 
           throw new AuraHandledException('Erreur lors de la mise à jour des notifications : ' + e.getMessage());
        } 
    } 
}