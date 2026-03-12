import { LightningElement, api, track, wire } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getLanguageOptions from '@salesforce/apex/sessionSpeakerProductRepeaterCTRL.languageOptions';
import getProducts from '@salesforce/apex/sessionSpeakerProductRepeaterCTRL.getProducts';
import getSpeakerContacts from '@salesforce/apex/CustomCalendarHelper.getSpeakerContacts';
import getDefaultSpeakerForEvent from '@salesforce/apex/sessionSpeakerProductRepeaterCTRL.getDefaultSpeakerForEvent';

const uniq = () => Math.random().toString(36).slice(2);

export default class SessionSpeakerProductRepeater extends LightningElement {
    // Flow inputs/outputs (do not rename)
    @api debug = false;
    @api outputValue = '[]';
    @api parentEventId;

    // Optional JSON input (Lightning pages / parent components).
    // Accepts JSON string OR array of sessionSpeakerProduct__c-like objects.
    @api
    set inputValue(value) {
        this._inputValue = value;
        // if we receive an input list, we are in "edit existing" mode
        this._hasExistingInput =
            value !== null && value !== undefined && value !== '' &&
            !(Array.isArray(value) && value.length === 0) &&
            !(typeof value === 'string' && value.trim() === '[]');
        // eslint-disable-next-line no-console
        console.log('===[SSPRepeater] set inputValue - hasExistingInput=', this._hasExistingInput);
        this._applyInputValue(value);
    }
    get inputValue() {
        return this._inputValue;
    }

    @track entries = [
        {
            key: uniq(),
            speakerIds: [],
            productIds: [],
            language: null,
            speakerPills: [],
            productPills: []
        }
    ];

    languageOptions = [];
    hasLanguagePicklist = false;

    @track allSpeakers = []; // [{label,value}]
    @track allProducts = []; // [{label,value}]

    // Default speaker logic
    defaultSpeakerId = null;
    _defaultApplied = false;

    get debugEnabled() {
        return this.debug === true || this.debug === 'true';
    }

    connectedCallback() {
        // Avoid class fields: keep parser compatible
        if (this._hasExistingInput === undefined) {
            this._hasExistingInput = false;
        }
        this._pendingInputValue = null;
        this._hasAppliedInput = false;

        if (this._inputValue !== null && this._inputValue !== undefined && this._inputValue !== '') {
            this._applyInputValue(this._inputValue);
        } else {
            this._rebuildRecords();
        }
    }

    // ===== LANGUAGE OPTIONS =====
    @wire(getLanguageOptions)
    wiredLang({ data, error }) {
        if (data) {
            this.languageOptions = data || [];
            this.hasLanguagePicklist = this.languageOptions.length > 0;
        } else if (error) {
            this.languageOptions = [];
            this.hasLanguagePicklist = false;
        }
    }

    // ===== SPEAKER OPTIONS (Contacts) =====
    @wire(getSpeakerContacts)
    wiredSpeakerContacts({ data, error }) {
        if (data) {
            // Supports both [{label,value}] and Contact[] styles
            if (data.length && data[0].label !== undefined && data[0].value !== undefined) {
                this.allSpeakers = data;
            } else {
                this.allSpeakers = (data || []).map((c) => ({
                    label: c.Name,
                    value: c.Id
                }));
            }

            // Sort speakers alphabetically
            this.allSpeakers = (this.allSpeakers || [])
                .slice()
                .sort((a, b) => (a.label || '').localeCompare(b.label || ''));

            this._refreshPills();

            // Apply pending input (if any) when options become ready
            this._applyPendingInputIfAny();

            // try apply default speaker when options are ready
            this._tryApplyDefaultSpeaker();
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading speakers (Contacts): ', error);
            this.allSpeakers = [];
        }
    }

