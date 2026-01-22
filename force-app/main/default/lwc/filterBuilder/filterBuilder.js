import { LightningElement, api, track } from 'lwc';

export default class FilterBuilder extends LightningElement {
    @api objectOptions = [];
    @api filterLogicOptions = [];
    @api showValuesWhenNotSelecting = false;
    @api filterValueSeparator = ';';
    @api fieldsByObject = {};
    @api operatorsByField = {};
    @api defaultFilterOperator = 'IN';
    @api picklistValuesByField = {};
    @api filterLimit = 10;
    @api startingLogicType;
    @api filterPicklistEmptyVal = { label: '-- None --', value: '' }
    
    @track criteriaState = { filterLogicType: null, filterLogicText: '', details: [] };

    nextId = 1;

    connectedCallback() {
        this.startingLogicType = this.startingLogicType || 'AND';
        this.initializeCriteriaState();
    }

    // -------- Computed ----------
    get showFiltersSection() {
        return (this.criteriaState.details || []).length >= 1;
    }

    get haveMoreThanOneFilter() {
        return (this.criteriaState.details || []).length > 1;
    }

    get canAddFilter() {
        return (this.criteriaState.details || []).length < this.filterLimit;
    }

    get showFilterLogicExpression() {
        return this.haveMoreThanOneFilter && this.criteriaState.filterLogicType === 'Custom Logic';
    }

    get applyFiltersDisabled() {
        const details = this.criteriaState.details || [];
        if (!details.length) {
            return false;
        }
        const isFilled = d => !!d.objectApi && !!d.fieldApi && !!d.operator;
        if (details.length === 1) {
            const d = details[0];
            const hasAny = !!d.objectApi || !!d.fieldApi || !!d.operator;
            return hasAny && !isFilled(d);
        }
        return details.some(d => !isFilled(d));
    }

    // -------- Initialization ----------
    initializeCriteriaState() {
        this.criteriaState = { filterLogicType: null, filterLogicText: '', details: [] };
        this.criteriaState = { ...this.criteriaState, filterLogicType: this.startingLogicType || 'AND' };
        this.addEmptyFilterInternal();
    }

    cloneDetails(details) {
        return (details || []).map(d => ({ ...d, multiValue: Array.isArray(d.multiValue) ? [...d.multiValue] : [] }));
    }

    // -------- Handlers ----------
    handleDetailChange(event) {
        const id = event.currentTarget.dataset.id;
        const field = event.currentTarget.dataset.field;
        const value = event.detail.value;
        this.criteriaState = { ...this.criteriaState, details: this.updateDetails(id, field, value) };
    }

    handleMultiSelection(event) {
        let isSearchChange = event.detail && event.detail.isSearchChange;
        if(!isSearchChange) {
            const id = event.currentTarget.dataset.id;
            const selectedValues = event.detail.selectedValues || [];
            const value = selectedValues.join(this.filterValueSeparator);
            this.criteriaState = { ...this.criteriaState, details: this.updateDetails(id, 'value', value, selectedValues)};
        }
    }

    handleRefreshMultiSelectSearchList(id, multiSelectSearchRefreshArray) {
        const multiSelectSearchList = this.template.querySelector('c-multi-select-search-list[data-id=' + id + ']');
        if (multiSelectSearchList) {
            multiSelectSearchList.refreshOptions(multiSelectSearchRefreshArray);
        }
    }

    handleAddFilter() {
        if (!this.canAddFilter) {
            return;
        }
        this.addEmptyFilterInternal();
    }

    handleRemoveFilter(event) {
        const id = event.currentTarget.dataset.id;
        const newDetails = [];
        let index = 0;
        for (let i = 0; i < this.criteriaState.details.length; i++) {
            const d = this.criteriaState.details[i];
            if (d.id !== id) {
                index++;
                newDetails.push(this.setNewCriteriaDetails(d.id, index, d.objectApi, d.fieldApi, d.operator, d.value, d.fieldOptions, d.fieldInputDisabled, d.operatorOptions, d.operatorInputDisabled, d.picklistValues, d.isPicklistField, d.operatorExpectsMulti, d.multiValue));
            }
        }

        const updatedLogicType = newDetails.length === 1 ? this.startingLogicType : this.criteriaState.filterLogicType;
        const updatedLogicText = newDetails.length === 1 ? '' : this.criteriaState.filterLogicText;

        this.criteriaState = {
            ...this.criteriaState,
            filterLogicType: updatedLogicType,
            filterLogicText: updatedLogicText,
            details: newDetails
        };
    }

