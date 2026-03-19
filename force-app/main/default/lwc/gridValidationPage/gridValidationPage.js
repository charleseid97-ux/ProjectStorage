import { LightningElement, api, track } from 'lwc';
import getProducts from '@salesforce/apex/GridValidationController.getProducts';
import saveGrid from '@salesforce/apex/GridValidationController.saveGrid';
import {LABELS, reduceError, showToast, buildShareClassGridIdMap, buildProductGridOptions, buildResultColumnsList, updateCriteriaListWithIsins, 
    addIsinExclusionsFromRows} from 'c/gridBuilderUtils';

export default class GridValidationPage extends LightningElement {
    @api gridBuilderSettingName = 'StandardGridBuilderSetting';
    @api selectedTeam;
    @api selectedShareClasses = [];
    @api selectedAgreements = [];
    @api criteriaList = [];
    @api gridRequestData = {};
    @api agreementNames;
    @api gridShareClassMap = {};
    @api existingGridId = null;

    @track validationProducts = [];
    @track validationColumns = [];
    @track isLoading = false;
    
    @track showGridPicker = false;
    @track gridPickerOptions = [];
    @track gridPickerShareClass;
    @track gridPickerProductId;

    labels = LABELS;
    previousIdsKey;
    validationFieldsMap;
    productGridOptions = new Map();

    get hasValidationResults() {
        return this.validationProducts && this.validationProducts.length > 0;
    }

    get isValidateButtonDisabled() {
        return !this.hasValidationResults;
    }

    get validationColumnWidthStyle() {
        const totalCols = (this.validationColumns?.length || 0);
        if (!totalCols) {
            return '';
        }
        const width = (100 / totalCols).toFixed(2) + '%';
        return `width: ${width};`;
    }

    get allExpanded() {
        return (this.validationProducts || []).length > 0 && this.validationProducts.every(p => p.isOpen);
    }

    get toggleAllLabel() {
        return this.allExpanded ? this.labels.UI_CollapseAll : this.labels.UI_ExpandAll;
    }

    connectedCallback() {
        this.runValidation();
    }

    async handleValidate() {
        this.isLoading = true;
        try {
            const request = this.buildSaveRequest();
            const shareClassGridIdMap = buildShareClassGridIdMap(this.selectedShareClasses);
            const result = await saveGrid({
                requestJson: JSON.stringify(request),
                shareClassGridIdMap: shareClassGridIdMap,
                draftGridId: this.existingGridId || null
            });

            if (result.success) {
                showToast(this, this.labels.UI_Success, this.labels.Grid_CreatedSuccess.replace('{0}', result.gridName), 'success');
                // Dispatch event to parent to handle navigation
                const firstAgreementId = this.selectedAgreements && this.selectedAgreements.length > 0
                    ? this.selectedAgreements[0]
                    : null;
                this.dispatchEvent(new CustomEvent('gridsaved', {
                    detail: { gridId: result.gridId, gridName: result.gridName, agreementId: firstAgreementId }
                }));
            } else {
                showToast(this, this.labels.UI_Error, result.errors.join('\n'), 'error');
            }
        } catch (error) {
            showToast(this, this.labels.UI_Error, this.labels.Grid_ErrorSavingGrid + ', ' + this.labels.UI_ErrorMessage + ': ' + reduceError(error), 'error');
            console.error('Error saving grid', error);
        } finally {
            this.isLoading = false;
        }
    }

