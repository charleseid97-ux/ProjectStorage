import { LightningElement, api, track, wire } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getLanguageOptions from '@salesforce/apex/sessionSpeakerProductRepeaterCTRL.languageOptions';
import getProducts from '@salesforce/apex/sessionSpeakerProductRepeaterCTRL.getProducts';
import getSpeakerContacts from '@salesforce/apex/CustomCalendarHelper.getSpeakerContacts';
import getDefaultSpeakerForEvent from '@salesforce/apex/sessionSpeakerProductRepeaterCTRL.getDefaultSpeakerForEvent';
import getEventCategory from '@salesforce/apex/sessionSpeakerProductRepeaterCTRL.getEventCategory';
const uniq = () => Math.random().toString(36).slice(2);

export default class SessionSpeakerProductRepeater extends LightningElement {
    // Flow inputs/outputs (do not rename)
    @api defaultSpeakerDate;
    @api debug = false;
    @api outputValue = '[]';
    @api showTimeSlots = false;
    @api defaultStartTime;
    @api defaultEndTime;
    _parentEventId = null;
    @api
    set parentEventId(value) {
        this._parentEventId = value ?? null;
    }
    get parentEventId() {
        return this._parentEventId;
    }
    
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
            speakerId: null,
            productIds: [],
            language: null,
            speakerLanguage: null,
            startTime: null,
            endTime: null,
            date: this.defaultSpeakerDate || null, 
            showSlidesLanguage: false,
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
        if(this.defaultSpeakerDate){
            console.log('====connectedCallback==[SSPRepeater] defaultSpeakerDate=', this.defaultSpeakerDate);
        }else console.log('===[SSPRepeater] defaultSpeakerDate=undefined ');
        if (this._hasExistingInput === undefined) {
            this._hasExistingInput = false;
        }
        this._pendingInputValue = null;
        this._hasAppliedInput = false;

        if (this.entries && this.entries.length > 0) {
            this.entries = this.entries.map((entry, index) => {
                if (index === 0) {
                    return {
                        ...entry,
                        startTime: entry.startTime || this.defaultStartTime || null,
                        endTime: entry.endTime || this.defaultEndTime || null,
                        date: entry.date || this.defaultSpeakerDate || null

                    };
                }
                return entry;
            });
        }

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
  @wire(getSpeakerContacts, { parentEventId: '$_parentEventId' })
wiredSpeakerContacts({ data, error }) {
    if (data) {
        if (data.length && data[0].label !== undefined && data[0].value !== undefined) {
            this.allSpeakers = (data || []).map((s) => ({
                label: s.label,
                value: s.value,
                jobTitle: s.jobTitle
            }));
        } else {
            this.allSpeakers = (data || []).map((c) => ({
                label: c.Name,
                value: c.Id,
                jobTitle: c.JobTitle__c
            }));
        }

        this.allSpeakers = (this.allSpeakers || [])
            .slice()
            .sort((a, b) => (a.label || '').localeCompare(b.label || ''));

        this._refreshPills();
        this._applyVisibilityRules();
        this._applyPendingInputIfAny();
        this._tryApplyDefaultSpeaker();
    } else if (error) {
        // eslint-disable-next-line no-console
        console.error('Error loading speakers (Contacts): ', error);
        this.allSpeakers = [];
    }
}
_applyVisibilityRules() {
    const cloned = JSON.parse(JSON.stringify(this.entries || []));
    const speakerById = new Map((this.allSpeakers || []).map((s) => [s.value, s]));

    cloned.forEach((entry) => {
        const speaker = speakerById.get(entry.speakerId);
        entry.showSlidesLanguage = !!speaker && speaker.jobTitle !== 'Sales';
    });

    this.entries = cloned;
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
    @wire(getDefaultSpeakerForEvent, { parentEventId: '$_parentEventId' })
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

            const {
                speakerId,
                productId,
                lang,
                speakerLanguage,
                startTime,
                endTime,
                date,
                key
            } = normalized;

            const entry = this._ensureGroupedEntry(
                byKey,
                key,
                speakerId,
                lang,
                speakerLanguage,
                startTime,
                endTime,
                date
            );

            if (productId) this._pushUnique(entry.productIds, productId);
        }

