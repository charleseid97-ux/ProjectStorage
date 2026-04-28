import { LightningElement, api, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import LightningConfirm from 'lightning/confirm';

import getContext from '@salesforce/apex/TaxDataActionController.getContext';
import createTaxDataPairs from '@salesforce/apex/TaxDataActionController.createTaxDataPairs';
import getUnregisteredCountries from '@salesforce/apex/TaxDataActionController.getUnregisteredCountries';
import getClosableTaxDataOptions from '@salesforce/apex/TaxDataActionController.getClosableTaxDataOptions';
import submitClosureRequests from '@salesforce/apex/TaxDataActionController.submitClosureRequests';

export default class TaxDataAction extends LightningElement {
    @api recordId;

    @track loading = true;
    shareClassName = '';
    actionMode = null;

    @track selectedCountries = [];
    @track beTypeValues = [];
    comment = '';

    @track closureOptions = [];
    @track selectedClosureKeys = [];

    countryOptions = [
        { label: 'Austria (AT)', value: 'AT' },
        { label: 'Belgium (BE)', value: 'BE' },
        { label: 'Switzerland (CH)', value: 'CH' },
        { label: 'United Kingdom (UK)', value: 'UK' }
    ];

    beTypeOptions = [
        { label: 'BE Asset Test', value: 'BE Asset Test' },
        { label: 'BE TIS', value: 'BE TIS' },
        { label: 'Belgium Simulator', value: 'Belgium Simulator' }
    ];

    connectedCallback() {
        this.loadContext();
    }

    async loadContext() {
        this.loading = true;
        try {
            const sc = await getContext({ shareClassId: this.recordId });
            this.shareClassName = sc && sc.Name ? sc.Name : '';
            await this.loadClosableOptions();
        } catch (err) {
            this.showToast('Error', this.getErrorMessage(err), 'error');
        } finally {
            this.loading = false;
        }
    }

    async loadClosableOptions() {
        const result = await getClosableTaxDataOptions({ shareClassId: this.recordId });
        this.closureOptions = (result || []).map(item => ({
            label: item.label,
            value: item.key
        }));
    }

    handleModeSelect(event) {
        const selectedMode = event.currentTarget.dataset.mode;
        this.actionMode = selectedMode;
    }

    handleCountriesChange(event) {
        this.selectedCountries = event.detail.value || [];

        if (!this.isBEselected) {
            this.beTypeValues = [];
        }
    }

    handleBETypeChange(event) {
        let selectedValues = [...(event.detail.value || [])];

        const BE_TIS = 'BE TIS';
        const BE_ASSET_TEST = 'BE Asset Test';

        const hasBeTis = selectedValues.includes(BE_TIS);
        const hasBeAssetTest = selectedValues.includes(BE_ASSET_TEST);

        if (hasBeTis && !hasBeAssetTest) {
            selectedValues.push(BE_ASSET_TEST);
        } else if (hasBeAssetTest && !hasBeTis) {
            selectedValues.push(BE_TIS);
        }

        this.beTypeValues = [...new Set(selectedValues)];
    }

    handleClosureSelectionChange(event) {
        this.selectedClosureKeys = event.detail.value || [];
    }

    handleCommentChange(event) {
        this.comment = event.detail.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    get displayShareClassName() {
        return this.shareClassName || '';
    }

    get isCreateMode() {
        return this.actionMode === 'create';
    }

    get isClosureMode() {
        return this.actionMode === 'close';
    }

    get isBEselected() {
        return Array.isArray(this.selectedCountries) && this.selectedCountries.includes('BE');
    }

    get hasClosureOptions() {
        return Array.isArray(this.closureOptions) && this.closureOptions.length > 0;
    }

    get createCardClass() {
        return this.actionMode === 'create' ? 'mode-card selected' : 'mode-card';
    }

    get closureCardClass() {
        return this.actionMode === 'close' ? 'mode-card selected' : 'mode-card';
    }

    get submitLabel() {
        if (this.isCreateMode) {
            return 'Submit request';
        }
        if (this.isClosureMode) {
            return 'Submit closure';
        }
        return 'Submit';
    }

    get submitDisabled() {
        if (!this.actionMode) {
            return true;
        }

        if (this.isCreateMode) {
            if (!this.selectedCountries || this.selectedCountries.length === 0) {
                return true;
            }
            if (this.isBEselected && (!this.beTypeValues || this.beTypeValues.length === 0)) {
                return true;
            }
            return false;
        }

        if (this.isClosureMode) {
            return !this.selectedClosureKeys || this.selectedClosureKeys.length === 0;
        }

        return true;
    }

    async confirmIfUnregisteredCountries() {
        const countriesToCheck = [...(this.selectedCountries || [])];

        if (!countriesToCheck.length) {
            return true;
        }

        const unregisteredCountries = await getUnregisteredCountries({
            shareClassId: this.recordId,
            countries: countriesToCheck
        });

        if (!unregisteredCountries || unregisteredCountries.length === 0) {
            return true;
        }

        const labelsByCode = {
            AT: 'Austria',
            BE: 'Belgium',
            CH: 'Switzerland',
            IT: 'Italy',
            UK: 'United Kingdom'
        };

        const countryLabels = unregisteredCountries.map(code => labelsByCode[code] || code);

        return LightningConfirm.open({
            message:
                'This share class is not registered in the following country(ies): ' +
                countryLabels.join(', ') +
                '. Are you sure you want to proceed with the request?',
            variant: 'header',
            label: 'Confirmation required'
        });
    }

    async handleSubmit() {
        if (this.isCreateMode) {
            await this.handleCreateSubmit();
            return;
        }

        if (this.isClosureMode) {
            await this.handleClosureSubmit();
        }
    }

    async handleCreateSubmit() {
        try {
            const shouldProceed = await this.confirmIfUnregisteredCountries();
            if (!shouldProceed) {
                return;
            }

            this.loading = true;

            const pairs = [];
            this.selectedCountries.forEach(country => {
                if (country === 'BE') {
                    (this.beTypeValues || []).forEach(typeVal => {
                        pairs.push({ country: 'BE', typeValue: typeVal });
                    });
                } else {
                    pairs.push({ country, typeValue: 'Transparency' });
                }
            });

            const result = await createTaxDataPairs({
                shareClassId: this.recordId,
                pairsJson: JSON.stringify(pairs),
                comment: this.comment
            });

            const created = result?.createdCount || 0;
            const failedByCountry = result?.failedByCountry || {};
            const failedKeys = Object.keys(failedByCountry);
            const serverMessage = (result?.message || '').trim();

            if (created === 0) {
                if (failedKeys.length > 0) {
                    const details = failedKeys.map(k => `${k}: ${failedByCountry[k]}`).join(' ; ');
                    this.showToast('No records created', details, 'error');
                } else if (serverMessage) {
                    this.showToast('No records created', serverMessage, 'warning');
                } else {
                    this.showToast('No records created', 'No records were created. Please check inputs or validations.', 'warning');
                }
                return;
            }

            if (failedKeys.length === 0) {
                this.showToast('Success', `Created: ${created}`, 'success');
            } else {
                const details = failedKeys.map(k => `${k}: ${failedByCountry[k]}`).join(' ; ');
                this.showToast('Partial Success', `Created: ${created} • Failed: ${failedKeys.length} — ${details}`, 'warning');
            }

            getRecordNotifyChange([{ recordId: this.recordId }]);
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (err) {
            this.showToast('Error', this.getErrorMessage(err), 'error');
        } finally {
            this.loading = false;
        }
    }

    async handleClosureSubmit() {
        try {
            this.loading = true;

            const result = await submitClosureRequests({
                shareClassId: this.recordId,
                selectionKeys: this.selectedClosureKeys
            });

            const updated = result?.updatedCount || 0;
            const failedByCountry = result?.failedByCountry || {};
            const failedKeys = Object.keys(failedByCountry);
            const serverMessage = (result?.message || '').trim();

            if (updated === 0) {
                if (failedKeys.length > 0) {
                    const details = failedKeys.map(k => `${k}: ${failedByCountry[k]}`).join(' ; ');
                    this.showToast('No records updated', details, 'error');
                } else if (serverMessage) {
                    this.showToast('No records updated', serverMessage, 'warning');
                } else {
                    this.showToast('No records updated', 'No closure request could be submitted.', 'warning');
                }
                return;
            }

            if (failedKeys.length === 0) {
                this.showToast('Success', `Closure request submitted for ${updated} record(s).`, 'success');
            } else {
                const details = failedKeys.map(k => `${k}: ${failedByCountry[k]}`).join(' ; ');
                this.showToast('Partial Success', `Updated: ${updated} • Failed: ${failedKeys.length} — ${details}`, 'warning');
            }

            getRecordNotifyChange([{ recordId: this.recordId }]);
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (err) {
            this.showToast('Error', this.getErrorMessage(err), 'error');
        } finally {
            this.loading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getErrorMessage(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || JSON.stringify(error);
    }
}