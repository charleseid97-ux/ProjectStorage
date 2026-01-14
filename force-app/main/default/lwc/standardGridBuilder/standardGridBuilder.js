import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getGridSettings from '@salesforce/apex/GridBuilderController.getGridSettings';
import getAvailableGrids from '@salesforce/apex/GridBuilderController.getAvailableGrids';
import getAgreementSelectionPageSettings from '@salesforce/apex/GridBuilderController.getAgreementSelectionPageSettings';
import getAllProductsForSelection from '@salesforce/apex/GridBuilderController.getAllProductsForSelection';
import getProductsAndShareClasses from '@salesforce/apex/GridBuilderController.getProductsAndShareClasses';

export default class StandardGridBuilder extends LightningElement {
    @api gridBuilderSettingName = 'StandardGridBuilderSetting';

    @track isLoading = true;

    @track showAgreementsPage = false;
    @track showGridBuilderPage = false;
    @track showValidationPage = false;

    // First Page: Agreement Selection
    @track agreementSelectionMode = 'Single';
    @track agreementOptions = [];
    @track availableTeams = [];
    @track primaryTeam;
    @track selectedTeam;
    @track selectedAgreements = [];
    @track agreementStartDate;
    
    // Second Page: Grid Builder
    startingLogicType = 'AND';
    filterValueSeparator = ';';
    filterLogicOptions = [{label: 'AND', value:'AND'},{label: 'OR', value: 'OR'}];
    filterLimit = 10;
    filterPicklistEmptyVal = { label: '-- None --', value: '' }

    allShareTypeOptions = [];
    defaultShareTypeValues = [];
    selectedShareTypes = [];

    objectOptions = [];
    fieldsByObject = {};
    operatorsByField = {};
    picklistValuesByField = {};
    showValuesWhenNotSelecting = true;

    @track gridOptions = [];
    @track selectedGrid;

    @track resultColumns = [];
    @track shareClasses = [];
    @track selectedResultColumns = [];
    @track allQueriedShareClasses = [];
    @track selectedShareClasses = [];
    @track showSelectedPanel = false;

    @track criteriaList = [];
    criteriaCounter = 0;

    @track criteria = {
        grid: null,
        filterLogicType: '',
        filterLogicText: '',
        details: []
    };

    get addToGridDisabled() {
        return !this.selectedGrid || !(this.shareClasses && this.shareClasses.length > 0);
    }

    get validateGridDisabled() {
        return !this.selectedShareClasses || this.selectedShareClasses.length === 0;
    }

    async connectedCallback() {
        try {
            var agreementSettings = await getAgreementSelectionPageSettings({
                gridBuilderSettingName: this.gridBuilderSettingName
            });
            if (agreementSettings) {
                if(!agreementSettings.gridBuilderFound) {
                    this.showToastFunction('Error', 'The Grid Builder Setting "' + this.gridBuilderSettingName + '" was not found. Please contact your system administrator.', 'error');
                    return;
                }
                this.agreementSelectionMode = agreementSettings.agreementSelectionMode;
                this.agreementOptions = agreementSettings.agreementOptions || [];
                this.availableTeams = (agreementSettings.availableTeams || []).map(t => ({ label: t, value: t }));
                this.primaryTeam = agreementSettings.primaryTeam;
                this.selectedTeam = this.primaryTeam || (this.availableTeams.length ? this.availableTeams[0].value : null);
                this.agreementStartDate = new Date().toISOString().split('T')[0];
                this.isLoading = false;
                this.showAgreementsPage = true;
            }
        }
        catch (error) {
            this.showToastFunction('Error', 'Error on agreement settings loading, ' + this.reduceError(error), 'error');
        }
        finally {
            this.isLoading = false;
        }
    }