    buildSaveRequest() {
        const grid = {
            Name:                        (this.gridRequestData.gridName || '').slice(0, 80),
            Team__c:                     this.selectedTeam,
            ActiveGrid__c:               true,
            AutomaticGridUpdate__c:      this.gridRequestData.isAutoGridUpdate,
            Kind__c:                     this.gridRequestData.kind                    || null,
            Type__c:                     this.gridRequestData.gridType                || null,
            StartDate__c:                this.gridRequestData.startDate               || null,
            EndDate__c:                  this.gridRequestData.endDate                 || null,
            ThresholdAmount__c:          this.gridRequestData.thresholdAmount         || null,
            ThresholdAmountCurrency__c:  this.gridRequestData.thresholdAmountCurrency || null,
            MinimumAmount__c:            this.gridRequestData.minimumAmount           || null,
            MinimumAmountCurrency__c:    this.gridRequestData.minimumAmountCurrency   || null,
            MinimumAmountFrequency__c:   this.gridRequestData.minimumAmountFrequency  || null
        };

        // Group share classes by criteriaRefId
        const criteriaMap = new Map();
        (this.selectedShareClasses || []).forEach(sc => {
            if (!criteriaMap.has(sc.criteriaRefId)) {
                const entry = (this.criteriaList || []).find(c => c.id === sc.criteriaRefId);
                criteriaMap.set(sc.criteriaRefId, {
                    criteriaRefId: sc.criteriaRefId,
                    criteria: {
                        StandardGrid__c: entry?.criteria?.StandardGrid__c,
                        FilterLogic__c: entry?.criteria?.FilterLogic__c || 'AND',
                        FilterLogicExpression__c: entry?.criteria?.FilterLogicExpression__c || null,
                        StartDate__c: this.gridRequestData.startDate || null
                    },
                    details: (entry?.criteriaDetails || []).map(d => ({
                        Object__c: d.Object__c,
                        Field__c: d.Field__c,
                        Logic__c: d.Logic__c,
                        Value__c: d.Value__c,
                        FilterNumber__c: d.FilterNumber__c,
                        TECHOrigin__c: d.TECHOrigin__c
                    })),
                    shareClassIds: []
                });
            }
            criteriaMap.get(sc.criteriaRefId).shareClassIds.push(sc.id);
        });

        return {
            grid: grid,
            criteriaList: Array.from(criteriaMap.values()),
            agreementIds: this.selectedAgreements || []
        };
    }

    async runValidation() {
        const idsKey = (this.selectedShareClasses || []).map(r => `${r.id}:${r.gridId || ''}`).join(',') + '|' + (this.selectedAgreements || []).join(',');
        if (idsKey === this.previousIdsKey) {
            return;
        }
        this.previousIdsKey = idsKey;

        if (!this.selectedShareClasses || !this.selectedShareClasses.length) {
            this.validationProducts = [];
            this.validationColumns = [];
            showToast(this, this.labels.Grid_NoProductsFound, this.labels.Grid_NoProductsFoundValidation, 'info');
            return;
        }

        this.isLoading = true;
        try {
            const shareClassIds = this.selectedShareClasses.map(row => row.id);
            this.productGridOptions = buildProductGridOptions(this.selectedShareClasses);

            const shareClassGridIdMap = buildShareClassGridIdMap(this.selectedShareClasses);
            const validationResult = await getProducts({
                gridBuilderSettingName: this.gridBuilderSettingName,
                selectedTeam: this.selectedTeam,
                selectedShareClassIds: shareClassIds,
                agreementIds: this.selectedAgreements,
                shareClassGridIdMap: shareClassGridIdMap,
                availableGridIds: Object.keys(this.gridShareClassMap || {})
            });
            const fieldsApiToInfoMap = validationResult?.fieldsApiToInfoMap || {};
            const products = validationResult?.products || [];
            const selectedGridMap = new Map(
                this.selectedShareClasses.map(row => {
                    const gridCell = (row.cells || []).find(c => c.label === 'Grid');
                    return [row.id, { label: (gridCell?.value || ''), id: row.gridId, criteriaRefId: row.criteriaRefId }];
                })
            );

            this.validationFieldsMap = fieldsApiToInfoMap;
            this.validationColumns = buildResultColumnsList(fieldsApiToInfoMap, true, true, true, true);
            this.validationProducts = products.map(prod => this.buildProductWithStatus(prod, fieldsApiToInfoMap, selectedGridMap));

            if (!this.validationProducts.length) {
                showToast(this, this.labels.Grid_NoProductsFound, this.labels.Grid_NoProductsFoundValidation, 'info');
            }
        } catch (error) {
            this.validationProducts = [];
            this.validationColumns = [];
            showToast(this, this.labels.UI_Error, this.labels.Grid_ErrorValidatingProducts + ', ' + this.labels.UI_ErrorMessage + ': ' + reduceError(error), 'error');
            console.error('Error validating products', reduceError(error));
        } finally {
            this.isLoading = false;
        }
    }

