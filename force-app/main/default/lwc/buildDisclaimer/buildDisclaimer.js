/**
 * @description	: Disclaimer Builder demo screen - lets a user pick Products/Source/Content/Media/Country,
 *                    search matching Disclaimer-record-type Narrative__c records, preview the concatenated
 *                    Footnote/End Disclaimer content, then build the Disclaimer__c + DisclaimerDetail__c records.
 * @author		    : Charles EID
**/
import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { showToast, reduceError } from 'c/gridBuilderUtils';
import searchNarratives from '@salesforce/apex/DisclaimerBuilderController.searchNarratives';
import buildDisclaimer from '@salesforce/apex/DisclaimerBuilderController.buildDisclaimer';

const PRODUCT_OPTIONS = [
    { label: 'CI', value: 'CI' },
    { label: 'CP', value: 'CP' },
    { label: 'CSC', value: 'CSC' },
    { label: 'PP', value: 'PP' }
];

const SOURCE_OPTIONS = [
    { label: 'Carmignac', value: 'Carmignac' },
    { label: 'Morningstar', value: 'Morningstar' },
    { label: 'MSCI', value: 'MSCI' }
];

const CONTENT_OPTIONS = [
    { label: 'Simulated Performances', value: 'Simulated Performances' },
    { label: 'Performance', value: 'Performance' },
    { label: 'Risk Scale', value: 'Risk Scale' },
    { label: 'Rating', value: 'Rating' }
];

const MEDIA_OPTIONS = [
    { label: 'Website', value: 'Website' }
];

const COUNTRY_OPTIONS = [
    { label: 'Belgium', value: 'BE' },
    { label: 'Italy', value: 'IT' }
];

export default class BuildDisclaimer extends NavigationMixin(LightningElement) {
    productOptions = PRODUCT_OPTIONS;
    sourceOptions = SOURCE_OPTIONS;
    contentOptions = CONTENT_OPTIONS;
    mediaOptions = MEDIA_OPTIONS;
    countryOptions = COUNTRY_OPTIONS;

    selectedProducts = [];
    selectedSources = [];
    selectedContentTypes = [];
    selectedMedia = [];
    selectedCountry = '';

    isLoading = false;
    hasSearched = false;
    previewResult;

    get isSearchDisabled() {
        return this.isLoading
            || !this.selectedProducts.length
            || !this.selectedSources.length
            || !this.selectedContentTypes.length
            || !this.selectedMedia.length
            || !this.selectedCountry;
    }

    get isBuildDisabled() {
        return this.isLoading || !this.hasSearched;
    }

    get footnoteContent() {
        return this.previewResult?.footnote?.content || '';
    }

    get footnoteCount() {
        return this.previewResult?.footnote?.matchCount || 0;
    }

    get endDisclaimerContent() {
        return this.previewResult?.endDisclaimer?.content || '';
    }

    get endDisclaimerCount() {
        return this.previewResult?.endDisclaimer?.matchCount || 0;
    }

    handleProductsChange(event) {
        this.selectedProducts = event.detail.value;
        this.hasSearched = false;
    }

    handleSourceChange(event) {
        if (event.detail.isSearchChange) return;
        this.selectedSources = event.detail.selectedValues || [];
        this.hasSearched = false;
    }

    handleContentChange(event) {
        this.selectedContentTypes = event.detail.value;
        this.hasSearched = false;
    }

    handleMediaChange(event) {
        if (event.detail.isSearchChange) return;
        this.selectedMedia = event.detail.selectedValues || [];
        this.hasSearched = false;
    }

    handleCountryChange(event) {
        this.selectedCountry = event.detail.value;
        this.hasSearched = false;
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Disclaimer__c',
                actionName: 'list'
            }
        });
    }

    async handleSearch() {
        try {
            this.isLoading = true;
            const criteriaJson = JSON.stringify(this.buildCriteria());
            this.previewResult = await searchNarratives({ criteriaJson });
            this.hasSearched = true;
        } catch (error) {
            showToast(this, 'Error', reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleBuild() {
        try {
            this.isLoading = true;
            const criteriaJson = JSON.stringify(this.buildCriteria());
            const previewJson = JSON.stringify(this.previewResult);
            const disclaimerId = await buildDisclaimer({ criteriaJson, previewJson });
            showToast(this, 'Success', 'Disclaimer built successfully', 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: disclaimerId,
                    objectApiName: 'Disclaimer__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            showToast(this, 'Error', reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    buildCriteria() {
        return {
            products: this.selectedProducts,
            sources: this.selectedSources,
            contentTypes: this.selectedContentTypes,
            media: this.selectedMedia,
            country: this.selectedCountry
        };
    }
}