    async loadGridSettings() {
        try {
            this.isLoading = true;
            var gridSettings = await getGridSettings({
                gridBuilderSettingName: this.gridBuilderSettingName,
                selectedTeam: this.selectedTeam
            });
            if (gridSettings && gridSettings.filterObjects && gridSettings.filterObjects.length > 0) {
                this.setGridSettings(gridSettings);
            }
        }
        catch (error) {
            this.showToastFunction('Error', 'Error on grid settings loading, ' + this.reduceError(error), 'error');
        }
        finally {
            this.isLoading = false;
        }
    }

    setGridSettings(gridSettings) {
        var objectLabelsAndAPINames = [];
        var fieldsByObjectMap = {};
        var operatorsByFieldMap = {};
        var picklistValuesByFieldMap = {};

        var filterObjects = gridSettings.filterObjects;
        var obj, fieldIndex, field;
        for (var index in filterObjects) {
            if (filterObjects.hasOwnProperty(index)) {
                obj = filterObjects[index];
                objectLabelsAndAPINames.push({label: obj.objectLabel, value: obj.objectApiName}); // Object picklist option

                // Field options for this object
                var fieldOptions = [];
                var fields = obj.fields;
                if (fields) {
                    for (fieldIndex in fields) {
                        if (fields.hasOwnProperty(fieldIndex)) {
                            field = fields[fieldIndex];
                            fieldOptions.push({
                                label: field.fieldLabel, 
                                value: field.fieldApiName,
                                type: field.fieldType
                            });

                            var opMapKey = obj.objectApiName + '.' + field.fieldApiName; // Key by "ObjectApi.FieldApi"
                            operatorsByFieldMap[opMapKey] = this.setOperatorOptions(field.operators); // Operator options for this field
                            picklistValuesByFieldMap[opMapKey] = this.setPicklistValuesIfApplicable(field.fieldType, field.fieldValuesAvailable); // Picklist values for this field if field is picklist type
                        }
                    }
                }

                fieldsByObjectMap[obj.objectApiName] = fieldOptions;
            }
        }

        this.filterLogicOptions = gridSettings.filterLogics || this.filterLogicOptions;
        this.startingLogicType = gridSettings.onLoadFilterLogic || this.startingLogicType;
        this.criteria.filterLogicType = this.startingLogicType;
        this.filterLimit = gridSettings.filterLimit || this.filterLimit;
        this.filterValueSeparator = gridSettings.filterValueSeparator || this.filterValueSeparator;

        this.allShareTypeOptions = gridSettings.shareTypeWrp.allShareTypeOptions;
        this.defaultShareTypeValues = gridSettings.shareTypeWrp.defaultShareTypeValues;
        this.selectedShareTypes = this.defaultShareTypeValues;

        this.objectOptions = objectLabelsAndAPINames;
        this.fieldsByObject = fieldsByObjectMap;
        this.operatorsByField = operatorsByFieldMap;
        this.picklistValuesByField = picklistValuesByFieldMap;
    }

    setOperatorOptions(ops) {
        var opOptions = [];
        if(ops) {
            for (var opKey in ops) {
                opOptions.push({label: opKey, value: ops[opKey]});
            }
        }
        return opOptions;
    }

    setPicklistValuesIfApplicable(fieldType, fieldValuesAvailable) {
        var picklistValues = [];
        if (fieldType === 'PICKLIST' || fieldType === 'MULTIPICKLIST' || fieldType === 'STRING') {
            picklistValues.push(this.filterPicklistEmptyVal);
            for (var valKey in fieldValuesAvailable) {
                picklistValues.push({label: valKey, value: fieldValuesAvailable[valKey]});
            }
        }
        return picklistValues;
    }

    async loadGrids() {
        try {
            this.isLoading = true;
            var grids = await getAvailableGrids({
                selectedTeam: this.selectedTeam
            });
            if(grids && grids.length > 0) {
                this.gridOptions = grids;
            }
        }
        catch (error) {
            this.showToastFunction('Error', 'Error on grid loading, ' + this.reduceError(error), 'error');
        }
        finally {
            this.isLoading = false;
        }
    }

