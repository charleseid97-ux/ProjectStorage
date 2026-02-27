/**
* @description Shared utility functions for Grid Builder LWC components
* @author Charles EID
*/

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

//Import Labels - UI
import UI_Add from '@salesforce/label/c.UI_Add';
import UI_Back from '@salesforce/label/c.UI_Back';
import UI_Cancel from '@salesforce/label/c.UI_Cancel';
import UI_Close from '@salesforce/label/c.UI_Close';
import UI_CollapseAll from '@salesforce/label/c.UI_CollapseAll';
import UI_Confirm from '@salesforce/label/c.UI_Confirm';
import UI_Error from '@salesforce/label/c.UI_Error';
import UI_ErrorMessage from '@salesforce/label/c.UI_ErrorMessage';
import UI_Errors from '@salesforce/label/c.UI_Errors';
import UI_Excluded from '@salesforce/label/c.UI_Excluded';
import UI_ExpandAll from '@salesforce/label/c.UI_ExpandAll';
import UI_Field from '@salesforce/label/c.UI_Field';
import UI_Import from '@salesforce/label/c.UI_Import';
import UI_Included from '@salesforce/label/c.UI_Included';
import UI_Loading from '@salesforce/label/c.UI_Loading';
import UI_NA from '@salesforce/label/c.UI_NA';
import UI_Next from '@salesforce/label/c.UI_Next';
import UI_Object from '@salesforce/label/c.UI_Object';
import UI_Off from '@salesforce/label/c.UI_Off';
import UI_On from '@salesforce/label/c.UI_On';
import UI_Operator from '@salesforce/label/c.UI_Operator';
import UI_Refresh from '@salesforce/label/c.UI_Refresh';
import UI_Remove from '@salesforce/label/c.UI_Remove';
import UI_SelectOption from '@salesforce/label/c.UI_SelectOption';
import UI_Success from '@salesforce/label/c.UI_Success';
import UI_UnknownField from '@salesforce/label/c.UI_UnknownField';
import UI_UnknownObject from '@salesforce/label/c.UI_UnknownObject';
import UI_Value from '@salesforce/label/c.UI_Value';
import UI_Warning from '@salesforce/label/c.UI_Warning';
//Import Labels - Grid
import Grid_AddFilter from '@salesforce/label/c.Grid_AddFilter';
import Grid_AddRestrictedShareTypes from '@salesforce/label/c.Grid_AddRestrictedShareTypes';
import Grid_AddToGrid from '@salesforce/label/c.Grid_AddToGrid';
import Grid_AgreementErrorLoadingSettings from '@salesforce/label/c.Grid_AgreementErrorLoadingSettings';
import Grid_Agreements from '@salesforce/label/c.Grid_Agreements';
import Grid_AllRowsImported from '@salesforce/label/c.Grid_AllRowsImported';
import Grid_AlreadySelected from '@salesforce/label/c.Grid_AlreadySelected';
import Grid_ApplyFilters from '@salesforce/label/c.Grid_ApplyFilters';
import Grid_AutoIncludeHelpText from '@salesforce/label/c.Grid_AutoIncludeHelpText';
import Grid_AutoIncludeLabel from '@salesforce/label/c.Grid_AutoIncludeLabel';
import Grid_AutomaticUpdate from '@salesforce/label/c.Grid_AutomaticUpdate';
import Grid_Builder from '@salesforce/label/c.Grid_Builder';
import Grid_CreatedSuccess from '@salesforce/label/c.Grid_CreatedSuccess';
import Grid_CriteriaCreated from '@salesforce/label/c.Grid_CriteriaCreated';
import Grid_CriteriaDetailsCreated from '@salesforce/label/c.Grid_CriteriaDetailsCreated';
import Grid_CriteriaHistory from '@salesforce/label/c.Grid_CriteriaHistory';
import Grid_CriteriaLabel from '@salesforce/label/c.Grid_CriteriaLabel';
import Grid_CriteriaNumber from '@salesforce/label/c.Grid_CriteriaNumber';
import Grid_AgreementGridHistory from '@salesforce/label/c.Grid_AgreementGridHistory';
import Grid_AgreementGridRecap from '@salesforce/label/c.Grid_AgreementGridRecap';
import Grid_CurrentGridRecap from '@salesforce/label/c.Grid_CurrentGridRecap';
import Grid_DetailsTitle from '@salesforce/label/c.Grid_DetailsTitle';
import Grid_DifferentGridsSelected from '@salesforce/label/c.Grid_DifferentGridsSelected';
import Grid_ErrorLoadingGrids from '@salesforce/label/c.Grid_ErrorLoadingGrids';
import Grid_ErrorLoadingProducts from '@salesforce/label/c.Grid_ErrorLoadingProducts';
import Grid_ErrorLoadingSettings from '@salesforce/label/c.Grid_ErrorLoadingSettings';
import Grid_ErrorRetrievingProducts from '@salesforce/label/c.Grid_ErrorRetrievingProducts';
import Grid_ErrorSavingGrid from '@salesforce/label/c.Grid_ErrorSavingGrid';
import Grid_ErrorValidatingProducts from '@salesforce/label/c.Grid_ErrorValidatingProducts';
import Grid_ExcelImportTitle from '@salesforce/label/c.Grid_ExcelImportTitle';
import Grid_ExcludedProducts from '@salesforce/label/c.Grid_ExcludedProducts';
import Grid_FailedToLoadSheetJS from '@salesforce/label/c.Grid_FailedToLoadSheetJS';
import Grid_FilterNumber from '@salesforce/label/c.Grid_FilterNumber';
import Grid_FixValidationErrors from '@salesforce/label/c.Grid_FixValidationErrors';
import Grid_GridDetailsCreated from '@salesforce/label/c.Grid_GridDetailsCreated';
import Grid_GridName from '@salesforce/label/c.Grid_GridName';
import Grid_ImportCompleted from '@salesforce/label/c.Grid_ImportCompleted';
import Grid_ImportCompletedWithErrors from '@salesforce/label/c.Grid_ImportCompletedWithErrors';
import Grid_ImportFailed from '@salesforce/label/c.Grid_ImportFailed';
import Grid_ImportedFilePrefix from '@salesforce/label/c.Grid_ImportedFilePrefix';
import Grid_IncludedInGrid from '@salesforce/label/c.Grid_IncludedInGrid';
import Grid_IncludedProducts from '@salesforce/label/c.Grid_IncludedProducts';
import Grid_Label from '@salesforce/label/c.Grid_Label';
import Grid_LogicLabel from '@salesforce/label/c.Grid_LogicLabel';
import Grid_MissingShareClass from '@salesforce/label/c.Grid_MissingShareClass';
import Grid_MissingShareClasses from '@salesforce/label/c.Grid_MissingShareClasses';
import Grid_NoActiveGridAssigned from '@salesforce/label/c.Grid_NoActiveGridAssigned';
import Grid_NoDetailsFound from '@salesforce/label/c.Grid_NoDetailsFound';
import Grid_NoExcludedProducts from '@salesforce/label/c.Grid_NoExcludedProducts';
import Grid_NoGridAvailable from '@salesforce/label/c.Grid_NoGridAvailable';
import Grid_NoGridSelectionFound from '@salesforce/label/c.Grid_NoGridSelectionFound';
import Grid_NoNewShareClassesAdded from '@salesforce/label/c.Grid_NoNewShareClassesAdded';
import Grid_NoProducts from '@salesforce/label/c.Grid_NoProducts';
import Grid_NoProductsFound from '@salesforce/label/c.Grid_NoProductsFound';
import Grid_NoProductsFoundValidation from '@salesforce/label/c.Grid_NoProductsFoundValidation';
import Grid_NoProductsMatched from '@salesforce/label/c.Grid_NoProductsMatched';
import Grid_NoProductsSelected from '@salesforce/label/c.Grid_NoProductsSelected';
import Grid_NoProductsToDisplay from '@salesforce/label/c.Grid_NoProductsToDisplay';
import Grid_NoProductsToValidate from '@salesforce/label/c.Grid_NoProductsToValidate';
import Grid_NoShareClassesFound from '@salesforce/label/c.Grid_NoShareClassesFound';
import Grid_NoShareClassesToAdd from '@salesforce/label/c.Grid_NoShareClassesToAdd';
import Grid_ProductAlreadyAssignedWarning from '@salesforce/label/c.Grid_ProductAlreadyAssignedWarning';
import Grid_ProductNameLabel from '@salesforce/label/c.Grid_ProductNameLabel';
import Grid_ProductsRecap from '@salesforce/label/c.Grid_ProductsRecap';
import Grid_RemoveFilter from '@salesforce/label/c.Grid_RemoveFilter';
import Grid_RemoveProduct from '@salesforce/label/c.Grid_RemoveProduct';
import Grid_ResetAll from '@salesforce/label/c.Grid_ResetAll';
import Grid_ResetAll_Confirm from '@salesforce/label/c.Grid_ResetAll_Confirm';
import Grid_ResetAll_Success from '@salesforce/label/c.Grid_ResetAll_Success';
import Grid_ResetFilters from '@salesforce/label/c.Grid_ResetFilters';
import Grid_RowErrors from '@salesforce/label/c.Grid_RowErrors';
import Grid_GridRulesCreated from '@salesforce/label/c.Grid_GridRulesCreated';
import Grid_Saved_Success from '@salesforce/label/c.Grid_Saved_Success';
import Grid_ScopesUpserted from '@salesforce/label/c.Grid_ScopesUpserted';
import Grid_SelectExcelFile from '@salesforce/label/c.Grid_SelectExcelFile';
import Grid_SelectGrid from '@salesforce/label/c.Grid_SelectGrid';
import Grid_SelectShareTypes from '@salesforce/label/c.Grid_SelectShareTypes';
import Grid_Selection from '@salesforce/label/c.Grid_Selection';
import Grid_SettingNotFound from '@salesforce/label/c.Grid_SettingNotFound';
import Grid_ShareClassesAdded from '@salesforce/label/c.Grid_ShareClassesAdded';
import Grid_ShareClassesAddedTitle from '@salesforce/label/c.Grid_ShareClassesAddedTitle';
import Grid_ShareClassesNotAdded_DifferentGrid from '@salesforce/label/c.Grid_ShareClassesNotAdded_DifferentGrid';
import Grid_ShareTypeFilterIndependentInfo from '@salesforce/label/c.Grid_ShareTypeFilterIndependentInfo';
import Grid_ShareTypesLabel from '@salesforce/label/c.Grid_ShareTypesLabel';
import Grid_SomeRowsFailed from '@salesforce/label/c.Grid_SomeRowsFailed';
import Grid_SortedBy from '@salesforce/label/c.Grid_SortedBy';
import Grid_StandardGridsSelected from '@salesforce/label/c.Grid_StandardGridsSelected';
import Grid_StartDate from '@salesforce/label/c.Grid_StartDate';
import Grid_SystemFilters from '@salesforce/label/c.Grid_SystemFilters';
import Grid_Team from '@salesforce/label/c.Grid_Team';
import Grid_Title from '@salesforce/label/c.Grid_Title';
import Grid_ValidateGrid from '@salesforce/label/c.Grid_ValidateGrid';
import Grid_ValidationErrors from '@salesforce/label/c.Grid_ValidationErrors';
import Grid_ViewExcludedProducts from '@salesforce/label/c.Grid_ViewExcludedProducts';
import Grid_ViewRecap from '@salesforce/label/c.Grid_ViewRecap';

