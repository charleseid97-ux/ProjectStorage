import { LightningElement, api } from 'lwc';
import getCompletionData from '@salesforce/apex/PRIIPSKidCompletionController.getCompletionData';

export default class PriisKidCompletion extends LightningElement {
    _recordId;
    loadedRecordId;

    data;
    errorMessage;
    isLoading = false;
    expandedTeamKeys = [];

    // Record Id injected by the Project Product record page.
    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        this.load();
    }

    // Loads completion data when the component is inserted in the page.
    connectedCallback() {
        this.load();
    }

    // Calls Apex once per record Id and keeps the component compact for the right panel.
    load() {
        if (!this._recordId || this.isLoading || this.loadedRecordId === this._recordId) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = undefined;
        this.loadedRecordId = this._recordId;

        // Retrieves completion indicators calculated from PRIISField__mdt.
        getCompletionData({ recordId: this._recordId })
            .then((data) => {
                this.data = data;
                this.errorMessage = undefined;
            })
            .catch((error) => {
                this.data = undefined;
                this.loadedRecordId = undefined;
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Toggles the detail area for the clicked team.
    toggleTeam(event) {
        const teamKey = event.currentTarget.dataset.key;
        if (!teamKey) {
            return;
        }

        if (this.expandedTeamKeys.includes(teamKey)) {
            this.expandedTeamKeys = this.expandedTeamKeys.filter((key) => key !== teamKey);
            return;
        }

        this.expandedTeamKeys = [...this.expandedTeamKeys, teamKey];
    }

    // Returns true when Apex is done and no team indicator exists.
    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && !this.hasTeams;
    }

    // Returns true when at least one team completion row is available.
    get hasTeams() {
        return this.teams.length > 0;
    }

    // Returns raw team completion rows from Apex.
    get teams() {
        return this.data && this.data.teams ? this.data.teams : [];
    }

    // Builds display-only values, CSS classes, and progress widths for the template.
    get teamViewModels() {
        return this.teams.map((team) => {
            const expanded = this.expandedTeamKeys.includes(team.key);

            // CSS classes are generated here because LWC templates cannot call methods with arguments.
            return {
                ...team,
                expanded,
                percentLabel: `${team.percentage}%`,
                ratioLabel: `${team.completed} / ${team.total}`,
                barStyle: `width: ${team.percentage}%;`,
                barClass: `progress-bar progress-${team.status}`,
                dotClass: `status-dot status-${team.status}`,
                details: (team.details || []).map((detail) => ({
                    ...detail,
                    percentLabel: `${detail.percentage}%`,
                    ratioLabel: `${detail.completed} / ${detail.total}`,
                    barStyle: `width: ${detail.percentage}%;`,
                    barClass: `detail-progress-bar progress-${detail.status}`
                }))
            };
        });
    }

    // Returns the warning produced by Apex when configuration is incomplete.
    get warningMessage() {
        return this.data ? this.data.warningMessage : undefined;
    }

    // Extracts a clean message from Apex and LDS error shapes.
    reduceError(error) {
        if (!error) {
            return 'Unknown error.';
        }

        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }

        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }

        return error.message || 'Unknown error.';
    }
}