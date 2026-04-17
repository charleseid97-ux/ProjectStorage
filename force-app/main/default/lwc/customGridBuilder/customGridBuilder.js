import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getGridSettings from '@salesforce/apex/GridBuilderController.getGridSettings';
import getAvailableGrids from '@salesforce/apex/GridBuilderController.getAvailableGrids';
import getAgreementSelectionPageSettings from '@salesforce/apex/GridBuilderController.getAgreementSelectionPageSettings';
import getDraftGridData from '@salesforce/apex/GridBuilderController.getDraftGridData';
import getApprovedGridData from '@salesforce/apex/GridBuilderController.getApprovedGridData';
import getAllProductsForSelection from '@salesforce/apex/GridBuilderController.getAllProductsForSelection';
import getProductsAndShareClasses from '@salesforce/apex/GridBuilderController.getProductsAndShareClasses';
import {LABELS, reduceError, showToast, buildShareTypesKey, getProductNameFromRows, getQueryParam, getSystemProductExclusionDetail, 
    applySystemProductExclusion, mergeSystemDetail, addIsinExclusionsFromRows, pruneOrphanedCriteria} from 'c/gridBuilderUtils';

export default class CustomGridBuilder extends NavigationMixin(LightningElement) {
    @api gridBuilderSettingName = 'CustomGridBuilderSetting';

    @track isLoading = true;
    labels = LABELS;

    @track showAgreementsPage = false;
    @track showGridBuilderPage = false;
    @track showValidationPage = false;
    @track showSimulation = false;

    // First Page: Agreement Selection
    @track agreementSelectionMode = 'Single';
    @track agreementOptions = [];
    @track selectedAgreementNames = [];
    @track availableTeams = [];
    @track primaryTeam;
    @track selectedTeam;
    @track countriesOfDistribution;
    @track selectedAgreements = [];

    // Existing grid info (from pre-selected agreement)
    @track existingGridInfo = { hasExistingGrid: false, kind: null, type: null, endDate: null };
    @track hasDraftGrid = false;
    
    // Second Page: Grid Builder
    @track gridRequestData = {};

    startingLogicType = 'AND';
    filterValueSeparator = ';';
    filterLogicOptions = [{label: 'AND', value:'AND'},{label: 'OR', value: 'OR'}];
    filterLimit = 10;
    filterPicklistEmptyVal = { label: '-- None --', value: '' }

    allShareTypeOptions = [];
    defaultShareTypeValues = [];
    selectedShareTypes = [];
    enabledShareTypeValues = [];

    objectOptions = [];
    fieldsByObject = {};
    defaultFilterOperator = 'IN';
    operatorsByField = {};
    picklistValuesByField = {};
    showValuesWhenNotSelecting = true;

    @track draftGridId = null;
    pendingDraftData = null;

    @track gridOptions = [];
    @track selectedGrid;
    @track gridShareClassMap = {};

    @track resultColumns = [];
    @track shareClasses = [];
    @track selectedResultColumns = [];
    @track allQueriedShareClasses = [];
    @track selectedShareClasses = [];
    @track showSelectedPanel = false;
    @track showRecapExcludedOnly = false;
    @track showConfirmationModal = false;
    @track confirmationContext = { action: '', title: '', message: '' };

    @track criteriaList = [];
    criteriaCounter = 0;

    criteriaDefVal = {grid: null, filterLogicType: '', filterLogicText: '', details: []};
    @track criteria = {};

    recId;

    get addToGridDisabled() {
        return !this.selectedGrid || !(this.shareClasses && this.shareClasses.length > 0);
    }

    get validateGridDisabled() {
        return !this.selectedShareClasses || this.selectedShareClasses.length === 0;
    }

    get isGridBuilderOrValidationPage() {
        return this.showGridBuilderPage || this.showValidationPage;
    }

    get computedGridOptions() {
        if (this.gridRequestData?.gridType !== 'SINGLE RULE' || !(this.selectedShareClasses || []).length) {
            return this.gridOptions || [];
        }
        const lockedGridId = this.selectedShareClasses[0].gridId;
        return (this.gridOptions || []).map(opt => ({
            ...opt,
            disabled: opt.value !== lockedGridId
        }));
    }

