import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getLogs from '@salesforce/apex/OperationLogRecordController.getLogs';

export default class OperationLogViewer extends LightningElement {
    @api recordId;
    @api title = 'Technical logs';
    @api defaultLimit = 50;
    @api defaultLevel = 'DEBUG';

    logs = [];
    errorMessage;
    isLoading = true;
    levelFilter = 'DEBUG';
    maxRows = 50;
    wiredResult;

    levelOptions = [
        { label: 'DEBUG and above', value: 'DEBUG' },
        { label: 'INFO and above', value: 'INFO' },
        { label: 'WARN and above', value: 'WARN' },
        { label: 'ERROR only', value: 'ERROR' }
    ];

    limitOptions = [
        { label: '10', value: '10' },
        { label: '25', value: '25' },
        { label: '50', value: '50' },
        { label: '100', value: '100' },
        { label: '200', value: '200' }
    ];

    // Initialise les valeurs configurées dans le Lightning App Builder.
    connectedCallback() {
        this.levelFilter = this.normalizeLevel(this.defaultLevel);
        this.maxRows = this.normalizeLimit(this.defaultLimit);
    }

    // Charge les logs du record courant depuis Apex.
    @wire(getLogs, { recordId: '$recordId', maxRows: '$maxRows', minLevel: '$levelFilter' })
    wiredLogs(result) {
        this.wiredResult = result;
        this.isLoading = false;

        if (result.data) {
            this.errorMessage = undefined;
            this.logs = result.data.map((log) => this.decorateLog(log));
        } else if (result.error) {
            this.logs = [];
            this.errorMessage = this.reduceError(result.error);
        }
    }

    // Retourne la limite au format attendu par lightning-combobox.
    get maxRowsAsString() {
        return String(this.maxRows);
    }

    // Indique si des logs doivent être affichés.
    get hasLogs() {
        return this.logs.length > 0;
    }

    // Affiche l'état vide uniquement après chargement et sans erreur.
    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && !this.hasLogs;
    }

    // Met à jour le niveau minimum et relance automatiquement le wire Apex.
    handleLevelChange(event) {
        this.isLoading = true;
        this.levelFilter = event.detail.value;
    }

    // Met à jour la limite et relance automatiquement le wire Apex.
    handleLimitChange(event) {
        this.isLoading = true;
        this.maxRows = this.normalizeLimit(event.detail.value);
    }

    // Rafraîchit manuellement les logs affichés.
    handleRefresh() {
        if (!this.wiredResult) {
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        refreshApex(this.wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    // Prépare les libellés et classes CSS côté client pour garder l'Apex simple.
    decorateLog(log) {
        const level = log.level || 'INFO';
        const apexLocation = [log.apexClass, log.methodName].filter(Boolean).join('.');

        return {
            ...log,
            level,
            levelClass: `level-badge level-${level.toLowerCase()}`,
            url: `/${log.id}`,
            operationLabel: log.operation || 'Opération non renseignée',
            messageLabel: log.message || 'Aucun message renseigné',
            createdDateLabel: this.formatDateTime(log.createdDate),
            expirationDateLabel: this.formatDate(log.expirationDate),
            apexLocation,
            hasDetails: Boolean(log.contextJson || log.stackTrace || log.exceptionType || log.correlationId)
        };
    }

    // Normalise le niveau par défaut venant de la configuration du composant.
    normalizeLevel(value) {
        const normalized = String(value || 'DEBUG').trim().toUpperCase();
        return ['DEBUG', 'INFO', 'WARN', 'ERROR'].includes(normalized) ? normalized : 'DEBUG';
    }

    // Normalise la limite pour rester aligné avec le contrôleur Apex.
    normalizeLimit(value) {
        const parsedValue = Number.parseInt(value, 10);

        if (!Number.isFinite(parsedValue) || parsedValue < 1) {
            return 50;
        }
        if (parsedValue > 200) {
            return 200;
        }

        return parsedValue;
    }

    // Formate une date/heure Salesforce dans la locale de l'utilisateur.
    formatDateTime(value) {
        if (!value) {
            return '';
        }

        return new Intl.DateTimeFormat(undefined, {
            dateStyle: 'short',
            timeStyle: 'short'
        }).format(new Date(value));
    }

    // Formate une date Salesforce dans la locale de l'utilisateur.
    formatDate(value) {
        if (!value) {
            return '';
        }

        return new Intl.DateTimeFormat(undefined, {
            dateStyle: 'short'
        }).format(new Date(value));
    }

    // Réduit les erreurs Apex/LDS en message lisible.
    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }

        return error?.message || 'Erreur inconnue pendant le chargement des logs.';
    }
}