    buildProductWithStatus(prod, fieldsApiToInfoMap, selectedGridMap) {
        const shareClasses = this.buildValidationShareClasses(fieldsApiToInfoMap, prod, selectedGridMap);
        const total = shareClasses.length;
        const selectedCount = shareClasses.filter(sc => sc.isSelected).length;
        const missingShareClasses = shareClasses.some(sc => !sc.isSelected);
        const selectedGrids = shareClasses.filter(sc => sc.isSelected).map(sc => sc.gridLabel).filter(r => r !== '');
        const distinctSelectedGrids = [...new Set(selectedGrids)];
        const gridMismatch = distinctSelectedGrids.length > 1;
        const hasIssues = missingShareClasses || gridMismatch;
        const sectionStyle = hasIssues ? 'background: #ffc8c8;' : '';
        const headerMessages = [];
        if (missingShareClasses) {
            headerMessages.push(this.labels.Grid_MissingShareClasses);
        }
        if (gridMismatch) {
            headerMessages.push(this.labels.Grid_DifferentGridsSelected);
        }
        const headerGrid = (!gridMismatch && distinctSelectedGrids.length === 1) ? distinctSelectedGrids[0] : '';
        const headerMessagesText = headerMessages.length ? headerMessages.join(' | ') : '';

        return {
            ...prod,
            headerMessagesText: headerMessagesText,
            headerGrid: headerGrid,
            missingShareClasses: missingShareClasses,
            totalShareClasses: total,
            selectedCount: selectedCount,
            missingCount: total - selectedCount,
            hasIssues: hasIssues,
            sectionStyle: sectionStyle,
            isOpen: false,
            toggleIconName: 'utility:chevronright',
            noShareClassesSelected: selectedCount === 0,
            shareClasses: shareClasses
        };
    }

    buildValidationShareClasses(fieldsApiToInfoMap, product, selectedGridMap) {
        const fieldApis = fieldsApiToInfoMap ? Object.keys(fieldsApiToInfoMap) : [];
        const shareClasses = product.shareClasses || [];
        return shareClasses.map(sc => {
            const recordResults = sc.recordResults || {};
            const gridInfo = selectedGridMap?.get(sc.shareClassId) || {};
            const gridLabel = gridInfo.label || '';
            const criteriaRefId = gridInfo.criteriaRefId || null;
            const cells = fieldApis.map(apiName => ({
                label: fieldsApiToInfoMap[apiName].label,
                value: recordResults[apiName] != null ? recordResults[apiName] : '',
                class: 'slds-truncate'
            }));
            cells.push({ label: 'Grid', value: gridLabel, class: 'slds-truncate'});
            cells.push({ label: 'Status', value: sc.isSelected ? this.labels.Grid_IncludedInGrid : this.labels.Grid_MissingShareClass, class: 'slds-truncate'});
            cells.push({ label: 'AUM', value: sc.amountAUM != null ? sc.amountAUM : 0, class: 'slds-truncate alignRight'});
            const gridOptions = this.productGridOptions.get(product.productId) || [];
            const canAdd = !sc.isSelected && gridOptions.some(opt => (this.gridShareClassMap?.[opt.gridId] || []).includes(sc.shareClassId));
            return {
                ...sc,
                productId: product.productId,
                productLabel: product.productLabel,
                gridLabel: gridLabel,
                criteriaRefId: criteriaRefId,
                shareClassName: recordResults.Name || recordResults['Name'] || '',
                isin: recordResults.ISIN__c || recordResults['ISIN__c'] || '',
                rowClass: sc.isSelected ? '' : 'missing-share-class',
                cells: cells,
                actionLabel: sc.isSelected ? this.labels.UI_Remove : this.labels.UI_Add,
                actionVariant: sc.isSelected ? 'neutral' : 'brand',
                addDisabled: sc.isSelected ? false : !canAdd
            };
        });
    }

    handleToggleValidationSection(event) {
        const prodId = event.currentTarget.dataset.id;
        this.validationProducts = this.validationProducts.map(prod => {
            if (prod.productId === prodId) {
                const newIsOpen = !prod.isOpen;
                return {
                    ...prod,
                    isOpen: newIsOpen,
                    toggleIconName: newIsOpen ? 'utility:chevrondown' : 'utility:chevronright'
                };
            }
            return prod;
        });
    }

    handleRemoveProduct(event) {
        event.stopPropagation();
        const productId = event.currentTarget.dataset.id;
        if (!productId) return;
        const current = this.selectedShareClasses || [];
        const removedRows = current.filter(row => row.productId === productId);
        const next = current.filter(row => row.productId !== productId);
        if (next.length === current.length) return;
        if (removedRows.length && this.criteriaList?.length) {
            this.criteriaList = addIsinExclusionsFromRows(this.criteriaList, removedRows);
        }
        this.selectedShareClasses = next;
        this.dispatchEvent(new CustomEvent('removeproduct', { detail: { productId, criteriaList: this.criteriaList } }));
        this.runValidation();
    }

