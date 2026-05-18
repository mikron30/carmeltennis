// Shared state hook + sample data for all booking-grid variants.
// Each variant gets its own isolated copy via useBookingState().

const PARTNERS = [
  { id: 'noa',   name: 'נועה לוי',     short: 'נועה ל.',    initial: 'נ' },
  { id: 'dani',  name: 'דני כהן',      short: 'דני כ.',     initial: 'ד' },
  { id: 'yoav',  name: 'יואב בן שלום',  short: 'יואב ב.',    initial: 'י' },
  { id: 'rotem', name: 'רותם שמש',     short: 'רותם ש.',    initial: 'ר' },
  { id: 'maya',  name: 'מיה קליין',    short: 'מיה ק.',     initial: 'מ' },
  { id: 'tom',   name: 'תום לוי',      short: 'תום ל.',     initial: 'ת' },
  { id: 'gal',   name: 'גל שניר',      short: 'גל ש.',      initial: 'ג' },
  { id: 'shir',  name: 'שיר אורן',     short: 'שיר א.',     initial: 'ש' },
  { id: 'liron', name: 'ליאור פינטו',   short: 'ליאור פ.',   initial: 'ל' },
];

const ME = { id: 'me', name: 'מיכאל רון', short: 'אני', initial: 'מ' };

const HOURS = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
const NOW_HOUR = 13; // pretend current hour for "now-line" placement
const NOW_MINUTE = 42;

// initial reservations: { [day]: { [court]: { [hour]: {a, b} } } }
function makeInitialBookings() {
  return {
    today: {
      1: {
        11: { a: 'rotem', b: 'yoav' },
        13: { a: 'me',    b: 'noa'  },
        15: { a: 'tom',   b: 'gal'  },
        18: { a: 'shir',  b: 'maya' },
        19: { a: 'dani',  b: 'liron' },
      },
      2: {
        11: { a: 'maya',  b: 'tom'  },
        16: { a: 'shir',  b: 'rotem' },
        18: { a: 'gal',   b: 'yoav' },
      },
    },
    tomorrow: {
      1: {
        13: { a: 'dani',  b: 'liron' },
        17: { a: 'maya',  b: 'tom'   },
        19: { a: 'rotem', b: 'shir'  },
      },
      2: {
        15: { a: 'noa',   b: 'gal'   },
        18: { a: 'tom',   b: 'yoav'  },
      },
    },
  };
}

function useBookingState() {
  const [day, setDay]       = React.useState('today');
  const [partner, setPartner] = React.useState('noa');
  const [bookings, setBookings] = React.useState(makeInitialBookings);
  const [toast, setToast]   = React.useState(null);

  const showToast = React.useCallback((msg, kind = 'info') => {
    setToast({ msg, kind, id: Date.now() });
    setTimeout(() => setToast(t => (t && t.kind === kind ? null : t)), 2400);
  }, []);

  const isPast = (hour) => day === 'today' && hour < NOW_HOUR;

  const slotAt = (court, hour) =>
    bookings[day]?.[court]?.[hour] || null;

  const isMine = (slot) =>
    !!slot && (slot.a === 'me' || slot.b === 'me');

  const book = (court, hour) => {
    if (isPast(hour)) return;
    const existing = slotAt(court, hour);
    if (existing) {
      if (!isMine(existing)) {
        showToast('הזמנה זו שייכת לחברים אחרים', 'warn');
        return;
      }
      // cancel
      setBookings(prev => {
        const next = structuredClone(prev);
        delete next[day][court][hour];
        return next;
      });
      showToast('ההזמנה בוטלה', 'info');
      return;
    }
    if (!partner) {
      showToast('בחר/י שותף/ה לפני ההזמנה', 'warn');
      return;
    }
    setBookings(prev => {
      const next = structuredClone(prev);
      next[day] = next[day] || {};
      next[day][court] = next[day][court] || {};
      next[day][court][hour] = { a: 'me', b: partner };
      return next;
    });
    showToast('הוזמן', 'good');
  };

  const partnerObj = (id) =>
    id === 'me' ? ME : PARTNERS.find(p => p.id === id);

  return {
    day, setDay,
    partner, setPartner,
    bookings, slotAt, isMine, isPast, book,
    toast, showToast,
    partnerObj,
    HOURS, NOW_HOUR, NOW_MINUTE,
    PARTNERS, ME,
  };
}

window.useBookingState = useBookingState;
window.PARTNERS = PARTNERS;
window.ME = ME;
window.HOURS = HOURS;
window.NOW_HOUR = NOW_HOUR;
window.NOW_MINUTE = NOW_MINUTE;
