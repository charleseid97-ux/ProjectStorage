import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getContext from '@salesforce/apex/RegistrationCountryActionController.getContext';
import submitRegistrationCountryRequest from '@salesforce/apex/RegistrationCountryActionController.submitRegistrationCountryRequestJson';

export default class RegistrationCountryAction extends LightningElement {
    _recordId;
    contextRequestRecordId;

    // Tracks asynchronous processing and blocking context errors.
    loading = true;
    loadError = '';

    // Stores the active type and the independent country selections.
    registrationType = null;
    allCountryOptions = [];
    selectedCountriesByType = {
        Retail: [],
        Institutional: [],
        'Semi-Pro': []
    };

    // Stores the shared comment and confirmation popup state.
    comment = '';
    showConfirmation = false;

    // Returns the current Share Class record identifier.
    @api
    get recordId() {
        return this._recordId;
    }

    // Loads the component context when Salesforce provides the record identifier.
    set recordId(value) {
        this._recordId = value;

        if (value) {
            this.loadContext();
        }
    }

    // Loads the active CountryRegNeeded values and verifies Share Class access.
    async loadContext() {
        const recordId = this._recordId;
        if (!recordId || this.contextRequestRecordId === recordId) {
            return;
        }

        this.contextRequestRecordId = recordId;
        this.loading = true;
        this.loadError = '';

        try {
            // Keeps only the active options returned by the Apex controller.
            const context = await getContext({ shareClassId: recordId });
            this.allCountryOptions = context?.countryOptions || [];
        } catch (error) {
            this.contextRequestRecordId = null;
            this.loadError = this.getErrorMessage(error);
            this.showToast('Error', this.loadError, 'error');
        } finally {
            this.loading = false;
        }
    }

    // Selects one registration type without clearing saved countries.
    handleTypeSelect(event) {
        this.registrationType = event.currentTarget.dataset.type;
    }

    // Stores a copied country array for the currently displayed type.
    handleCountriesChange(event) {
        const countries = Array.isArray(event.detail.value)
            ? [...event.detail.value]
            : [];

        this.selectedCountriesByType = {
            ...this.selectedCountriesByType,
            [this.registrationType]: countries
        };
    }

    // Stores the optional comment shared by all registration types.
    handleCommentChange(event) {
        this.comment = event.detail.value || '';
    }

    // Closes the quick action without submitting the current selections.
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // Opens the recap popup only when countries have been selected.
    handleSubmit() {
        if (this.registrationRequests.length === 0) {
            this.showToast(
                'Error',
                'At least one registration country is required.',
                'error'
            );
            return;
        }

        this.showConfirmation = true;
    }

    // Closes the recap popup and preserves the current selections.
    handleConfirmationCancel() {
        this.showConfirmation = false;
    }

