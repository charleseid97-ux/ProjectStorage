import { LightningElement, api, track, wire } from 'lwc';

import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import EVENT_FIELD from '@salesforce/schema/Campaign.Event__c';

import getByEvent from '@salesforce/apex/sessionSpeakerProductRelatedListCTRL.getByEvent';

export default class SpeakerProductsBySessionReadOnly extends LightningElement {

    // Current Campaign Id
    @api recordId;

    // Event Id read from Campaign.Event__c
    @track campaignEventId;

    // Displayed speaker groups
    @track groups = [];

    // Loading state
    @track loading = false;

    // Prevent duplicate loads
    _loadedEventId;

    // Load Campaign record
    @wire(getRecord, {
        recordId: '$recordId',
        fields: [EVENT_FIELD]
    })
    wiredCampaign({ data, error }) {

        console.log('========== recordId', this.recordId);

        if (data) {

            // Read Event__c from Campaign
            this.campaignEventId = getFieldValue(data, EVENT_FIELD);

            console.log('========== campaignEventId', this.campaignEventId);

        } else if (error) {

            console.error('========== wire error', JSON.stringify(error));
        }
    }

    // Check if Campaign has linked Event
    get hasEventId() {
        return !!this.campaignEventId;
    }

    // Check if data exists
    get hasData() {
        return this.groups && this.groups.length > 0;
    }

    // Empty state
    get empty() {
        return this.hasEventId && !this.loading && !this.hasData;
    }

    // Reload when Event changes
    renderedCallback() {

        console.log('========== renderedCallback', this.campaignEventId);

        if (this._loadedEventId === this.campaignEventId) {
            return;
        }

        this._loadedEventId = this.campaignEventId;

        this.load();
    }

    // Load speakers/products from Apex
    async load() {

        console.log('========== load START');

        // Reset if no Event
        if (!this.campaignEventId) {

            console.log('========== NO EVENT ID');

            this.groups = [];
            return;
        }

        this.loading = true;

        try {

            console.log('========== calling apex with', this.campaignEventId);

            // Load SSP linked to Session/Event
            const data = await getByEvent({
                eventId: this.campaignEventId
            });

            // Build product labels for table display
            this.groups = (data || []).map((group) => ({
                ...group,
                productsLabel: (group.products || [])
                    .map((product) => product.productName)
                    .join(', ')
            }));

            console.log('========== groups', JSON.stringify(this.groups));

        } catch (e) {

            console.error('========== load error', JSON.stringify(e));

        } finally {

            this.loading = false;

            console.log('========== load END');
        }
    }

}