    async connectedCallback() {
        try {
            this.recId = getQueryParam('c__recordId');
            let agreementSettings = await getAgreementSelectionPageSettings({
                gridBuilderSettingName: this.gridBuilderSettingName,
                agreementId: this.recId
            });
            if (agreementSettings) {
                if(!agreementSettings.gridBuilderFound) {
                    showToast(this, this.labels.UI_Error, this.labels.Grid_SettingNotFound.replace('{0}', this.gridBuilderSettingName), 'error');
                    return;
                }
                this.agreementSelectionMode = agreementSettings.agreementSelectionMode;
                this.agreementOptions = agreementSettings.agreementOptions || [];
                this.availableTeams = (agreementSettings.availableTeams || []).map(t => ({ label: t, value: t }));
                this.primaryTeam = agreementSettings.primaryTeam;
                this.selectedTeam = this.primaryTeam || (this.availableTeams.length ? this.availableTeams[0].value : null);
                this.gridRequestData.startDate = new Date().toISOString().split('T')[0];
                this.existingGridInfo = {
                    hasExistingGrid: agreementSettings.hasExistingGrid  || false,
                    kind:            agreementSettings.existingGridKind || null,
                    type:            agreementSettings.existingGridType || null,
                    endDate:         agreementSettings.existingGridEndDate || null
                };
                this.hasDraftGrid = agreementSettings.hasDraftGrid || false;

                // If a Draft grid request exists, prefill the builder from it
                if (agreementSettings.hasDraftGrid && this.recId) {
                    const draftData = await getDraftGridData({ agreementId: this.recId });
                    if (draftData) {
                        this.draftGridId     = draftData.grid.Id;
                        this.pendingDraftData = draftData;
                        this.gridRequestData = {
                            kind:                    draftData.grid.Kind__c,
                            gridType:                draftData.grid.Type__c,
                            isAutoGridUpdate:        draftData.grid.AutomaticGridUpdate__c,
                            startDate:               draftData.grid.StartDate__c,
                            endDate:                 draftData.grid.EndDate__c,
                            thresholdAmount:         draftData.grid.ThresholdAmount__c,
                            thresholdAmountCurrency: draftData.grid.ThresholdAmountCurrency__c,
                            otherFees:               draftData.grid.OtherFees__c,
                            comment:                 draftData.grid.Comment__c
                        };
                    }
                }

                this.isLoading = false;
                this.showAgreementsPage = true;
            }
        }
        catch (error) {
            showToast(this, this.labels.UI_Error, this.labels.Grid_AgreementErrorLoadingSettings + ', ' + this.labels.UI_ErrorMessage + ': ' + reduceError(error), 'error');
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
                countriesOfDistribution: this.countriesOfDistribution,
                availableGridIds: Object.keys(this.gridShareClassMap)
            });
            if (gridSettings && gridSettings.filterObjects && gridSettings.filterObjects.length > 0) {
                this.setGridSettings(gridSettings);
            }
        }
        catch (error) {
            showToast(this, this.labels.UI_Error, this.labels.Grid_ErrorLoadingSettings + ', ' + this.labels.UI_ErrorMessage + ': ' + reduceError(error), 'error');
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
        let allObjectLabels = {};
        let obj, fieldIndex, field;
        for (let index in filterObjects) {
            if (filterObjects.hasOwnProperty(index)) {
                obj = filterObjects[index];
                allObjectLabels[obj.objectApiName] = obj.objectLabel; // Always register label for criteria detail display (even for inactive filter objects)
                if (obj.showFilter !== false) { // Only add to filter dropdown if the metadata record is active
                    objectLabelsAndAPINames.push({label: obj.objectLabel, value: obj.objectApiName});
                }

                // Field options — always populated so getFieldLabel resolves for inactive objects too
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
        this.allObjectLabels = allObjectLabels;

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
            const result = await getAvailableGrids({
                countriesOfDistribution: this.countriesOfDistribution,
                agreementNames: this.selectedAgreementNames
            });
            if (result) {
                this.gridOptions = result.gridOptions || [];
                this.gridShareClassMap = result.gridShareClassIds || {};
            }
        }
        catch (error) {
            showToast(this, this.labels.UI_Error, this.labels.Grid_ErrorLoadingGrids + ', ' + this.labels.UI_ErrorMessage + ': ' + reduceError(error), 'error');
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
                countriesOfDistribution: this.countriesOfDistribution,
                availableGridIds: Object.keys(this.gridShareClassMap)
            });
            const hasFields = productSelection?.fieldsApiToInfoMap && Object.keys(productSelection.fieldsApiToInfoMap).length > 0;
            const hasProducts = productSelection?.products && productSelection.products.length > 0;
            if (hasFields && hasProducts) {
                this.allQueriedShareClasses = this.buildShareClassesFromProducts(productSelection.fieldsApiToInfoMap, productSelection.products, null, true);
                this.selectedResultColumns = this.buildResultColumnsList(productSelection.fieldsApiToInfoMap, true);
            }
        }
        catch (error) {
            showToast(this, this.labels.UI_Error, this.labels.Grid_ErrorLoadingProducts + ', ' + this.labels.UI_ErrorMessage + ': ' + reduceError(error), 'error');
        }
        finally {
            this.isLoading = false;
        }
    }


    handleGridChange(event) {
        this.selectedGrid = event.detail.value;
        this.criteria = { grid: this.selectedGrid, filterLogicType: this.criteria.filterLogicType, filterLogicText: this.criteria.filterLogicText, details: this.criteria.details };

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

    handleShareTypeSelection(event) {
        this.selectedShareTypes = event.detail.value;
    }

    handleEnabledShareTypesChanged(event) {
        this.enabledShareTypeValues = event.detail.value;
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
        const productName = getProductNameFromRows(removedRows, this.getProductNameLabel());
        this.shareClasses = currentRows.filter(row => row.productId !== productId);
        if (!productName) {
            return;
        }
        this.criteria = applySystemProductExclusion(this.criteria, productName, this.filterValueSeparator);
    }

    handleApplyFilters(event) {
        const criteriaFromChild = event.detail?.criteria;
        if (criteriaFromChild) {
            const systemDetail = getSystemProductExclusionDetail(this.criteria?.details);
            const mergeResult = mergeSystemDetail(criteriaFromChild, systemDetail);
            this.criteria = { grid: this.selectedGrid, filterLogicType: mergeResult.filterLogicType, filterLogicText: mergeResult.filterLogicText, details: mergeResult.details || [] };
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
                countriesOfDistribution: this.countriesOfDistribution,
                gridCriteriaJson: JSON.stringify(this.getCriteriaSObject()),
                gridCriteriaDetailsJson: JSON.stringify(this.getCriteriaDetailSObject()),
                getAllProductsWithSelection: false,
                availableGridIds: Object.keys(this.gridShareClassMap)
            });
            const hasFields = productSelection?.fieldsApiToInfoMap && Object.keys(productSelection.fieldsApiToInfoMap).length > 0;
            const hasProducts = productSelection?.products && productSelection.products.length > 0;
            if (hasFields && hasProducts) {
                this.resultColumns = this.buildResultColumnsList(productSelection.fieldsApiToInfoMap, false);
                this.shareClasses = this.buildShareClassesFromProducts(productSelection.fieldsApiToInfoMap, productSelection.products, null, false);
            }
            else {
                this.resetResults(false);
                showToast(this, this.labels.Grid_NoProductsFound, this.labels.Grid_NoProductsMatched, 'info');
            }
        }
        catch (error) {
            showToast(this, this.labels.UI_Error, this.labels.Grid_ErrorRetrievingProducts + ', ' + this.labels.UI_ErrorMessage + ': ' + reduceError(error), 'error');
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
                countriesOfDistribution: this.countriesOfDistribution,
                gridCriteriaJson: JSON.stringify(this.getCriteriaSObject()),
                gridCriteriaDetailsJson: JSON.stringify(this.getCriteriaDetailSObject()),
                getAllProductsWithSelection: true,
                availableGridIds: Object.keys(this.gridShareClassMap)
            });

            const hasFields = productSelection?.fieldsApiToInfoMap && Object.keys(productSelection.fieldsApiToInfoMap).length > 0;
            const hasProducts = productSelection?.products && productSelection.products.length > 0;

            if (hasFields && hasProducts) {
                const existingMap = new Map(existingRows.map(row => [row.id, row]));
                const allRows = this.buildShareClassesFromProducts(productSelection.fieldsApiToInfoMap, productSelection.products, existingMap, true);

                const criteriaRef = this.buildCriteriaReference();

                // Filter to only share classes belonging to the selected grid (Point 2)
                const validIds = new Set(this.gridShareClassMap[this.selectedGrid] || []);
                const filteredRows = validIds.size > 0 ? allRows.filter(row => existingMap.has(row.id) || validIds.has(row.id)) : allRows;
                const gridExcluded = validIds.size > 0 ? allRows.filter(row => !existingMap.has(row.id) && row.isSelected && !validIds.has(row.id)).length : 0;

                const { selectedRows, skippedCount } = this.buildSelectedShareClasses(filteredRows, existingMap, criteriaRef);
                this.selectedShareClasses = selectedRows;
                this.selectedResultColumns = this.buildResultColumnsList(productSelection.fieldsApiToInfoMap, true);

                const selectedIds = new Set(selectedRows.map(r => r.id));
                this.allQueriedShareClasses = allRows.map(row => {
                    if (!selectedIds.has(row.id) && !existingMap.has(row.id)) {
                        return { ...row, gridId: '', gridLabel: '', isSelected: false, cells: (row.cells || []).map(c => c.label === 'Grid' ? { ...c, value: '' } : c) };
                    }
                    return row;
                });

                const addedCount = Math.max(this.selectedShareClasses.length - previousCount, 0);
                const message = addedCount > 0 ? this.labels.Grid_ShareClassesAdded.replace('{0}', addedCount) : this.labels.Grid_NoNewShareClassesAdded;
                showToast(this, this.labels.Grid_ShareClassesAddedTitle, message, addedCount > 0 ? 'success' : 'info');
                if (skippedCount > 0) {
                    showToast(this, this.labels.UI_Warning, this.labels.Grid_ShareClassesNotAdded_DifferentGrid.replace('{0}', skippedCount), 'warning');
                }
                if (gridExcluded > 0) {
                    showToast(this, this.labels.UI_Warning, this.labels.Grid_ShareClassesNotAdded_NotInGrid.replace('{0}', gridExcluded), 'warning');
                }
            }
            else {
                showToast(this, this.labels.Grid_NoShareClassesFound, this.labels.Grid_NoShareClassesToAdd, 'info');
            }
        }
        catch (error) {
            showToast(this, this.labels.UI_Error, this.labels.Grid_ErrorRetrievingProducts + ', ' + this.labels.UI_ErrorMessage + ': ' + reduceError(error), 'error');
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
        const shareTypeKey = buildShareTypesKey(shareTypes);
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
            this.criteriaList = [...this.criteriaList.slice(0, existingIndex), criteriaRef, ...this.criteriaList.slice(existingIndex + 1)];
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
        let skippedCount = 0;

        const productGridMap = new Map();
        existingMap.forEach(row => {
            if (row.productId && row.gridId) {
                productGridMap.set(row.productId, row.gridId);
            }
        });

        allRows.forEach(row => {
            const existing = existingMap.get(row.id);
            if (existing) {
                selectedRows.push({ ...existing, isSelected: true });
            }
            else if (row.isSelected) {
                const existingGridForProduct = productGridMap.get(row.productId);
                if (existingGridForProduct && existingGridForProduct !== criteriaRef.gridId) {
                    skippedCount++;
                    return;
                }
                selectedRows.push({
                    ...row,
                    gridId: criteriaRef.gridId,
                    gridLabel: criteriaRef.gridLabel,
                    criteriaRefId: criteriaRef.id,
                    isSelected: true
                });
            }
        });
        return { selectedRows, skippedCount };
    }

    resetResults(resetFilter) {
        this.resultColumns = [];
        this.shareClasses = [];
        if (this.gridRequestData?.gridType !== 'SINGLE RULE' || !(this.selectedShareClasses || []).length) {
            this.selectedGrid = null;
        }
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
        if (!productId) return;
        const updatedCriteria = event.detail?.criteriaList;
        const hasExternalCriteria = Array.isArray(updatedCriteria);
        if (hasExternalCriteria) {
            this.criteriaList = updatedCriteria;
        }
        const current = this.selectedShareClasses || [];
        const removedRows = current.filter(row => row.productId === productId);
        const next = current.filter(row => row.productId !== productId);
        if (next.length === current.length) return;
        if (!hasExternalCriteria && removedRows.length && this.criteriaList?.length) {
            this.criteriaList = addIsinExclusionsFromRows(this.criteriaList, removedRows, this.filterValueSeparator);
        }
        this.selectedShareClasses = next;
        this.criteriaList = pruneOrphanedCriteria(this.criteriaList, this.selectedShareClasses);
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

    buildCriteriaListFromDraft(draftCriteriaList) {
        return (draftCriteriaList || []).map(entry => {
            const stableId  = 'crit_' + (++this.criteriaCounter);
            const gridId    = entry.criteria?.StandardGrid__c;
            const gridLabel = this.getGridLabelById(gridId);
            return {
                id:              stableId,
                key:             stableId,
                gridId:          gridId,
                gridLabel:       gridLabel,
                criteria: {
                    StandardGrid__c:          entry.criteria?.StandardGrid__c,
                    FilterLogic__c:           entry.criteria?.FilterLogic__c,
                    FilterLogicExpression__c: entry.criteria?.FilterLogicExpression__c,
                    SelectedShareTypes__c:    entry.criteria?.SelectedShareTypes__c
                },
                criteriaDetails: this.decorateCriteriaDetails(entry.details || []),
                shareTypes:      entry.criteria?.SelectedShareTypes__c ? entry.criteria.SelectedShareTypes__c.split(',') : []
            };
        });
    }

    buildSelectedShareClassesFromDraft(draftCriteriaList, builtCriteriaList) {
        // Map each share class ID to its criteria reference
        const scToCritRef = new Map();
        (draftCriteriaList || []).forEach((entry, idx) => {
            const critRef = builtCriteriaList[idx];
            if (critRef) {
                (entry.shareClassIds || []).forEach(scId => scToCritRef.set(scId, critRef));
            }
        });

        return (this.allQueriedShareClasses || [])
            .filter(sc => scToCritRef.has(sc.id))
            .map(sc => {
                const critRef = scToCritRef.get(sc.id);
                return {
                    ...sc,
                    gridId:       critRef.gridId,
                    gridLabel:    critRef.gridLabel,
                    criteriaRefId: critRef.id,
                    isSelected:   true,
                    cells: (sc.cells || []).map(cell =>
                        cell.label === 'Grid' ? { ...cell, value: critRef.gridLabel } : cell
                    )
                };
            });
    }

    getSelectedAgreementNames() {
        if (!this.selectedAgreements || !this.selectedAgreements.length || !this.agreementOptions) {
            return '';
        }
        return this.selectedAgreements.map(id => {
            const opt = this.agreementOptions.find(a => a.value === id || a.value.substring(0, 15) === id);
            return opt ? opt.name : null;
        }).filter(Boolean).join(', ');
    }

    resetAll(notify) {
        this.selectedShareClasses = [];
        this.criteriaList = [];
        this.resetResults(true);
        if(notify)
            showToast(this, this.labels.UI_Success, this.labels.Grid_ResetAll_Success, 'success');
    }

    // ------------------------------------ Confirmation Modal methods ------------------------------------
    openConfirmation(action, title, message) {
        this.confirmationContext = { action, title, message };
        this.showConfirmationModal = true;
    }

    handleConfirmationConfirm() {
        const action = this.confirmationContext.action;
        this.showConfirmationModal = false;
        if (action === 'resetAll') {
            this.resetAll(true);
        }
    }

    handleConfirmationCancel() {
        this.showConfirmationModal = false;
    }

    handleResetAllClick() {
        this.openConfirmation('resetAll', this.labels.Grid_ResetAll, this.labels.Grid_ResetAll_Confirm);
    }

    // ------------------------------------ Page Handling methods ------------------------------------
    async handleAgreementsNext(event) {
        let alreadySelectedAgreements = JSON.stringify(this.selectedAgreements);
        let alreadySelectedTeam = this.selectedTeam;
        this.selectedAgreements = event.detail?.agreements || [];
        this.selectedTeam = event.detail?.team;
        this.countriesOfDistribution = event.detail?.countriesOfDistribution;
        this.selectedAgreementNames = this.getSelectedAgreementNames();
        this.gridRequestData = {
            kind:                    event.detail?.kind,
            gridType:                event.detail?.gridType,
            isAutoGridUpdate:        event.detail?.isAutoGridUpdate,
            startDate:               event.detail?.startDate,
            endDate:                 event.detail?.endDate,
            thresholdAmount:         event.detail?.thresholdAmount,
            thresholdAmountCurrency: event.detail?.thresholdAmountCurrency,
            otherFees:               event.detail?.otherFees,
            comment:                 event.detail?.comment,
            gridName:                event.detail?.gridName
        };

        if((alreadySelectedAgreements != JSON.stringify(this.selectedAgreements)) || (alreadySelectedTeam != this.selectedTeam)) {
            this.resetAll(false);
            await this.loadGrids();
            await this.loadGridSettings();
            await this.loadAllProductsForSelection();
        }

        // Inject prefilled draft data if available (set in connectedCallback when hasDraftGrid)
        if (this.pendingDraftData) {
            const draftCriteriaList = this.pendingDraftData.criteriaList;
            this.criteriaList = this.buildCriteriaListFromDraft(draftCriteriaList);
            this.selectedShareClasses = this.buildSelectedShareClassesFromDraft(draftCriteriaList, this.criteriaList);
            this.pendingDraftData = null;
        }

        if (event.detail?.loadPreviousGrid && this.recId) {
            await this.loadApprovedGridAsTemplate();
        }

        this.handlePages(false, true, false);
    }

    async loadApprovedGridAsTemplate() {
        try {
            this.isLoading = true;
            const approvedData = await getApprovedGridData({ agreementId: this.recId });
            if (approvedData) {
                const criteriaList = approvedData.criteriaList;
                this.criteriaList = this.buildCriteriaListFromDraft(criteriaList);
                this.selectedShareClasses = this.buildSelectedShareClassesFromDraft(criteriaList, this.criteriaList);
            }
        } catch (error) {
            showToast(this, this.labels.UI_Error, reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
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

    handleSimulationRequested() {
        this.showSimulation = true;
    }

    handleSimulationBack() {
        this.showSimulation = false;
    }

    handleGridSaved(event) {
        const { gridName, agreementId } = event.detail || {};
        showToast(this, this.labels.UI_Success, this.labels.Grid_Saved_Success.replace('{0}', gridName), 'success');

        // Navigate to the first agreement record
        if (agreementId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: agreementId,
                    objectApiName: 'Convention__c',
                    actionName: 'view'
                }
            });
        }
    }

    handlePages(showGridAgreementSelectionP, showGridBuilderP, showValidationP) {
        this.showAgreementsPage = showGridAgreementSelectionP;
        this.showGridBuilderPage = showGridBuilderP;
        this.showValidationPage = showValidationP;
    }

    // ------------------------------------ Criteria -> SObject ------------------------------------
    getCriteriaSObject() {
        return {
            StandardGrid__c:          this.criteria.grid,
            FilterLogic__c:           this.criteria.filterLogicType,
            FilterLogicExpression__c: this.criteria.filterLogicText,
            SelectedShareTypes__c:    (this.selectedShareTypes || []).join(',')
        };
    }

    getCriteriaDetailSObject() {
        const details = this.criteria.details || [];
        return details
            .filter(detail => detail.objectApi && detail.fieldApi && detail.operator)
            .map(detail => {
                return {
                    Object__c       : detail.objectApi,
                    Field__c        : detail.fieldApi,
                    Logic__c        : detail.operator,
                    Value__c        : detail.value,
                    FilterNumber__c : detail.filterNumber,
                    TECHOrigin__c   : detail.TECHOrigin__c || 'User-Defined'
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
        return this.allObjectLabels?.[objectApi] || this.labels.UI_UnknownObject;
    }

    getFieldLabel(objectApi, fieldApi) {
        const fields = this.fieldsByObject?.[objectApi] || [];
        const match = fields.find(field => field.value === fieldApi);
        return match ? match.label : this.labels.UI_UnknownObject;
    }

    getProductNameLabel() {
        const productFields = this.fieldsByObject?.Product__c || [];
        const match = productFields.find(field => field.value === 'ProductName__c');
        return match ? match.label : this.labels.Grid_ProductNameLabel;
    }
}