    // Submits all populated types as one serialized request after confirmation.
    async handleConfirmationSubmit() {
        const countriesByType = {
            retailCountries: [
                ...(this.selectedCountriesByType.Retail || [])
            ],
            institutionalCountries: [
                ...(this.selectedCountriesByType.Institutional || [])
            ],
            semiProCountries: [
                ...(this.selectedCountriesByType['Semi-Pro'] || [])
            ]
        };

        // Prevents the Apex call when every registration type is empty.
        const hasCountries =
            countriesByType.retailCountries.length > 0 ||
            countriesByType.institutionalCountries.length > 0 ||
            countriesByType.semiProCountries.length > 0;

        if (!hasCountries) {
            this.showConfirmation = false;
            this.showToast(
                'Error',
                'At least one registration country is required.',
                'error'
            );
            return;
        }

        this.showConfirmation = false;
        this.loading = true;

        try {
            // Sends one primitive JSON parameter containing all selections.
            const result = await submitRegistrationCountryRequest({
                shareClassId: this._recordId,
                countriesByTypeJson: JSON.stringify(countriesByType),
                comment: this.comment
            });

            // Keeps the form open when the future external API fails.
            if (result?.failed) {
                this.showToast(
                    'Submission failed',
                    result.message || 'The external submission failed.',
                    'error'
                );
                return;
            }

            // Uses the appropriate toast according to the returned status.
            const toastTitle = result?.submitted
                ? 'Success'
                : 'Request prepared';
            const toastVariant =
                result?.submitted && result?.notificationSent === false
                    ? 'warning'
                    : result?.submitted
                        ? 'success'
                        : 'info';

            this.showToast(
                toastTitle,
                result?.message || 'Request processed.',
                toastVariant
            );
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    // Builds one confirmation line per populated registration type.
    get confirmationRows() {
        const labelsByValue = new Map(
            this.allCountryOptions.map(option => [option.value, option.label])
        );

        return this.registrationRequests.map(request => ({
            type: request.registrationType,
            countries: request.countries
                .map(country => labelsByValue.get(country) || country)
                .join(', ')
        }));
    }

    // Returns true when context loading failed.
    get hasLoadError() {
        return Boolean(this.loadError);
    }

    // Returns true after a distribution type has been selected.
    get hasRegistrationType() {
        return Boolean(this.registrationType);
    }

    // Returns countries selected for the currently displayed type.
    get selectedCountries() {
        if (!this.registrationType) {
            return [];
        }

        return this.selectedCountriesByType[this.registrationType] || [];
    }

    // Hides countries already selected for another distribution type.
    get countryOptions() {
        if (!this.registrationType) {
            return this.allCountryOptions;
        }

        const currentSelections = new Set(this.selectedCountries);
        const unavailableCountries = new Set();

        // Collects countries assigned to the other distribution types.
        Object.keys(this.selectedCountriesByType).forEach(type => {
            if (type !== this.registrationType) {
                this.selectedCountriesByType[type].forEach(country => {
                    unavailableCountries.add(country);
                });
            }
        });

        return this.allCountryOptions.filter(option =>
            currentSelections.has(option.value) ||
            !unavailableCountries.has(option.value)
        );
    }

    // Returns every populated type in the fixed business order.
    get registrationRequests() {
        return ['Retail', 'Institutional', 'Semi-Pro']
            .map(type => ({
                registrationType: type,
                countries: this.selectedCountriesByType[type] || []
            }))
            .filter(request => request.countries.length > 0);
    }

    // Applies the selected visual state to the Retail card.
    get retailCardClass() {
        return this.registrationType === 'Retail'
            ? 'mode-card selected'
            : 'mode-card';
    }

    // Applies the selected visual state to the Institutional card.
    get institutionalCardClass() {
        return this.registrationType === 'Institutional'
            ? 'mode-card selected'
            : 'mode-card';
    }

    // Applies the selected visual state to the Semi-Pro card.
    get semiProCardClass() {
        return this.registrationType === 'Semi-Pro'
            ? 'mode-card selected'
            : 'mode-card';
    }

    // Exposes the Retail selection state for accessibility.
    get isRetailSelected() {
        return this.registrationType === 'Retail';
    }

    // Exposes the Institutional selection state for accessibility.
    get isInstitutionalSelected() {
        return this.registrationType === 'Institutional';
    }

    // Exposes the Semi-Pro selection state for accessibility.
    get isSemiProSelected() {
        return this.registrationType === 'Semi-Pro';
    }

    // Blocks submission until at least one type contains countries.
    get submitDisabled() {
        return this.hasLoadError || this.registrationRequests.length === 0;
    }

    // Dispatches a standard Lightning toast message.
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    // Extracts the most useful Apex or JavaScript error message.
    getErrorMessage(error) {
        if (!error) {
            return 'Unknown error';
        }

        if (Array.isArray(error.body)) {
            return error.body
                .map(item => item.message)
                .join(', ');
        }

        if (error.body?.message) {
            return error.body.message;
        }

        return error.message || JSON.stringify(error);
    }
}