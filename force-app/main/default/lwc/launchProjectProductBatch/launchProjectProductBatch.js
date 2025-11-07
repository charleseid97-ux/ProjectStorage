import { LightningElement, api } from 'lwc';
import launch from '@salesforce/apex/LaunchProjectProductBatch.launch';
 
export default class LaunchBatchButton extends LightningElement {
    @api recordId;
    boutonDisabled = false;
 
    handleClick() {
        this.boutonDisabled = true;
        launch({ projectProductIds: [this.recordId] })
            .then(() => {
                this.boutonDisabled = true;
                console.log('Batch lancé');
            })
            .catch(error => {
                this.boutonDisabled = true;
                console.error('Erreur:', error);
            });
    }
}