import { LightningElement, api } from 'lwc';
 
export default class PicklistTemplate extends LightningElement {
    @api typeAttributes;
 
    handleChange(event) {
        event.stopPropagation();
        this.dispatchEvent(new CustomEvent('privatecellchange', {
            bubbles: true,
            composed: true,
            detail: {
                value: event.detail.value
            }
        }));
    }
}