    // ===== PRODUCT OPTIONS =====
    @wire(getProducts)
    wiredProducts({ data, error }) {
        if (data) {
            // getProducts returns PickOpt => { label, value }
            this.allProducts = (data || []).map((p) => ({
                label: p.label,
                value: p.value
            }));

            // Sort products alphabetically
            this.allProducts = (this.allProducts || [])
                .slice()
                .sort((a, b) => (a.label || '').localeCompare(b.label || ''));

            this._refreshPills();

            // Apply pending input (if any) when options become ready
            this._applyPendingInputIfAny();
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading products: ', error);
            this.allProducts = [];
        }
    }

    _applyPendingInputIfAny() {
        if (this._hasAppliedInput) return;
        if (this._pendingInputValue === null || this._pendingInputValue === undefined || this._pendingInputValue === '') return;
        this._applyInputValue(this._pendingInputValue);
    }

    // ===== DEFAULT SPEAKER FROM PARENT EVENT =====
    @wire(getDefaultSpeakerForEvent, { parentEventId: '$parentEventId' })
    wiredDefaultSpeaker({ data, error }) {
        if (data) {
            this.defaultSpeakerId = data; // Contact Id
            this._tryApplyDefaultSpeaker();
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading default speaker for parentEventId:', error);
            this.defaultSpeakerId = null;
        }
    }

    /**
     * Refactor: reduce Cognitive Complexity (30 -> <= 15) by splitting:
     * - readiness check
     * - parsing/validation
     * - grouping
     * - sorting + fallback
     * - final apply
     */
    _applyInputValue(value) {
        if (this._isEmptyInput(value)) return;

        if (!this._areOptionsReady()) {
            this._deferInput(value);
            return;
        }

        const rows = this._parseRows(value);
        if (!rows) return;

        const nextEntries = this._buildEntriesFromRows(rows);

        this.entries = (nextEntries && nextEntries.length) ? nextEntries : [this._emptyEntry()];
        this._finalizeApplyInput();
    }

    // -----------------------------
    // Helpers for _applyInputValue
    // -----------------------------
    _isEmptyInput(value) {
        return value === undefined || value === null || value === '';
    }

    _areOptionsReady() {
        return (this.allSpeakers && this.allSpeakers.length) && (this.allProducts && this.allProducts.length);
    }

    _deferInput(value) {
        this._pendingInputValue = value;
        // eslint-disable-next-line no-console
        if (this.debugEnabled) console.debug('===[SSPRepeater] _applyInputValue deferred (options not ready)');
    }

    _parseRows(value) {
        let rows = value;

        if (typeof value === 'string') {
            rows = this._safeJsonParse(value);
            if (!rows) return null;
        }

        if (!Array.isArray(rows)) {
            // eslint-disable-next-line no-console
            console.warn('===[SSPRepeater] _applyInputValue - input is not an array, ignored');
            return null;
        }

        return rows;
    }

    _safeJsonParse(jsonTxt) {
        try {
            return JSON.parse(jsonTxt);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.warn('===[SSPRepeater] _applyInputValue - invalid JSON, ignored');
            return null;
        }
    }

    _buildEntriesFromRows(rows) {
        const byKey = this._groupRowsBySpeakerLang(rows);
        const entries = Array.from(byKey.values());
        return this._sortEntriesBySpeakerLabel(entries);
    }

    _groupRowsBySpeakerLang(rows) {
        const byKey = new Map();

        for (const r of (rows || [])) {
            const normalized = this._normalizeRow(r);
            if (!normalized) continue;

            const { speakerId, productId, lang, key } = normalized;
            const entry = this._ensureGroupedEntry(byKey, key, speakerId, lang);

            if (productId) this._pushUnique(entry.productIds, productId);
        }

        return byKey;
    }

    _normalizeRow(r) {
        const speakerId = r && r.speakerContact__c ? r.speakerContact__c : null;
        if (!speakerId) return null;

        const productId = r && r.strategy__c ? r.strategy__c : null;
        const lang = r && r.Language__c ? r.Language__c : null;

        return {
            speakerId,
            productId,
            lang,
            key: `${speakerId}|${lang || ''}`
        };
    }