    async loadAllProductsForSelection() {
        try {
            this.isLoading = true;
            const productSelection = await getAllProductsForSelection({
                gridBuilderSettingName: this.gridBuilderSettingName,
                selectedTeam: this.selectedTeam
            });
            const hasFields = productSelection?.fieldsApiToInfoMap && Object.keys(productSelection.fieldsApiToInfoMap).length > 0;
            const hasProducts = productSelection?.products && productSelection.products.length > 0;
            if (hasFields && hasProducts) {
                this.allQueriedShareClasses = this.buildShareClassesFromProducts(productSelection.fieldsApiToInfoMap, productSelection.products);
                this.selectedResultColumns = this.buildResultColumnsList(productSelection.fieldsApiToInfoMap);
            }
        }
        catch (error) {
            this.showToastFunction('Error', 'Error loading products, error message: ' + this.reduceError(error), 'error');
        }
        finally {
            this.isLoading = false;
        }
    }

    handleGridChange(event) {
        this.selectedGrid = event.detail.value;
        this.criteria = this.setNewCriteria(this.selectedGrid, this.criteria.filterLogicType, this.criteria.filterLogicText, this.criteria.details);

        if (this.shareClasses?.length) {
            this.shareClasses = this.shareClasses.map(row => ({
                ...row,
                gridId: this.selectedGrid,
                cells: (row.cells || []).map(cell => cell.label === 'Grid' ? { ...cell, value: this.getGridLabelById(this.selectedGrid) } : cell)
            }));
        }
    }

    getGridLabelById(gridId) {
        const match = (this.gridOptions || []).find(opt => opt.value === gridId);
        return match ? match.label : '';
    }

    setNewCriteria(selectedGrid, criteriaFilterLogicType, criteriaFilterLogicText, criteriaDetails) {
        var newCriteria = {
            grid: selectedGrid,
            filterLogicType: criteriaFilterLogicType,
            filterLogicText: criteriaFilterLogicText,
            details: criteriaDetails
        };
        return newCriteria;
    }

    handleShareTypeSelection(event) {
        this.selectedShareTypes = event.detail.value;
    }

    handleApplyFilters(event) {
        const criteriaFromChild = event.detail?.criteria;
        if (criteriaFromChild) {
            this.criteria = this.setNewCriteria(this.selectedGrid, criteriaFromChild.filterLogicType, criteriaFromChild.filterLogicText, criteriaFromChild.details || []);
        }
        this.handleSearchProducts();
    }

    handleFilterReset() {
        this.resetResults();
    }

    async handleSearchProducts() {
        this.isLoading = true;
        this.resetResults();
        
        try {
            const productSelection = await getProductsAndShareClasses({
                gridBuilderSettingName: this.gridBuilderSettingName,
                selectedTeam: this.selectedTeam,
                gridCriteriaJson: JSON.stringify(this.getCriteriaSObject()),
                gridCriteriaDetailsJson: JSON.stringify(this.getCriteriaDetailSObject()),
                getAllProductsWithSelection: false,
                selectedShareTypes: this.selectedShareTypes
            });
            const hasFields = productSelection?.fieldsApiToInfoMap && Object.keys(productSelection.fieldsApiToInfoMap).length > 0;
            const hasProducts = productSelection?.products && productSelection.products.length > 0;
            if (hasFields && hasProducts) {
                this.resultColumns = this.buildResultColumnsList(productSelection.fieldsApiToInfoMap);
                this.shareClasses = this.buildShareClassesFromProducts(productSelection.fieldsApiToInfoMap, productSelection.products);
            }
            else {
                this.resetResults();
                this.showToastFunction('No Products Found', 'No products matched the search criteria.', 'info');
            }
        }
        catch (error) {
            this.showToastFunction('Error', 'Error retrieving products, error message: ' + this.reduceError(error), 'error');
        }
        finally {
            this.isLoading = false;
        }
    }

