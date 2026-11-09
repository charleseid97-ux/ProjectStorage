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
    typeSections = [];

    selectedProducts = [];
    selectedMedia = [];
    selectedCountry = '';
    selectedLanguage = '';

    builderOptions;
    footnotePicklists;
    endDisclaimerPicklists;

    filtersExpanded = true;
    isLoading = false;
    hasSearched = false;
    previewResult;

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
        return this.isLoading || !this.hasSearched;
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
        this.typeSections = buildTypeSections(picklists, this.builderOptions.logicalRuleType);
    }

    toggleFilters() {
        this.filtersExpanded = !this.filtersExpanded;
    }

    // Country, Language, Products: the property to set is the input's data-field.
    handleValueChange(event) {
        this[event.target.dataset.field] = event.detail.value;
        this.hasSearched = false;
    }

    handleMediaChange(event) {
        if (event.detail.isSearchChange) return;
        this.selectedMedia = event.detail.selectedValues || [];
        this.hasSearched = false;
    }

    handleTypeChange(event) {
        const type = event.target.dataset.type;
        this.typeSections = this.typeSections.map(section => (section.type === type ? { ...section, selected: event.detail.value } : section));
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
        }
        catch (error) {
            showToast(this, 'Error', reduceError(error), 'error');
        }
        finally {
            this.isLoading = false;
        }
    }

    // Only the Types with selected Sub Types are sent: { Type: [Sub Types] }.
    buildCriteria() {
        const subTypesByType = {};
        this.typeSections
            .filter(section => section.selected.length)
            .forEach(section => {
                subTypesByType[section.type] = section.selected;
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
