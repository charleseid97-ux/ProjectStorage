import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import PARENT_EVENT_FIELD from '@salesforce/schema/Event__c.parentEvent__c';
import START_DATE_FIELD from '@salesforce/schema/Event__c.startDate__c';
import RECORDTYPEID_FIELD from '@salesforce/schema/Event__c.RecordTypeId';

import getByEvent from '@salesforce/apex/sessionSpeakerProductRelatedListCTRL.getByEvent';
import getRepeaterInputByEvent from '@salesforce/apex/sessionSpeakerProductRelatedListCTRL.getRepeaterInputByEvent';
import saveFromRepeaterJson from '@salesforce/apex/sessionSpeakerProductRelatedListCTRL.saveFromRepeaterJson';
import updateSpeakerSlot from '@salesforce/apex/sessionSpeakerProductRelatedListCTRL.updateSpeakerSlot';
import canUserEditEvent from '@salesforce/apex/sessionSpeakerProductRelatedListCTRL.canUserEditEvent';
import RECORDTYPE_DEV_NAME from '@salesforce/schema/Event__c.RecordType.DeveloperName';
export default class SpeakerProductsBySession extends LightningElement {
    @api recordId;
    @api selectedRecordId;

    @track eventStartDate;
    @track parentEventId;
    @track groups = [];
    @track loading = false;
    @track error;
    @track canEditEvent = false;
    @track isEditOpen = false;
    @track initialJson = '[]';
    @track draftJson = '[]';
    @track impactedCount;
    @track recordTypeId;
    recordTypeDeveloperName;
    _lastEffectiveId;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [PARENT_EVENT_FIELD, RECORDTYPEID_FIELD, START_DATE_FIELD,RECORDTYPE_DEV_NAME]
    })
    wiredEvent({ error, data }) {
        if (data) {
            this.parentEventId = getFieldValue(data, PARENT_EVENT_FIELD);
            this.recordTypeId = getFieldValue(data, RECORDTYPEID_FIELD);
            this.eventStartDate = getFieldValue(data, START_DATE_FIELD);
            this.recordTypeDeveloperName = getFieldValue(data, RECORDTYPE_DEV_NAME);
            // eslint-disable-next-line no-console
            console.debug('[speakerProductsBySession] parentEventId loaded', this.parentEventId);
            // eslint-disable-next-line no-console
            console.debug('[speakerProductsBySession] recordTypeId loaded', this.recordTypeId);
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('[speakerProductsBySession] error loading parentEventId / recordTypeId', error);
            this.parentEventId = null;
            this.recordTypeId = null;
            this.eventStartDate = null;
        }
    }
    get showSlots() {
        console.log('========recordTypeDeveloperName==='+this.recordTypeDeveloperName);
        return this.recordTypeDeveloperName !== 'MeetingDays';
    }
    get effectiveEventId() {
        return this.selectedRecordId || this.recordId;
    }

    get hasEventId() {
        return !!this.effectiveEventId;
    }

    get hasData() {
        return this.groups && this.groups.length > 0;
    }

    get empty() {
        return this.hasEventId && !this.loading && !this.error && !this.hasData;
    }

    get errorMessage() {
        return this.error
            ? (this.error.body ? this.error.body.message : this.error.message)
            : '';
    }

    renderedCallback() {
        const currentId = this.effectiveEventId;
        if (this._lastEffectiveId !== currentId) {
            // eslint-disable-next-line no-console
            console.debug('[speakerProductsBySession] context changed', {
                previous: this._lastEffectiveId,
                current: currentId
            });
            this._lastEffectiveId = currentId;
            this.load();
        }
    }

    async load() {
        if (!this.hasEventId) {
            this.groups = [];
            this.error = null;
            this.canEditEvent = false;
            return;
        }

        this.loading = true;
        this.error = null;

        try {
            const [data, canEdit] = await Promise.all([
            getByEvent({ eventId: this.effectiveEventId }),
            canUserEditEvent({ eventId: this.effectiveEventId })
        ]);

        this.canEditEvent = !!canEdit;

        this.groups = (data || []).map((s) => {
                const formattedStartTime = this.formatTime(s.startTime);
                const formattedEndTime = this.formatTime(s.endTime);

                return {
                    speakerId: s.speakerId,
                    speakerName: s.speakerName,
                    productCount: s.productCount,
                    language: s.language,
                    speakerLanguage: s.speakerLanguage,
                    presentationStatus: s.presentationStatus,
                    sessionNumber: s.sessionNumber,
                    startTime: formattedStartTime,
                    endTime: formattedEndTime,
                    date: s.recDate,
                    duration: this.calculateDuration(formattedStartTime, formattedEndTime),
                    draftStartTime: formattedStartTime,
                    draftEndTime: formattedEndTime,
                    slotLabel: this.buildSlotLabel(formattedStartTime, formattedEndTime),
                    isEditingSlot: false,
                    products: (s.products || []).map((p) => ({
                        linkId: p.linkId,
                        productId: p.productId,
                        productName: p.productName
                    }))
                };
            });
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('[speakerProductsBySession] load error', e);
            this.error = e;
            this.groups = [];
            this.canEditEvent = false;
        } finally {
            this.loading = false;
        }
    }

    async openEdit() {
        if (!this.hasEventId || !this.canEditEvent) {
            return;
        }

        this.loading = true;
        this.error = null;
        this.impactedCount = null;

        try {
            await this.load();

            const json = await getRepeaterInputByEvent({ eventId: this.effectiveEventId });
            this.initialJson = json || '[]';
            this.draftJson = this.initialJson;

            // eslint-disable-next-line no-console
            console.debug('[speakerProductsBySession] openEdit initialJson', this.initialJson);
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

    handleRepeaterJsonChange(event) {
        this.draftJson = event.detail?.json || '[]';
    }

    async saveEdit() {
        this.loading = true;
        this.error = null;
        this.impactedCount = null;

        try {
            const repeater = this.template.querySelector('c-session-speaker-product-repeater');

            if (repeater) {
                const validation = repeater.validate();

                if (!validation.isValid) {
                    this.error = { message: validation.errorMessage };
                    return;
                }
            }

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

    handleEditSlot(event) {
        const sessionNumber = event.currentTarget.dataset.sessionNumber;
        this.groups = this.groups.map((group) => {
            if (group.sessionNumber !== sessionNumber) {
                return group;
            }

            return {
                ...group,
                isEditingSlot: true,
                draftStartTime: group.startTime || null,
                draftEndTime: group.endTime || null
            };
        });
    }

    handleSlotChange(event) {
        const sessionNumber = event.target.dataset.sessionNumber;
        const field = event.target.dataset.field;
        const value = event.target.value;

        this.groups = this.groups.map((group) => {
            if (group.sessionNumber !== sessionNumber) {
                return group;
            }

            return {
                ...group,
                [field]: value
            };
        });
    }

    handleCancelSlot(event) {
        const sessionNumber = event.currentTarget.dataset.sessionNumber;
        this.groups = this.groups.map((group) => {
            if (group.sessionNumber !== sessionNumber) {
                return group;
            }

            return {
                ...group,
                isEditingSlot: false,
                draftStartTime: group.startTime || null,
                draftEndTime: group.endTime || null,
                slotLabel: this.buildSlotLabel(group.startTime, group.endTime)
            };
        });
    }

    async handleSaveSlot(event) {
        const sessionNumber = event.currentTarget.dataset.sessionNumber;
        const group = this.groups.find((item) => item.sessionNumber == sessionNumber);

        if (!group || !this.effectiveEventId) {
            return;
        }

        this.loading = true;
        this.error = null;

        try {
            await updateSpeakerSlot({
                eventId: this.effectiveEventId,
                speakerId: group.speakerId,
                startTime: group.draftStartTime,
                endTime: group.draftEndTime
            });

            this.groups = this.groups.map((item) => {
                if (item.sessionNumber != sessionNumber) {
                    return item;
                }

                const formattedStartTime = this.formatTime(item.draftStartTime);
                const formattedEndTime = this.formatTime(item.draftEndTime);

                return {
                    ...item,
                    startTime: formattedStartTime,
                    endTime: formattedEndTime,
                    draftStartTime: formattedStartTime,
                    draftEndTime: formattedEndTime,
                    duration: this.calculateDuration(formattedStartTime, formattedEndTime),
                    slotLabel: this.buildSlotLabel(formattedStartTime, formattedEndTime),
                    isEditingSlot: false
                };
            });
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('[speakerProductsBySession] handleSaveSlot error', e);
            this.error = e;
        } finally {
            this.loading = false;
        }
    }

    refresh = () => this.load();

    formatTime(value) {
        if (!value) {
            return null;
        }

        const parts = value.split(':');
        if (parts.length < 2) {
            return value;
        }

        const hh = parts[0];
        const mm = parts[1];

        return `${hh}:${mm}`;
    }

    buildSlotLabel(startTime, endTime) {
        if (!startTime && !endTime) {
            return 'No slot defined';
        }

        if (startTime && endTime) {
            const durationLabel = this.calculateDuration(startTime, endTime);
            return `${durationLabel} from ${startTime} to ${endTime}`;
        }

        if (startTime) {
            return `from ${startTime}`;
        }

        return `to ${endTime}`;
    }

    calculateDuration(startTime, endTime) {
        const startMinutes = this.toMinutes(startTime);
        const endMinutes = this.toMinutes(endTime);

        if (startMinutes === null || endMinutes === null || endMinutes < startMinutes) {
            return '';
        }

        const totalMinutes = endMinutes - startMinutes;
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;

        if (hours > 0 && minutes > 0) {
            return `${hours}h${minutes}min`;
        }

        if (hours > 0) {
            return `${hours}h`;
        }

        return `${minutes}min`;
    }

    toMinutes(timeValue) {
        if (!timeValue) {
            return null;
        }

        const parts = timeValue.split(':');
        if (parts.length < 2) {
            return null;
        }

        const hours = parseInt(parts[0], 10);
        const minutes = parseInt(parts[1], 10);

        if (Number.isNaN(hours) || Number.isNaN(minutes)) {
            return null;
        }

        return (hours * 60) + minutes;
    }

}