    async handleAddAllToSelection() {
        const existingRows = this.selectedShareClasses || [];
        this.isLoading = true;
        const previousCount = existingRows.length;
        try {
            const productSelection = await getProductsAndShareClasses({
                gridBuilderSettingName: this.gridBuilderSettingName,
                selectedTeam: this.selectedTeam,
                gridCriteriaJson: JSON.stringify(this.getCriteriaSObject()),
                gridCriteriaDetailsJson: JSON.stringify(this.getCriteriaDetailSObject()),
                getAllProductsWithSelection: true,
                selectedShareTypes: this.selectedShareTypes
            });

            const hasFields = productSelection?.fieldsApiToInfoMap && Object.keys(productSelection.fieldsApiToInfoMap).length > 0;
            const hasProducts = productSelection?.products && productSelection.products.length > 0;

            if (hasFields && hasProducts) {
                const existingMap = new Map(existingRows.map(row => [row.id, row]));
                const allRows = this.buildShareClassesFromProducts(productSelection.fieldsApiToInfoMap, productSelection.products, existingMap);

                const criteriaRef = this.buildCriteriaReference();

                this.selectedShareClasses = this.buildSelectedShareClasses(allRows, existingMap, criteriaRef);
                this.selectedResultColumns = this.buildResultColumnsList(productSelection.fieldsApiToInfoMap);
                this.allQueriedShareClasses = allRows;

                const addedCount = Math.max(this.selectedShareClasses.length - previousCount, 0);
                const message = addedCount > 0 ? addedCount + ' share classes have been added to the Grid.' : 'No new share classes were added.';
                this.showToastFunction('Share classes added', message, addedCount > 0 ? 'success' : 'info');
            }
            else {
                this.showToastFunction('No share classes found', 'No share classes found to add to the Grid.', 'info');
            }
        }
        catch (error) {
            this.showToastFunction('Error', 'Error retrieving products, error message: ' + this.reduceError(error), 'error');
        }
        finally {
            this.resetResults();
            this.isLoading = false;
            const filterBuilder = this.template.querySelector('c-filter-builder');
            if (filterBuilder) {
                filterBuilder.handleResetFilters();
            }
        }
    }

    buildResultColumnsList(fieldsApiToInfoMap) {
        const resultCols = Object.keys(fieldsApiToInfoMap).map(apiName => {
            var fieldInfo = fieldsApiToInfoMap[apiName];
            return { 
                apiName: apiName, 
                label: fieldInfo.label,
                type: fieldInfo.type,
                isSortable: fieldInfo.isSortable
            };
        });
        resultCols.push({apiName: 'GridSelection', label: 'Grid', type: 'String', isSortable: false});
        return resultCols;
    }

    buildShareClassesFromProducts(fieldApiToInfoMap, products, existingMap) {
        if (!products || products.length === 0) {
            return [];
        }

        const apiNames = Object.keys(fieldApiToInfoMap);
        const gridLabel = this.getGridLabelById(this.selectedGrid) || '';
        const rows = [];
        const selectionMap = existingMap || new Map((this.selectedShareClasses || []).map(row => [row.id, row]));

        products.forEach(product => {
            (product.shareClasses || []).forEach(sc => {
                const recordResults = sc.recordResults || {};
                const existing = selectionMap.get(sc.shareClassId);
                const existingGridLabel = existing?.gridLabel || (existing?.cells || []).find(c => c.label === 'Grid')?.value || '';
                const effectiveGridLabel = existingGridLabel || (sc.isSelected ? gridLabel : '');
                const effectiveGridId = existing?.gridId || (sc.isSelected ? this.selectedGrid : '');
                const effectiveSelected = sc.isSelected || !!existing;
                const cells = apiNames.map(apiName => {
                    return {
                        label: fieldApiToInfoMap[apiName].label,
                        value: recordResults[apiName] != null ? recordResults[apiName] : ''
                    };
                });
                cells.push({ label: 'Grid', value: effectiveGridLabel });

                rows.push({
                    id: sc.shareClassId,
                    cells: cells,
                    gridId: effectiveGridId,
                    effManFees: recordResults['EffectiveManagementFees__c'],
                    isSelected: effectiveSelected,
                    productId: product.productId,
                    productLabel: product.productLabel,
                    gridLabel: effectiveGridLabel,
                    criteriaRefId: existing?.criteriaRefId || null
                });
            });
        });

        return rows;
    }

