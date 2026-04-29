import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import exportBETISHistory from '@salesforce/apex/TaxDataExportController.exportBETISHistory';

export default class ExportBetisHistoryButton extends LightningElement {
    @api recordId;
    isLoading = false;

    handleClick() {
    this.isLoading = true;

    exportBETISHistory({ shareClassId: this.recordId })
        .then(result => {
            if (!result || !result.content) {
                throw new Error('No file content returned.');
            }

            const fileContent = result.content;
            const encodedContent = encodeURIComponent(fileContent);

            const link = document.createElement('a');
            link.setAttribute(
                'href',
                'data:application/vnd.ms-excel;charset=utf-8,' + encodedContent
            );
            link.setAttribute(
                'download',
                result.fileName || 'BE_TIS_History.xlsx'
            );

            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        })
        .catch(error => {
            let message = 'An error occurred during export.';
            if (error?.body?.message) {
                message = error.body.message;
            } else if (error?.message) {
                message = error.message;
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Export failed',
                    message,
                    variant: 'error'
                })
            );
        })
        .finally(() => {
            this.isLoading = false;
        });
}
}