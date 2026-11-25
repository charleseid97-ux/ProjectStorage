import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import hasLinkedProducts from '@salesforce/apex/WTPProductSelectorController.hasLinkedProducts';
import FlowModal from 'c/flowModal';

// US-20300: on a WTP (Case) record page, opens the WTP_Product_Selector flow in a pop-up while no product is linked to the WTP; the flexipage visibility rule says which WTPs get it
const FLOW_API_NAME = 'WTP_Product_Selector';
const MANDATORY_DESCRIPTION = 'This WTP does not have any Products linked to it.';

// Opens the WTP_Product_Selector pop-up, then refreshes the record page from host; a mandatory pop-up can't be closed until the flow ends. Also used by the wtpProductSelectorAction quick action
export async function openProductSelector(host, recordId, isMandatory) {
    await FlowModal.open({
        size: 'large',
        label: 'Select Product(s)',
        description: isMandatory ? MANDATORY_DESCRIPTION : undefined,
        disableClose: isMandatory,
        flowApiName: FLOW_API_NAME,
        inputVariables: [{ name: 'recordId', type: 'String', value: recordId }]
    });
    // The flow creates the products server side: refresh the page so its related lists show them
    host.dispatchEvent(new RefreshEvent());
}

export default class WtpProductSelector extends LightningElement {
    @api recordId;

    async connectedCallback() {
        try {
            const hasProducts = await hasLinkedProducts({ wtpId: this.recordId });
            if (!hasProducts) await openProductSelector(this, this.recordId, true);
        }
        catch (error) {
            this.dispatchEvent(new ShowToastEvent({ title: 'WTP Product Selector', message: error.body?.message ?? error.message, variant: 'error' }));
        }
    }
}
