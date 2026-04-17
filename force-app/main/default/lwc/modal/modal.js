import {LightningElement, api} from 'lwc';

// noinspection JSUnusedGlobalSymbols
export default class Modal extends LightningElement {
    @api isVisibleConfirm;
    @api isVisibleClose;
    @api confirmButtonLabel = 'Confirm';
    @api closeButtonLabel = 'Close';
    @api isVisibleModal;
    @api isDisabledConfirm;
    @api isDisabledClose;

    constructor() {
        super();
        this.isVisibleConfirm = true;
        this.isVisibleClose = true;
        this.isVisibleModal = false;
    }

    handleConfirm() {
        this.dispatchEvent(new CustomEvent('confirm'));
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}