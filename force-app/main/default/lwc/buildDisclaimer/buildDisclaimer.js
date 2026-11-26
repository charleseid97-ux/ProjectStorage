/**
 * @description	: Disclaimer Builder screen, a 2-step path:
 *                    1. General Settings: Country, Language, Media and whether products are chosen, shared by every tab of step 2.
 *                    2. Disclaimer Content: Footnote / End Disclaimer tabs, each picking per Narrative Type its Sub Types (and the shared Products when chosen in step 1),
 *                       searching the matching Narrative__c records of its record type and previewing the concatenated content, then building the Disclaimer__c + DisclaimerDetail__c records.
 *                    Every option comes from Apex: Country / Language / Media from the field describe, valid products, and on the way to step 2 the Type => Sub Types sections of each record type,
 *                    built from the narratives matching the step 1 settings (only Sub Types that find narratives, picklist dependency respected).
 *                    A new Type with its Sub Types shows up as a new box without code change.
 * @author		    : Charles EID
 * @lastModifiedBy  : Charles EID   [26-11-26]
**/
import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { showToast, reduceError } from 'c/gridBuilderUtils';
import getBuilderOptions from '@salesforce/apex/DisclaimerBuilderController.getBuilderOptions';
import getContentOptions from '@salesforce/apex/DisclaimerBuilderController.getContentOptions';
import searchNarratives from '@salesforce/apex/DisclaimerBuilderController.searchNarratives';
import buildDisclaimer from '@salesforce/apex/DisclaimerBuilderController.buildDisclaimer';

const SHOWN_VALUES_IN_SUMMARY = 2;
const GENERAL_STEP = '1';
const CONTENT_STEP = '2';

// One bucket from several (footnote tabs merged into the single Footnote detail).
function mergeBuckets(buckets) {
    return {
        content: buckets.map(bucket => bucket.content).filter(Boolean).join('\n\n'),
        narrativeIds: buckets.flatMap(bucket => bucket.narrativeIds),
        matchCount: buckets.reduce((total, bucket) => total + bucket.matchCount, 0)
    };
}

// "Name: a, b +3" (first values shown) or "Name (5)" when no value is shown.
function summarize(name, values, shownCount) {
    if (!values.length) return null;
    const shown = values.slice(0, shownCount);
    const rest = values.length - shown.length;
    if (!shown.length) return `${name} (${rest})`;
    return `${name}: ${shown.join(', ')}${rest ? ` +${rest}` : ''}`;
}

export default class BuildDisclaimer extends NavigationMixin(LightningElement) {
    productOptions = [];
    countryOptions = [];
    languageOptions = [];
    mediaOptions = [];

    selectedProducts = [];
    selectedMedia = [];
    selectedCountry = '';
    selectedLanguage = '';
    includeProducts = false;

    currentStep = GENERAL_STEP;

    builderOptions;
    // Type sections offered per record type for the step 1 settings, reloaded on the way to step 2 once a setting changed.
    contentOptions;
    isContentOptionsStale = true;

    // One tab per footnote, then the End Disclaimer: each holds its record type, Type sections and preview.
    tabs = [];
    activeTabId;
    tabCount = 0;

    filtersExpanded = true;
    isLoading = false;

    @wire(getBuilderOptions)
    wiredBuilderOptions({ data, error }) {
        if (data) {
            this.builderOptions = data;
            this.countryOptions = data.countries;
            this.languageOptions = data.languages;
            this.mediaOptions = data.media;
            this.productOptions = data.products;
        }
        else if (error) {
            showToast(this, 'Error', reduceError(error), 'error');
        }
    }

    get isGeneralStep() {
        return this.currentStep === GENERAL_STEP;
    }

    get isContentStep() {
        return this.currentStep === CONTENT_STEP;
    }

    // Country and Language are required to leave step 1.
    get isGeneralStepValid() {
        return Boolean(this.selectedCountry && this.selectedLanguage);
    }

    get isBackDisabled() {
        return this.isGeneralStep;
    }

    get isNextDisabled() {
        return this.isContentStep || !this.isGeneralStepValid;
    }

    // Path steps: the current one keeps the default style, the other one is clickable (step 2 only once step 1 is valid).
    get generalStepClass() {
        return this.isContentStep ? 'step-enabled' : '';
    }

    get contentStepClass() {
        if (this.isContentStep) return '';
        return this.isGeneralStepValid ? 'step-enabled' : 'step-disabled';
    }

