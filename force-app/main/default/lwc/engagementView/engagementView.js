import { LightningElement, api } from 'lwc';

export default class engagementView extends LightningElement {

    @api recordId
    @api clickedButton = 'All'

    showGlobal = true
    clickGlobal(event) {
        this.clickedButton = event.target.label
        this.showGlobal = true;
        this.showInteractionsByProduct = false
    }

    showInteractionsByProduct = false
    clickInteractionsByProduct(event) {
        this.clickedButton = event.target.label
        this.showInteractionsByProduct = true
        this.showGlobal = false
    }
}