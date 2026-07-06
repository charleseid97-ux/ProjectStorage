import { LightningElement, api } from 'lwc';
import getPriipsKidData from '@salesforce/apex/PRIIPSKidController.getPriipsKidData';

const ALL_SHARECLASSES = 'ALL';

export default class PriipsKid extends LightningElement {
    // Record Id of the current Project Product.
    @api recordId;

    data;
    errorMessage;
    isLoading = false;
    selectedShareclassId = ALL_SHARECLASSES;
    activeMainSections = ['shareclass', 'fund'];
    activeProductTeamSections = [];
    activeShareclassTeamSections = [];

    // Loads data when the component is inserted in the record page.
    connectedCallback() {
        this.load();
    }

    // Calls Apex only when Salesforce has injected the record Id.
    load() {
        if (!this.recordId) {
            this.errorMessage = 'Record Id introuvable.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = undefined;

        // Retrieves PRIIPs/KID data from Apex.
        getPriipsKidData({
            recordId: this.recordId
        })
            .then((data) => {
                this.data = data;
                this.selectedShareclassId = ALL_SHARECLASSES;

                // Opens all team subsections by default.
                this.activeProductTeamSections = (data?.productTeams || [])
                    .map((team) => team.key);
                this.activeShareclassTeamSections = this.getAllShareclassTeamKeys(data);
            })
            .catch((error) => {
                this.data = undefined;
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Returns the warning produced by Apex when configuration is incomplete.
    get warningMessage() {
        return this.data ? this.data.warningMessage : undefined;
    }

    // Returns Product-level teams from the Apex response.
    get productTeams() {
        return this.data && this.data.productTeams ? this.data.productTeams : [];
    }

    // Returns Shareclass records from the Apex response.
    get shareclasses() {
        return this.data && this.data.shareclasses ? this.data.shareclasses : [];
    }

    // Returns true when at least one Product field is available.
    get hasProductTeams() {
        return this.productTeams.length > 0;
    }

    // Returns true when at least one Shareclass is available.
    get hasShareclasses() {
        return this.shareclasses.length > 0;
    }

    // Returns true when loading is complete but there is no data and no error.
    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && !this.hasProductTeams && !this.hasShareclasses;
    }

    // Builds the Shareclass picklist options.
    get shareclassOptions() {
        return [
            { label: 'All ShareClasses', value: ALL_SHARECLASSES },
            ...this.shareclasses.map((shareclassRecord) => ({
                label: shareclassRecord.label,
                value: shareclassRecord.id
            }))
        ];
    }

    // Returns the Shareclass cards matching the selected picklist value.
    get visibleShareclasses() {
        if (this.selectedShareclassId === ALL_SHARECLASSES) {
            return this.shareclasses;
        }

        return this.shareclasses.filter((shareclassRecord) => shareclassRecord.id === this.selectedShareclassId);
    }

    // Updates the selected Shareclass when the picklist changes.
    handleShareclassChange(event) {
        this.selectedShareclassId = event.detail.value;
    }

    // Collects all Shareclass team section keys to open them by default.
    getAllShareclassTeamKeys(data) {
        const keys = new Set();

        // Avoids duplicate accordion section names across Shareclasses.
        (data?.shareclasses || []).forEach((shareclassRecord) => {
            (shareclassRecord.teams || []).forEach((team) => keys.add(team.key));
        });

        return Array.from(keys);
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