    _ensureGroupedEntry(byKey, key, speakerId, lang) {
        if (!byKey.has(key)) {
            byKey.set(key, {
                key: uniq(),
                speakerIds: [speakerId],
                productIds: [],
                language: lang,
                speakerPills: [],
                productPills: []
            });
        }
        return byKey.get(key);
    }

    _pushUnique(arr, value) {
        if (!arr.includes(value)) arr.push(value);
    }

    _sortEntriesBySpeakerLabel(entries) {
        const labelById = new Map((this.allSpeakers || []).map((s) => [s.value, s.label]));

        return (entries || []).slice().sort((a, b) => {
            const la = labelById.get(a.speakerIds && a.speakerIds[0]) || '';
            const lb = labelById.get(b.speakerIds && b.speakerIds[0]) || '';
            return la.localeCompare(lb);
        });
    }

    _emptyEntry() {
        return {
            key: uniq(),
            speakerIds: [],
            productIds: [],
            language: null,
            speakerPills: [],
            productPills: []
        };
    }

    _finalizeApplyInput() {
        this._refreshPills();
        this._rebuildRecords();

        this._pendingInputValue = null;
        this._hasAppliedInput = true;

        // eslint-disable-next-line no-console
        if (this.debugEnabled) console.debug('===[SSPRepeater] _applyInputValue applied entries=' + this.entries.length);
    }

    _refreshPills() {
        const cloned = JSON.parse(JSON.stringify(this.entries || []));
        for (let i = 0; i < cloned.length; i++) {
            const e = cloned[i];
            e.speakerPills = this.selectionPills(this.allSpeakers, 'standard:contact', e.speakerIds || []);
            e.productPills = this.selectionPills(this.allProducts, 'standard:product', e.productIds || []);
        }
        this.entries = cloned;
    }

    addEntry = () => {
        // Find the last non-null language
        let lastLanguage = null;
        if (this.entries && this.entries.length > 0) {
            for (let i = this.entries.length - 1; i >= 0; i--) {
                const lang = this.entries[i].language;
                if (lang) {
                    lastLanguage = lang;
                    break;
                }
            }
        }

        const newEntry = {
            key: uniq(),
            speakerIds: [],
            productIds: [],
            language: lastLanguage,
            speakerPills: [],
            productPills: []
        };

        this.entries = [...this.entries, newEntry];
        this._rebuildRecords();
    };

    removeEntry = (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.entries = this.entries.filter((_, i) => i !== index);

        if (this.entries.length === 0) {
            this.entries = [this._emptyEntry()];
        }
        this._rebuildRecords();
    };

    // ===== HELPER TO BUILD PILLS =====
    selectionPills(sourceOptions, iconName, selectedValues) {
        const set = new Set(selectedValues || []);
        return (sourceOptions || [])
            .filter((opt) => set.has(opt.value))
            .map((opt) => ({
                label: opt.label,
                name: opt.value,
                iconName
            }));
    }

    handleMultiSelection = (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const field = event.currentTarget.dataset.field; // "Speakers" or "Products"
        const selectedValues = event.detail && event.detail.selectedValues ? event.detail.selectedValues : [];

        const cloned = JSON.parse(JSON.stringify(this.entries));
        const entry = cloned[index];

        if (field === 'Speakers') {
            entry.speakerIds = [...selectedValues];
            entry.speakerPills = this.selectionPills(this.allSpeakers, 'standard:contact', entry.speakerIds);
        } else if (field === 'Products') {
            entry.productIds = [...selectedValues];
            entry.productPills = this.selectionPills(this.allProducts, 'standard:product', entry.productIds);
        }

        this.entries = cloned;
        this._rebuildRecords();
    };