    handleFilterLogicTypeChange(event) {
        this.criteriaState = { ...this.criteriaState, filterLogicType: event.detail.value };
    }

    handleFilterLogicTextChange(event) {
        this.criteriaState = { ...this.criteriaState, filterLogicText: event.detail.value };
    }

    handleApplyFilters() {
        this.dispatchEvent(new CustomEvent('applyfilters', { detail: { criteria: this.cloneCriteriaForDispatch() } }));
    }

    @api handleResetFilters() {
        this.initializeCriteriaState();
        this.dispatchEvent(new CustomEvent('resetfilters'));
    }

    // -------- Detail manipulation ----------
    addEmptyFilterInternal() {
        const newDetail = this.setNewCriteriaDetails('tmp-' + this.nextId, (this.criteriaState.details.length + 1), null, null, null, '', [], true, [], true, [], false);
        this.nextId += 1;
        const details = [...(this.criteriaState.details || []), newDetail];
        this.criteriaState = { ...this.criteriaState, details };
    }

    updateDetails(id, field, value, multiValue) {
        return this.criteriaState.details.map(d => {
            if (d.id !== id) {
                return d;
            }
            let clone = this.cloneDetail(d);
            clone = this.applyDetailChange(clone, field, value, multiValue);
            return clone;
        });
    }

    cloneDetail(detail) {
        return this.setNewCriteriaDetails(detail.id, detail.filterNumber, detail.objectApi, detail.fieldApi, detail.operator, detail.value, detail.fieldOptions, detail.fieldInputDisabled, detail.operatorOptions, detail.operatorInputDisabled, detail.picklistValues, detail.isPicklistField, detail.operatorExpectsMulti, detail.multiValue);
    }

    applyDetailChange(clone, field, value, multiValue) {
        clone[field] = value;
        if (field === 'value' && multiValue !== undefined) {
            clone.multiValue = multiValue;
        }
        switch (field) {
            case 'objectApi':
                return this.applyObjectChange(clone, value);
            case 'fieldApi':
                return this.applyFieldApiChange(clone, value);
            case 'operator':
                return this.applyOperatorChange(clone, value);
            default:
                return clone;
        }
    }

    applyObjectChange(clone, objectApi) {
        clone.fieldApi = null;
        clone.fieldOptions = this.getFieldOptionsForObject(objectApi);
        clone.operator = null;
        clone.operatorOptions = [];
        clone.fieldInputDisabled = false;
        clone.operatorInputDisabled = true;
        clone.picklistValues = [];
        clone.isPicklistField = false;
        clone.operatorExpectsMulti = false;
        clone.value = '';
        clone.multiValue = [];
        return clone;
    }

    applyFieldApiChange(clone, fieldApi) {
        clone.operatorOptions = this.getOperatorOptionsForField(clone.objectApi, fieldApi);
        const operatorStillValid = clone.operatorOptions.some(o => o.value === clone.operator);
        const defaultOperatorValid = clone.operatorOptions.some(o => o.value === this.defaultFilterOperator);
        clone.operator = operatorStillValid ? clone.operator : defaultOperatorValid? this.defaultFilterOperator : null;
        clone.operatorInputDisabled = false;
        clone.picklistValues = [...this.getPicklistValuesForField(clone.objectApi, fieldApi)];
        clone.isPicklistField = this.checkIfFieldIsPicklist(clone, fieldApi);
        clone.operatorExpectsMulti = clone.isPicklistField && (clone.operator === 'IN' || clone.operator === 'NOT IN');
        clone.multiValue = [];
        if (clone.operatorExpectsMulti) {
            clone.picklistValues = (clone.picklistValues || []).filter(opt => opt.value !== '');
        }
        clone = this.applyOperatorChange(clone, clone.operator);
        this.handleRefreshMultiSelectSearchList(clone.id, clone.picklistValues);
        return clone;
    }