        return byKey;
    }

    _normalizeRow(r) {
        const speakerId = r && r.speakerContact__c ? r.speakerContact__c : null;
        if (!speakerId) return null;
        const date = r && r.Date__c ? r.Date__c : this.defaultSpeakerDate || null;
        const productId = r && r.strategy__c ? r.strategy__c : null;
        const lang = r && r.Language__c ? r.Language__c : null;
        const speakerLanguage = r && r.speakerLanguage__c ? r.speakerLanguage__c : null;
        const startTime = r && r.startTime__c ? r.startTime__c : null;
        const endTime = r && r.endTime__c ? r.endTime__c : null;
        return {
            speakerId,
            productId,
            lang,
            speakerLanguage,
            startTime,
            endTime,
            date,
           key: `${speakerId}|${lang || ''}|${speakerLanguage || ''}|${startTime || ''}|${endTime || ''}|${date || ''}`
        };
    }

    _ensureGroupedEntry(byKey, key, speakerId, lang, speakerLanguage, startTime, endTime,date) {
        if (!byKey.has(key)) {
            byKey.set(key, {
                key: uniq(),
                speakerId: speakerId,
                productIds: [],
                language: lang,
                speakerLanguage: speakerLanguage,
                startTime: startTime,
                endTime: endTime,
                date: date,
                showSlidesLanguage: false,
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
            const la = labelById.get(a.speakerId) || '';
            const lb = labelById.get(b.speakerId) || '';
            return la.localeCompare(lb);
        });
    }

    _emptyEntry() {
        return {
            key: uniq(),
            speakerId: null,
            productIds: [],
            language: null,
            speakerLanguage: null,
            startTime: null,
            endTime: null,
            date: this.defaultSpeakerDate || null,
            showSlidesLanguage: false,
            speakerPills: [],
            productPills: []
        };
    }

    _finalizeApplyInput() {
        this._refreshPills();
        this._applyVisibilityRules();
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
            e.speakerPills = this.selectionPills(
                this.allSpeakers,
                'standard:contact',
                e.speakerId ? [e.speakerId] : []
            );
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
            speakerId: null,
            productIds: [],
            language: lastLanguage,
            speakerLanguage: null,
            startTime: this.defaultStartTime || null,
            endTime: this.defaultEndTime || null,
            date: this.defaultSpeakerDate || null,
            showSlidesLanguage: false,
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
        const field = event.currentTarget.dataset.field;
        const selectedValues = event.detail && event.detail.selectedValues ? event.detail.selectedValues : [];

        const cloned = JSON.parse(JSON.stringify(this.entries));
        const entry = cloned[index];

        if (field === 'Products') {
            entry.productIds = [...selectedValues];
            entry.productPills = this.selectionPills(this.allProducts, 'standard:product', entry.productIds);
        }

        this.entries = cloned;
        this._rebuildRecords();
    };

    handleMultiItemRemove = (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const field = event.currentTarget.dataset.field;
        const item = event.detail ? event.detail.item : null;
        const nameToRemove = item ? item.name : null;

        if (!nameToRemove && nameToRemove !== 0) {
            return;
        }

        const cloned = JSON.parse(JSON.stringify(this.entries));
        const entry = cloned[index];

        if (field === 'Products') {
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
    handleSpeakerLanguageChange = (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const value = event.detail.value;

        const cloned = JSON.parse(JSON.stringify(this.entries));
        cloned[index].speakerLanguage = value;
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
        console.log('===[SSPRepeater] defaultSpeakerDate=', this.defaultSpeakerDate);
    }

    _entryToRecords(entry) {
        const speakers = entry && entry.speakerId ? [entry.speakerId] : [];
        const products = this._toArray(entry && entry.productIds ? entry.productIds : []);
        const lang = entry ? entry.language || null : null;
        const speakerLanguage = entry ? entry.speakerLanguage || null : null;
        const startTime = entry ? entry.startTime || null : null;
        const endTime = entry ? entry.endTime || null : null;
        const date = entry ? entry.date || null : null;
        const hasSpeaker = speakers.length > 0;
        const hasProducts = products.length > 0;

        // Règle métier
        if (hasSpeaker && !hasProducts) {
            return [];
        }

        if (!hasSpeaker && !hasProducts) {
            return [];
        }

        return this._pairSelections(speakers, products)
            .map(({ sid, pid }) => this._makeRecord(sid, pid, lang, speakerLanguage, startTime, endTime,date));
    }

    _toArray(value) {
        if (Array.isArray(value)) return value;
        return value ? [value] : [];
    }

    _pairSelections(speakers, products) {
        console.debug('===[SSPRepeater] _pairSelections speakers=', speakers, 'products=', products);
        const hasSpeakers = speakers.length > 0;
        const hasProducts = products.length > 0;

        // speaker sans produit = interdit
        if (hasSpeakers && !hasProducts) {
            return [];
        }

        if (!hasSpeakers && hasProducts) {
            return products.map((pid) => ({ sid: null, pid }));
        }

        if (!hasSpeakers && !hasProducts) {
            return [];
        }

        return speakers.flatMap((sid) => products.map((pid) => ({ sid, pid })));
    }

    _makeRecord(contactId, productId, lang, speakerLanguage, startTime, endTime,date) {
        return {
            attributes: { type: 'sessionSpeakerProduct__c' },
            speakerContact__c: contactId,
            strategy__c: productId,
            Language__c: lang,
            speakerLanguage__c: speakerLanguage,
            startTime__c: startTime,
            endTime__c: endTime,
            Date__c: date,
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

        const exists = (this.allSpeakers || []).some((s) => s.value === this.defaultSpeakerId);
        if (!exists) return;

        const cloned = JSON.parse(JSON.stringify(this.entries));
        const speaker = (this.allSpeakers || []).find((s) => s.value === this.defaultSpeakerId);

        cloned[0].speakerId = this.defaultSpeakerId;
        cloned[0].showSlidesLanguage = !!speaker && speaker.jobTitle !== 'Sales';
        cloned[0].speakerPills = this.selectionPills(
            this.allSpeakers,
            'standard:contact',
            cloned[0].speakerId ? [cloned[0].speakerId] : []
        );
        cloned[0].productIds = [];
        cloned[0].productPills = [];

        this.entries = cloned;
        this._defaultApplied = true;
        this._rebuildRecords();
    }

    handleSpeakerChange = (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const value = event.detail.value;

        const cloned = JSON.parse(JSON.stringify(this.entries));
        cloned[index].speakerId = value;

        const speaker = (this.allSpeakers || []).find((s) => s.value === value);
        cloned[index].showSlidesLanguage = !!speaker && speaker.jobTitle !== 'Sales';

        this.entries = cloned;
        this._rebuildRecords();
    };
    handleStartTimeChange = (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const value = event.detail.value;

        const cloned = JSON.parse(JSON.stringify(this.entries));
        cloned[index].startTime = value;
        this.entries = cloned;

        this._rebuildRecords();
    };

    handleEndTimeChange = (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const value = event.detail.value;

        const cloned = JSON.parse(JSON.stringify(this.entries));
        cloned[index].endTime = value;
        this.entries = cloned;

        this._rebuildRecords();
    };

    // Met à jour la date d'une ligne
    handleDateChange = (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const value = event.detail.value;

        const cloned = JSON.parse(JSON.stringify(this.entries));
        cloned[index].date = value; // update date
        this.entries = cloned;

        this._rebuildRecords(); // refresh output JSON
    };

    @api
    validate() {
        let errorMessage = null;

        const hasInvalidRow = (this.entries || []).some((e) => {
            const hasSpeaker = !!e.speakerId;
            const hasProducts = Array.isArray(e.productIds) && e.productIds.length > 0;

            // Si un speaker est renseigné, au moins un produit est obligatoire
            if (hasSpeaker && !hasProducts) {
                errorMessage = 'Any line with a speaker must include at least one product.';
                return true;
            }

            // Si les time slots sont affichés, les 3 champs sont obligatoires avec un speaker
            if (this.showTimeSlots && hasSpeaker && (!e.startTime || !e.endTime || !e.date)) {
                errorMessage = 'Any line with a speaker must include start time, end time and date.';
                return true;
            }

            return false;
        });

        if (hasInvalidRow) {
            return {
                isValid: false,
                errorMessage: errorMessage
            };
        }

        return { isValid: true };
    }
    get hasError() {
        return false; // ou ta logique
    }

    get errorMessage() {
        return 'Any line with a speaker must include at least one product.';
    }

    // Génère les heures de 08:00 à 20:00 (toutes les 30 min)
    get timeOptions() {
        const options = [];
        for (let h = 8; h <= 20; h++) {
            for (let m of ['00', '30']) {
                const hour = String(h).padStart(2, '0');
                const value = `${hour}:${m}`;
                options.push({ label: value, value });
            }
        }
        return options;
    }

}