import { api, wire, LightningElement, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { subscribe /*, unsubscribe*/ } from "lightning/empApi";
import Id from "@salesforce/user/Id";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import EVENT_OBJECT from "@salesforce/schema/Event__c";
import TIMEZONE_FIELD from "@salesforce/schema/Event__c.timezone__c";
import SALES_TEAM_FIELD from "@salesforce/schema/Event__c.salesTeam__c";
// Apex
import getEvents from "@salesforce/apex/CustomCalendarHelper.getEvents";
import getEventPrefix from "@salesforce/apex/CustomCalendarHelper.getEventPrefix";
import getSpeakerContacts from "@salesforce/apex/CustomCalendarHelper.getSpeakerContacts";
import getUserUtcOffset from "@salesforce/apex/CustomCalendarHelper.getUserUtcOffset";
import getEventColors from "@salesforce/apex/CustomCalendarHelper.getEventColors";
import BooklyCanCreateMeetingNotes from "@salesforce/customPermission/BooklyCanCreateMeetingNotes";
import { formatEvents } from "c/calendarUtils";

export default class CustomCalendar extends NavigationMixin(LightningElement) {
  activeSections = [];
  @track selectedSpeakerContactIds = [];
  @track selectedCountries = [];
  @track selectedTimezone = "UTC";
  @track colorLegendRows = [];
  @track colorLegendHeaders = [];
  @track allSpeakers = [];
  @track allSalesTeams = [];
  @track allTimezones = [];

  @track speakerPills = [];
  @track salesTeamPills = [];

  @track selectedJobTitles = [];
  @track allJobTitles = [];
  @track jobTitlePills = [];

  @track dispSelectionPills = {
    Speakers: false,
    SalesTeams: false,
    JobTitles: false
  };

 
  @api recordId;
  @api childObject = "Event__c";
  @api parentFieldName = "parentEvent__c";

  @api startDateField = "startDate__c";
  @api startTimeField = "startTime__c";
  @api endDateField = "endDate__c";
  @api endTimeField = "endTime__c";

  @api titleField = "Name";
  @api channelName;
  @api colorField = "color__c";
  @api selectedRecordId;

  @api startDate;
  @api endDate;
  selectedEventType;
  userId = Id;
  eventPrefix;
  isEvent = false;
  subscription;
  errorMsg;
  _fetchTimeout;
  userTimezoneLoaded = false;

  scheduleFetchEvents(delay = 300) {
    window.clearTimeout(this._fetchTimeout);
    this._fetchTimeout = window.setTimeout(() => {
      this.fetchEvents();
    }, delay);
  }
  @wire(getPicklistValues, {
    recordTypeId: "$objectInfo.data.defaultRecordTypeId",
    fieldApiName: SALES_TEAM_FIELD
  })
  wiredSalesTeamPicklist({ data, error }) {
    if (data) {
      this.allSalesTeams = (data.values || []).map((item) => ({
        label: item.label,
        value: item.value
      }));
    } else if (error) {
      console.error("Error loading sales team picklist", error);
      this.allSalesTeams = [];
    }
  }
  // Récupère les métadonnées de l'objet pour obtenir le record type par défaut.
  @wire(getObjectInfo, { objectApiName: EVENT_OBJECT })
  objectInfo;

  // Charge dynamiquement les valeurs de la picklist Timezone__c.
  @wire(getPicklistValues, {
    recordTypeId: "$objectInfo.data.defaultRecordTypeId",
    fieldApiName: TIMEZONE_FIELD
  })
  wiredTimezonePicklist({ data, error }) {
    if (data) {
      this.allTimezones = (data.values || []).map((item) => ({
        label: item.label,
        value: item.value
      }));

      const exists = this.allTimezones.some(
        (tz) => tz.value === this.selectedTimezone
      );

      if (!exists && this.allTimezones.length) {
        this.selectedTimezone = this.allTimezones[0].value;
      }
    } else if (error) {
      console.error("Error loading timezone picklist", error);
      this.allTimezones = [];
    }
  }

  // Initialise la timezone à partir de la valeur utilisateur si elle existe dans la picklist.
  @wire(getUserUtcOffset)
  wiredUserTz({ data, error }) {
    this.userTimezoneLoaded = true;

    if (data) {
      this.selectedTimezone = data;

      const exists = (this.allTimezones || []).some(
        (tz) => tz.value === this.selectedTimezone
      );

      if (!exists && this.allTimezones.length) {
        this.selectedTimezone = this.allTimezones[0].value;
      }

      this.scheduleFetchEvents(0);
    } else if (error) {
      console.error("Error loading user timezone", error);

      if (this.allTimezones.length) {
        this.selectedTimezone = this.allTimezones[0].value;
      } else {
        this.selectedTimezone = "UTC";
      }
    }
  }

  handleTimezoneChange = (e) => {
    this.selectedTimezone = e.detail.value;
    this.scheduleFetchEvents();
  };

  @wire(getEventColors)
  wiredEventColors({ data, error }) {
    if (data) {
      const records = (data || []).map((row) => ({
        id: row.id,
        label: row.label,
        meetingDays: this.normalizeHex(row.meetingDays),
        oneToOne: this.normalizeHex(row.oneToOne),
        eventColor: this.normalizeHex(row.eventColor)
      }));

      this.colorLegendHeaders = records.map((rec) => ({
        key: rec.id,
        label: rec.label
      }));

      this.colorLegendRows = [
        {
          key: "meetingDays",
          label: "Meeting Days",
          cells: records.map((rec) => ({
            key: `meeting-${rec.id}`,
            style: this.buildLegendCellStyle(rec.meetingDays)
          }))
        },
        {
          key: "oneToOne",
          label: "One to One",
          cells: records.map((rec) => ({
            key: `oto-${rec.id}`,
            style: this.buildLegendCellStyle(rec.oneToOne)
          }))
        },
        {
          key: "event",
          label: "Event",
          cells: records.map((rec) => ({
            key: `event-${rec.id}`,
            style: this.buildLegendCellStyle(rec.eventColor)
          }))
        }
      ];
    } else {
      this.colorLegendHeaders = [];
      this.colorLegendRows = [];
    }
  }

  @wire(getSpeakerContacts)
  wiredSpeakerContacts({ data, error }) {
    if (data) {
      this.allSpeakers = (data || []).map((c) => ({
        label: c.label,
        value: c.value,
        jobTitle: c.jobTitle
      }));

      const titles = [
        ...new Set(
          (data || [])
            .map((c) => c.jobTitle)
            .filter((v) => !!v)
        )
      ].sort();

      this.allJobTitles = titles.map((title) => ({
        label: title,
        value: title
      }));
    } else if (error) {
      console.error("Error loading Speaker Contacts", error);
      this.allSpeakers = [];
      this.allJobTitles = [];
    }
  }

  @wire(getEventPrefix)
  wiredPrefix({ data }) {
    if (data) {
      this.eventPrefix = data;
      this.updateContextFlags();
    }
  }

  connectedCallback() {

    this.updateContextFlags();

    this.addEventListener("fceventclick", this.handleEventClick);
    this.addEventListener("fcdateclick", this.handleDateClick);

    if (this.channelName) {
      this.handleSubscribe();
    }
  }

  renderedCallback() {
    this.updateContextFlags();
  }

  errorCallback(error, stack) {
    console.error("LWC errorCallback", error, stack);
    this.errorMsg =
      (error && (error.message || error.body?.message)) || "Unknown error";
  }

  updateContextFlags() {
    this.isEvent =
      !!this.recordId &&
      !!this.eventPrefix &&
      this.recordId.startsWith(this.eventPrefix);
  }

  get isUserContext() {
    return !!this.recordId && !this.isEvent;
  }

  get eventRecordId() {
    return this.isEvent ? this.recordId : null;
  }

  handleChange(event) {
    const { name, value } = event.target;
    this[name] = value;
  }

  handleDirectChange(event) {
    const { name, value } = event.target;
    this[name] = value;
    this.fetchEvents();
  }

  selectionPills(sourceOptions, iconName, selectedValues) {
    const set = new Set(selectedValues || []);
    return (sourceOptions || [])
      .filter((opt) => set.has(opt.value))
      .map((opt) => ({
        label: opt.label,
        name: opt.value,
        iconName
      }));
  }

  normalizeHex(value) {
    if (!value) return null;
    const v = String(value).trim().replace(/^#/, "");
    return v ? `#${v}` : null;
  }

  get hasColorLegend() {
    return (this.colorLegendHeaders || []).length > 0;
  }

  handleMultiSelection = (e) => {
    const lookup = e.target?.dataset?.id;

    switch (lookup) {
      case "Speakers":
        this.selectedSpeakerContactIds = [...(e.detail.selectedValues || [])];
        this.speakerPills = this.selectionPills(
          this.allSpeakers,
          "standard:contact",
          this.selectedSpeakerContactIds
        );
        this.dispSelectionPills.Speakers = this.speakerPills.length > 0;
        break;

      case "SalesTeams":
        this.selectedCountries = [...(e.detail.selectedValues || [])];
        this.salesTeamPills = this.selectionPills(
          this.allSalesTeams,
          "standard:groups",
          this.selectedCountries
        );
        this.dispSelectionPills.SalesTeams = this.salesTeamPills.length > 0;
        break;

      case "JobTitles":
        this.selectedJobTitles = [...(e.detail.selectedValues || [])];
        this.jobTitlePills = this.selectionPills(
          this.allJobTitles,
          "standard:skill_entity",
          this.selectedJobTitles
        );
        this.dispSelectionPills.JobTitles = this.jobTitlePills.length > 0;
        break;

      default:
        return;
    }

    this.scheduleFetchEvents();
  };

  handleMultiItemRemove = (event) => {
    const type = event.target.dataset.id;
    const nameToRemove = event.detail?.item?.name;
    if (!nameToRemove) return;

    if (type === "Speakers") {
      this.selectedSpeakerContactIds = this.selectedSpeakerContactIds.filter(
        (id) => id !== nameToRemove
      );
      this.speakerPills = this.speakerPills.filter(
        (pill) => pill.name !== nameToRemove
      );
      this.dispSelectionPills.Speakers = this.speakerPills.length > 0;
    }

    if (type === "SalesTeams") {
      this.selectedCountries = this.selectedCountries.filter(
        (val) => val !== nameToRemove
      );
      this.salesTeamPills = this.salesTeamPills.filter(
        (pill) => pill.name !== nameToRemove
      );
      this.dispSelectionPills.SalesTeams = this.salesTeamPills.length > 0;
    }

    if (type === "JobTitles") {
      this.selectedJobTitles = this.selectedJobTitles.filter(
        (val) => val !== nameToRemove
      );
      this.jobTitlePills = this.jobTitlePills.filter(
        (pill) => pill.name !== nameToRemove
      );
      this.dispSelectionPills.JobTitles = this.jobTitlePills.length > 0;
    }

    this.scheduleFetchEvents();
  };

  handleClear = () => {
    this.selectedSpeakerContactIds = [];
    this.selectedCountries = [];
    this.selectedTimezone = this.selectedTimezone || "UTC";

    this.speakerPills = [];
    this.salesTeamPills = [];
    this.selectedJobTitles = [];
    this.jobTitlePills = [];
    this.dispSelectionPills = {
      Speakers: false,
      SalesTeams: false,
      JobTitles: false
    };
    this.fetchEvents();
  };

  applyFilters = () => {
    this.fetchEvents();
  };

  openPrintVF = () => {
    const params = new URLSearchParams();

    if (this.selectedTimezone) {
      params.set("timezone", this.selectedTimezone);
    }

    if ((this.selectedCountries || []).length) {
      params.set("salesTeams", this.selectedCountries.join(","));
    }

    if ((this.selectedSpeakerContactIds || []).length) {
      params.set("speakerIds", this.selectedSpeakerContactIds.join(","));
    }

    if ((this.selectedJobTitles || []).length) {
      params.set("jobTitles", this.selectedJobTitles.join(","));
    }

    if (this.startDate) {
      params.set("start", this.startDate);
    }

    if (this.endDate) {
      params.set("end", this.endDate);
    }

    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: {
        url: `/apex/VFP17_PrintEvents?${params.toString()}`
      }
    });
  };

  async handleSubscribe() {
    const messageCallback = () => {
      this.fetchEvents();
    };
    this.subscription = await subscribe(this.channel, -1, messageCallback);
  }

  get channel() {
    return `/event/${this.channelName}`;
  }

  get config() {
    return {
      recordId: this.recordId || null,
      childObject: this.childObject,
      parentFieldName: this.parentFieldName,
      startDatetimeField: this.startDateField,
      endDatetimeField: this.endDateField,
      titleField: this.titleField,
      startDate: this.startDate,
      endDate: this.endDate,
      colorField: this.colorField,
      speakerIds: this.selectedSpeakerContactIds,
      speakerJobTitles: this.selectedJobTitles,
      salesTeams: this.selectedCountries,
      targetTimezone: this.selectedTimezone || "UTC"
    };
  }

  get hasJobTitles() {
    return (this.allJobTitles || []).length > 0;
  }

  handleDateChange(event) {
    const { startDate, endDate } = event.detail.value;
    this.startDate = startDate;
    this.endDate = endDate;
    this.fetchEvents();
  }

  handleEventClick = (e) => {
    const clickedEvent = e.detail?.value?.event;
    const props = clickedEvent?._def?.extendedProps;

    this.selectedRecordId =
      props?.sObjectId ||
      clickedEvent?.id;

    this.selectedEventType = props?.category || null;

    console.log("props =", JSON.stringify(props));
    console.log("selectedEventType =", this.selectedEventType);
  };
  get showMeetingNoteButton() {
  return BooklyCanCreateMeetingNotes
    && this.childObject === "Event__c"
    && this.selectedEventType === "One to One meeting";
}
  openRecord = () => {
    if (!this.selectedRecordId) return;

    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.selectedRecordId,
        objectApiName: this.childObject,
        actionName: "view"
      }
    });
  };

  get canCreateEventFromDateClick() {
    return this.isEvent;
  }

  handleDateClick = (event) => {
    if (!this.canCreateEventFromDateClick) return;

    const date = event.detail?.value?.date;
    if (!date) return;

    const yyyy = date.getFullYear();
    const mm = String(date.getMonth() + 1).padStart(2, "0");
    const dd = String(date.getDate()).padStart(2, "0");
    const clickedDate = `${yyyy}-${mm}-${dd}`;

    const hh = String(date.getHours()).padStart(2, "0");
    const min = String(date.getMinutes()).padStart(2, "0");
    const clickedStartTime = `${hh}:${min}`;

    const end = new Date(date.getTime() + 60 * 60 * 1000);
    const endH = String(end.getHours()).padStart(2, "0");
    const endM = String(end.getMinutes()).padStart(2, "0");
    const clickedEndTime = `${endH}:${endM}`;

    const retURL = `/lightning/r/Event__c/${this.recordId}/view`;

    const url =
      `/flow/NewEvent` +
      `?recordId=${encodeURIComponent(this.recordId)}` +
      `&clickedDate=${encodeURIComponent(clickedDate)}` +
      `&clickedStartTime=${encodeURIComponent(clickedStartTime)}` +
      `&clickedEndTime=${encodeURIComponent(clickedEndTime)}` +
      `&timezone=${encodeURIComponent(this.selectedTimezone || "UTC")}` +
      `&retURL=${encodeURIComponent(retURL)}`;

    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url }
    });
  };

  async fetchEvents() {
    try {
      const rows = await getEvents(this.config);

      const normalizedRows = (rows || []).map((r) => ({
        ...r,
        Id: r.id,
        start: r.startIso,
        end: r.endIso
      }));

      const events = formatEvents(normalizedRows, this.config);
      const calendarCmp = this.template.querySelector("c-calendar");

      if (calendarCmp) {
        calendarCmp.setEvents(events);
      }
    } catch (e) {
      console.error("fetchEvents error", e);
      this.errorMsg =
        (e && (e.message || e.body?.message)) || "Error fetching events";
    }
  }

  get hasSpeakers() {
    return (this.allSpeakers || []).length > 0;
  }

  get hasSalesTeams() {
    return (this.allSalesTeams || []).length > 0;
  }

  buildLegendCellStyle(hex) {
    const bg = hex || "#FFFFFF";
    return `display:block;min-height:2rem;border-radius:0.25rem;border:1px solid #d8dde6;background-color:${bg};`;
  }

  openAgendaWindow(showMeetingNotes) {
    const origin = window.location.origin;
    const siteOrigin = origin.replace(
      /\.lightning\.force\.com$/i,
      ".my.salesforce-sites.com"
    );

    const path = "/EventAgenda/apex/VFP18_EventAgenda";
    const url = `${siteOrigin}${path}?EventId=${this.recordId}&SMN=${showMeetingNotes}`;

    window.open(url, "_blank");
  }

  openRecap() {
    this.openAgendaWindow(false);
  }

  openRecapWithNotes() {
    this.openAgendaWindow(true);
  }

  openMeetingNoteQuickAction = () => {
    if (!this.selectedRecordId) return;

    this[NavigationMixin.Navigate]({
      type: "standard__quickAction",
      attributes: {
        apiName: "Event__c.MeetingNote_meetingDays"
      },
      state: {
        recordId: this.selectedRecordId
      }
    });
  };
}