    handleMultiItemRemove = (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const field = event.currentTarget.dataset.field; // "Speakers" or "Products"
        const item = event.detail ? event.detail.item : null;
        const nameToRemove = item ? item.name : null;

        if (!nameToRemove && nameToRemove !== 0) {
            return;
        }

        const cloned = JSON.parse(JSON.stringify(this.entries));
        const entry = cloned[index];

        if (field === 'Speakers') {
            entry.speakerIds = (entry.speakerIds || []).filter((id) => id !== nameToRemove);
            entry.speakerPills = (entry.speakerPills || []).filter((pill) => pill.name !== nameToRemove);
        } else if (field === 'Products') {
            entry.productIds = (entry.productIds || []).filter((id) => id !== nameToRemove);
            entry.productPills = (entry.productPills || []).filter((pill) => pill.name !== nameToRemove);
        }

        this.entries = cloned;
        this._rebuildRecords();
    };

    handleLanguageChange = (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const value = event.detail.value;

        const cloned = JSON.parse(JSON.stringify(this.entries));
        cloned[index].language = value;
        this.entries = cloned;

        this._rebuildRecords();
    };

    handleRebuildClick = () => {
        this._rebuildRecords();
    };

    _rebuildRecords() {
        const out = (this.entries || []).flatMap((e) => this._entryToRecords(e));
        this.outputValue = JSON.stringify(out);

        // Flow output
        this.dispatchEvent(new FlowAttributeChangeEvent('outputValue', this.outputValue));

        // Parent component output
        this.dispatchEvent(new CustomEvent('jsonchange', { detail: { json: this.outputValue } }));

        // eslint-disable-next-line no-console
        console.log('===[SSPRepeater] _rebuildRecords - outputValue', this.outputValue);
    }

    _entryToRecords(entry) {
        const speakers = this._toArray(entry && entry.speakerIds ? entry.speakerIds : []);
        const products = this._toArray(entry && entry.productIds ? entry.productIds : []);
        const lang = entry ? entry.language || null : null;

        if (!speakers.length && !products.length) {
            return [];
        }
        console.debug('===[SSPRepeater] _entryToRecords speakers=', speakers, 'products=', products, 'lang=', lang);    
        return this._pairSelections(speakers, products).map(({ sid, pid }) => this._makeRecord(sid, pid, lang));
    }

    _toArray(value) {
        if (Array.isArray(value)) return value;
        return value ? [value] : [];
    }

    _pairSelections(speakers, products) {
        console.debug('===[SSPRepeater] _pairSelections speakers=', speakers, 'products=', products);
        const hasSpeakers = speakers.length > 0;
        const hasProducts = products.length > 0;

        if (hasSpeakers && !hasProducts) {
            return speakers.map((sid) => ({ sid, pid: null }));
        }
        if (!hasSpeakers && hasProducts) {
            return products.map((pid) => ({ sid: null, pid }));
        }

        return speakers.flatMap((sid) => products.map((pid) => ({ sid, pid })));
    }

    _makeRecord(contactId, productId, lang) {
        return {
            attributes: { type: 'sessionSpeakerProduct__c' },
            speakerContact__c: contactId,
            strategy__c: productId,
            Language__c: lang,
            Session__c: null
        };
    }

    // ===== APPLY DEFAULT SPEAKER ON FIRST ROW =====
    _tryApplyDefaultSpeaker() {
        if (this._hasExistingInput) return;
        if (this._defaultApplied) return;
        if (!this.parentEventId) return;
        if (!this.defaultSpeakerId) return;
        if (!this.allSpeakers || this.allSpeakers.length === 0) return;
        if (!this.entries || this.entries.length === 0) return;

        // Ensure speaker exists in current options
        const exists = (this.allSpeakers || []).some((s) => s.value === this.defaultSpeakerId);
        if (!exists) return;

        const cloned = JSON.parse(JSON.stringify(this.entries));

        // Apply only to the first row
        cloned[0].speakerIds = [this.defaultSpeakerId];
        cloned[0].speakerPills = this.selectionPills(this.allSpeakers, 'standard:contact', cloned[0].speakerIds);

        // Keep products empty
        cloned[0].productIds = [];
        cloned[0].productPills = [];

        this.entries = cloned;
        this._defaultApplied = true;
        this._rebuildRecords();
    }
}