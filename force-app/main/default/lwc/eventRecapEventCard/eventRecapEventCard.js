import { LightningElement, api } from 'lwc';

export default class EventRecapEventCard extends LightningElement {
    @api event;

    connectedCallback() {
        // eslint-disable-next-line no-console
        console.debug('[EventRecapEventCard] init', { eventId: this.event?.id });
    }

    // Child: meetingGoal is inside collapsible; still show accordion if speakers exist
    get showGoalSection() {
        return !!this.event?.meetingGoal || this.hasSpeakers;
    }

    get hasSpeakers() {
        return Array.isArray(this.event?.speakers) && this.event.speakers.length > 0;
    }

    get speakersView() {
        if (!this.hasSpeakers) return [];
        return this.event.speakers.map((sp, idx) => ({
            key: `${sp.speakerName || 'speaker'}-${idx}`,
            speakerName: sp.speakerName || '',
            productsLabel: Array.isArray(sp.products) ? sp.products.join(', ') : ''
        }));
    }

    get hasAttendees() {
        return Array.isArray(this.event?.attendees) && this.event.attendees.length > 0;
    }

    get attendeeCount() {
        return this.hasAttendees ? this.event.attendees.length : 0;
    }

    trimTime(t) {
        if (!t) return '';
        const m = String(t).match(/^(\d{2}:\d{2})/);
        return m ? m[1] : String(t);
    }

    get timeRangeLabel() {
        const st = this.trimTime(this.event?.startTime);
        const et = this.trimTime(this.event?.endTime);
        if (st && et) return `${st} - ${et}`;
        return st || et || '';
    }
}