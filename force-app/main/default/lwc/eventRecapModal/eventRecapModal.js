import { LightningElement, api, track } from 'lwc';
import getEventRecap from '@salesforce/apex/EventRecapController.getEventRecap';

export default class EventRecapModal extends LightningElement {
    @api eventId;

    @track recap;
    loading = false;
    isOpen = false;
    errorMessage;

    // Entry point when used from another component
    @api
    open(eventId) {
        if (eventId) this.eventId = eventId;
        this.isOpen = true;

        // eslint-disable-next-line no-console
        console.debug('[EventRecapModal] open()', { eventId: this.eventId });

        this.load();
    }

    @api
    close() {
        // eslint-disable-next-line no-console
        console.debug('[EventRecapModal] close()');
        this.isOpen = false;
    }

    async load() {
        if (this.loading) return; // prevents double requests if open() is called twice
        this.errorMessage = null;

        if (!this.eventId) {
            this.recap = null;
            this.errorMessage = 'Missing Event__c Id (eventId).';
            return;
        }

        this.loading = true;
        // eslint-disable-next-line no-console
        console.debug('[EventRecapModal] load() start', { eventId: this.eventId });

        try {
            const data = await getEventRecap({ eventId: this.eventId });
            this.recap = data;

            // eslint-disable-next-line no-console
            console.debug('[EventRecapModal] load() success', {
                hasParent: !!data?.parent,
                children: Array.isArray(data?.children) ? data.children.length : 0
            });
        } catch (e) {
            this.recap = null;
            this.errorMessage = e?.body?.message || e?.message || 'Unknown error';

            // eslint-disable-next-line no-console
            console.debug('[EventRecapModal] load() error', this.errorMessage);
        } finally {
            this.loading = false;

            // eslint-disable-next-line no-console
            console.debug('[EventRecapModal] load() end');
        }
    }

    get hasChildren() {
        return Array.isArray(this.recap?.children) && this.recap.children.length > 0;
    }

    // ----- Formatting helpers -----
    formatDateFR(dateStr) {
        if (!dateStr) return '';
        const [y, m, d] = String(dateStr).split('-');
        return `${d}-${m}-${y}`;
    }

    trimTime(t) {
        if (!t) return '';
        const m = String(t).match(/^(\d{2}:\d{2})/);
        return m ? m[1] : String(t);
    }

    // For grouping headings like "Monday 12th January"
    daySuffix(n) {
        const nn = Number(n);
        if (Number.isNaN(nn)) return '';
        const mod100 = nn % 100;
        if (mod100 >= 11 && mod100 <= 13) return 'th';
        const mod10 = nn % 10;
        if (mod10 === 1) return 'st';
        if (mod10 === 2) return 'nd';
        if (mod10 === 3) return 'rd';
        return 'th';
    }

    formatDayHeading(dateStr) {
        // dateStr expected YYYY-MM-DD
        if (!dateStr) return '';
        const [y, m, d] = String(dateStr).split('-').map((x) => Number(x));
        const dt = new Date(Date.UTC(y, (m || 1) - 1, d || 1));
        const weekday = new Intl.DateTimeFormat('en-GB', { weekday: 'long', timeZone: 'UTC' }).format(dt);
        const month = new Intl.DateTimeFormat('en-GB', { month: 'long', timeZone: 'UTC' }).format(dt);
        const day = d;
        return `${weekday} ${day}${this.daySuffix(day)} ${month}`;
    }

    // ----- Parent presentation -----
    get parentStartDate() {
        return this.formatDateFR(this.recap?.parent?.startDate);
    }
    get parentEndDate() {
        return this.formatDateFR(this.recap?.parent?.endDate);
    }
    get parentStartTime() {
        return this.trimTime(this.recap?.parent?.startTime);
    }
    get parentEndTime() {
        return this.trimTime(this.recap?.parent?.endTime);
    }

    // Parent background (collapsible)
    get hasParentBackground() {
        return !!this.recap?.parent?.meetingBackground;
    }

    // Parent speakers/products (NOT collapsible)
    get hasParentSpeakers() {
        return Array.isArray(this.recap?.parent?.speakers) && this.recap.parent.speakers.length > 0;
    }

    get parentSpeakersView() {
        if (!this.hasParentSpeakers) return [];
        return this.recap.parent.speakers.map((sp, idx) => ({
            key: `${sp.speakerName || 'speaker'}-${idx}`,
            speakerName: sp.speakerName || '',
            productsLabel: Array.isArray(sp.products) ? sp.products.join(', ') : ''
        }));
    }

    // ----- Child grouping -----
    get isParentMultiDay() {
        const sd = this.recap?.parent?.startDate;
        const ed = this.recap?.parent?.endDate;
        return !!sd && !!ed && String(sd) !== String(ed);
    }

    get childrenGroups() {
        if (!this.hasChildren || !this.isParentMultiDay) return [];

        // group by child.startDate (fallback to parent.startDate if missing)
        const buckets = new Map();
        for (const ev of this.recap.children) {
            const key = ev?.startDate || this.recap?.parent?.startDate || 'unknown';
            if (!buckets.has(key)) buckets.set(key, []);
            buckets.get(key).push(ev);
        }

        // sort dates ascending when possible (YYYY-MM-DD lexicographically works)
        const keys = Array.from(buckets.keys()).sort((a, b) => String(a).localeCompare(String(b)));

        return keys.map((dateKey) => ({
            key: `grp-${dateKey}`,
            dateKey,
            label: this.formatDayHeading(dateKey),
            events: buckets.get(dateKey)
        }));
    }
}