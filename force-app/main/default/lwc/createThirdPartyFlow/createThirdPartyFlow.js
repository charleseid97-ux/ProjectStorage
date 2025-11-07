import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';

export default class CreateThirdPartyFlow extends LightningElement {
    @api recordId;
    isModalOpen = false;

    get inputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleFlowStatusChange(event) {
        console.log('Flow status changed:', event.detail.status);
        if (event.detail.status === 'FINISHED') {
            this.isModalOpen = false;

            // Optional: show toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Succès',
                    message: 'Third Party created successfully',
                    variant: 'success'
                })
            );
            
            // Refresh related list
            this.dispatchEvent(new RefreshEvent());

        }
    }
}