import { LightningElement, api } from 'lwc';
import getIcsContent from '@salesforce/apex/eventAddToCalendarCtrl.getIcsContent';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class EventAddToCalendarScreen extends LightningElement {
    _recordId;
    hasRun = false;

    @api
    set recordId(value) {
        this._recordId = value;

        if (value && !this.hasRun) {
            this.hasRun = true;
            this.run();
        }
    }

    get recordId() {
        return this._recordId;
    }

    async run() {
        try {
            const icsContent = await getIcsContent({ recordId: this._recordId });

            const link = document.createElement('a');
            link.href = 'data:text/plain;charset=utf-8,' + encodeURIComponent(icsContent);
            link.download = 'event.ics';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Calendar file generated',
                    variant: 'success'
                })
            );
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: e?.body?.message || e.message,
                    variant: 'error'
                })
            );
        } finally {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
}