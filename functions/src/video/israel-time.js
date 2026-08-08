"use strict";

const {VideoRequestError} = require("./errors");

const ISRAEL_TIME_ZONE = "Asia/Jerusalem";

const israelFormatter = new Intl.DateTimeFormat("en-CA", {
  timeZone: ISRAEL_TIME_ZONE,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hourCycle: "h23",
});

function asNumber(parts, type) {
  const value = parts.find((part) => part.type === type)?.value;
  return Number(value);
}

function israelParts(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new TypeError("A valid date is required");
  }
  const formattedParts = israelFormatter.formatToParts(date);
  const hour = asNumber(formattedParts, "hour");
  return {
    year: asNumber(formattedParts, "year"),
    month: asNumber(formattedParts, "month"),
    day: asNumber(formattedParts, "day"),
    // A few older ICU builds render midnight as 24 despite hourCycle.  The
    // local calendar date has already been supplied separately, so 24 means 0.
    hour: hour === 24 ? 0 : hour,
    minute: asNumber(formattedParts, "minute"),
    second: asNumber(formattedParts, "second"),
  };
}

function pad(value) {
  return String(value).padStart(2, "0");
}

function israelDate(value) {
  const parts = israelParts(value);
  return `${parts.year}-${pad(parts.month)}-${pad(parts.day)}`;
}

function israelReservationSlot(value) {
  const parts = israelParts(value);
  return {
    date: `${parts.year}-${pad(parts.month)}-${pad(parts.day)}`,
    hour: parts.hour,
  };
}

function parseManagerDate(dateText) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(dateText || ""));
  if (!match) {
    throw new VideoRequestError(
        "invalid_request",
        "date must use YYYY-MM-DD",
        {httpStatus: 400},
    );
  }
  const [, yearText, monthText, dayText] = match;
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const candidate = new Date(Date.UTC(year, month - 1, day));
  if (candidate.getUTCFullYear() !== year ||
      candidate.getUTCMonth() !== month - 1 ||
      candidate.getUTCDate() !== day) {
    throw new VideoRequestError(
        "invalid_request",
        "date is not a calendar date",
        {httpStatus: 400},
    );
  }
  return {year, month, day};
}

function parseManagerTime(timeText) {
  const match = /^(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(String(timeText || ""));
  if (!match) {
    throw new VideoRequestError(
        "invalid_request",
        "time must use HH:mm or HH:mm:ss",
        {httpStatus: 400},
    );
  }
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  const second = match[3] === undefined ? 0 : Number(match[3]);
  if (hour > 23 || minute > 59 || second > 59) {
    throw new VideoRequestError(
        "invalid_request",
        "time is not a clock time",
        {httpStatus: 400},
    );
  }
  return {hour, minute, second};
}

function hasSameLocalParts(candidate, wanted) {
  const actual = israelParts(candidate);
  return actual.year === wanted.year &&
    actual.month === wanted.month &&
    actual.day === wanted.day &&
    actual.hour === wanted.hour &&
    actual.minute === wanted.minute &&
    actual.second === wanted.second;
}

function offsetAt(candidate) {
  const parts = israelParts(candidate);
  const localClockAsUtc = Date.UTC(
      parts.year,
      parts.month - 1,
      parts.day,
      parts.hour,
      parts.minute,
      parts.second,
  );
  return localClockAsUtc - candidate.getTime();
}

/**
 * Converts a manager-selected wall-clock time in Israel to an instant.  It
 * rejects skipped and duplicated DST clock readings; asking the manager to
 * choose an unambiguous instant is safer than silently downloading the wrong
 * recording.
 */
function israelLocalDateTimeToUtc(dateText, timeText) {
  const date = parseManagerDate(dateText);
  const time = parseManagerTime(timeText);
  const wanted = {...date, ...time};
  const localClockAsUtc = Date.UTC(
      wanted.year,
      wanted.month - 1,
      wanted.day,
      wanted.hour,
      wanted.minute,
      wanted.second,
  );

  // Israel only has two practical offsets, but sampling broadly makes this
  // robust to historical offset changes and to a future rule change.
  const offsets = new Set();
  for (let hours = -18; hours <= 18; hours += 1) {
    offsets.add(offsetAt(new Date(localClockAsUtc + (hours * 60 * 60 * 1000))));
  }
  const candidates = [...offsets]
      .map((offset) => new Date(localClockAsUtc - offset))
      .filter((candidate) => hasSameLocalParts(candidate, wanted));

  if (candidates.length !== 1) {
    throw new VideoRequestError(
        "invalid_request",
        candidates.length === 0 ?
          "The selected Israel time does not exist" :
          "The selected Israel time is ambiguous",
        {httpStatus: 400},
    );
  }
  return candidates[0];
}

module.exports = {
  ISRAEL_TIME_ZONE,
  israelDate,
  israelLocalDateTimeToUtc,
  israelParts,
  israelReservationSlot,
  parseManagerDate,
  parseManagerTime,
};