    handleToggleAllSections() {
        const nextOpen = !this.allExpanded;
        this.validationProducts = (this.validationProducts || []).map(prod => ({
            ...prod,
            isOpen: nextOpen,
            toggleIconName: nextOpen ? 'utility:chevrondown' : 'utility:chevronright'
        }));
    }

    handleToggleShareClass(event) {
        const shareClassId = event.currentTarget.dataset.id;
        const productId = event.currentTarget.dataset.product;
        const isSelected = event.currentTarget.dataset.selected === 'true';
        const product = this.validationProducts.find(p => p.productId === productId);
        if (!product) {
            return;
        }

        const targetShareClass = product.shareClasses.find(sc => sc.shareClassId === shareClassId);
        if (!targetShareClass) {
            return;
        }

        if (isSelected) {
            this.removeShareClass(shareClassId, productId);
        } else {
            this.handleAddShareClass(targetShareClass, productId);
        }
    }

    handleAddShareClass(shareClass, productId) {
        const allGridOptions = this.productGridOptions.get(productId) || [];
        const gridOptions = allGridOptions.filter(opt => (this.gridShareClassMap?.[opt.gridId] || []).includes(shareClass.shareClassId));
        if (!gridOptions.length) {
            showToast(this, this.labels.Grid_NoGridAvailable, this.labels.Grid_NoGridSelectionFound, 'warning');
            return;
        }
        if (gridOptions.length === 1) {
            this.applyAddShareClass(shareClass, productId, gridOptions[0]);
        } else {
            this.gridPickerOptions = gridOptions.map(opt => ({
                label: opt.gridLabel,
                value: opt.gridId
            }));
            this.gridPickerShareClass = shareClass;
            this.gridPickerProductId = productId;
            this.showGridPicker = true;
        }
    }

    handleGridPick(event) {
        const gridId = event.detail?.value;
        const productId = this.gridPickerProductId;
        if (!gridId || !this.gridPickerShareClass || !productId) {
            this.resetGridPicker();
            return;
        }
        const gridOptions = this.productGridOptions.get(productId) || [];
        const selectedGrid = gridOptions.find(opt => opt.gridId === gridId);
        if (selectedGrid) {
            this.applyAddShareClass(this.gridPickerShareClass, productId, selectedGrid);
        }
        this.resetGridPicker();
    }

    handleCancelGridPick() {
        this.resetGridPicker();
    }

    resetGridPicker() {
        this.showGridPicker = false;
        this.gridPickerShareClass = null;
        this.gridPickerProductId = null;
        this.gridPickerOptions = [];
    }

    applyAddShareClass(shareClass, productId, gridOption) {
        const isin = shareClass.isin || (shareClass.recordResults ? shareClass.recordResults['ISIN__c'] : null);
        this.criteriaList = updateCriteriaListWithIsins(this.criteriaList, gridOption.criteriaRefId, [isin], 'IN');
        const newRow = this.buildSelectionRowFromShareClass(shareClass, gridOption);
        const existingMap = new Map(this.selectedShareClasses.map(r => [r.id, r]));
        existingMap.set(newRow.id, newRow);
        this.selectedShareClasses = Array.from(existingMap.values());
        this.updateValidationProducts(productId, shareClass.shareClassId, true, gridOption.gridLabel);
        this.dispatchSelectionChange();
    }

    removeShareClass(shareClassId, productId) {
        const target = (this.selectedShareClasses || []).find(r => r.id === shareClassId);
        if (target && target.criteriaRefId) {
            this.criteriaList = updateCriteriaListWithIsins(this.criteriaList, target.criteriaRefId, [target.isin], 'NOT IN');
        }
        this.selectedShareClasses = (this.selectedShareClasses || []).filter(r => r.id !== shareClassId);
        this.updateValidationProducts(productId, shareClassId, false, '');
        this.dispatchSelectionChange();
    }

