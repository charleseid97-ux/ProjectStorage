import { LightningElement, api } from 'lwc';
import { openProductSelector } from 'c/wtpProductSelector';

// US-20300: "Add Products / Share Classes" quick action of the WTP record pages, opening the WTP_Product_Selector pop-up (closable, products can be added at any time)
export default class WtpProductSelectorAction extends LightningElement {
    @api recordId;

    @api
    invoke() {
        return openProductSelector(this, this.recordId, false);
    }
}