    buildCriteriaReference() {
        var gridId = this.selectedGrid;
        var gridLabel = this.getGridLabelById(this.selectedGrid);
        var criteriaObj = this.getCriteriaSObject();
        var criteriaDetailsList = this.getCriteriaDetailSObject();
        const key = JSON.stringify({
            gridId: gridId,
            filterLogicType: criteriaObj?.FilterLogic__c,
            filterLogicText: criteriaObj?.FilterLogicExpression__c,
            details: criteriaDetailsList
        });
        const existingIndex = this.criteriaList.findIndex(c => c.key === key);
        let criteriaRef;
        if (existingIndex >= 0) {
            const existing = this.criteriaList[existingIndex];
            const cleanedDetails = (existing.criteriaDetails || []).filter(d => d.TECHOrigin__c !== 'System');
            criteriaRef = { ...existing, criteriaDetails: cleanedDetails };
            this.criteriaList = [
                ...this.criteriaList.slice(0, existingIndex),
                criteriaRef,
                ...this.criteriaList.slice(existingIndex + 1)
            ];
        }
        else {
            const stableId = 'crit_' + (++this.criteriaCounter);
            criteriaRef = {
                id: stableId,
                key: key,
                gridId: gridId,
                gridLabel: gridLabel,
                criteria: criteriaObj,
                criteriaDetails: criteriaDetailsList
            };
            this.criteriaList = [...this.criteriaList, criteriaRef];
        }
        return criteriaRef;
    }

    buildSelectedShareClasses(allRows, existingMap, criteriaRef) {
        const selectedRows = [];
        allRows.forEach(row => {
            const existing = existingMap.get(row.id);
            if (existing) {
                selectedRows.push({ ...existing, isSelected: true });
            } 
            else if (row.isSelected) {
                selectedRows.push({
                    ...row,
                    gridId: criteriaRef.gridId,
                    gridLabel: criteriaRef.gridLabel,
                    criteriaRefId: criteriaRef.id,
                    isSelected: true
                });
            }
        });
        return selectedRows;
    }

    resetResults() {
        this.resultColumns = [];
        this.shareClasses = [];
        this.selectedGrid = null;
        const resultsTable = this.template.querySelector('c-results-table');
        if (resultsTable) {
            resultsTable.resetProductExpansions();
        }
    }

    handleOpenSelectedPanel() {
        this.showSelectedPanel = true;
    }

    handleCloseSelectedPanel() {
        this.showSelectedPanel = false;
    }