    // Products chosen in step 1: at least one is required to search.
    get isSearchDisabled() {
        return this.isLoading || (this.includeProducts && !this.selectedProducts.length);
    }

    get isBuildDisabled() {
        return this.isLoading || !this.tabs.some(tab => tab.hasSearched);
    }

    get activeTab() {
        return this.tabs.find(tab => tab.id === this.activeTabId);
    }

    get footnoteTabs() {
        return this.toTabItems(this.tabs.filter(tab => tab.isFootnote));
    }

    get endDisclaimerTabs() {
        return this.toTabItems(this.tabs.filter(tab => !tab.isFootnote));
    }

    get typeSections() {
        return this.activeTab?.typeSections || [];
    }

    get hasNoTypeSection() {
        return !this.typeSections.length;
    }

    // A footnote tab still searches the Logical Rule narratives, which have no Type box.
    get noTypeSectionMessage() {
        const message = 'No narrative of this tab matches the General Settings with a Type and Sub Type.';
        return this.activeTab?.isFootnote ? `${message} Search still finds the Logical Rule narratives.` : message;
    }

    get hasSearched() {
        return this.activeTab?.hasSearched;
    }

    get filtersBodyClass() {
        return this.filtersExpanded ? 'filters-body' : 'filters-body slds-hide';
    }

