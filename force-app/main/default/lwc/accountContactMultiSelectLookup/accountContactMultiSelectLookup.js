import { LightningElement, api, track } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getContactsByAccount from '@salesforce/apex/AccountContactMultiSelectCtrl.getContactsByAccount';
import getAccountAddress from '@salesforce/apex/AccountContactMultiSelectCtrl.getAccountAddress';


export default class AccountContactMultiSelectLookup extends LightningElement {
    // ===== FLOW INPUTS =====
    @api accountLabel = 'Account';
    @api picklistLabel = 'Contacts';
    @api limitSize = 200;

    // Optional preselection
    @api preselectedAccountId;
    @api preselectedIdsJson;

    // ===== FLOW OUTPUTS =====
    @api accountId = '';
    @api selectedIdsJson = '[]';
    @api selectedIdsCsv = '';
    @api showAddress = false; // contrôle affichage adresse
    // ===== UI / STATE =====
    @track options = [];
    @track selectedIds = [];
    @track selectedPills = [];
    @track address;

    isLoading = false;
    lastError = null;

    _initialized = false;
    _initializedContactsFromPreselected = false;
    _lastLoadedAccountId = null;


    connectedCallback() {
        this._initFromPreselectedIfNeeded();
        this._syncOutputs();
    }

    renderedCallback() {
        if (!this._initialized) {
            this._initialized = true;
            if (this.accountId) {
                this._loadContacts();
            }
        }
    }

    get hasAccount() {
        return !!this.accountId;
    }

    get accountPickerValue() {
        return this.accountId || null;
    }
    get displayAddress() {
        return this.showAddress && this.address;
    }
    handleAccountChange(event) {
        const newAccountId = event?.detail?.recordId || '';

        if (newAccountId === this.accountId) return;

        this.accountId = newAccountId;
        this.lastError = null;
        this._initializedContactsFromPreselected = false;

        this.selectedIds = [];
        this.selectedPills = [];
        this.options = [];
        this._syncOutputs();

        if (!this.accountId) {
            this._lastLoadedAccountId = null;
            return;
        }

        this._loadContacts();
        this._loadAddress();
    }
    
    // Charge l'adresse après sélection Account
    async _loadAddress() {
        // ne fait rien si désactivé
        if (!this.accountId || !this.showAddress) return;

        try {
            const a = await getAccountAddress({ accountId: this.accountId });

            // map des champs Billing vers objet UI
            this.address = a ? {
                name: a.Name,
                street: a.BillingStreet,
                city: a.BillingCity,
                postalCode: a.BillingPostalCode,
                country: a.BillingCountry
            } : null;

        } catch (e) {
            this.address = null;
        }
    }
    async _loadContacts() {
        if (!this.accountId || this.accountId === this._lastLoadedAccountId) {
            return;
        }

        this.isLoading = true;
        this.lastError = null;

        try {
            const data = await getContactsByAccount({
                accountId: this.accountId,
                limitSize: this.limitSize
            });

            this.options = data || [];
            this._lastLoadedAccountId = this.accountId;

            this._initContactPreselectionIfNeeded();
            this._rebuildPills();
            this._syncOutputs();
        } catch (e) {
            this.options = [];
            this.lastError = this._reduceError(e);
            this._rebuildPills();
            this._syncOutputs();
        } finally {
            this.isLoading = false;
        }
    }

    handleMultiSelection = (event) => {
        const values = event?.detail?.selectedValues || [];
        this.selectedIds = [...values];

        this._rebuildPills();
        this._syncOutputs();
    };

    handlePillRemove = (event) => {
        const idToRemove = event?.detail?.item?.name;
        if (!idToRemove) return;

        this.selectedIds = (this.selectedIds || []).filter((x) => x !== idToRemove);

        this._rebuildPills();
        this._syncOutputs();
    };

    _initFromPreselectedIfNeeded() {
        if (this.preselectedAccountId && !this.accountId) {
            this.accountId = this.preselectedAccountId;
        }
    }

    _initContactPreselectionIfNeeded() {
        if (this._initializedContactsFromPreselected) return;

        if (!this.preselectedIdsJson) {
            this._initializedContactsFromPreselected = true;
            return;
        }

        try {
            const parsed = JSON.parse(this.preselectedIdsJson);
            if (Array.isArray(parsed)) {
                const availableValues = new Set((this.options || []).map((opt) => opt.value));
                this.selectedIds = parsed.filter((id) => !!id && availableValues.has(id));
            }
        } catch (e) {
            // ignore invalid JSON
        }

        this._initializedContactsFromPreselected = true;
    }

    _rebuildPills() {
        const set = new Set(this.selectedIds || []);
        this.selectedPills = (this.options || [])
            .filter((opt) => set.has(opt.value))
            .map((opt) => ({
                label: opt.label,
                name: opt.value,
                iconName: 'standard:contact'
            }));
    }

    _syncOutputs() {
        const arr = this.selectedIds || [];
        this.selectedIdsJson = JSON.stringify(arr);
        this.selectedIdsCsv = arr.join(',');

        this.dispatchEvent(new FlowAttributeChangeEvent('accountId', this.accountId || ''));
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedIdsJson', this.selectedIdsJson));
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedIdsCsv', this.selectedIdsCsv));
    }

    _reduceError(err) {
        try {
            if (Array.isArray(err?.body)) {
                return err.body.map((e) => e.message).join(' | ');
            }
            return err?.body?.message || err?.message || 'Unknown error';
        } catch (e) {
            return 'Unknown error';
        }
    }
}