    updateValidationProducts(productId, shareClassId, isSelected, gridLabel) {
        this.validationProducts = this.validationProducts.map(prod => {
            if (prod.productId !== productId) {
                return prod;
            }
            const updatedShareClasses = prod.shareClasses.map(sc => {
                if (sc.shareClassId !== shareClassId) {
                    return sc;
                }
                const newCells = (sc.cells || []).map(cell => cell.label === 'Grid' ? { ...cell, value: gridLabel } : cell);
                const statusCell = { label: 'Status', value: isSelected ? this.labels.Grid_IncludedInGrid : this.labels.Grid_MissingShareClass, class: 'slds-truncate'};
                const aumCell = { label: 'AUM', value: sc.amountAUM != null ? sc.amountAUM : 0, class: 'slds-truncate alignRight' };
                const filteredCells = newCells.filter(c => c.label !== 'Status').filter(c => c.label !== 'AUM');
                filteredCells.push(statusCell);
                filteredCells.push(aumCell);
                const gridOpts = this.productGridOptions.get(productId) || [];
                const canAdd = !isSelected && gridOpts.some(opt => (this.gridShareClassMap?.[opt.gridId] || []).includes(sc.shareClassId));
                return {
                    ...sc,
                    isSelected: isSelected,
                    gridLabel: gridLabel,
                    criteriaRefId: sc.criteriaRefId || null,
                    rowClass: isSelected ? '' : 'missing-share-class',
                    cells: filteredCells,
                    actionLabel: isSelected ? this.labels.UI_Remove : this.labels.UI_Add,
                    actionVariant: isSelected ? 'neutral' : 'brand',
                    addDisabled: isSelected ? false : !canAdd
                };
            });
            const total = updatedShareClasses.length;
            const selectedCount = updatedShareClasses.filter(sc => sc.isSelected).length;
            const missingShareClasses = updatedShareClasses.some(sc => !sc.isSelected);
            const selectedGrids = updatedShareClasses.filter(sc => sc.isSelected).map(sc => sc.gridLabel).filter(r => r !== '');
            const distinctSelectedGrids = [...new Set(selectedGrids)];
            const gridMismatch = distinctSelectedGrids.length > 1;
            const hasIssues = missingShareClasses || gridMismatch;
            const headerMessages = [];
            if (missingShareClasses) {
                headerMessages.push(this.labels.Grid_MissingShareClasses);
            }
            if (gridMismatch) {
                headerMessages.push(this.labels.Grid_DifferentGridsSelected);
            }
            const headerGrid = (!gridMismatch && distinctSelectedGrids.length === 1) ? distinctSelectedGrids[0] : '';
            const headerMessagesText = headerMessages.length ? headerMessages.join(' | ') : '';

            return {
                ...prod,
                headerMessagesText,
                headerGrid,
                missingShareClasses,
                totalShareClasses: total,
                selectedCount,
                missingCount: total - selectedCount,
                hasIssues,
                sectionStyle: hasIssues ? 'background: #ffc8c8;' : '',
                shareClasses: updatedShareClasses
            };
        });
    }

    buildSelectionRowFromShareClass(sc, gridOption) {
        const fieldMap = this.validationFieldsMap || {};
        const apiNames = Object.keys(fieldMap);
        const cells = apiNames.map(apiName => ({
            label: fieldMap[apiName].label,
            value: sc.recordResults && sc.recordResults[apiName] != null ? sc.recordResults[apiName] : '',
            class: 'slds-truncate'
        }));
        cells.push({ label: 'Grid', value: gridOption.gridLabel, class: 'slds-truncate' });
        cells.push({ label: 'AUM', value: sc.amountAUM != null ? sc.amountAUM : 0, class: 'slds-truncate alignRight' });

        return {
            id: sc.shareClassId,
            cells: cells,
            gridId: gridOption.gridId,
            effManFees: sc.recordResults ? sc.recordResults['EffectiveManagementFees__c'] : null,
            isin: sc.isin || (sc.recordResults ? sc.recordResults['ISIN__c'] : null),
            isSelected: true,
            productId: sc.productId,
            productLabel: sc.productLabel,
            gridLabel: gridOption.gridLabel,
            criteriaRefId: gridOption.criteriaRefId || null
        };
    }

    dispatchSelectionChange() {
        this.dispatchEvent(new CustomEvent('selectionchange', {
            detail: { selectedShareClasses: this.selectedShareClasses, criteriaList: this.criteriaList }
        }));
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleViewRecap() {
        this.dispatchEvent(new CustomEvent('viewrecap'));
    }
}