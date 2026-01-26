import { api, wire, LightningElement, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { subscribe /*, unsubscribe*/ } from "lightning/empApi";
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import Id from "@salesforce/user/Id";

// Apex
import getEvents from "@salesforce/apex/CustomCalendarHelper.getEvents";
import getEventPrefix from "@salesforce/apex/CustomCalendarHelper.getEventPrefix";
import getSpeakerContacts from "@salesforce/apex/CustomCalendarHelper.getSpeakerContacts";
import getUserUtcOffset from "@salesforce/apex/CustomCalendarHelper.getUserUtcOffset";

// Utils
import { formatEvents } from "c/calendarUtils";

export default class CustomCalendar extends NavigationMixin(LightningElement) {
  /* ============================================================
   * FILTER STATE
   * ============================================================
   */

  @track selectedSpeakerContactIds = []; // Speakers (Contacts)
  @track selectedCountries = []; // Sales Teams (Countries)
  @track selectedTimezone; // ✅ Time zone (UTC±HH) e.g. "UTC+01"

  @track allSpeakers = []; // Speakers options (Contacts)
  @track allSalesTeams = []; // Sales Teams options
  @track allTimezones = []; // ✅ Time zone options

  @track speakerPills = [];
  @track salesTeamPills = [];

  @track dispSelectionPills = {
    Speakers: false,
    SalesTeams: false
  };

  // Static Sales Teams (temporary)
  countryOptions = [
    { label: "France", value: "France" },
    { label: "Germany", value: "Germany" },
    { label: "Italy", value: "Italy" },
    { label: "Spain", value: "Spain" },
    { label: "United Kingdom", value: "United Kingdom" },
    { label: "Switzerland", value: "Switzerland" },
    { label: "Luxembourg", value: "Luxembourg" },
    { label: "Netherlands", value: "Netherlands" },
    { label: "Belgium", value: "Belgium" },
    { label: "Austria", value: "Austria" }
  ];

  /* ============================================================
   * API PROPERTIES / CONTEXT
   * ============================================================
   */

  @api recordId;
  @api childObject = "Event__c";
  @api parentFieldName = "parentEvent__c";

  // NEW MODEL FIELDS (kept for future; helper currently hardcodes model fields)
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

 
  userId = Id;
  eventPrefix;
  isEvent = false;
  subscription;
  errorMsg;

  /* ============================================================
   * DEBOUNCE (avoid Apex spam)
   * ============================================================
   */

  _fetchTimeout;

  scheduleFetchEvents(delay = 300) {
    window.clearTimeout(this._fetchTimeout);
    this._fetchTimeout = window.setTimeout(() => {
      this.fetchEvents();
    }, delay);
  }

  /* ============================================================
   * TIMEZONE OPTIONS
   * ============================================================
   */

  buildTimezoneOptions() {
    const opts = [];
    for (let h = -5; h <= 5; h++) {
      const sign = h >= 0 ? "+" : "-";
      const abs = String(Math.abs(h)).padStart(2, "0");
      const v = `UTC${sign}${abs}`;
      opts.push({ label: v, value: v });
    }
    this.allTimezones = opts;
  }

  /* ============================================================
   * LOAD USER TZ (default selection)
   * ============================================================
   */

  @wire(getUserUtcOffset)
  wiredUserTz({ data, error }) {
    if (!this.allTimezones?.length) this.buildTimezoneOptions();

    if (data) {
      this.selectedTimezone = data; // ex "UTC+01"
      // optional: refresh immediately when TZ arrives
      this.scheduleFetchEvents(0);
    } else if (error) {
      console.error("Error loading user timezone offset", error);
      this.selectedTimezone = "UTC+00";
    }
  }

  handleTimezoneChange = (e) => {
    this.selectedTimezone = e.detail.value;
    this.scheduleFetchEvents();
  };

  /* ============================================================
   * LOAD SPEAKERS (Contacts)
   * ============================================================
   */

  @wire(getSpeakerContacts)
  wiredSpeakerContacts({ data, error }) {
    if (data) {
      console.log("====Loaded Speaker Contacts", data);
      // data is Option[] => {label,value}
      this.allSpeakers =
        data.length && data[0].label !== undefined && data[0].value !== undefined
          ? data
          : (data || []).map((c) => ({
              label: c.Name,
              value: c.Id
            }));
    } else if (error) {
      console.error("Error loading Speaker Contacts", error);
      this.allSpeakers = [];
    }
  }

  /* ============================================================
   * ERROR HANDLER
   * ============================================================
   */

  errorCallback(error, stack) {
    console.error("LWC errorCallback", error, stack);
    this.errorMsg =
      (error && (error.message || error.body?.message)) || "Unknown error";
  }

  /* ============================================================
   * GENERIC INPUT HANDLERS
   * ============================================================
   */

  handleChange(event) {
    const { name, value } = event.target;
    this[name] = value;
  }

  handleDirectChange(event) {
    const { name, value } = event.target;
    this[name] = value;
    this.fetchEvents();
  }

  /* ============================================================
   * PILLS UTILITY
   * ============================================================
   */

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

  /* ============================================================
   * MULTI-SELECT CHANGE (AUTO REFRESH)
   * ============================================================
   */

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

      default:
        return;
    }

    // 🔁 Auto refresh calendar
    this.scheduleFetchEvents();
  };

  /* ============================================================
   * PILL REMOVE (AUTO REFRESH)
   * ============================================================
   */

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

    // 🔁 Auto refresh calendar
    this.scheduleFetchEvents();
  };

  /* ============================================================
   * CLEAR FILTERS
   * ============================================================
   */

  handleClear = () => {
    this.selectedSpeakerContactIds = [];
    this.selectedCountries = [];
    this.selectedTimezone = this.selectedTimezone || "UTC+00"; // keep user default if already loaded

    this.speakerPills = [];
    this.salesTeamPills = [];
    this.dispSelectionPills = { Speakers: false, SalesTeams: false };

    this.fetchEvents();
  };

  /* ============================================================
   * APPLY FILTERS (your template calls it)
   * ============================================================
   * If you keep auto-refresh, this can just fetch immediately.
   */
  applyFilters = () => {
    this.fetchEvents();
  };
  openPrintVF = () => {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: {
        url: "/apex/VFP17_PrintEvents"
      }
    });
  };
  /* ============================================================
   * LIFECYCLE
   * ============================================================
   */

  connectedCallback() {
    if (!this.recordId) {
      this.recordId = this.userId;
    }

    this.allSalesTeams = this.countryOptions;

    if (!this.allTimezones?.length) this.buildTimezoneOptions();

    this.addEventListener("fceventclick", this.handleEventClick);
    this.addEventListener("fcdateclick", this.handleDateClick);

    if (this.channelName) {
      this.handleSubscribe();
    }
  }

  // Optional: avoid ghost subscriptions
  // disconnectedCallback() {
  //   try {
  //     if (this.subscription) {
  //       unsubscribe(this.subscription, () => {});
  //     }
  //   } catch (e) {
  //     // ignore
  //   }
  // }

  /* ============================================================
   * EMP API SUBSCRIPTION
   * ============================================================
   */

  async handleSubscribe() {
    const messageCallback = () => {
      this.fetchEvents();
    };
    this.subscription = await subscribe(this.channel, -1, messageCallback);
  }

  get channel() {
    return `/event/${this.channelName}`;
  }

  /* ============================================================
   * CONFIG SENT TO APEX
   * ============================================================
   */

  get config() {
    return {
      recordId: this.recordId,
      childObject: this.childObject,
      parentFieldName: this.parentFieldName,

      // backward compat (still sent)
      startDatetimeField: this.startDatetimeField,
      endDatetimeField: this.endDatetimeField,

      titleField: this.titleField,
      startDate: this.startDate,
      endDate: this.endDate,
      colorField: this.colorField,

      // ✅ filters
      speakerIds: this.selectedSpeakerContactIds,
      salesTeams: this.selectedCountries,
      targetTimezone: this.selectedTimezone || "UTC+00"
    };
  }

  /* ============================================================
   * DATE RANGE CHANGE (FROM CALENDAR)
   * ============================================================
   */

  handleDateChange(event) {
    const { startDate, endDate } = event.detail.value;
    this.startDate = startDate;
    this.endDate = endDate;
    this.fetchEvents();
  }

  /* ============================================================
   * EVENT CLICK
   * ============================================================
   */

  handleEventClick = (e) => {
    this.selectedRecordId =
      e.detail?.value?.event?._def?.extendedProps?.Id || e.detail?.value?.event?.id;
  };

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
  /* ============================================================
   * DATE CLICK → FLOW
   * ============================================================
   */

  handleDateClick = (event) => {
    // Do nothing if current record IS not an Event
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
      `&retURL=${encodeURIComponent(retURL)}`;

    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: { url }
    });
  };

  /* ============================================================
   * FETCH EVENTS
   * ============================================================
   */

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

  /* ============================================================
   * EVENT PREFIX
   * ============================================================
   */

  @wire(getEventPrefix)
  wiredPrefix({ data }) {
    if (data) {
      this.eventPrefix = data;
      this.isEvent = this.recordId?.startsWith(this.eventPrefix);
    }
  }

  renderedCallback() {
    if (this.eventPrefix && this.recordId) {
      this.isEvent = this.recordId.startsWith(this.eventPrefix);
    }
  }

  get hasSpeakers() {
    return (this.allSpeakers || []).length > 0;
  }

  get hasSalesTeams() {
    return (this.allSalesTeams || []).length > 0;
  }

   /*openRecap() {
        const modal = this.template.querySelector('c-event-recap-modal');
        if (!modal) {
            // safety fallback
            // eslint-disable-next-line no-console
            console.error('EventRecapModal not found in template');
            return;
        }
        modal.open(this.recordId);
    }*/
   openRecap() {
    // Exemple: https://carmignac-crm--partcopy.lightning.force.com
    // ou https://carmignac-crm--partcopy.sandbox.lightning.force.com
    const origin = window.location.origin;

    // On passe du domaine lightning.force.com au domaine "my.salesforce-sites.com"
    // (ça garde le bon préfixe d'env: carmignac-crm--partcopy)
    const siteOrigin = origin.replace(
        /\.lightning\.force\.com$/i,
        '.my.salesforce-sites.com'
    );

    const path = '/EventAgenda/apex/VFP18_EventAgenda';
    const url = `${siteOrigin}${path}?EventId=${this.recordId}&SMN=false`;

    window.open(url, '_blank');
}
}