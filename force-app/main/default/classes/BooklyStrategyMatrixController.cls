public without sharing class BooklyStrategyMatrixController {
    public List<RowWrapper> rows { get; set; }
    public String userSearchText { get; set; }
    public String selectedUsername { get; set; }
    public String selectedStrategyCode { get; set; }
    public List<UserOption> userOptions { get; set; }
    public List<RowWrapper> matrixUsers { get; set; }
    public List<MatrixStrategyWrapper> matrixStrategies { get; set; }
    private static final String STRATEGY_SEPARATOR = ';';
    private static final String USERNAME_PARAMETER = 'username';
    private static final String STRATEGY_CODE_PARAMETER = 'strategyCode';
    
    // Initialise la matrice au chargement de la page.
    public BooklyStrategyMatrixController() {
        rows = new List<RowWrapper>();
        userOptions = new List<UserOption>();
        matrixUsers = new List<RowWrapper>();
        matrixStrategies = new List<MatrixStrategyWrapper>();
        loadRows();
    }

    // Charge les mappings User / Strategies depuis le custom metadata.
    private void loadRows() {
        rows.clear();

        Map<String, User> usersByUsername = loadUsersByUsername();
        Map<String, Strategy__c> strategiesByCode = loadStrategiesByCode();

        for (BooklyStrategiesByUsers__mdt mapping : [
            SELECT DeveloperName, MasterLabel, Username__c, StrategyCodes__c, IsActive__c
            FROM BooklyStrategiesByUsers__mdt
            WHERE Username__c != null
            AND IsActive__c = true
            ORDER BY Username__c
        ]) {
            User userRecord = usersByUsername.get(mapping.Username__c);
            String displayName = userRecord == null ? mapping.Username__c : userRecord.Name;

            // Transforme les codes stockés en stratégies affichables.
            rows.add(
                new RowWrapper(
                    mapping.DeveloperName,
                    mapping.Username__c,
                    displayName,
                    buildStrategyWrappers(mapping.StrategyCodes__c, strategiesByCode)
                )
            );
        }

        // Reconstruit la matrice affichée sous la table principale.
        buildStrategyUserMatrix(strategiesByCode);
    }

    // Charge les utilisateurs utilisés par les mappings existants.
    private Map<String, User> loadUsersByUsername() {
        Set<String> usernames = new Set<String>();

        for (BooklyStrategiesByUsers__mdt mapping : [
            SELECT Username__c
            FROM BooklyStrategiesByUsers__mdt
            WHERE Username__c != null
            AND IsActive__c = true
        ]) {
            usernames.add(mapping.Username__c);
        }

        Map<String, User> result = new Map<String, User>();

        if (usernames.isEmpty()) {
            return result;
        }

        // Récupère le nom Salesforce à afficher dans la matrice.
        for (User userRecord : [
            SELECT Id, Name, Username
            FROM User
            WHERE Username IN :usernames
        ]) {
            result.put(userRecord.Username, userRecord);
        }

        return result;
    }

        // Charge toutes les stratégies autorisées pour la matrice.
    private Map<String, Strategy__c> loadStrategiesByCode() {
        Map<String, Strategy__c> result = new Map<String, Strategy__c>();

        List<String> strategyCodes = System.Label.BooklyInScopeStrategy.split(',');

        Set<Id> strategyIds = new Set<Id>();

        // Récupère les stratégies utilisées par les fonds valides.
        for (Product__c productRecord : [
            SELECT FundStrategy__c
            FROM Product__c
            WHERE VehicleType__c = 'Funds'
            AND Validity__c = true
            AND FundStrategy__c != null
        ]) {
            strategyIds.add(productRecord.FundStrategy__c);
        }

        // Charge les stratégies éligibles.
        for (Strategy__c strategyRecord : [
            SELECT Id, Name, Code__c
            FROM Strategy__c
            WHERE Id IN :strategyIds
            OR Code__c IN :strategyCodes
            ORDER BY Name
        ]) {
            result.put(strategyRecord.Code__c, strategyRecord);
        }

        return result;
    }

    // Convertit la liste de codes stockée en wrappers affichables.
    private List<StrategyWrapper> buildStrategyWrappers(
        String rawCodes,
        Map<String, Strategy__c> strategiesByCode
    ) {
        List<StrategyWrapper> result = new List<StrategyWrapper>();

        if (String.isBlank(rawCodes)) {
            return result;
        }

        // Chaque code est résolu vers le nom fonctionnel de la stratégie.
        for (String code : rawCodes.split(STRATEGY_SEPARATOR)) {
            String cleanCode = code == null ? null : code.trim();

            if (String.isBlank(cleanCode)) {
                continue;
            }

            Strategy__c strategyRecord = strategiesByCode.get(cleanCode);
            String strategyName = strategyRecord == null ? cleanCode : strategyRecord.Name;

            result.add(new StrategyWrapper(cleanCode, strategyName));
        }

        return result;
    }

    // Lit les paramètres envoyés par les liens Visualforce.
    private void readRequestParameters() {
        Map<String, String> parameters = ApexPages.currentPage().getParameters();

        String usernameParameterValue = parameters.get(USERNAME_PARAMETER);
        String strategyCodeParameterValue = parameters.get(STRATEGY_CODE_PARAMETER);

        // Les paramètres nommés évitent les pertes de valeur dans les repeat/table.
        if (!String.isBlank(usernameParameterValue)) {
            selectedUsername = usernameParameterValue;
        }

        if (!String.isBlank(strategyCodeParameterValue)) {
            selectedStrategyCode = strategyCodeParameterValue;
        }
    }

    // Recharge les données depuis le custom metadata.
    public void refreshMatrix() {
        loadRows();
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Matrix refreshed.'));
    }

    // Construit la matrice Strategies en lignes / Users en colonnes.
    private void buildStrategyUserMatrix(Map<String, Strategy__c> strategiesByCode) {
        matrixUsers.clear();
        matrixStrategies.clear();

        Map<String, Set<String>> strategyCodesByUsername = new Map<String, Set<String>>();
        Set<String> allStrategyCodes = new Set<String>();

        for (RowWrapper row : rows) {
            matrixUsers.add(row);
            strategyCodesByUsername.put(row.username, row.getStrategyCodes());
            allStrategyCodes.addAll(row.getStrategyCodes());
        }

        // Chaque cellule contient ✓ si l'utilisateur possède la stratégie.
        for (String strategyCode : allStrategyCodes) {
            Strategy__c strategyRecord = strategiesByCode.get(strategyCode);
            String strategyName = strategyRecord == null ? strategyCode : strategyRecord.Name;

            MatrixStrategyWrapper matrixStrategy = new MatrixStrategyWrapper(strategyCode, strategyName);

            for (RowWrapper userRow : matrixUsers) {
                Boolean hasStrategy = strategyCodesByUsername.get(userRow.username).contains(strategyCode);
                matrixStrategy.cells.add(hasStrategy ? '✓' : '');
            }

            matrixStrategies.add(matrixStrategy);
        }

        matrixStrategies.sort();
    }

    // Recherche les utilisateurs pendant la saisie du nom.
    public void searchUsers() {
        userOptions.clear();

        if (String.isBlank(userSearchText) || userSearchText.trim().length() < 2) {
            return;
        }

        String searchValue = '%' + userSearchText.trim() + '%';

        // Recherche type lookup standard sur nom, username et email.
        for (User userRecord : [
            SELECT Id, Name, Username
            FROM User
            WHERE IsActive = true
            AND (
                Name LIKE :searchValue
                OR Username LIKE :searchValue
                OR Email LIKE :searchValue
            )
            ORDER BY Name
            LIMIT 10
        ]) {
            userOptions.add(
                new UserOption(userRecord.Username, userRecord.Name + ' - ' + userRecord.Username)
            );
        }
    }

    // Sélectionne un utilisateur et ajoute immédiatement la ligne.
    public void selectUser() {
        readRequestParameters();

        if (String.isBlank(selectedUsername)) {
            return;
        }

        // Le clic sur un utilisateur crée directement la ligne en édition.
        addUser();
    }

    // Ajoute une nouvelle ligne en mode édition.
   /* public void addUser() {
        if (String.isBlank(selectedUsername)) {
            return;
        }

        for (RowWrapper row : rows) {
            if (row.username == selectedUsername) {
                row.isEditing = true;
                return;
            }
        }

        User userRecord = [
            SELECT Id, Name, Username
            FROM User
            WHERE Username = :selectedUsername
            LIMIT 1
        ];

        // La ligne est ajoutée localement puis sauvegardée après sélection des stratégies.
        rows.add(
            new RowWrapper(
                null,
                userRecord.Username,
                userRecord.Name,
                new List<StrategyWrapper>()
            )
        );

        rows[rows.size() - 1].isEditing = true;
        selectedUsername = null;
        userSearchText = null;
    }
*/

    // Ajoute une nouvelle ligne en mode édition.
    public void addUser() {
        readRequestParameters();

        if (String.isBlank(selectedUsername)) {
            return;
        }

        for (RowWrapper row : rows) {
            if (row.username == selectedUsername) {
                row.isEditing = true;
                userOptions.clear();
                userSearchText = null;
                selectedUsername = null;
                return;
            }
        }

        // Cherche aussi les mappings inactifs pour réutiliser le même metadata.
        List<BooklyStrategiesByUsers__mdt> existingMappings = [
            SELECT DeveloperName, MasterLabel, Username__c, StrategyCodes__c, IsActive__c
            FROM BooklyStrategiesByUsers__mdt
            WHERE Username__c = :selectedUsername
            LIMIT 1
        ];

        List<User> userRecords = [
            SELECT Id, Name, Username
            FROM User
            WHERE Username = :selectedUsername
            LIMIT 1
        ];

        if (userRecords.isEmpty()) {
            return;
        }

        User userRecord = userRecords[0];

        // Si un mapping inactif existe, on l'ajoute localement en édition.
        if (!existingMappings.isEmpty()) {
            BooklyStrategiesByUsers__mdt mapping = existingMappings[0];

            if (!mapping.IsActive__c) {
                RowWrapper inactiveRow = new RowWrapper(
                    mapping.DeveloperName,
                    userRecord.Username,
                    userRecord.Name,
                    buildStrategyWrappers(mapping.StrategyCodes__c, loadStrategiesByCode())
                );

                inactiveRow.isActive = true;
                inactiveRow.isEditing = true;
                rows.add(inactiveRow);
            }

            userOptions.clear();
            userSearchText = null;
            selectedUsername = null;
            return;
        }

        // La ligne est ajoutée localement en mode édition.
        rows.add(
            new RowWrapper(
                null,
                userRecord.Username,
                userRecord.Name,
                new List<StrategyWrapper>()
            )
        );

        rows[rows.size() - 1].isEditing = true;
        userOptions.clear();
        userSearchText = null;
        selectedUsername = null;
    }

    // Réactive un custom metadata sans modifier les stratégies existantes.
    private Id reactivateMapping(BooklyStrategiesByUsers__mdt mapping) {
        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        customMetadata.fullName = 'BooklyStrategiesByUsers.' + mapping.DeveloperName;
        customMetadata.label = mapping.MasterLabel;

        // Met uniquement le flag actif à true.
        Metadata.CustomMetadataValue isActiveValue = new Metadata.CustomMetadataValue();
        isActiveValue.field = 'IsActive__c';
        isActiveValue.value = true;
        customMetadata.values.add(isActiveValue);

        Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
        deployContainer.addMetadata(customMetadata);

        // Lance le déploiement metadata asynchrone.
        return Metadata.Operations.enqueueDeployment(
            deployContainer,
            new BooklyMetadataDeployCallback()
        );
    }


    // Active le mode édition sur la ligne sélectionnée.
    public void editRow() {
        readRequestParameters();

        RowWrapper row = getSelectedRow();

        if (row != null) {
            row.isEditing = true;
        }
    }

    // Désactive la ligne sélectionnée dans le custom metadata.
    public void removeRow() {
        readRequestParameters();

        RowWrapper row = getSelectedRow();

        if (row == null) {
            return;
        }

        // Le record metadata est conservé mais exclu des affichages.
        row.isActive = false;
        upsertMapping(row);
        rows.remove(rows.indexOf(row));
    }

    // Recherche les stratégies pendant la saisie dans une ligne.
    public void searchStrategies() {
        readRequestParameters();

        RowWrapper row = getSelectedRow();

        if (row == null) {
            return;
        }

        row.strategyOptions.clear();

        if (String.isBlank(row.strategySearchText) || row.strategySearchText.trim().length() < 2) {
            return;
        }

        String searchValue = '%' + row.strategySearchText.trim() + '%';
        Set<String> existingCodes = row.getStrategyCodes();

        // Propose uniquement les stratégies non déjà sélectionnées.
        for (Strategy__c strategyRecord : [
            SELECT Id, Name, Code__c
            FROM Strategy__c
            WHERE Code__c != null
            AND (
                Name LIKE :searchValue
                OR Code__c LIKE :searchValue
            )
            ORDER BY Name
            LIMIT 10
        ]) {
            if (!existingCodes.contains(strategyRecord.Code__c)) {
                row.strategyOptions.add(
                    new SelectOption(strategyRecord.Code__c, strategyRecord.Name)
                );
            }
        }
    }

    // Ajoute une stratégie à la ligne en cours d’édition.
    public void addStrategy() {
        readRequestParameters();

        RowWrapper row = getSelectedRow();

        if (row == null || String.isBlank(selectedStrategyCode)) {
            return;
        }

        if (row.getStrategyCodes().contains(selectedStrategyCode)) {
            row.strategySearchText = null;
            row.strategyOptions.clear();
            selectedStrategyCode = null;
            return;
        }

        List<Strategy__c> strategyRecords = [
            SELECT Id, Name, Code__c
            FROM Strategy__c
            WHERE Code__c = :selectedStrategyCode
            LIMIT 1
        ];

        if (strategyRecords.isEmpty()) {
            return;
        }

        // Ajoute la stratégie sélectionnée puis réinitialise la recherche.
        Strategy__c strategyRecord = strategyRecords[0];
        row.strategies.add(new StrategyWrapper(strategyRecord.Code__c, strategyRecord.Name));
        row.strategySearchText = null;
        row.strategyOptions.clear();
        selectedStrategyCode = null;
    }

    // Retire une stratégie de la ligne en cours d’édition.
    public void removeStrategy() {
        readRequestParameters();

        RowWrapper row = getSelectedRow();

        if (row == null || String.isBlank(selectedStrategyCode)) {
            return;
        }

        for (Integer index = row.strategies.size() - 1; index >= 0; index--) {
            if (row.strategies[index].code == selectedStrategyCode) {
                row.strategies.remove(index);
            }
        }

        selectedStrategyCode = null;
    }

    // Termine le mode édition et lance la sauvegarde du custom metadata.
    public void saveRow() {
        readRequestParameters();

        RowWrapper row = getSelectedRow();

        if (row == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No row selected.'));
            return;
        }

        if (String.isBlank(row.metadataDeveloperName)) {
            row.metadataDeveloperName = buildMetadataDeveloperName(row.username);
        }

        try {
            // La sauvegarde custom metadata est lancée en déploiement asynchrone.
            Id deploymentId = upsertMapping(row);
            row.isEditing = false;

            ApexPages.addMessage(
                new ApexPages.Message(
                    ApexPages.Severity.INFO,
                    'Save requested. Deployment Id: ' + deploymentId
                )
            );
        } catch (Exception exceptionRecord) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, exceptionRecord.getMessage())
            );
        }
    }

    // Construit la valeur StrategyCodes__c à partir des stratégies sélectionnées.
    private String buildStrategyCodes(RowWrapper row) {
        List<String> strategyCodes = new List<String>();

        for (StrategyWrapper strategy : row.strategies) {
            strategyCodes.add(strategy.code);
        }

        // Les codes sont stockés avec le même séparateur que la lecture.
        return String.join(strategyCodes, STRATEGY_SEPARATOR);
    }

      // Génère le DeveloperName à partir du nom Salesforce de l'utilisateur.
    private String buildMetadataDeveloperName(String username) {
        User userRecord = [
            SELECT Name
            FROM User
            WHERE Username = :username
            LIMIT 1
        ];

        String developerName = userRecord.Name.toLowerCase();

        // Remplace espaces et caractères spéciaux par "_".
        developerName = developerName.replaceAll('[^a-zA-Z0-9]', '_');
        developerName = developerName.replaceAll('_+', '_');
        developerName = developerName.replaceAll('^_+', '');
        developerName = developerName.replaceAll('_+$', '');

        // Limite Salesforce à 40 caractères.
        if (developerName.length() > 40) {
            developerName = developerName.substring(0, 40).replaceAll('_+$', '');
        }

        return developerName;
    }

    // Génère un label compatible avec le custom metadata.
    private String buildMetadataLabel(String displayName) {
        if (String.isBlank(displayName)) {
            return 'Bookly Mapping';
        }

        // Évite un échec de déploiement si le nom affiché est trop long.
        if (displayName.length() > 40) {
            return displayName.substring(0, 40);
        }

        return displayName;
    }

        // Crée ou met à jour le custom metadata User / Strategies.
    private Id upsertMapping(RowWrapper row) {
        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        customMetadata.fullName = 'BooklyStrategiesByUsers.' + row.metadataDeveloperName;
        customMetadata.label = buildMetadataLabel(row.displayName);

        Metadata.CustomMetadataValue usernameValue = new Metadata.CustomMetadataValue();
        usernameValue.field = 'Username__c';
        usernameValue.value = row.username;
        customMetadata.values.add(usernameValue);

        Metadata.CustomMetadataValue strategyCodesValue = new Metadata.CustomMetadataValue();
        strategyCodesValue.field = 'StrategyCodes__c';
        strategyCodesValue.value = buildStrategyCodes(row);
        customMetadata.values.add(strategyCodesValue);

        Metadata.CustomMetadataValue isActiveValue = new Metadata.CustomMetadataValue();
        isActiveValue.field = 'IsActive__c';
        isActiveValue.value = row.isActive;
        customMetadata.values.add(isActiveValue);

        Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
        deployContainer.addMetadata(customMetadata);

        // Retourne l'Id du déploiement pour tracer la sauvegarde.
        Id deploymentId = Metadata.Operations.enqueueDeployment(
            deployContainer,
            new BooklyMetadataDeployCallback()
        );

        System.debug('BOOKLY METADATA DEPLOYMENT ID = ' + deploymentId);
        return deploymentId;
    }

    public class BooklyMetadataDeployCallback implements Metadata.DeployCallback {

        // Reçoit le résultat asynchrone de la sauvegarde custom metadata.
        public void handleResult(
            Metadata.DeployResult result,
            Metadata.DeployCallbackContext context
        ) {
            System.debug('BOOKLY METADATA SAVE STATUS = ' + result.status);
            System.debug('BOOKLY METADATA SAVE SUCCESS = ' + result.success);

            if (result.details == null || result.details.componentFailures == null) {
                return;
            }

            // Les erreurs réelles d'insert/update sont visibles ici dans les logs.
            for (Metadata.DeployMessage failure : result.details.componentFailures) {
                System.debug(
                    'BOOKLY METADATA SAVE FAILURE = ' +
                    failure.fullName + ' - ' + failure.problem
                );
            }
        }
    }

    // Annule le mode édition et recharge les données.
    public void cancelEdit() {
        loadRows();
    }

    // Retrouve la ligne concernée à partir du username sélectionné.
    private RowWrapper getSelectedRow() {
        if (String.isBlank(selectedUsername)) {
            return null;
        }

        for (RowWrapper row : rows) {
            if (row.username == selectedUsername) {
                return row;
            }
        }

        return null;
    }

    public class RowWrapper {
        public String metadataDeveloperName { get; set; }
        public String username { get; set; }
        public String displayName { get; set; }
        public Boolean isEditing { get; set; }
        public Boolean isActive { get; set; }
        public String strategySearchText { get; set; }
        public List<StrategyWrapper> strategies { get; set; }
        public List<SelectOption> strategyOptions { get; set; }

        // Représente une ligne User / Strategies affichée dans la matrice.
        public RowWrapper(
            String metadataDeveloperName,
            String username,
            String displayName,
            List<StrategyWrapper> strategies
        ) {
            this.metadataDeveloperName = metadataDeveloperName;
            this.username = username;
            this.displayName = displayName;
            this.strategies = strategies;
            this.isEditing = false;
            this.isActive = true;
            this.strategyOptions = new List<SelectOption>();
        }

        // Retourne les codes stratégies déjà sélectionnés sur la ligne.
        public Set<String> getStrategyCodes() {
            Set<String> result = new Set<String>();

            for (StrategyWrapper strategy : strategies) {
                result.add(strategy.code);
            }

            return result;
        }
    }

   

    public class MatrixStrategyWrapper implements Comparable {
        public String code { get; set; }
        public String name { get; set; }
        public List<String> cells { get; set; }

        // Représente une ligne de la matrice Strategy / Users.
        public MatrixStrategyWrapper(String code, String name) {
            this.code = code;
            this.name = name;
            this.cells = new List<String>();
        }

        // Trie les stratégies par nom alphabétique.
        public Integer compareTo(Object otherObject) {
            MatrixStrategyWrapper otherStrategy = (MatrixStrategyWrapper) otherObject;
            return name.compareTo(otherStrategy.name);
        }
    }

    public class StrategyWrapper {
        public String code { get; set; }
        public String name { get; set; }

        // Représente une stratégie sélectionnée sur une ligne.
        public StrategyWrapper(String code, String name) {
            this.code = code;
            this.name = name;
        }
    }



        public class UserOption {
        public String value { get; set; }
        public String label { get; set; }

        // Représente un utilisateur proposé dans la recherche.
        public UserOption(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }
}