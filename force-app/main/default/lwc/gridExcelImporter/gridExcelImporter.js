import { LightningElement } from 'lwc';
import SheetJs from '@salesforce/resourceUrl/sheetjs';
import { loadScript } from 'lightning/platformResourceLoader';
import importFromJson from '@salesforce/apex/GridExcelImportService.importFromJson';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const SCOPE_HEADERS = ['Grid', 'Agreement', 'Country', 'PtfCode'];
const RULE_HEADERS = [
  'Grid',
  'Include',
  'Exclude',
  'Comment',
  'RuleToApply',
  'FeesType',
  'RuleValue',
  'OtherShareType'
];

export default class GridExcelImporter extends LightningElement {
  file;
  isLoading = false;
  errors = [];
  result;
  sheetJsLoaded = false;
  sheetJsReady = false;

  get acceptedFormats() {
    return '.xlsx';
  }

  get hasErrors() {
    return this.errors && this.errors.length > 0;
  }

  get hasResultErrors() {
    return (
      this.result && this.result.errors && this.result.errors.length > 0
    );
  }

  renderedCallback() {
    if (this.sheetJsLoaded) {
      return;
    }
    this.sheetJsLoaded = true;
    loadScript(this, SheetJs)
      .then(() => {
        this.sheetJsReady = true;
      })
      .catch((error) => {
        this.errors = [
          `Failed to load SheetJS static resource: ${this.normalizeError(error)}`
        ];
      });
  }

  handleFileChange(event) {
    const file = event.target.files[0];
    this.file = file;
    this.errors = [];
    this.result = null;
  }

  async handleImport() {
    this.errors = [];
    this.result = null;

    if (!this.file) {
      this.errors = ['Select an .xlsx file to import.'];
      return;
    }

    if (!this.sheetJsReady || !window.XLSX) {
      this.errors = [
        'SheetJS is not available. Deploy the "sheetjs" static resource first.'
      ];
      return;
    }

    this.isLoading = true;
    try {
      const data = await this.readFile(this.file);
      const workbook = window.XLSX.read(data, { type: 'array' });

      const scopeParse = this.parseSheet(
        workbook,
        'GridScopes',
        SCOPE_HEADERS
      );
      const ruleParse = this.parseSheet(workbook, 'GridRules', RULE_HEADERS);

      this.errors = [...scopeParse.errors, ...ruleParse.errors];
      if (this.errors.length > 0) {
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
        this.showToast(
          'Import completed with errors',
          'Some rows failed. Review details below.',
          'warning'
        );
      } else {
        this.showToast('Import completed', 'All rows imported.', 'success');
      }
    } catch (error) {
      const message = this.normalizeError(error);
      this.errors = [message];
      this.showToast('Import failed', message, 'error');
    } finally {
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
      result.errors.push(`Missing sheet "${sheetName}".`);
      return result;
    }

    const raw = window.XLSX.utils.sheet_to_json(sheet, {
      header: 1,
      defval: ''
    });
    if (!raw.length) {
      result.errors.push(`Sheet "${sheetName}" is empty.`);
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
        result.errors.push(
          `Sheet "${sheetName}" is missing required column "${header}".`
        );
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
    return row.every(
      (cell) => cell === null || cell === undefined || String(cell).trim() === ''
    );
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  normalizeError(error) {
    if (!error) {
      return 'Unknown error.';
    }
    if (Array.isArray(error.body)) {
      return error.body.map((e) => e.message).join(' ');
    }
    if (error.body && typeof error.body.message === 'string') {
      return error.body.message;
    }
    if (error.message) {
      return error.message;
    }
    return String(error);
  }
}