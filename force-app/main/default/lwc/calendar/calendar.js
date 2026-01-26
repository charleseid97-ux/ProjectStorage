import { api, LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import fullCalendar from "@salesforce/resourceUrl/fullCalendar";
import { loadStyle, loadScript } from "lightning/platformResourceLoader";
import { jsToApexDate } from "c/calendarUtils";
import { getRecord } from "lightning/uiRecordApi";

// ✅ Fetch only the fields we need (faster + stable)
import START_DATE from "@salesforce/schema/Event__c.startDate__c";
import END_DATE from "@salesforce/schema/Event__c.endDate__c";
// (Optional) if you want to use them later
// import START_TIME from '@salesforce/schema/Event__c.startTime__c';
// import END_TIME from '@salesforce/schema/Event__c.endTime__c';

const FIELDS = [START_DATE, END_DATE];

export default class Calendar extends LightningElement {
  @api recordId;

  initialView_var = "dayGridMonth";
  calendarLabel = "";
  calendar;
  initialized = false;

  validRangeStart; // YYYY-MM-DD
  validRangeEnd; // YYYY-MM-DD (exclusive in FC)

  _pendingEvents = null;

  connectedCallback() {
    console.log("=====v33==connectedCallback: recordId =", this.recordId);
  }

  // récupération du record (Event__c) pour connaître la validRange
  @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
  wiredEvent({ data, error }) {
    console.log("=======wiredEvent fired: recordId =", this.recordId);

    if (error) {
      console.error("=======wiredEvent: Error", error);
      return;
    }

    if (!data) {
      console.log(
        "=======wiredEvent: no data and no error (probably no recordId yet)"
      );
      return;
    }

    console.log("=======wiredEvent: data received", JSON.parse(JSON.stringify(data)));

    if (!this.isEventRecord(data)) {
      console.warn("=======wiredEvent: not Event__c");
      return;
    }

    const { startDate, endDate } = this.getStartEndDates(data);
    this.logStartEndDates(startDate, endDate);

    if (!startDate || !endDate) {
      console.warn("=======wiredEvent: no start/end dates → skip validRange");
      return;
    }

    this.setValidRangeFromDates(startDate, endDate);

    if (this.calendar) {
      this.applyValidRangeToCalendarAndNotify();
    } else {
      console.log("=======wiredEvent: calendar not ready yet → will apply in init()");
      this.initialView_var = "timeGridWeek";
    }
  }

  /** Helpers */

  isEventRecord(data) {
    const apiName = data?.apiName;
    console.log("=======wiredEvent: apiName =", apiName);
    return apiName === "Event__c";
  }

  // ✅ New model: Date fields only
  getStartEndDates(data) {
    // LDS Date value is already "YYYY-MM-DD"
    const startDate = data.fields.startDate__c?.value || null;
    const endDate = data.fields.endDate__c?.value || null;
    return { startDate, endDate };
  }

  logStartEndDates(startDate, endDate) {
    console.log("=======wiredEvent: raw startDate__c =", startDate);
    console.log("=======wiredEvent: raw endDate__c   =", endDate);
  }

  setValidRangeFromDates(startDate, endDate) {
    this.validRangeStart = startDate;                 // inclusif
    this.validRangeEnd = this.addDaysToYmd(endDate, 1); // exclusif => inclut endDate

    console.log("validRangeStart (FC) =", this.validRangeStart);
    console.log("validRangeEnd   (FC, exclusive) =", this.validRangeEnd);
    }

    addDaysToYmd(ymd, daysToAdd) {
    const [y, m, d] = ymd.split("-").map(Number);
    const dt = new Date(Date.UTC(y, m - 1, d)); // calcul UTC (pas local)
    dt.setUTCDate(dt.getUTCDate() + daysToAdd);

    const yy = dt.getUTCFullYear();
    const mm = String(dt.getUTCMonth() + 1).padStart(2, "0");
    const dd = String(dt.getUTCDate()).padStart(2, "0");
    return `${yy}-${mm}-${dd}`;
    }

  applyValidRangeToCalendarAndNotify() {
    if (!this.validRangeStart || !this.validRangeEnd) {
      console.warn("=======wiredEvent: validRange missing → skip applying to calendar");
      return;
    }

    console.log("=======wiredEvent: applying validRange to calendar");

    this.calendar.setOption("validRange", {
      start: this.validRangeStart,
      end: this.validRangeEnd
    });

    this.safeChangeViewAndGotoDate();
    this.calendarLabel = this.calendar.view.title;

    // Avoid extra render loops; keep if you really need it
    this.calendar.render();

    this.safeDispatchDateChange();
  }

  safeChangeViewAndGotoDate() {
    try {
      this.calendar.changeView("timeGridWeek");
      this.calendar.gotoDate(this.validRangeStart);
    } catch (e) {
      console.error("=======wiredEvent: error when changing view/gotoDate", e);
    }
  }

  safeDispatchDateChange() {
    try {
      const startDate = jsToApexDate(this.calendar.view.activeStart);
      const endDate = jsToApexDate(this.calendar.view.activeEnd);
      this.event("datechange", { startDate, endDate });
      console.log(
        "=======wiredEvent: dispatched datechange after applying validRange",
        startDate,
        endDate
      );
    } catch (e) {
      console.error("=======wiredEvent: error dispatching datechange", e);
    }
  }

  async renderedCallback() {
    console.log("===========renderedCallback: initialized =", this.initialized);
    if (this.initialized) {
      return;
    }
    this.initialized = true;

    try {
      console.log("===========renderedCallback: loading core scripts/styles");
      await Promise.all([
        loadScript(this, fullCalendar + "/packages/core/main.js"),
        loadStyle(this, fullCalendar + "/packages/core/main.css")
      ]);

      console.log("===========renderedCallback: loading plugins");
      await Promise.all([
        loadScript(this, fullCalendar + "/packages/daygrid/main.js"),
        loadStyle(this, fullCalendar + "/packages/daygrid/main.css"),
        loadScript(this, fullCalendar + "/packages/list/main.js"),
        loadStyle(this, fullCalendar + "/packages/list/main.css"),
        loadScript(this, fullCalendar + "/packages/timegrid/main.js"),
        loadStyle(this, fullCalendar + "/packages/timegrid/main.css"),
        loadScript(this, fullCalendar + "/packages/interaction/main.js"),
        loadScript(this, fullCalendar + "/packages/moment/main.js"),
        loadScript(this, fullCalendar + "/packages/moment-timezone/main.js")
      ]);

      console.log("===========renderedCallback: init()");
      this.init();
    } catch (error) {
      console.error("=======renderedCallback: error loading calendar", error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error loading Calendar",
          variant: "error"
        })
      );
    }
    console.log("==========renderedCallback end");
  }

  // initialise FullCalendar et émet la première datechange
  init() {
    console.log("=====init start: recordId =", this.recordId);
    console.log("=====init start: this.initialView_var =", this.initialView_var);

    if (this.validRangeStart && this.validRangeEnd) {
      this.initialView_var = "timeGridWeek";
    }

    const calendarEl = this.template.querySelector(".calendar");

    const options = {
      weekends: false,
      minTime: "06:00:00",
      maxTime: "24:00:00",
      scrollTime: "08:00:00",
      height: 600,
      contentHeight: 600,
      expandRows: false,
      plugins: ["dayGrid", "timeGrid", "list", "interaction", "moment"],
      views: {
        listDay: { buttonText: "list day" },
        listWeek: { buttonText: "list week" },
        listMonth: { buttonText: "list month" },
        dayGridMonth: { buttonText: "month" },
        timeGridWeek: {
          minTime: "06:00:00",
          maxTime: "24:00:00",
          buttonText: "week"
        },
        timeGridDay: {
          minTime: "06:00:00",
          maxTime: "24:00:00",
          buttonText: "day"
        }
      },
      defaultView: this.initialView_var,
      header: false,
      events: [],
      eventRendering: "list-item",
      eventDrop: (info) => {
        console.log("=======eventDrop", info);
      },
      eventClick: (info) => {
        console.log("=======eventClick", info);
        this.event("fceventclick", info);
      },
      eventMouseEnter: (info) => {
        console.log("=======eventMouseEnter", info);
      },
      eventMouseLeave: (info) => {
        console.log("=======eventMouseLeave", info);
      },
      dateClick: (info) => {
        console.log("=======dateClick", info);
        this.event("fcdateclick", info);
      }
    };

    // appliquer validRange si déjà connue
    console.log(
      "=====init: validRangeStart =",
      this.validRangeStart,
      ", validRangeEnd =",
      this.validRangeEnd
    );
    if (this.validRangeStart && this.validRangeEnd) {
      options.validRange = {
        start: this.validRangeStart,
        end: this.validRangeEnd
      };
    }

    this.calendar = new FullCalendar.Calendar(calendarEl, options);

    console.log("=====init: calendar instance created", this.calendar);

    this.calendar.render();
    this.calendarLabel = this.calendar.view.title;

    // appliquer les events bufferisés si présents
    if (this._pendingEvents) {
      console.log("=====init: applying buffered events");
      this.setEvents(this._pendingEvents);
      this._pendingEvents = null;
    }

    const startDate = jsToApexDate(this.calendar.view.activeStart);
    const endDate = jsToApexDate(this.calendar.view.activeEnd);

    console.log(
      "=====init: activeStart =",
      this.calendar.view.activeStart,
      ", activeEnd =",
      this.calendar.view.activeEnd
    );
    console.log("=====init: jsToApexDate startDate =", startDate, ", endDate =", endDate);

    this.event("datechange", { startDate, endDate });

    console.log("=====init end");
  }

  // ---------------------------
  // ✅ EVENTS API
  // ---------------------------

  @api setEvents(events) {
    console.log("=======setEvents: events received", JSON.parse(JSON.stringify(events)));

    if (!this.calendar) {
      console.warn("=======setEvents: calendar not ready yet, buffering events");
      this._pendingEvents = events;
      return;
    }

    const postedEvents = this.calendar.getEvents();
    console.log("=======setEvents: existing events count =", postedEvents.length);
    postedEvents.forEach((event) => event.remove());

    (events || []).forEach((event) => {
      console.log("=======setEvents: adding event", event);
      this.calendar.addEvent(event);
    });
  }

  @api setValidRanges(range) {
    console.log("=======setValidRanges called with range =", range);

    if (!this.calendar) {
      console.warn("=======setValidRanges: calendar not ready yet");
      return;
    }

    this.calendar.setOption("validRange", range);
    this.calendar.render();
  }

  // ---------------------------
  // ✅ REFRESH
  // ---------------------------

  refreshHandler() {
    console.log("=======refreshHandler called");
    this.refresh();
  }

  @api refresh() {
    console.log("=======refresh called");

    if (!this.calendar) {
      console.warn("=======refresh: calendar not ready yet");
      return;
    }

    // Re-dispatch current visible range so parent can refetch events
    this.setDates();

    // Optional: force redraw
    // this.calendar.render();
  }

  // calcule et émet la période active au parent
  setDates() {
    if (!this.calendar) {
      console.warn("=======setDates: calendar not ready yet");
      return;
    }

    const startDate = jsToApexDate(this.calendar.view.activeStart);
    const endDate = jsToApexDate(this.calendar.view.activeEnd);

    console.log("=======setDates: startDate =", startDate, ", endDate =", endDate);

    this.event("datechange", { startDate, endDate });
  }

  // ---------------------------
  // ✅ NAVIGATION
  // ---------------------------

  nextHandler() {
    console.log("=======nextHandler");
    this.calendar.next();
    this.calendarLabel = this.calendar.view.title;
    this.setDates();
  }

  previousHandler() {
    console.log("=======previousHandler");
    this.calendar.prev();
    this.calendarLabel = this.calendar.view.title;
    this.setDates();
  }

  today() {
    console.log("=======today");
    this.calendar.today();
    this.calendarLabel = this.calendar.view.title;
    this.setDates();
  }

  dailyViewHandler() {
    console.log("=======dailyViewHandler");
    this.calendar.changeView("timeGridDay");
    this.calendarLabel = this.calendar.view.title;
  }

  weeklyViewHandler() {
    console.log("=======weeklyViewHandler");
    this.calendar.changeView("timeGridWeek");
    this.calendarLabel = this.calendar.view.title;
  }

  monthlyViewHandler() {
    console.log("=======monthlyViewHandler");
    this.calendar.changeView("dayGridMonth");
    this.calendarLabel = this.calendar.view.title;
  }

  listViewHandler() {
    console.log("=======listViewHandler");
    this.calendar.changeView("listWeek");
    this.calendarLabel = this.calendar.view.title;
  }

  handleScroll(event) {
    console.log("=======handleScroll");
    event.stopImmediatePropagation();
  }

  // helper pour dispatcher des CustomEvents au parent
  event(name, value) {
    console.log("=======dispatching event:", name, "with value =", value);
    this.dispatchEvent(
      new CustomEvent(name, {
        bubbles: true,
        composed: true,
        detail: { value }
      })
    );
  }
}