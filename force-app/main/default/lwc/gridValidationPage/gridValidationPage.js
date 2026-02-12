import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProducts from '@salesforce/apex/GridValidationController.getProducts';
import saveGrid from '@salesforce/apex/GridValidationController.saveGrid';

export default class GridValidationPage extends LightningElement {
    @api gridBuilderSettingName = 'StandardGridBuilderSetting';
    @api selectedTeam;
    @api selectedShareClasses = [];
    @api selectedAgreements = [];
    @api criteriaList = [];
    @api isAutoGridUpdate = false;
    @api agreementStartDate;
    @api agreementNames;

    @track validationProducts = [];
    @track validationColumns = [];
    @track isLoading = false;
    
    @track showGridPicker = false;
    @track gridPickerOptions = [];
    @track gridPickerShareClass;
    @track gridPickerProductId;

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
        return this.allExpanded ? 'Collapse All' : 'Expand All';
    }

    connectedCallback() {
        this.runValidation();
    }

    async handleValidate() {
        this.isLoading = true;
        try {
            const request = this.buildSaveRequest();
            const shareClassGridIdMap = this.buildShareClassGridIdMap(this.selectedShareClasses);
            const result = await saveGrid({ 
                requestJson: JSON.stringify(request),
                shareClassGridIdMap: shareClassGridIdMap
            });

            if (result.success) {
                this.showToast('Success', `Grid "${result.gridName}" created successfully`, 'success');
                // Dispatch event to parent to handle navigation
                const firstAgreementId = this.selectedAgreements && this.selectedAgreements.length > 0
                    ? this.selectedAgreements[0]
                    : null;
                this.dispatchEvent(new CustomEvent('gridsaved', {
                    detail: { gridId: result.gridId, gridName: result.gridName, agreementId: firstAgreementId }
                }));
            } else {
                this.showToast('Error', result.errors.join('\n'), 'error');
            }
        } catch (error) {
            this.showToast('Error', 'Error saving grid: ' + this.reduceError(error), 'error');
            console.error('Error saving grid', error);
        } finally {
            this.isLoading = false;
        }
    }

    buildGridName() {
        const names = this.agreementNames || 'Unknown';
        const mode = this.isAutoGridUpdate ? 'Auto' : 'Manual';
        const dateStr = this.agreementStartDate || new Date().toISOString().split('T')[0];
        return `Custom - ${names} - ${mode} - ${dateStr}`;
    }

    buildSaveRequest() {
        const grid = {
            Name: this.buildGridName(),
            Team__c: this.selectedTeam,
            ActiveGrid__c: true,
            AutomaticGridUpdate__c: this.isAutoGridUpdate
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
                        StartDate__c: this.agreementStartDate || null
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
            this.showToast('No products found', 'No products found to validate with the current selection.', 'info');
            return;
        }

        this.isLoading = true;
        try {
            const shareClassIds = this.selectedShareClasses.map(row => row.id);
            this.productGridOptions = this.buildProductGridOptions(this.selectedShareClasses);

            const shareClassGridIdMap = this.buildShareClassGridIdMap(this.selectedShareClasses);
            const validationResult = await getProducts({
                gridBuilderSettingName: this.gridBuilderSettingName,
                selectedTeam: this.selectedTeam,
                selectedShareClassIds: shareClassIds, 
                agreementIds: this.selectedAgreements,
                shareClassGridIdMap: shareClassGridIdMap
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
            this.validationColumns = this.buildResultColumnsList(fieldsApiToInfoMap);
            this.validationProducts = products.map(prod => this.buildProductWithStatus(prod, fieldsApiToInfoMap, selectedGridMap));

            if (!this.validationProducts.length) {
                this.showToast('No products found', 'No products found to validate with the current selection.', 'info');
            }
        } catch (error) {
            this.validationProducts = [];
            this.validationColumns = [];
            this.showToast('Error', 'Error validating products, ' + this.reduceError(error), 'error');
            console.error('Error validating products', this.reduceError(error));
        } finally {
            this.isLoading = false;
        }
    }

    buildResultColumnsList(fieldsApiToInfoMap) {
        const resultCols = Object.keys(fieldsApiToInfoMap || {}).map(apiName => {
            const fieldInfo = fieldsApiToInfoMap[apiName];
            return {
                apiName: apiName,
                label: fieldInfo.label
            };
        });
        resultCols.push({ apiName: 'Grid', label: 'Grid' });
        resultCols.push({ apiName: 'Status', label: 'Status' });
        resultCols.push({ apiName: 'AUM', label: 'AUM (Eur)', class: 'alignRight' });
        resultCols.push({ apiName: 'Action', label: 'Action', class: 'alignCenter' });
        return resultCols;
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
            headerMessages.push('Missing share class(es)');
        }
        if (gridMismatch) {
            headerMessages.push('Different Grids selected');
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
            cells.push({ label: 'Status', value: sc.isSelected ? 'Included in grid' : 'Missing share class', class: 'slds-truncate'});
            cells.push({ label: 'AUM', value: sc.amountAUM != null ? sc.amountAUM : 0, class: 'slds-truncate alignRight'});
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
                actionLabel: sc.isSelected ? 'Remove' : 'Add',
                actionVariant: sc.isSelected ? 'neutral' : 'brand'
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
        if (!productId) {
            return;
        }
        const current = this.selectedShareClasses || [];
        const removedRows = current.filter(row => row.productId === productId);
        const next = current.filter(row => row.productId !== productId);
        if (next.length === current.length) {
            return;
        }
        if (removedRows.length && this.criteriaList?.length) {
            const byCriteria = new Map();
            removedRows.forEach(row => {
                if (!row.criteriaRefId) {
                    return;
                }
                const isin = this.getIsinFromRow(row);
                if (!isin) {
                    return;
                }
                if (!byCriteria.has(row.criteriaRefId)) {
                    byCriteria.set(row.criteriaRefId, []);
                }
                byCriteria.get(row.criteriaRefId).push(isin);
            });
            byCriteria.forEach((ids, criteriaRefId) => {
                this.criteriaList = this.updateCriteria(ids, criteriaRefId, 'NOT IN');
            });
        }
        this.selectedShareClasses = next;
        this.dispatchEvent(new CustomEvent('removeproduct', { detail: { productId: productId, criteriaList: this.criteriaList } }));
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
        const gridOptions = this.productGridOptions.get(productId) || [];
        if (!gridOptions.length) {
            this.showToast('No grid available', 'No grid selection found for this product.', 'warning');
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
        this.criteriaList = this.updateCriteria([isin], gridOption.criteriaRefId, 'IN');
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
            this.criteriaList = this.updateCriteria([target.isin], target.criteriaRefId, 'NOT IN');
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
                const statusCell = { label: 'Status', value: isSelected ? 'Included in grid' : 'Missing share class', class: 'slds-truncate'};
                const aumCell = { label: 'AUM', value: sc.amountAUM != null ? sc.amountAUM : 0, class: 'slds-truncate alignRight' };
                const filteredCells = newCells.filter(c => c.label !== 'Status').filter(c => c.label !== 'AUM');
                filteredCells.push(statusCell);
                filteredCells.push(aumCell);
                return {
                    ...sc,
                    isSelected: isSelected,
                    gridLabel: gridLabel,
                    criteriaRefId: sc.criteriaRefId || null,
                    rowClass: isSelected ? '' : 'missing-share-class',
                    cells: filteredCells,
                    actionLabel: isSelected ? 'Remove' : 'Add',
                    actionVariant: isSelected ? 'neutral' : 'brand'
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
                headerMessages.push('Missing share class(es)');
            }
            if (gridMismatch) {
                headerMessages.push('Different Grids selected');
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

    updateCriteria(shareClassIsins, criteriaRefId, logic) {
        const isins = (Array.isArray(shareClassIsins) ? shareClassIsins : []).filter(val => val);
        if (!isins.length) {
            return this.criteriaList;
        }
        const separator = ';';
        const updated = this.criteriaList.map(entry => {
            if (entry.id !== criteriaRefId) {
                return entry;
            }
            const details = (entry.criteriaDetails || []).slice();
            const idx = details.findIndex(d => d.Object__c === 'Share_Class__c' && d.Field__c === 'ISIN__c' && d.Logic__c === logic && d.TECHOrigin__c === 'System');
            const currentValues = idx >= 0 && details[idx].Value__c ? details[idx].Value__c.split(separator).map(val => val.trim()).filter(val => val) : [];
            const valueSet = new Set(currentValues);
            isins.forEach(isin => {
                if (valueSet.has(isin)) {
                    valueSet.delete(isin);
                }
                else {
                    valueSet.add(isin);
                }
            });
            const nextValues = Array.from(valueSet);
            if (nextValues.length) {
                const detail = {
                    Object__c: 'Share_Class__c',
                    Field__c: 'ISIN__c',
                    Logic__c: logic,
                    Value__c: nextValues.join(' '+separator+' '),
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
            }
            else if (idx >= 0) {
                details.splice(idx, 1);
            }
            return { ...entry, criteriaDetails: details };
        });
        return updated;
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

    buildProductGridOptions(selectedRows) {
        const mapByProduct = new Map();
        (selectedRows || []).forEach(row => {
            const productId = row.productId;
            if (!productId) {
                return;
            }
            const gridId = row.gridId;
            const gridLabel = (row.cells || []).find(c => c.label === 'Grid')?.value || '';
            const criteriaRefId = row.criteriaRefId;
            if (!gridId || !gridLabel) {
                return;
            }
            const key = productId;
            if (!mapByProduct.has(key)) {
                mapByProduct.set(key, []);
            }
            const existing = mapByProduct.get(key);
            if (!existing.find(g => g.gridId === gridId)) {
                existing.push({
                    gridId: gridId,
                    gridLabel: gridLabel,
                    criteriaRefId: criteriaRefId || null
                });
            }
        });
        return mapByProduct;
    }

    buildShareClassGridIdMap(selectedRows) {
        const shareClassGridIdMap = {};
        (selectedRows || []).forEach(row => {
            if (row?.id && row?.gridId) {
                shareClassGridIdMap[row.id] = row.gridId;
            }
        });
        return shareClassGridIdMap;
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

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
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