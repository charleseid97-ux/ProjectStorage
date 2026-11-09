/**
 * @description	: Disclaimer Builder screen - lets a user pick Country/Language/Media, Products and, per Narrative Type, its Sub Types,
 *                    search the matching Footnote / End Disclaimer Narrative__c records, preview the concatenated content,
 *                    then build the Disclaimer__c + DisclaimerDetail__c records.
 *                    Every option comes from the org: picklists (values, Type => Sub Type dependency) of the 2 disclaimer record types, valid products from Apex.
 *                    A new Type with its Sub Types shows up as a new box without code change.
 * @author		    : Charles EID
**/
import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import NARRATIVE_OBJECT from '@salesforce/schema/Narrative__c';
import { showToast, reduceError } from 'c/gridBuilderUtils';
import getBuilderOptions from '@salesforce/apex/DisclaimerBuilderController.getBuilderOptions';
import searchNarratives from '@salesforce/apex/DisclaimerBuilderController.searchNarratives';
import buildDisclaimer from '@salesforce/apex/DisclaimerBuilderController.buildDisclaimer';

const TYPE_FIELD = 'Type__c';
const SUBTYPE_FIELD = 'SubType__c';
const COUNTRY_FIELD = 'Country__c';
const LANGUAGE_FIELD = 'Language__c';
const MEDIA_FIELD = 'Media__c';
const SHOWN_VALUES_IN_SUMMARY = 2;

// Values of a picklist field across record types, without duplicates, in picklist order.
function mergeValues(picklists, fieldName) {
    const labelByValue = new Map();
    picklists.forEach(picklist => {
        (picklist.picklistFieldValues[fieldName]?.values || []).forEach(option => {
            if (!labelByValue.has(option.value)) labelByValue.set(option.value, option.label);
        });
    });
    return [...labelByValue].map(([value, label]) => ({ label, value }));
}

// One section per Type having Sub Types on the record types (Type => Sub Types from the dependency), the excluded Type (Logical Rule) left out.
function buildTypeSections(picklists, excludedType) {
    const sectionByType = new Map();
    picklists.forEach(picklist => {
        const subTypeField = picklist.picklistFieldValues[SUBTYPE_FIELD];
        if (!subTypeField) return;
        (picklist.picklistFieldValues[TYPE_FIELD]?.values || []).forEach(type => {
            if (type.value === excludedType) return;
            const index = subTypeField.controllerValues[type.value];
            if (!sectionByType.has(type.value)) sectionByType.set(type.value, { type: type.value, label: type.label, optionByValue: new Map() });
            const section = sectionByType.get(type.value);
            subTypeField.values
                .filter(subType => subType.validFor.includes(index))
                .forEach(subType => section.optionByValue.set(subType.value, subType.label));
        });
    });
    return [...sectionByType.values()]
        .filter(section => section.optionByValue.size)
        .map(section => ({
            type: section.type,
            label: section.label,
            options: [...section.optionByValue].map(([value, label]) => ({ label, value })),
            selected: []
        }));
}

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

    builderOptions;
    footnotePicklists;
    endDisclaimerPicklists;

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
            this.productOptions = data.products;
            this.buildFilterOptions();
        }
        else if (error) {
            showToast(this, 'Error', reduceError(error), 'error');
        }
    }

    @wire(getPicklistValuesByRecordType, { objectApiName: NARRATIVE_OBJECT, recordTypeId: '$builderOptions.footnoteRecordTypeId' })
    wiredFootnotePicklists({ data, error }) {
        this.storePicklists('footnotePicklists', data, error);
    }

    @wire(getPicklistValuesByRecordType, { objectApiName: NARRATIVE_OBJECT, recordTypeId: '$builderOptions.endDisclaimerRecordTypeId' })
    wiredEndDisclaimerPicklists({ data, error }) {
        this.storePicklists('endDisclaimerPicklists', data, error);
    }

    get isSearchDisabled() {
        return this.isLoading || !this.selectedCountry || !this.selectedLanguage;
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

    storePicklists(propertyName, data, error) {
        if (data) {
            this[propertyName] = data;
            this.buildFilterOptions();
        }
        else if (error) {
            showToast(this, 'Error', reduceError(error), 'error');
        }
    }

    // Built once the Apex options and both record types' picklists are loaded.
    buildFilterOptions() {
        if (!this.builderOptions || !this.footnotePicklists || !this.endDisclaimerPicklists) return;
        const picklists = [this.footnotePicklists, this.endDisclaimerPicklists];
        this.countryOptions = mergeValues(picklists, COUNTRY_FIELD);
        this.languageOptions = mergeValues(picklists, LANGUAGE_FIELD);
        this.mediaOptions = mergeValues(picklists, MEDIA_FIELD);
        if (this.tabs.length) return;
        this.tabs = [this.newTab(true), this.newTab(false)];
        this.activeTabId = this.tabs[0].id;
    }

    // A footnote tab (Footnote, Footnote 2...) or the End Disclaimer tab, with the Types of its record type.
    newTab(isFootnote) {
        this.tabCount += 1;
        const footnoteNumber = this.tabs.filter(tab => tab.isFootnote).length + 1;
        const footnoteLabel = footnoteNumber === 1 ? 'Footnote' : `Footnote ${footnoteNumber}`;
        return {
            id: `tab-${this.tabCount}`,
            label: isFootnote ? footnoteLabel : 'End Disclaimer',
            isFootnote,
            recordTypeId: isFootnote ? this.builderOptions.footnoteRecordTypeId : this.builderOptions.endDisclaimerRecordTypeId,
            typeSections: buildTypeSections([isFootnote ? this.footnotePicklists : this.endDisclaimerPicklists], this.builderOptions.logicalRuleType),
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

    // Country, Language, Products: the property to set is the input's data-field.
    handleValueChange(event) {
        this[event.target.dataset.field] = event.detail.value;
        this.resetSearches();
    }

    handleMediaChange(event) {
        if (event.detail.isSearchChange) return;
        this.selectedMedia = event.detail.selectedValues || [];
        this.resetSearches();
    }

    handleTypeChange(event) {
        const type = event.target.dataset.type;
        const typeSections = this.typeSections.map(section => (section.type === type ? { ...section, selected: event.detail.value } : section));
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
                subTypesByType[section.type] = [...new Set([...(subTypesByType[section.type] || []), ...section.selected])];
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
