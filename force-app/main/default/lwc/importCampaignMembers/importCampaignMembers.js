import {LightningElement, api} from 'lwc';

// noinspection JSUnusedGlobalSymbols
export default class ImportCampaignMembers extends LightningElement {
    @api recordId;
    isVisibleImportModal = false;
    isVisibleConfirm = false;

    displayImportModal() {
        this.isVisibleImportModal = true;
    }

    hideImportModal() {
        this.isVisibleImportModal = false;
    }
}