export const LABELS = {
    UI_Add, UI_Back, UI_Cancel, UI_Close, UI_CollapseAll, UI_Confirm, UI_Error, UI_ErrorMessage, UI_Errors,
    UI_Excluded, UI_ExpandAll, UI_Field, UI_Import, UI_Included, UI_Loading, UI_NA, UI_Next, UI_Object,
    UI_Off, UI_On, UI_Operator, UI_Refresh, UI_Remove, UI_SelectOption, UI_Success, UI_UnknownField, UI_UnknownObject, UI_Value, UI_Warning,
    Grid_AddFilter, Grid_AddRestrictedShareTypes, Grid_AddToGrid, Grid_AgreementErrorLoadingSettings, Grid_Agreements,
    Grid_AllRowsImported, Grid_AlreadySelected, Grid_ApplyFilters, Grid_AutoIncludeHelpText, Grid_AutoIncludeLabel,
    Grid_AutomaticUpdate, Grid_Builder, Grid_CreatedSuccess, Grid_CriteriaCreated, Grid_CriteriaDetailsCreated, Grid_CriteriaHistory,
    Grid_CriteriaLabel, Grid_CriteriaNumber, Grid_AgreementGridHistory, Grid_AgreementGridRecap, Grid_CurrentGridRecap, Grid_DetailsTitle, Grid_DifferentGridsSelected,
    Grid_ErrorLoadingGrids, Grid_ErrorLoadingProducts, Grid_ErrorLoadingSettings, Grid_ErrorRetrievingProducts,
    Grid_ErrorSavingGrid, Grid_ErrorValidatingProducts, Grid_ExcelImportTitle, Grid_ExcludedProducts,
    Grid_FailedToLoadSheetJS, Grid_FilterNumber, Grid_FixValidationErrors, Grid_GridDetailsCreated, Grid_GridName,
    Grid_ImportCompleted, Grid_ImportCompletedWithErrors, Grid_ImportFailed, Grid_ImportedFilePrefix,
    Grid_IncludedInGrid, Grid_IncludedProducts, Grid_Label, Grid_LogicLabel,
    Grid_MissingShareClass, Grid_MissingShareClasses, Grid_NoActiveGridAssigned, Grid_NoDetailsFound, Grid_NoExcludedProducts,
    Grid_NoGridAvailable, Grid_NoGridSelectionFound, Grid_NoNewShareClassesAdded, Grid_NoProducts,
    Grid_NoProductsFound, Grid_NoProductsFoundValidation, Grid_NoProductsMatched, Grid_NoProductsSelected,
    Grid_NoProductsToDisplay, Grid_NoProductsToValidate, Grid_NoShareClassesFound, Grid_NoShareClassesToAdd,
    Grid_ProductAlreadyAssignedWarning, Grid_ProductNameLabel, Grid_ProductsRecap,
    Grid_RemoveFilter, Grid_RemoveProduct, Grid_ResetAll, Grid_ResetAll_Confirm, Grid_ResetAll_Success,
    Grid_ResetFilters, Grid_RowErrors, Grid_GridRulesCreated, Grid_Saved_Success, Grid_ScopesUpserted,
    Grid_SelectExcelFile, Grid_SelectGrid, Grid_SelectShareTypes, Grid_Selection, Grid_SettingNotFound,
    Grid_ShareClassesAdded, Grid_ShareClassesAddedTitle, Grid_ShareClassesNotAdded_DifferentGrid,
    Grid_ShareTypeFilterIndependentInfo, Grid_ShareTypesLabel, Grid_SomeRowsFailed, Grid_SortedBy,
    Grid_StandardGridsSelected, Grid_StartDate, Grid_SystemFilters, Grid_Team, Grid_Title, Grid_ValidateGrid, Grid_ValidationErrors,
    Grid_ViewExcludedProducts, Grid_ViewRecap
};