    applyOperatorChange(clone, operator) {
        clone.isPicklistField = this.checkIfFieldIsPicklist(clone, clone.fieldApi);
        clone.operatorExpectsMulti = clone.isPicklistField && (operator === 'IN' || operator === 'NOT IN');
        const picklistValuesCopy = Array.isArray(clone.picklistValues) ? [...clone.picklistValues] : [];
        if (clone.operatorExpectsMulti) {
            const filtered = picklistValuesCopy.filter(opt => opt.value !== '');
            clone.picklistValues = filtered;
            if (clone.multiValue.length === 0 && clone.value && clone.picklistValues.some(opt => opt.value === clone.value)) {
                clone.multiValue.push(clone.value);
            }
            clone.value = clone.multiValue.join(this.filterValueSeparator);
        } else {
            if (!picklistValuesCopy.some(opt => opt.value === '')) {
                picklistValuesCopy.unshift(this.filterPicklistEmptyVal);
            }
            clone.picklistValues = picklistValuesCopy;
            clone.value = clone.value && clone.value.length > 0 ? clone.value.split(this.filterValueSeparator)[0] : '';
        }
        return clone;
    }

    checkIfFieldIsPicklist(clone, value) {
        let fieldTypeIsPicklist = clone.fieldOptions.some(o => o.value === value && (o.type === 'PICKLIST' || o.type === 'MULTIPICKLIST'));
        let fieldTypeIsString = clone.fieldOptions.some(o => o.value === value && (o.type === 'STRING'));
        return (fieldTypeIsPicklist || (fieldTypeIsString && (clone.objectApi == 'Product__c' || clone.objectApi == 'Strategy__c') && !(clone.operator === 'LIKE' || clone.operator === 'NOT {_} LIKE')));
    }

    setNewCriteriaDetails(id, filterNumber, objectApi, fieldApi, operator, value, fieldOptions, fieldInputDisabled, operatorOptions, operatorInputDisabled, picklistValues, isPicklistField, operatorExpectsMulti, multiValue) {
        return {
            id: id,
            filterNumber: filterNumber,
            filterCode: '~F' + filterNumber + '~',
            objectApi: objectApi,
            fieldApi: fieldApi,
            operator: operator,
            value: value,
            fieldOptions: Array.isArray(fieldOptions) ? [...fieldOptions] : [],
            fieldInputDisabled: fieldInputDisabled,
            operatorOptions: Array.isArray(operatorOptions) ? [...operatorOptions] : [],
            operatorInputDisabled: operatorInputDisabled,
            picklistValues: Array.isArray(picklistValues) ? [...picklistValues] : [],
            isPicklistField: isPicklistField,
            operatorExpectsMulti: operatorExpectsMulti,
            multiValue: Array.isArray(multiValue) ? [...multiValue] : []
        };
    }

    // -------- Helpers ----------
    getFieldOptionsForObject(objectApi) {
        const opts = (this.fieldsByObject && this.fieldsByObject[objectApi]) ? this.fieldsByObject[objectApi] : [];
        return Array.isArray(opts) ? [...opts] : [];
    }

    getOperatorOptionsForField(objectApi, fieldApi) {
        const key = objectApi && fieldApi ? objectApi + '.' + fieldApi : null;
        const opts = (key && this.operatorsByField && this.operatorsByField[key]) ? this.operatorsByField[key] : [];
        return Array.isArray(opts) ? [...opts] : [];
    }

    getPicklistValuesForField(objectApi, fieldApi) {
        const key = objectApi && fieldApi ? objectApi + '.' + fieldApi : null;
        const vals = (key && this.picklistValuesByField && this.picklistValuesByField[key]) ? this.picklistValuesByField[key] : [];
        return Array.isArray(vals) ? [...vals] : [];
    }

    cloneCriteriaForDispatch() {
        return {
            filterLogicType: this.criteriaState.filterLogicType,
            filterLogicText: this.criteriaState.filterLogicText,
            details: this.cloneDetails(this.criteriaState.details)
        };
    }
}