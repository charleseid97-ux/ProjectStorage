import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { reduceError, showToast } from 'c/gridBuilderUtils';
import SheetJs from '@salesforce/resourceUrl/sheetjs';
import importFromJson from '@salesforce/apex/GridExcelImportService.importFromJson';
import { LABELS } from 'c/gridBuilderUtils';

export default class GridExcelImporter extends LightningElement {

	@track scopeHeaders = ['Grid', 'Agreement', 'Country', 'PtfCode'];
	@track ruleHeaders = ['Grid', 'Include', 'Exclude', 'Comment', 'RuleToApply', 'FeesType', 'RuleValue', 'ShareType', 'OtherShareType', 'RebateRate'];

	labels = LABELS;
	file;
	importedFileName;
	isLoading = false;
	errors = [];
	result;
	sheetJsLoaded = false;
	sheetJsReady = false;
	acceptedFormats = '.xlsx';

	get hasErrors() {
		return this.errors && this.errors.length > 0;
	}

	get hasResultErrors() {
		return (
			this.result && this.result.errors && this.result.errors.length > 0
		);
	}

	get isImportDisabled() {
		return this.isLoading || !this.file;
	}

	renderedCallback() {
		if (this.sheetJsLoaded) {
			return;
		}
		this.sheetJsLoaded = true;
		loadScript(this, SheetJs).then(() => {
			this.sheetJsReady = true;
		}).catch((error) => {
			this.errors = [`${this.labels.Grid_FailedToLoadSheetJS}: ${reduceError(error)}`];
		});
	}

	handleFileChange(event) {
		const file = event.target.files[0];
		this.file = file;
		this.errors = [];
		this.result = null;
		this.importedFileName = file ? file.name : null;
	}

	async handleImport() {
		this.errors = [];
		this.result = null;

		if (!this.file) {
			this.errors = [this.labels.Grid_SelectExcelFile];
			showToast(this, this.labels.Grid_ImportFailed, this.labels.Grid_SelectExcelFile, 'error');
			return;
		}

		if (!this.sheetJsReady || !window.XLSX) {
			this.errors = [this.labels.Grid_FailedToLoadSheetJS];
			showToast(this, this.labels.Grid_ImportFailed, this.labels.Grid_FailedToLoadSheetJS, 'error');
			return;
		}

		this.isLoading = true;
		try {
			const data = await this.readFile(this.file);
			const workbook = window.XLSX.read(data, { type: 'array' });

			const scopeParse = this.parseSheet(workbook, 'GridScopes', this.scopeHeaders);
			const ruleParse = this.parseSheet(workbook, 'GridRules', this.ruleHeaders);

			this.errors = [...scopeParse.errors, ...ruleParse.errors];
			if (this.errors.length > 0) {
				showToast(this, this.labels.Grid_ImportFailed, this.labels.Grid_FixValidationErrors, 'error');
				return;
			}

			const payload = {
				scopes: scopeParse.rows,
				rules: ruleParse.rows
			};

			const result = await importFromJson({
				payloadJson: JSON.stringify(payload)
			});
			if (result && result.errors) {
				result.errors = result.errors.map((err, index) => ({
					...err,
					key: `${err.sheetName}-${err.rowNumber}-${index}`
				}));
			}
			this.result = result;

			if (this.hasResultErrors) {
				showToast(this, this.labels.Grid_ImportCompletedWithErrors, this.labels.Grid_SomeRowsFailed, 'warning');
			} 
			else {
				showToast(this, this.labels.Grid_ImportCompleted, this.labels.Grid_AllRowsImported, 'success');
			}
		} 
		catch (error) {
			const message = reduceError(error);
			this.errors = [message];
			showToast(this, this.labels.Grid_ImportFailed, message, 'error');
		} 
		finally {
			this.isLoading = false;
		}
	}

	readFile(file) {
		return new Promise((resolve, reject) => {
			const reader = new FileReader();
			reader.onload = () => resolve(reader.result);
			reader.onerror = () => reject(reader.error);
			reader.readAsArrayBuffer(file);
		});
	}

	parseSheet(workbook, sheetName, requiredHeaders) {
		const result = { rows: [], errors: [] };
		const sheet = workbook.Sheets[sheetName];
		if (!sheet) {
			// Use the Import Failed label as prefix to keep it localized, then give the detail
			result.errors.push(`${this.labels.Grid_ImportFailed}: Missing sheet "${sheetName}".`);
			return result;
		}

		const raw = window.XLSX.utils.sheet_to_json(sheet, {header: 1, defval: ''});
		if (!raw.length) {
			result.errors.push(`${this.labels.Grid_ImportFailed}: Sheet "${sheetName}" is empty.`);
			return result;
		}

		const headers = raw[0].map((h) => this.normalizeHeader(h));
		const headerIndex = new Map();
		headers.forEach((header, index) => {
			if (header) {
				headerIndex.set(header, index);
			}
		});

		requiredHeaders.forEach((header) => {
			if (!headerIndex.has(header)) {
				result.errors.push(`${this.labels.Grid_ImportFailed}: Sheet "${sheetName}" is missing required column "${header}".`);
			}
		});

		if (result.errors.length > 0) {
			return result;
		}

		for (let i = 1; i < raw.length; i++) {
			const row = raw[i];
			if (this.isRowEmpty(row)) {
				continue;
			}
			const rowObj = { rowNumber: i + 1 };
			requiredHeaders.forEach((header) => {
				const idx = headerIndex.get(header);
				rowObj[header] = this.normalizeCell(row[idx]);
			});
			result.rows.push(rowObj);
		}

		return result;
	}

	normalizeHeader(value) {
		return value ? String(value).trim() : '';
	}

	normalizeCell(value) {
		if (value === null || value === undefined || value === '') {
			return null;
		}
		if (value instanceof Date) {
			return value.toISOString().slice(0, 10);
		}
		return String(value).trim();
	}

	isRowEmpty(row) {
		if (!row) {
			return true;
		}
		return row.every((cell) => cell === null || cell === undefined || String(cell).trim() === '');
	}
}