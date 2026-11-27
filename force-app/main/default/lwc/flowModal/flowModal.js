import { api } from 'lwc';
import LightningModal from 'lightning/modal';

// US-20300: generic pop-up running a screen flow, opened with FlowModal.open({ label, description, flowApiName, inputVariables, disableClose }); it closes itself once the flow ends
export default class FlowModal extends LightningModal {
    @api flowApiName;
    // [{ name, type, value }] passed to the flow's input variables
    @api inputVariables;

    handleStatusChange(event) {
        const status = event.detail.status;
        if (status !== 'FINISHED' && status !== 'FINISHED_SCREEN') return;
        // A pop-up opened with disableClose can't be closed, not even by close(), until it is switched off
        this.disableClose = false;
        this.close();
    }
}