export function showToast(component, title, message, variant) {
    component.dispatchEvent(new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
    }));
}

export function reduceError(error) {
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

export function getIsinFromRow(row) {
    if (!row) {
        return null;
    }
    if (row.isin) {
        return row.isin;
    }
    const cells = row.cells || [];
    const cell = cells.find(c => (c.label || '').toLowerCase() === 'isin') || cells.find(c => (c.label || '').toLowerCase().includes('isin'));
    return cell ? cell.value : null;
}

export function buildShareClassGridIdMap(selectedRows) {
    const shareClassGridIdMap = {};
    (selectedRows || []).forEach(row => {
        if (row?.id && row?.gridId) {
            shareClassGridIdMap[row.id] = row.gridId;
        }
    });
    return shareClassGridIdMap;
}

export function buildProductGridOptions(selectedRows) {
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

export function splitCriteriaValues(rawValue, separator = ';') {
    if (!rawValue) {
        return [];
    }
    return rawValue.split(separator).map(value => value.trim()).filter(value => value);
}

export function buildResultColumnsList(fieldsApiToInfoMap, addGridCol = false, addStatusCol = false, addAumCol = false, addActionCol = false) {
    const resultCols = Object.keys(fieldsApiToInfoMap || {}).map(apiName => {
        const fieldInfo = fieldsApiToInfoMap[apiName];
        return {
            apiName: apiName,
            label: fieldInfo.label,
            type: fieldInfo.type || 'String',
            isSortable: fieldInfo.isSortable || false
        };
    });
    if (addGridCol) {
        resultCols.push({ apiName: 'Grid', label: 'Grid', type: 'String', isSortable: false });
    }
    if (addStatusCol) {
        resultCols.push({ apiName: 'Status', label: 'Status', type: 'String', isSortable: false });
    }
    if (addAumCol) {
        resultCols.push({ apiName: 'AUM', label: 'AUM (Eur)', type: 'Currency', isSortable: false, class: 'alignRight' });
    }
    if (addActionCol) {
        resultCols.push({ apiName: 'Action', label: 'Action', type: 'Action', isSortable: false, class: 'alignCenter' });
    }
    return resultCols;
}

export function buildCriteriaKey(params) {
    const { gridId, filterLogicType, filterLogicText, details, shareTypes } = params;
    const shareTypeKey = buildShareTypesKey(shareTypes);
    return JSON.stringify({
        gridId: gridId,
        filterLogicType: filterLogicType,
        filterLogicText: filterLogicText,
        details: details,
        shareTypes: shareTypeKey
    });
}

export function buildShareTypesKey(shareTypes) {
    const values = Array.isArray(shareTypes) ? [...shareTypes] : [];
    values.sort((a, b) => a.localeCompare(b));
    return values.join('|');
}

export function updateCriteriaWithIsins(criteriaDetails, isins, logic, separator = ';') {
    const isinArray = (Array.isArray(isins) ? isins : []).filter(val => val);
    if (!isinArray.length) {
        return criteriaDetails;
    }
    const details = (criteriaDetails || []).slice();
    const idx = details.findIndex(d =>
        d.Object__c === 'Share_Class__c' &&
        d.Field__c === 'ISIN__c' &&
        d.Logic__c === logic &&
        d.TECHOrigin__c === 'System'
    );
    const currentValues = idx >= 0 && details[idx].Value__c ? details[idx].Value__c.split(separator).map(val => val.trim()).filter(val => val) : [];
    const valueSet = new Set(currentValues);
    isinArray.forEach(isin => {
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
            Value__c: nextValues.join(' ' + separator + ' '),
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
    return details;
}

export function getProductNameFromRows(rows, productNameLabel = 'Product Name') {
    const firstRow = rows && rows.length ? rows[0] : null;
    if (!firstRow) {
        return null;
    }
    const cellValue = (firstRow.cells || []).find(cell => cell.label === productNameLabel)?.value;
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

export function isSystemProductExclusionDetail(detail) {
    return detail && detail.objectApi === 'Product__c' && detail.fieldApi === 'ProductName__c' && detail.operator === 'NOT IN' && detail.TECHOrigin__c === 'System';
}

export function getSystemProductExclusionDetail(details) {
    return (details || []).find(detail => detail && detail.objectApi === 'Product__c' && detail.fieldApi === 'ProductName__c' && detail.operator === 'NOT IN' && detail.TECHOrigin__c === 'System');
}

export function getQueryParam(paramName) {
    let params = new URLSearchParams(window.location.search);
    let value = params.get(paramName);
    if (value) {
        return value;
    }
    return null;
}

export function buildDefaultLogicExpression(count, logicType) {
    if (count <= 0) {
        return '';
    }
    const op = logicType === 'OR' ? 'OR' : 'AND';
    return Array.from({ length: count }, (_, index) => index + 1).join(` ${op} `);
}

export function addIsinExclusionsFromRows(criteriaList, removedRows, separator = ';') {
    const byCriteria = new Map();
    (removedRows || []).forEach(row => {
        if (!row.criteriaRefId) return;
        const isin = getIsinFromRow(row);
        if (!isin) return;
        if (!byCriteria.has(row.criteriaRefId)) {
            byCriteria.set(row.criteriaRefId, []);
        }
        byCriteria.get(row.criteriaRefId).push(isin);
    });
    let result = criteriaList;
    byCriteria.forEach((isins, criteriaRefId) => {
        result = updateCriteriaListWithIsins(result, criteriaRefId, isins, 'NOT IN', separator);
    });
    return result;
}

export function updateCriteriaListWithIsins(criteriaList, criteriaRefId, isins, logic, separator = ';') {
    if (!criteriaList || !criteriaRefId) {
        return criteriaList || [];
    }
    return criteriaList.map(entry => {
        if (entry.id !== criteriaRefId) {
            return entry;
        }
        const updatedDetails = updateCriteriaWithIsins(entry.criteriaDetails, isins, logic, separator);
        return { ...entry, criteriaDetails: updatedDetails };
    });
}

export function applySystemProductExclusion(criteria, productName, separator = ';') {
    const details = Array.isArray(criteria?.details) ? criteria.details.map(d => ({ ...d })) : [];
    const systemDetail = getSystemProductExclusionDetail(details);
    const currentNames = splitCriteriaValues(systemDetail?.value, separator);
    if (!currentNames.includes(productName)) {
        currentNames.push(productName);
    }
    const nextDetail = {
        id: systemDetail?.id || 'sys-product-exclusion',
        objectApi: 'Product__c',
        fieldApi: 'ProductName__c',
        operator: 'NOT IN',
        value: currentNames.join(separator),
        TECHOrigin__c: 'System'
    };
    const updatedDetails = upsertSystemDetail(details, nextDetail);
    const logicUpdate = appendCustomLogicIfNeeded(criteria?.filterLogicType, criteria?.filterLogicText, updatedDetails, systemDetail == null);
    return {
        grid: criteria?.grid,
        filterLogicType: logicUpdate.filterLogicType,
        filterLogicText: logicUpdate.filterLogicText,
        details: updatedDetails
    };
}

export function mergeSystemDetail(criteriaFromChild, systemDetail) {
    const details = Array.isArray(criteriaFromChild?.details) ? criteriaFromChild.details.map(d => ({ ...d })) : [];
    const updatedDetails = !systemDetail
        ? reindexCriteriaDetails(details)
        : upsertSystemDetail(details, { ...systemDetail });
    return {
        filterLogicType: criteriaFromChild?.filterLogicType,
        filterLogicText: criteriaFromChild?.filterLogicText,
        details: updatedDetails
    };
}

export function reindexCriteriaDetails(details) {
    const updated = [];
    (details || []).forEach((detail, index) => {
        updated.push({ ...detail, filterNumber: index + 1});
    });
    return updated;
}

function upsertSystemDetail(details, systemDetail) {
    const filtered = (details || []).filter(d => !isSystemProductExclusionDetail(d));
    filtered.push({ ...systemDetail, TECHOrigin__c: 'System' });
    return reindexCriteriaDetails(filtered);
}

export function appendCustomLogicIfNeeded(filterLogicType, filterLogicText, updatedDetails, addedSystemDetail) {
    if (!addedSystemDetail || filterLogicType !== 'Custom Logic') {
        return { filterLogicType, filterLogicText };
    }
    const systemDetail = getSystemProductExclusionDetail(updatedDetails);
    const systemNumber = systemDetail?.filterNumber;
    if (!systemNumber) {
        return { filterLogicType, filterLogicText };
    }
    const baseExpression = filterLogicText?.trim() || buildDefaultLogicExpression(updatedDetails.length - 1, 'AND');
    const nextExpression = baseExpression ? `(${baseExpression}) AND ${systemNumber}` : String(systemNumber);
    return { filterLogicType: 'Custom Logic', filterLogicText: nextExpression };
}