    get filtersIcon() {
        return this.filtersExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get filterSummary() {
        return [
            this.countryOptions.find(option => option.value === this.selectedCountry)?.label,
            this.languageOptions.find(option => option.value === this.selectedLanguage)?.label,
            summarize('Media', this.selectedMedia, SHOWN_VALUES_IN_SUMMARY),
            summarize('Products', this.selectedProducts, SHOWN_VALUES_IN_SUMMARY),
            ...this.typeSections.map(section => summarize(section.label, section.selected, 0))
        ]
            .filter(Boolean)
            .map((label, index) => ({ key: index, label }));
    }

    get previewBucket() {
        const result = this.activeTab?.previewResult;
        if (!result) return null;
        return this.activeTab.isFootnote ? result.footnote : result.endDisclaimer;
    }

    get previewTitle() {
        return `${this.activeTab?.label} (${this.previewBucket?.matchCount || 0} matching narrative(s))`;
    }

    get previewContent() {
        return this.previewBucket?.content || '';
    }

    // Type sections of the step 1 settings: the first load creates the Footnote and End Disclaimer tabs, a reload keeps each tab's Sub Types still offered.
    async loadContentOptions() {
        try {
            this.isLoading = true;
            this.contentOptions = await getContentOptions({ criteriaJson: JSON.stringify(this.buildCriteria([])) });
            if (this.tabs.length) {
                this.tabs = this.tabs.map(tab => ({ ...tab, typeSections: this.buildTypeSections(tab.isFootnote, tab.typeSections) }));
            }
            else {
                this.tabs = [this.newTab(true), this.newTab(false)];
                this.activeTabId = this.tabs[0].id;
            }
            this.isContentOptionsStale = false;
            return true;
        }
        catch (error) {
            showToast(this, 'Error', reduceError(error), 'error');
            return false;
        }
        finally {
            this.isLoading = false;
        }
    }

    // A tab's Type sections for the loaded settings, keeping the selected Sub Types still offered.
    buildTypeSections(isFootnote, previousSections = []) {
        const sections = isFootnote ? this.contentOptions.footnote : this.contentOptions.endDisclaimer;
        return sections.map(section => {
            const offered = new Set(section.options.map(option => option.value));
            const selected = previousSections.find(previous => previous.typeName === section.typeName)?.selected || [];
            return { ...section, selected: selected.filter(value => offered.has(value)) };
        });
    }

    // A footnote tab (Footnote, Footnote 2...) or the End Disclaimer tab, with the Type sections of its record type.
    newTab(isFootnote) {
        this.tabCount += 1;
        const footnoteNumber = this.tabs.filter(tab => tab.isFootnote).length + 1;
        const footnoteLabel = footnoteNumber === 1 ? 'Footnote' : `Footnote ${footnoteNumber}`;
        return {
            id: `tab-${this.tabCount}`,
            label: isFootnote ? footnoteLabel : 'End Disclaimer',
            isFootnote,
            recordTypeId: isFootnote ? this.builderOptions.footnoteRecordTypeId : this.builderOptions.endDisclaimerRecordTypeId,
            typeSections: this.buildTypeSections(isFootnote),
            previewResult: null,
            hasSearched: false
        };
    }

    toTabItems(tabs) {
        return tabs.map(tab => ({ ...tab, isActive: tab.id === this.activeTabId, className: `slds-tabs_default__item${tab.id === this.activeTabId ? ' slds-is-active' : ''}` }));
    }

    updateTab(tabId, changes) {
        this.tabs = this.tabs.map(tab => (tab.id === tabId ? { ...tab, ...changes } : tab));
    }

    // Shared filters changed: every tab's preview is outdated.
    resetSearches() {
        this.tabs = this.tabs.map(tab => ({ ...tab, hasSearched: false }));
    }

    handlePathStepClick(event) {
        this.goToStep(event.currentTarget.dataset.step);
    }

    handleBack() {
        this.goToStep(GENERAL_STEP);
    }

    handleNext() {
        this.goToStep(CONTENT_STEP);
    }

    // Step 2 opens once its Type sections are loaded for the current step 1 settings.
    async goToStep(step) {
        if (step === CONTENT_STEP && !this.isGeneralStepValid) return;
        if (step === CONTENT_STEP && this.isContentOptionsStale && !(await this.loadContentOptions())) return;
        this.currentStep = step;
    }

    // Products no longer chosen: the selection is cleared so it is neither searched nor saved.
    handleIncludeProductsChange(event) {
        this.includeProducts = event.target.checked;
        if (!this.includeProducts) this.selectedProducts = [];
        this.resetSearches();
    }

    handleTabSelect(event) {
        event.preventDefault();
        this.activeTabId = event.currentTarget.dataset.id;
        this.filtersExpanded = !this.activeTab.hasSearched;
    }

    handleAddFootnote(event) {
        event.preventDefault();
        const tab = this.newTab(true);
        this.tabs = [...this.tabs, tab];
        this.activeTabId = tab.id;
        this.filtersExpanded = true;
    }

    toggleFilters() {
        this.filtersExpanded = !this.filtersExpanded;
    }

    handleProductsChange(event) {
        this.selectedProducts = event.detail.value;
        this.resetSearches();
    }

    // Country, Language (mono-select) and Media: the property to set is the list's data-field; the Type sections are reloaded on the way to step 2.
    handleSettingChange(event) {
        if (event.detail.isSearchChange) return;
        this[event.target.dataset.field] = event.detail.selectedValues;
        this.isContentOptionsStale = true;
        this.resetSearches();
    }

    handleTypeChange(event) {
        const typeName = event.target.dataset.type;
        const typeSections = this.typeSections.map(section => (section.typeName === typeName ? { ...section, selected: event.detail.value } : section));
        this.updateTab(this.activeTabId, { typeSections, hasSearched: false });
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

    // Searches the active tab's record type only.
    async handleSearch() {
        try {
            this.isLoading = true;
            const tab = this.activeTab;
            const criteriaJson = JSON.stringify({ ...this.buildCriteria(tab.typeSections), recordTypeId: tab.recordTypeId });
            const previewResult = await searchNarratives({ criteriaJson });
            this.updateTab(tab.id, { previewResult, hasSearched: true });
            this.filtersExpanded = false;
        }
        catch (error) {
            showToast(this, 'Error', reduceError(error), 'error');
        }
        finally {
            this.isLoading = false;
        }
    }

    async handleBuild() {
        try {
            this.isLoading = true;
            const searchedTabs = this.tabs.filter(tab => tab.hasSearched);
            const criteriaJson = JSON.stringify(this.buildCriteria(searchedTabs.flatMap(tab => tab.typeSections)));
            const previewJson = JSON.stringify({
                footnote: mergeBuckets(searchedTabs.filter(tab => tab.isFootnote).map(tab => tab.previewResult.footnote)),
                endDisclaimer: mergeBuckets(searchedTabs.filter(tab => !tab.isFootnote).map(tab => tab.previewResult.endDisclaimer))
            });
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
        }
        catch (error) {
            showToast(this, 'Error', reduceError(error), 'error');
        }
        finally {
            this.isLoading = false;
        }
    }

    // Only the Types with selected Sub Types are sent: { Type: [Sub Types] }, Sub Types of several tabs merged.
    buildCriteria(typeSections) {
        const subTypesByType = {};
        typeSections
            .filter(section => section.selected.length)
            .forEach(section => {
                subTypesByType[section.typeName] = [...new Set([...(subTypesByType[section.typeName] || []), ...section.selected])];
            });
        return {
            products: this.selectedProducts,
            subTypesByType,
            media: this.selectedMedia,
            country: this.selectedCountry,
            language: this.selectedLanguage
        };
    }
}