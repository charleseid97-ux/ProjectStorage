import { LightningElement, api, track } from 'lwc';

export default class CustomCombobox extends LightningElement {
    @api label = '';
    @api name = '';
    @api value;
    @api options = [];
    @api placeholder = 'Select an Option';
    @api disabled = false;

    @track isOpen = false;

    get selectedLabel() {
        const match = (this.options || []).find(opt => opt.value === this.value);
        return match ? match.label : '';
    }

    get comboboxClass() {
        return 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click' + (this.isOpen ? ' slds-is-open' : '');
    }

    get computedOptions() {
        return (this.options || []).map(opt => ({
            ...opt,
            itemClass: 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small' + (opt.value === this.value ? ' slds-is-selected' : '') + (opt.disabled ? ' slds-is-disabled' : '')
        }));
    }

    toggleDropdown() {
        if (this.disabled) return;
        this.isOpen = !this.isOpen;
    }

    handleBlur() {
        this.isOpen = false;
    }

    handleOptionSelect(event) {
        const newValue = event.currentTarget.dataset.value;
        const opt = (this.options || []).find(o => o.value === newValue);
        if (opt && opt.disabled) return;

        this.isOpen = false;
        this.dispatchEvent(new CustomEvent('change', { detail: { value: newValue } }));
    }
}