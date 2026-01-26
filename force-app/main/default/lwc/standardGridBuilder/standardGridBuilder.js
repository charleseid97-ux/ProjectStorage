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
    defaultFilterOperator = 'IN';
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
    @track showRecapExcludedOnly = false;

    @track criteriaList = [];
    criteriaCounter = 0;

    criteriaDefVal = {grid: null, filterLogicType: '', filterLogicText: '', details: []};
    @track criteria = {};

    get addToGridDisabled() {
        return !this.selectedGrid || !(this.shareClasses && this.shareClasses.length > 0);
    }

    get validateGridDisabled() {
        return !this.selectedShareClasses || this.selectedShareClasses.length === 0;
    }

    get isGridBuilderOrValidationPage() {
        return this.showGridBuilderPage || this.showValidationPage;
    }

    async connectedCallback() {
        try {
            let agreementSettings = await getAgreementSelectionPageSettings({
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
            let gridSettings = await getGridSettings({
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
        let objectLabelsAndAPINames = [];
        let fieldsByObjectMap = {};
        let operatorsByFieldMap = {};
        let picklistValuesByFieldMap = {};

        let filterObjects = gridSettings.filterObjects;
        let obj, fieldIndex, field;
        for (let index in filterObjects) {
            if (filterObjects.hasOwnProperty(index)) {
                obj = filterObjects[index];
                objectLabelsAndAPINames.push({label: obj.objectLabel, value: obj.objectApiName}); // Object picklist option

                // Field options for this object
                let fieldOptions = [];
                let fields = obj.fields;
                if (fields) {
                    for (fieldIndex in fields) {
                        if (fields.hasOwnProperty(fieldIndex)) {
                            field = fields[fieldIndex];
                            fieldOptions.push({
                                label: field.fieldLabel, 
                                value: field.fieldApiName,
                                type: field.fieldType
                            });

                            let opMapKey = obj.objectApiName + '.' + field.fieldApiName; // Key by "ObjectApi.FieldApi"
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
        this.criteria = this.criteriaDefVal;
        this.criteria.filterLogicType = this.startingLogicType;
        this.filterLimit = gridSettings.filterLimit || this.filterLimit;
        this.filterValueSeparator = gridSettings.filterValueSeparator || this.filterValueSeparator;

        const shareTypeWrp = gridSettings.shareTypeWrp || {};
        this.allShareTypeOptions = shareTypeWrp.allShareTypeOptions || [];
        this.defaultShareTypeValues = shareTypeWrp.defaultShareTypeValues || [];
        this.selectedShareTypes = [...this.defaultShareTypeValues];

        this.objectOptions = objectLabelsAndAPINames;
        this.fieldsByObject = fieldsByObjectMap;
        this.operatorsByField = operatorsByFieldMap;
        this.picklistValuesByField = picklistValuesByFieldMap;
    }

    setOperatorOptions(ops) {
        let opOptions = [];
        if(ops) {
            for (let opKey in ops) {
                opOptions.push({label: opKey, value: ops[opKey]});
            }
        }
        return opOptions;
    }

    setPicklistValuesIfApplicable(fieldType, fieldValuesAvailable) {
        let picklistValues = [];
        if (fieldType === 'PICKLIST' || fieldType === 'MULTIPICKLIST' || fieldType === 'STRING') {
            picklistValues.push(this.filterPicklistEmptyVal);
            for (let valKey in fieldValuesAvailable) {
                picklistValues.push({label: valKey, value: fieldValuesAvailable[valKey]});
            }
        }
        return picklistValues;
    }

    async loadGrids() {
        try {
            this.isLoading = true;
            let grids = await getAvailableGrids({
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
                this.allQueriedShareClasses = this.buildShareClassesFromProducts(productSelection.fieldsApiToInfoMap, productSelection.products, null, true);
                this.selectedResultColumns = this.buildResultColumnsList(productSelection.fieldsApiToInfoMap, true);
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
        let newCriteria = {
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

    handleRemoveProductFromResults(event) {
        const productId = event.detail?.productId;
        if (!productId) {
            return;
        }
        const currentRows = this.shareClasses || [];
        const removedRows = currentRows.filter(row => row.productId === productId);
        if (!removedRows.length) {
            return;
        }
        const productName = this.getProductNameFromRows(removedRows);
        this.shareClasses = currentRows.filter(row => row.productId !== productId);
        if (!productName) {
            return;
        }
        const updatedCriteria = this.applySystemProductExclusion(this.criteria, productName);
        this.criteria = updatedCriteria;
    }

    handleApplyFilters(event) {
        const criteriaFromChild = event.detail?.criteria;
        if (criteriaFromChild) {
            const systemDetail = this.getSystemProductExclusionDetail(this.criteria?.details);
            const mergeResult = this.mergeSystemDetail(criteriaFromChild, systemDetail);
            this.criteria = this.setNewCriteria(this.selectedGrid, mergeResult.filterLogicType, mergeResult.filterLogicText, mergeResult.details || []);
        }
        this.handleSearchProducts();
    }

    handleFilterReset() {
        this.resetResults(false);
    }

    async handleSearchProducts() {
        this.isLoading = true;
        this.resetResults(false);
        
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
                this.resultColumns = this.buildResultColumnsList(productSelection.fieldsApiToInfoMap, false);
                this.shareClasses = this.buildShareClassesFromProducts(productSelection.fieldsApiToInfoMap, productSelection.products, null, false);
            }
            else {
                this.resetResults(false);
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
                const allRows = this.buildShareClassesFromProducts(productSelection.fieldsApiToInfoMap, productSelection.products, existingMap, true);

                const criteriaRef = this.buildCriteriaReference();

                this.selectedShareClasses = this.buildSelectedShareClasses(allRows, existingMap, criteriaRef);
                this.selectedResultColumns = this.buildResultColumnsList(productSelection.fieldsApiToInfoMap, true);
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
            this.resetResults(true);
            this.isLoading = false;
        }
    }

    buildResultColumnsList(fieldsApiToInfoMap, addGridCol) {
        const resultCols = Object.keys(fieldsApiToInfoMap).map(apiName => {
            let fieldInfo = fieldsApiToInfoMap[apiName];
            return { 
                apiName: apiName, 
                label: fieldInfo.label,
                type: fieldInfo.type,
                isSortable: fieldInfo.isSortable
            };
        });
        if(addGridCol) {
            resultCols.push({apiName: 'GridSelection', label: 'Grid', type: 'String', isSortable: false});
        }
        return resultCols;
    }

    buildShareClassesFromProducts(fieldApiToInfoMap, products, existingMap, addGridCol) {
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
                if(addGridCol) {
                    cells.push({ label: 'Grid', value: effectiveGridLabel });
                }

                rows.push({
                    id: sc.shareClassId,
                    cells: cells,
                    gridId: effectiveGridId,
                    effManFees: recordResults['EffectiveManagementFees__c'],
                    isin: recordResults['ISIN__c'],
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
        let gridId = this.selectedGrid;
        let gridLabel = this.getGridLabelById(this.selectedGrid);
        let criteriaObj = this.getCriteriaSObject();
        let criteriaDetailsList = this.decorateCriteriaDetails(this.getCriteriaDetailSObject());
        const shareTypes = Array.isArray(this.selectedShareTypes) ? [...this.selectedShareTypes] : [];
        const shareTypeKey = this.buildShareTypesKey(shareTypes);
        const key = JSON.stringify({
            gridId: gridId,
            filterLogicType: criteriaObj?.FilterLogic__c,
            filterLogicText: criteriaObj?.FilterLogicExpression__c,
            details: criteriaDetailsList,
            shareTypes: shareTypeKey
        });
        const existingIndex = this.criteriaList.findIndex(c => c.key === key);
        let criteriaRef;
        if (existingIndex >= 0) {
            const existing = this.criteriaList[existingIndex];
            const cleanedDetails = (existing.criteriaDetails || []).filter(d => d.TECHOrigin__c !== 'System');
            criteriaRef = { ...existing, criteriaDetails: this.decorateCriteriaDetails(cleanedDetails), shareTypes: existing.shareTypes || shareTypes };
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
                criteriaDetails: criteriaDetailsList,
                shareTypes: shareTypes
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

    resetResults(resetFilter) {
        this.resultColumns = [];
        this.shareClasses = [];
        this.selectedGrid = null;
        const resultsTable = this.template.querySelector('c-results-table');
        if (resultsTable) {
            resultsTable.resetProductExpansions();
        }
        if(resetFilter) {
            this.criteria = this.criteriaDefVal;
            const filterBuilder = this.template.querySelector('c-filter-builder');
            if (filterBuilder) {
                filterBuilder.handleResetFilters();
            }
        }
    }

    handleOpenSelectedPanel() {
        this.showRecapExcludedOnly = false;
        this.showSelectedPanel = true;
    }

    handleOpenSelectedPanelFromValidation() {
        this.showRecapExcludedOnly = true;
        this.showSelectedPanel = true;
    }

    handleCloseSelectedPanel() {
        this.showSelectedPanel = false;
        this.showRecapExcludedOnly = false;
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
                    const isin = this.getIsinFromRow(row);
                    if (!isin) {
                        return;
                    }
                    if (!removedByCriteria.has(row.criteriaRefId)) {
                        removedByCriteria.set(row.criteriaRefId, new Set());
                    }
                    removedByCriteria.get(row.criteriaRefId).add(isin);
                });
                this.criteriaList = this.criteriaList.map(entry => {
                    const isins = removedByCriteria.get(entry.id);
                    if (!isins || !isins.size) {
                        return entry;
                    }
                    const details = (entry.criteriaDetails || []).slice();
                    const idx = details.findIndex(d =>
                        d.Object__c === 'Share_Class__c' &&
                        d.Field__c === 'ISIN__c' &&
                        d.Logic__c === 'NOT IN' &&
                        d.TECHOrigin__c === 'System'
                    );
                    const currentValues = idx >= 0 ? this.splitCriteriaValues(details[idx].Value__c) : [];
                    const valueSet = new Set(currentValues);
                    isins.forEach(isin => valueSet.add(isin));
                    const nextValues = Array.from(valueSet);
                    const detail = {
                        Object__c: 'Share_Class__c',
                        Field__c: 'ISIN__c',
                        Logic__c: 'NOT IN',
                        Value__c: nextValues.join(' '+this.filterValueSeparator+' '),
                        TECHOrigin__c: 'System',
                        objectLabel: 'Share Class',
                        fieldLabel: 'ISIN'
                    };
                    if (idx >= 0) {
                        details[idx] = { ...details[idx], ...detail };
                    }
                    else {
                        details.push(detail);
                    }
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
        let alreadySelectedAgreements = JSON.stringify(this.selectedAgreements);
        let alreadySelectedTeam = this.selectedTeam;
        this.selectedAgreements = event.detail?.agreements || [];
        this.agreementStartDate = event.detail?.startDate;
        this.selectedTeam = event.detail?.team || this.selectedTeam;

        if((alreadySelectedAgreements != JSON.stringify(this.selectedAgreements)) || (alreadySelectedTeam != this.selectedTeam)) {
            this.resetResults(true);
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
        this.resetResults(true);
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
                TECHOrigin__c: detail.TECHOrigin__c || 'User-Defined'
            };
        });
    }

    decorateCriteriaDetails(details) {
        return (details || []).map(detail => {
            const objectApi = detail.Object__c || detail.objectApi || '';
            const fieldApi = detail.Field__c || detail.fieldApi || '';
            return {
                ...detail,
                objectLabel: this.getObjectLabel(objectApi),
                fieldLabel: this.getFieldLabel(objectApi, fieldApi)
            };
        });
    }

    getObjectLabel(objectApi) {
        const match = (this.objectOptions || []).find(opt => opt.value === objectApi);
        return match ? match.label : 'Unknown Object';
    }

    getFieldLabel(objectApi, fieldApi) {
        const fields = this.fieldsByObject?.[objectApi] || [];
        const match = fields.find(field => field.value === fieldApi);
        return match ? match.label : 'Unknown Field';
    }

    buildShareTypesKey(shareTypes) {
        const values = Array.isArray(shareTypes) ? [...shareTypes] : [];
        values.sort((a, b) => a.localeCompare(b));
        return values.join('|');
    }

    getProductNameLabel() {
        const productFields = this.fieldsByObject?.Product__c || [];
        const match = productFields.find(field => field.value === 'ProductName__c');
        return match ? match.label : 'Product Name';
    }

    getProductNameFromRows(rows) {
        const firstRow = rows && rows.length ? rows[0] : null;
        if (!firstRow) {
            return null;
        }
        const label = this.getProductNameLabel();
        const cellValue = (firstRow.cells || []).find(cell => cell.label === label)?.value;
        if (cellValue) {
            return cellValue;
        }
        const fallbackLabel = firstRow.productLabel || '';
        const separatorIndex = fallbackLabel.indexOf(' (');
        if (separatorIndex > 0) {
            return fallbackLabel.substring(0, separatorIndex);
        }
        return fallbackLabel || null;
    }

    getIsinFromRow(row) {
        if (!row) {
            return null;
        }
        if (row.isin) {
            return row.isin;
        }
        const cells = row.cells || [];
        const cell = cells.find(c => (c.label || '').toLowerCase() === 'isin') ||
            cells.find(c => (c.label || '').toLowerCase().includes('isin'));
        return cell ? cell.value : null;
    }

    splitCriteriaValues(rawValue) {
        if (!rawValue) {
            return [];
        }
        const separator = this.filterValueSeparator || ';';
        return rawValue.split(separator).map(value => value.trim()).filter(value => value);
    }

    applySystemProductExclusion(criteria, productName) {
        const current = criteria || this.criteria;
        const details = Array.isArray(current?.details) ? current.details.map(d => ({ ...d })) : [];
        const systemDetail = this.getSystemProductExclusionDetail(details);
        const names = this.getValuesFromDetail(systemDetail);
        if (!names.includes(productName)) {
            names.push(productName);
        }
        const nextDetail = {
            id: systemDetail?.id || 'sys-product-exclusion',
            objectApi: 'Product__c',
            fieldApi: 'ProductName__c',
            operator: 'NOT IN',
            value: names.join(this.filterValueSeparator),
            TECHOrigin__c: 'System'
        };
        const updatedDetails = this.upsertSystemDetail(details, nextDetail);
        const logicUpdate = this.appendCustomLogicIfNeeded(current?.filterLogicType, current?.filterLogicText, updatedDetails, systemDetail == null);
        return this.setNewCriteria(current?.grid, logicUpdate.filterLogicType, logicUpdate.filterLogicText, updatedDetails);
    }

    mergeSystemDetail(criteriaFromChild, systemDetail) {
        const details = Array.isArray(criteriaFromChild?.details) ? criteriaFromChild.details.map(d => ({ ...d })) : [];
        const updatedDetails = !systemDetail? this.reindexCriteriaDetails(details) : this.upsertSystemDetail(details, { ...systemDetail });
        return {
            filterLogicType: criteriaFromChild?.filterLogicType,
            filterLogicText: criteriaFromChild?.filterLogicText,
            details: updatedDetails
        };
    }

    getSystemProductExclusionDetail(details) {
        return (details || []).find(detail =>
            detail &&
            detail.objectApi === 'Product__c' &&
            detail.fieldApi === 'ProductName__c' &&
            detail.operator === 'NOT IN' &&
            detail.TECHOrigin__c === 'System'
        );
    }

    getValuesFromDetail(detail) {
        if (!detail || !detail.value) {
            return [];
        }
        const separator = this.filterValueSeparator || ';';
        return detail.value.split(separator).map(value => value.trim()).filter(value => value);
    }

    upsertSystemDetail(details, systemDetail) {
        const filtered = (details || []).filter(detail => !this.isSystemProductExclusionDetail(detail));
        filtered.push({ ...systemDetail, TECHOrigin__c: 'System' });
        return this.reindexCriteriaDetails(filtered);
    }

    isSystemProductExclusionDetail(detail) {
        return detail &&
            detail.objectApi === 'Product__c' &&
            detail.fieldApi === 'ProductName__c' &&
            detail.operator === 'NOT IN' &&
            detail.TECHOrigin__c === 'System';
    }

    reindexCriteriaDetails(details) {
        const updated = [];
        (details || []).forEach((detail, index) => {
            updated.push({
                ...detail,
                filterNumber: index + 1
            });
        });
        return updated;
    }

    appendCustomLogicIfNeeded(filterLogicType, filterLogicText, updatedDetails, addedSystemDetail) {
        if (!addedSystemDetail || filterLogicType !== 'Custom Logic') {
            return { filterLogicType: filterLogicType, filterLogicText: filterLogicText };
        }
        const systemDetail = this.getSystemProductExclusionDetail(updatedDetails);
        const systemNumber = systemDetail?.filterNumber;
        if (!systemNumber) {
            return { filterLogicType: filterLogicType, filterLogicText: filterLogicText };
        }
        const baseExpression = filterLogicText && filterLogicText.trim()
            ? filterLogicText.trim()
            : this.buildDefaultLogicExpression(updatedDetails.length - 1, 'AND');
        const nextExpression = baseExpression ? `(${baseExpression}) AND ${systemNumber}` : String(systemNumber);
        return { filterLogicType: 'Custom Logic', filterLogicText: nextExpression };
    }

    buildDefaultLogicExpression(count, logicType) {
        if (count <= 0) {
            return '';
        }
        const op = logicType === 'OR' ? 'OR' : 'AND';
        return Array.from({ length: count }, (_, index) => index + 1).join(` ${op} `);
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