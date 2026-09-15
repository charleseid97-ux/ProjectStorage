import { LightningElement, api } from 'lwc';
import getPriipsKidData from '@salesforce/apex/PRIIPSKidController.getPriipsKidData';

export default class PriipsKid extends LightningElement {
    // Record Id of the current Project Product.
    @api recordId;

    data;
    errorMessage;
    isLoading = false;
    activeMainSections = ['priips'];
    activeTeamSections = [];
    activeTeamItemSections = [];

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
                const decoratedData = this.decorateData(data);
                const priipsTeams = this.buildPriipsTeams(decoratedData?.productTeams, decoratedData?.shareclasses);

                this.data = {
                    ...decoratedData,
                    priipsTeams
                };

                // Opens all accordion levels by default.
                this.activeTeamSections = priipsTeams.map((team) => team.key);
                this.activeTeamItemSections = this.getAllTeamItemKeys(priipsTeams);
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

    // Returns the final Team > Fund/Shareclass hierarchy consumed by the template.
    get priipsTeams() {
        return this.data && this.data.priipsTeams ? this.data.priipsTeams : [];
    }

    // Returns true when at least one team has Product or Shareclass fields.
    get hasPriipsTeams() {
        return this.priipsTeams.length > 0;
    }

    // Returns true when loading is complete but there is no data and no error.
    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && !this.hasPriipsTeams;
    }

    // Adds CSS classes to fields depending on empty value and Required__c.
    decorateData(data) {
        if (!data) {
            return data;
        }

        return {
            ...data,
            productTeams: this.decorateTeams(data.productTeams),
            shareclasses: (data.shareclasses || []).map((shareclassRecord) => ({
                ...shareclassRecord,
                teams: this.decorateTeams(shareclassRecord.teams)
            }))
        };
    }

    // Decorates all fields inside team sections.
    decorateTeams(teams) {
        return (teams || []).map((team) => ({
            ...team,
            fields: (team.fields || []).map((field) => this.decorateField(field))
        }));
    }

    // Adds CSS classes depending on completion state, Required__c and long text content.
    decorateField(field) {
        const plainValue = this.getPlainTextValue(field.value);
        const isEmpty = plainValue.length === 0;
        const isFilled = this.isFieldFilled(field, plainValue);
        const isLongText = !isEmpty && this.isLongTextField(field, plainValue);
        let itemClass = 'field-item';
        let valueClass = 'field-value';

        if (isLongText) {
            itemClass += ' field-item-full-width';
            valueClass += ' field-value-long-text';
        }

        if (!isFilled && field.required) {
            valueClass += ' field-value-required-empty';
        } else if (!isFilled) {
            valueClass += ' field-value-optional-empty';
        }

        return {
            ...field,
            value: isEmpty ? '\u2014' : field.value,
            itemClass,
            valueClass
        };
    }

    // Returns the Apex completion state or falls back to the displayed value.
    isFieldFilled(field, plainValue) {
        if (typeof field.isFilled === 'boolean') {
            return field.isFilled;
        }

        return plainValue.length > 0;
    }

    // Returns true when a field should use the full row width.
    isLongTextField(field, plainValue) {
        const label = (field.label || '').toLowerCase();

        return plainValue.length > 180 ||
            label.includes('objective') ||
            label.includes('investor') ||
            label.includes('information');
    }

    // Converts plain text or rich text into comparable text.
    getPlainTextValue(value) {
        if (value === null || value === undefined) {
            return '';
        }

        return String(value)
            .replace(/<[^>]*>/g, '')
            .replace(/&nbsp;/g, ' ')
            .replace(/&amp;/g, '&')
            .trim();
    }

    // Builds Team > Fund/Shareclass sections from the Apex Product and Shareclass response.
    buildPriipsTeams(productTeams, shareclasses) {
        const teamsByKey = new Map();
        const orderedKeys = [];

        (productTeams || []).forEach((team) => {
            const targetTeam = this.getOrCreatePriipsTeam(teamsByKey, orderedKeys, team.key, team.name);
            targetTeam.fundFields = team.fields || [];
            targetTeam.hasFundFields = targetTeam.fundFields.length > 0;
        });

        (shareclasses || []).forEach((shareclassRecord) => {
            (shareclassRecord.teams || []).forEach((team) => {
                const fields = team.fields || [];
                if (!fields.length) {
                    return;
                }

                const targetTeam = this.getOrCreatePriipsTeam(teamsByKey, orderedKeys, team.key, team.name);
                targetTeam.shareclasses.push({
                    key: `${team.key}_${shareclassRecord.id}`,
                    id: shareclassRecord.id,
                    label: shareclassRecord.label,
                    fields
                });
            });
        });

        return orderedKeys.map((key) => {
            const team = teamsByKey.get(key);
            return {
                ...team,
                hasShareclasses: team.shareclasses.length > 0
            };
        });
    }

    // Creates one team node used by both Fund fields and Shareclass fields.
    getOrCreatePriipsTeam(teamsByKey, orderedKeys, key, name) {
        if (!teamsByKey.has(key)) {
            teamsByKey.set(key, {
                key,
                name,
                fundKey: `${key}_fund`,
                hasFundFields: false,
                fundFields: [],
                shareclasses: []
            });
            orderedKeys.push(key);
        }

        return teamsByKey.get(key);
    }

    // Collects Fund and Shareclass subsection keys to open them by default.
    getAllTeamItemKeys(priipsTeams) {
        const keys = [];

        (priipsTeams || []).forEach((team) => {
            if (team.hasFundFields) {
                keys.push(team.fundKey);
            }

            (team.shareclasses || []).forEach((shareclassRecord) => {
                keys.push(shareclassRecord.key);
            });
        });

        return keys;
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