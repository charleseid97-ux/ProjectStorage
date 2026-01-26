const formatEvents = (events, config) => {
  console.log("====formatEvents INPUT events=", events);
  console.log("====formatEvents INPUT config=", config);

  const padZero = (str) => (str && str.length === 1 ? "0" + str : str);

  const safeHex = (hex) => {
    if (!hex || typeof hex !== "string") return null;
    let h = hex.trim();
    if (!h) return null;
    if (!h.startsWith("#")) h = "#" + h;
    return h;
  };

  const normalizeHex6 = (hex) => {
    const h = safeHex(hex);
    if (!h) return null;

    let raw = h.slice(1);
    if (raw.length === 3) {
      raw = raw[0] + raw[0] + raw[1] + raw[1] + raw[2] + raw[2];
    }
    if (raw.length !== 6) return null;
    if (!/^[0-9a-fA-F]{6}$/.test(raw)) return null;

    return "#" + raw.toUpperCase();
  };

  const invertColor = (hex, bw = true) => {
    const h = normalizeHex6(hex);
    if (!h) return bw ? "#000000" : "#FFFFFF";

    const raw = h.slice(1);
    const r = parseInt(raw.slice(0, 2), 16);
    const g = parseInt(raw.slice(2, 4), 16);
    const b = parseInt(raw.slice(4, 6), 16);

    if (bw) {
      return r * 0.299 + g * 0.587 + b * 0.114 > 186 ? "#000000" : "#FFFFFF";
    }

    const rr = padZero((255 - r).toString(16));
    const gg = padZero((255 - g).toString(16));
    const bb = padZero((255 - b).toString(16));
    return ("#" + rr + gg + bb).toUpperCase();
  };

  // -------------------------
  // Resolve fields (DTO-first)
  // -------------------------

  const resolveId = (evt) => evt?.id || evt?.Id;

  const resolveTitle = (evt) => {
    // DTO preferred
    if (evt?.title) return evt.title;

    // Some datasets still have Name
    if (evt?.Name) return evt.Name;

    // Config fallback (legacy)
    if (config?.titleField && evt && evt[config.titleField]) return evt[config.titleField];

    return "(no title)";
  };

  const resolveStart = (evt) => {
    // DTO preferred
    if (evt?.startIso) return evt.startIso;
    if (evt?.start) return evt.start;

    // Legacy dynamic field fallback
    if (config?.startDatetimeField && evt && evt[config.startDatetimeField]) {
      return evt[config.startDatetimeField];
    }

    return null;
  };

  const resolveEnd = (evt) => {
    // DTO preferred
    if (evt?.endIso) return evt.endIso;

    // Apex can't send "end" (reserved), so we accept endStr
    if (evt?.endStr) return evt.endStr;

    // Older payloads
    if (evt?.end) return evt.end;

    if (config?.endDatetimeField && evt && evt[config.endDatetimeField]) {
      return evt[config.endDatetimeField];
    }

    return null;
  };

  const resolveColor = (evt) => {
    // DTO preferred
    if (evt?.color) return evt.color;

    // Legacy possibilities
    if (evt?.color__c) return evt.color__c;
    if (config?.colorField && evt && evt[config.colorField]) return evt[config.colorField];

    return null;
  };

  const resolveTextColor = (evt, bgHex) => {
    // DTO preferred
    if (evt?.textColor) return evt.textColor;

    // Fallback computed
    return invertColor(bgHex, true);
  };

  // -------------------------
  // Build FullCalendar events
  // -------------------------
  return (events || []).map((evt) => {
    const id = resolveId(evt);
    const title = resolveTitle(evt);
    const start = resolveStart(evt);
    const end = resolveEnd(evt);

    const rawColor = resolveColor(evt);
    const hex = normalizeHex6(rawColor); // "#RRGGBB" or null
    const textColor = resolveTextColor(evt, hex || rawColor);

    const fcEvent = {
      ...evt,

      // FullCalendar essentials
      id,
      title,
      start,
      end,

      // Colors
      color: hex || rawColor || undefined,
      backgroundColor: hex || rawColor || undefined,
      borderColor: hex || rawColor || undefined,
      textColor
    };

    if (!fcEvent.title || fcEvent.title === "(no title)") {
      console.warn("formatEvents: missing title for evt id=", id, evt);
    }
    if (!fcEvent.start) {
      console.warn("formatEvents: missing start for evt id=", id, evt);
    }
    if (!fcEvent.end) {
      console.warn("formatEvents: missing end for evt id=", id, evt);
    }

    return fcEvent;
  });
};

const jsToApexDate = (date) => {
  const d = date instanceof Date ? date : new Date(date);
  if (Number.isNaN(d.getTime())) return null;

  const year = d.getFullYear();
  const month = d.getMonth() + 1 < 10 ? "0" + (d.getMonth() + 1) : "" + (d.getMonth() + 1);
  const day = d.getDate() < 10 ? "0" + d.getDate() : "" + d.getDate();
  return `${year}-${month}-${day}`;
};

export { formatEvents, jsToApexDate };