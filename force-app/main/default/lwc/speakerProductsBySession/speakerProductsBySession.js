import { LightningElement, api, track } from 'lwc';
import getByEvent from '@salesforce/apex/sessionSpeakerProductRelatedListCTRL.getByEvent';
import getRepeaterInputByEvent from '@salesforce/apex/sessionSpeakerProductRelatedListCTRL.getRepeaterInputByEvent';
import saveFromRepeaterJson from '@salesforce/apex/sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson';

export default class SpeakerProductsBySession extends LightningElement {
    @api recordId;
    @api selectedRecordId;

    @track groups = [];
    @track loading = false;
    @track error;

    // Global edit modal
    @track isEditOpen = false;
    @track initialJson = '[]';
    @track draftJson = '[]';
    @track impactedCount;

    _lastEffectiveId;

    get effectiveEventId() {
        return this.selectedRecordId || this.recordId;
    }

    get hasEventId() { return !!this.effectiveEventId; }
    get hasData() { return this.groups && this.groups.length > 0; }
    get empty() { return this.hasEventId && !this.loading && !this.error && !this.hasData; }
    get errorMessage() {
        return this.error ? (this.error.body ? this.error.body.message : this.error.message) : '';
    }

    renderedCallback() {
        const currentId = this.effectiveEventId;
        if (this._lastEffectiveId !== currentId) {
            // eslint-disable-next-line no-console
            console.debug('[speakerProductsBySession] context changed', { previous: this._lastEffectiveId, current: currentId });
            this._lastEffectiveId = currentId;
            this.load();
        }
    }

    async load() {
        if (!this.hasEventId) {
            this.groups = [];
            this.error = null;
            return;
        }

        this.loading = true;
        this.error = null;

        try {
            const data = await getByEvent({ eventId: this.effectiveEventId });
            this.groups = (data || []).map(s => ({
                speakerId: s.speakerId,
                speakerName: s.speakerName,
                productCount: s.productCount,
                products: (s.products || []).map(p => ({
                    linkId: p.linkId,
                    productId: p.productId,
                    productName: p.productName
                }))
            }));
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('[speakerProductsBySession] load error', e);
            this.error = e;
            this.groups = [];
        } finally {
            this.loading = false;
        }
    }

    // ---------- Global edit flow ----------
    async openEdit() {
        if (!this.hasEventId) return;

        this.loading = true;
        this.error = null;
        this.impactedCount = null;

        try {
            const json = await getRepeaterInputByEvent({ eventId: this.effectiveEventId });
            this.initialJson = json || '[]';
            this.draftJson = this.initialJson;

            // eslint-disable-next-line no-console
            console.debug('[speakerProductsBySession] openEdit initialJson length', this.initialJson.length);

            this.isEditOpen = true;
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('[speakerProductsBySession] openEdit error', e);
            this.error = e;
        } finally {
            this.loading = false;
        }
    }

    closeEdit() {
        this.isEditOpen = false;
    }

    // Repeater emits a jsonchange event (added for Lightning page use)
    handleRepeaterJsonChange(event) {
        this.draftJson = event.detail?.json || '[]';
    }

    async saveEdit() {
        this.loading = true;
        this.error = null;
        this.impactedCount = null;

        try {
            const impacted = await saveFromRepeaterJson({
                eventId: this.effectiveEventId,
                payloadJson: this.draftJson
            });
            this.impactedCount = impacted;

            this.isEditOpen = false;
            await this.load();
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('[speakerProductsBySession] saveEdit error', e);
            this.error = e;
        } finally {
            this.loading = false;
        }
    }

    refresh = () => this.load();
}