    handleRemoveProductFromSelection(event) {
        const productId = event.detail?.productId;
        if (!productId) {
            return;
        }
        const updatedCriteria = event.detail?.criteriaList;
        const hasExternalCriteria = Array.isArray(updatedCriteria);
        if (hasExternalCriteria) {
            this.criteriaList = updatedCriteria;
        }
        const current = this.selectedShareClasses || [];
        const removedRows = current.filter(row => row.productId === productId);
        const next = current.filter(row => row.productId !== productId);
        if (next.length !== current.length) {
            if (!hasExternalCriteria && removedRows.length && this.criteriaList?.length) {
                const removedByCriteria = new Map();
                removedRows.forEach(row => {
                    if (!row.criteriaRefId) {
                        return;
                    }
                    if (!removedByCriteria.has(row.criteriaRefId)) {
                        removedByCriteria.set(row.criteriaRefId, new Set());
                    }
                    removedByCriteria.get(row.criteriaRefId).add(row.id);
                });
                this.criteriaList = this.criteriaList.map(entry => {
                    const ids = removedByCriteria.get(entry.id);
                    if (!ids || !ids.size) {
                        return entry;
                    }
                    const details = (entry.criteriaDetails || []).slice();
                    ids.forEach(shareClassId => {
                        const idx = details.findIndex(d => d.Object__c === 'Share_Class__c' && d.Field__c === 'Id' && d.Value__c === shareClassId && d.TECHOrigin__c === 'System');
                        if (idx >= 0) {
                            if (details[idx].Logic__c !== '!=') {
                                details[idx] = { ...details[idx], Logic__c: '!=' };
                            }
                        }
                        else {
                            details.push({
                                Object__c: 'Share_Class__c',
                                Field__c: 'Id',
                                Logic__c: '!=',
                                Value__c: shareClassId,
                                TECHOrigin__c: 'System'
                            });
                        }
                    });
                    return { ...entry, criteriaDetails: details };
                });
            }
            this.selectedShareClasses = next;
        }
    }

    handleValidationSelectionChange(event) {
        const updatedSelection = event.detail?.selectedShareClasses;
        const updatedCriteria = event.detail?.criteriaList;
        if (Array.isArray(updatedSelection)) {
            this.selectedShareClasses = updatedSelection;
        }
        if (Array.isArray(updatedCriteria)) {
            this.criteriaList = updatedCriteria;
        }
    }

    // ------------------------------------ Page Handling methods ------------------------------------
    async handleAgreementsNext(event) {
        var alreadySelectedAgreements = JSON.stringify(this.selectedAgreements);
        var alreadySelectedTeam = this.selectedTeam;
        this.selectedAgreements = event.detail?.agreements || [];
        this.agreementStartDate = event.detail?.startDate;
        this.selectedTeam = event.detail?.team || this.selectedTeam;

        if((alreadySelectedAgreements != JSON.stringify(this.selectedAgreements)) || (alreadySelectedTeam != this.selectedTeam)) {
            this.resetResults();
            this.selectedShareClasses = [];
            this.criteriaList = [];
            await this.loadGridSettings();
            await this.loadGrids();
            await this.loadAllProductsForSelection();
        }
        this.handlePages(false, true, false);
    }

    handleBackToAgreementSelection() {
        this.handlePages(true, false, false);
    }

    handleGridValidation() {
        this.handlePages(false, false, true);
    }

    handleBackToBuilder() {
        this.resetResults();
        this.handlePages(false, true, false);
    }

    handlePages(showGridAgreementSelectionP, showGridBuilderP, showValidationP) {
        this.showAgreementsPage = showGridAgreementSelectionP;
        this.showGridBuilderPage = showGridBuilderP;
        this.showValidationPage = showValidationP;
    }

    // ------------------------------------ Criteria -> SObject ------------------------------------
    getCriteriaSObject() {
        return {
            Grid__c: this.criteria.grid,
            FilterLogic__c: this.criteria.filterLogicType,
            FilterLogicExpression__c: this.criteria.filterLogicText
        };
    }

    getCriteriaDetailSObject() {
        const details = this.criteria.details || [];
        return details.map(detail => {
            return {
                Object__c: detail.objectApi,
                Field__c: detail.fieldApi,
                Logic__c: detail.operator,
                Value__c: detail.value,
                FilterNumber__c: detail.filterNumber,
                TECHOrigin__c: 'User-Defined'
            };
        });
    }

    // ------------------------------------ Helper functions ------------------------------------
    showToastFunction(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
        console.error(title, message);
    }

    reduceError(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        if (typeof error.message === 'string') {
            return error.message;
        }
        return 'Unknown error';
    }
}