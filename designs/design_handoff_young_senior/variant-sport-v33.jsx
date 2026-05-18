// VARIANT B v3.3 — Sport / clay (compact + bigger type)
//
// Built from feedback on v3.2:
//   • "header is too big" → hero collapsed to a single 52px strip (day toggle + menu)
//   • "next-up shown twice / user already knows" → next-up info removed entirely
//   • "today shown twice" → only the day-toggle shows today/tomorrow now (date dropped)
//   • "partner shown twice" → colored partner bar dropped; the selected chip in the
//     partner row IS the partner display, scaled up + highlighted
//   • "fonts still too small" → grid slot text 18px (was 15), hour labels 19px (was 17),
//     slots 64px tall (was 56). The freed header space pays for the bigger grid.

const sport33Styles = `
  .s33-root{
    --bg:#fff8f3; --surface:#ffffff; --ink:#1f1715; --ink-2:#5a3d33;
    --line:#e9d8c8; --line-2:#d9c3ad;
    --clay:#b04420; --clay-d:#8f3415; --clay-tint:#fbeadb; --clay-ink:#8f3415;
    --green:#0f5a3a; --green-tint:#dceee4;
    --past-bg:#f1e7dd; --past-ink:#9c8a7d;
    --warn:#c43a14;
    --shadow-mine: inset 0 -3px 0 rgba(0,0,0,0.22);

    width:380px;height:820px;background:var(--bg);color:var(--ink);
    font-family:"Heebo",system-ui,sans-serif;direction:rtl;
    display:flex;flex-direction:column;border:1px solid var(--line-2);
    border-radius:28px;overflow:hidden;position:relative;
  }
  .s33-root[data-theme="dark"]{
    --bg:#0e1413; --surface:#161e1c; --ink:#f6f1ea; --ink-2:#bdaea0;
    --line:#22302c; --line-2:#314642;
    --clay:#ff8a5c; --clay-d:#e06a3e; --clay-tint:#3a2017; --clay-ink:#ffc8a8;
    --green:#54c98c; --green-tint:#0f2a1f;
    --past-bg:#141a19; --past-ink:#5e6e69;
    --warn:#ffb877;
  }

  /* ── HERO ── one 52px strip: day toggle (with temp) + menu. Nothing else. */
  .s33-hero{padding:8px 14px;background:linear-gradient(180deg,var(--clay) 0%,var(--clay-d) 100%);color:#fff;position:relative;overflow:hidden;display:flex;align-items:center;gap:10px;min-height:52px}
  .s33-hero::after{content:"";position:absolute;inset:0;background:repeating-linear-gradient(0deg,rgba(255,255,255,0) 0,rgba(255,255,255,0) 22px,rgba(255,255,255,0.07) 22px,rgba(255,255,255,0.07) 23px);pointer-events:none}
  .s33-toggle{background:rgba(0,0,0,0.22);border-radius:10px;padding:3px;display:flex;gap:2px;flex:1;position:relative;z-index:1}
  .s33-toggle button{flex:1;border:none;background:transparent;color:#fff;padding:8px 10px;font-size:16px;font-weight:800;border-radius:8px;cursor:pointer;font-family:inherit;display:flex;align-items:center;justify-content:center;gap:8px;line-height:1;min-height:38px}
  .s33-toggle button.on{background:#fff;color:var(--clay-d)}
  .s33-toggle .wx{font-size:13px;font-weight:700;opacity:0.85;font-variant-numeric:tabular-nums}
  .s33-toggle .wx.warn{color:#ffd6a8}
  .s33-toggle button.on .wx.warn{color:var(--clay)}
  .s33-cap{display:flex;align-items:center;gap:5px;padding:0 4px;color:#fff;font-size:13px;font-weight:700;letter-spacing:0.03em;position:relative;z-index:1;white-space:nowrap}
  .s33-cap .pips{display:flex;gap:3px}
  .s33-cap .pip{width:7px;height:7px;border-radius:50%;background:rgba(255,255,255,0.28)}
  .s33-cap .pip.on{background:#fff}
  .s33-menu{width:40px;height:40px;border-radius:10px;background:rgba(0,0,0,0.22);border:none;color:#fff;font-size:18px;cursor:pointer;display:flex;align-items:center;justify-content:center;font-family:inherit;position:relative;z-index:1;flex-shrink:0}

  /* ── PARTNER ROW ── only place the partner appears. Selected chip is big + bold. */
  .s33-partners{display:flex;gap:8px;padding:12px 14px;overflow-x:auto;scrollbar-width:none;background:var(--surface);border-bottom:1px solid var(--line);align-items:center}
  .s33-partners::-webkit-scrollbar{display:none}
  .s33-partners .lbl{font-size:13px;color:var(--ink-2);font-weight:800;letter-spacing:0.04em;flex-shrink:0;padding-inline-end:2px}
  .s33-chip{padding:10px 14px;border-radius:10px;background:var(--clay-tint);border:1.5px solid transparent;font-size:16px;color:var(--clay-ink);font-weight:700;white-space:nowrap;cursor:pointer;font-family:inherit;display:inline-flex;align-items:center;gap:8px;min-height:44px;flex-shrink:0}
  .s33-chip .dot{width:8px;height:8px;border-radius:50%;background:var(--green);flex-shrink:0}
  .s33-chip.on{background:var(--clay);color:#fff;border-color:var(--clay-d);font-size:17px;font-weight:800;padding:11px 16px;box-shadow:var(--shadow-mine)}
  .s33-chip.on .dot{background:#fff;opacity:0.85}
  .s33-chip .av{width:24px;height:24px;border-radius:7px;background:var(--clay);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:13px;flex-shrink:0}
  .s33-chip.on .av{background:rgba(0,0,0,0.22);color:#fff}

  /* ── COURT HEADER ── */
  .s33-courthdr{display:grid;grid-template-columns:48px 1fr 1fr;padding:12px 14px 6px;font-size:13px;font-weight:800;color:var(--ink);text-transform:uppercase;letter-spacing:0.08em;background:var(--bg);gap:8px}
  .s33-courthdr > *{text-align:center}

  /* ── GRID — 64px slots, 18px text, 19px hour labels ── */
  .s33-grid{flex:1;overflow-y:auto;padding:0 14px 14px;position:relative}
  .s33-row{display:grid;grid-template-columns:48px 1fr 1fr;gap:8px;margin-bottom:8px;align-items:stretch}
  .s33-row .h{font-size:19px;color:var(--ink);display:flex;align-items:center;justify-content:center;font-weight:800;font-variant-numeric:tabular-nums}
  .s33-slot{min-height:64px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:18px;font-weight:700;line-height:1.2;text-align:center;cursor:pointer;border:none;font-family:inherit;padding:8px 10px;position:relative;overflow:hidden;transition:transform 0.08s;gap:6px}
  .s33-slot:active{transform:scale(0.97)}
  .s33-slot.free{background:var(--green);color:#fff;border:2px solid transparent}
  .s33-slot.free .lbl{font-weight:800;font-size:18px}
  .s33-slot.taken{background:var(--surface);color:var(--ink-2);border:2px solid var(--line);flex-direction:column;gap:2px}
  .s33-slot.taken .name{font-size:15px;font-weight:700;color:var(--ink-2);overflow:hidden;text-overflow:ellipsis;max-width:100%;white-space:nowrap}
  .s33-slot.mine{background:var(--clay);color:#fff;box-shadow:var(--shadow-mine);border:2px solid var(--clay-d);flex-direction:column;gap:1px}
  .s33-slot.mine .name{font-size:15px;opacity:0.95;font-weight:700}
  .s33-slot.mine .badge{font-size:12px;font-weight:800;letter-spacing:0.06em;text-transform:uppercase;opacity:0.9}
  .s33-slot.past{background:var(--past-bg);color:var(--past-ink);border:2px dashed var(--line-2);cursor:not-allowed;font-size:16px}
  .s33-slot.preview{background:var(--clay-tint);color:var(--clay-ink);border:2px solid var(--clay);font-weight:800;flex-direction:column;gap:2px;animation:s33pulse 0.9s ease-in-out infinite}
  .s33-slot.preview .lbl{font-size:18px;font-weight:800}
  .s33-slot.preview .cta{font-size:11px;font-weight:800;letter-spacing:0.06em;text-transform:uppercase;opacity:0.85}
  @keyframes s33pulse{0%,100%{box-shadow:0 0 0 0 rgba(176,68,32,0.4)}50%{box-shadow:0 0 0 6px rgba(176,68,32,0)}}

  /* CONFIRM BANNER */
  .s33-confirm{position:absolute;left:14px;right:14px;bottom:14px;background:var(--surface);border:2px solid var(--clay);border-radius:16px;padding:14px 16px;display:flex;flex-direction:column;gap:12px;box-shadow:0 12px 32px rgba(0,0,0,0.22);z-index:5;animation:s33up 0.22s ease-out}
  @keyframes s33up{from{transform:translateY(40px);opacity:0}to{transform:translateY(0);opacity:1}}
  .s33-confirm .info{display:flex;align-items:center;gap:12px;min-width:0}
  .s33-confirm .info .av{width:44px;height:44px;border-radius:12px;background:var(--clay);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:18px;flex-shrink:0}
  .s33-confirm .info .txt{flex:1;min-width:0}
  .s33-confirm .info .lbl{font-size:11px;color:var(--clay-ink);font-weight:800;letter-spacing:0.08em;text-transform:uppercase;display:block;margin-bottom:1px}
  .s33-confirm .info b{display:block;font-size:18px;font-weight:800;color:var(--ink);line-height:1.25}
  .s33-confirm .info b .with{color:var(--clay)}
  .s33-confirm .row{display:flex;gap:10px}
  .s33-confirm .btn{flex:1;padding:14px;border-radius:12px;border:none;font-family:inherit;font-size:16px;font-weight:800;cursor:pointer;min-height:52px}
  .s33-confirm .btn.cancel{background:transparent;color:var(--ink-2);border:2px solid var(--line-2);flex:0 0 auto;padding:14px 20px}
  .s33-confirm .btn.confirm{background:var(--clay);color:#fff;box-shadow:inset 0 -3px 0 rgba(0,0,0,0.18)}

  /* TOAST */
  .s33-toast{position:absolute;left:16px;right:16px;bottom:16px;padding:14px 18px;border-radius:12px;font-size:16px;font-weight:700;text-align:center;z-index:10;animation:s33up 0.2s ease-out}
  .s33-toast.good{background:var(--green);color:#fff}
  .s33-toast.warn{background:var(--clay);color:#fff}
  .s33-toast.info{background:var(--ink);color:var(--bg)}

  /* sheet */
  .s33-sheet{position:absolute;inset:0;background:rgba(31,23,21,0.55);display:flex;align-items:flex-end;z-index:20;animation:s33fade 0.18s ease-out}
  @keyframes s33fade{from{opacity:0}to{opacity:1}}
  .s33-sheet-card{background:var(--surface);width:100%;border-radius:22px 22px 0 0;padding:22px 20px 24px}
  .s33-sheet h3{margin:0 0 6px;font-size:22px;font-weight:800;color:var(--ink)}
  .s33-sheet .sub{font-size:15px;color:var(--ink-2);margin-bottom:18px;line-height:1.4}
  .s33-sheet-btn{width:100%;padding:16px;border-radius:12px;border:none;font-family:inherit;font-size:17px;font-weight:800;cursor:pointer;margin-bottom:10px;min-height:56px}
  .s33-sheet-btn.primary{background:var(--clay);color:#fff}
  .s33-sheet-btn.secondary{background:var(--surface);color:var(--ink);border:1.5px solid var(--line-2)}
`;

function VariantSportV33({ initialTheme = 'light' }) {
  const s = window.useBookingState();
  const [theme, setTheme] = React.useState(initialTheme);
  const [preview, setPreview] = React.useState(null);
  const [sheet, setSheet] = React.useState(null);

  const wx = { today: { temp: 28, warn: true }, tomorrow: { temp: 24, warn: false } };

  const recents = [
    { id: 'noa', available: true }, { id: 'dani', available: false },
    { id: 'yoav', available: true }, { id: 'rotem', available: true },
    { id: 'maya', available: false }, { id: 'tom', available: true },
  ];

  const usedEvenings = (() => {
    let n = 0;
    for (const day of ['today', 'tomorrow']) {
      for (const c of [1, 2]) {
        for (const h of [18, 19, 20]) {
          const slot = s.bookings[day]?.[c]?.[h];
          if (slot && (slot.a === 'me' || slot.b === 'me')) n++;
        }
      }
    }
    return Math.min(n, 3);
  })();

  const handleTap = (court, hour) => {
    const slot = s.slotAt(court, hour);
    if (s.isPast(hour)) return;
    if (slot && s.isMine(slot)) { setSheet({ kind: 'cancel', court, hour, slot }); return; }
    if (slot) { setSheet({ kind: 'taken', court, hour, slot }); return; }
    const key = `${court}-${hour}`;
    if (preview && preview.key === key) { s.book(court, hour); setPreview(null); return; }
    setPreview({ key, court, hour });
  };

  const confirmBooking = () => {
    if (!preview) return;
    s.book(preview.court, preview.hour);
    setPreview(null);
  };

  return (
    <>
      <style>{sport33Styles}</style>
      <div className="s33-root" data-theme={theme}>

        {/* HERO — single 52px strip: day toggle + weekly-cap pips + menu */}
        <div className="s33-hero">
          <div className="s33-toggle">
            <button className={s.day === 'today' ? 'on' : ''} onClick={() => s.setDay('today')}>
              <span>היום</span>
              <span className={`wx ${wx.today.warn ? 'warn' : ''}`}>{wx.today.temp}°</span>
            </button>
            <button className={s.day === 'tomorrow' ? 'on' : ''} onClick={() => s.setDay('tomorrow')}>
              <span>מחר</span>
              <span className={`wx ${wx.tomorrow.warn ? 'warn' : ''}`}>{wx.tomorrow.temp}°</span>
            </button>
          </div>
          <div className="s33-cap" title={`${usedEvenings} מתוך 3 ערבים בשבוע`}>
            <span>ערב {usedEvenings}/3</span>
            <div className="pips">
              {[0,1,2].map(i => <div key={i} className={`pip ${i<usedEvenings?'on':''}`}></div>)}
            </div>
          </div>
          <button className="s33-menu" onClick={() => setTheme(t => t === 'dark' ? 'light' : 'dark')} title="תפריט">
            {theme === 'dark' ? '☀' : '☾'}
          </button>
        </div>

        {/* PARTNER ROW — the ONLY place partner appears. Selected chip is enlarged. */}
        <div className="s33-partners">
          <span className="lbl">עם:</span>
          {recents.map(({ id, available }) => {
            const p = s.partnerObj(id);
            const on = s.partner === id;
            return (
              <button key={id} className={`s33-chip ${on ? 'on' : ''}`} onClick={() => s.setPartner(id)}>
                {on && <span className="av">{p.initial}</span>}
                {!on && available && <span className="dot"></span>}
                {p.name}
              </button>
            );
          })}
        </div>

        <div className="s33-courthdr"><div></div><div>מגרש 2</div><div>מגרש 1</div></div>

        <div className="s33-grid">
          {s.HOURS.map(hour => (
            <div key={hour} className="s33-row">
              <div className="h">{hour}:00</div>
              {[2, 1].map(court => {
                const slot = s.slotAt(court, hour);
                const past = s.isPast(hour);
                const mine = s.isMine(slot);
                const key = `${court}-${hour}`;
                const isPreview = preview && preview.key === key;
                let cls = 'free';
                let inner = <span className="lbl">פנוי</span>;
                if (isPreview) {
                  cls = 'preview';
                  inner = <><span className="lbl">{hour}:00</span><span className="cta">לחצ.י שוב</span></>;
                } else if (past) {
                  cls = 'past';
                  inner = <span>עבר</span>;
                } else if (mine) {
                  cls = 'mine';
                  const partner = s.partnerObj(slot.a === 'me' ? slot.b : slot.a);
                  inner = <><span className="badge">ההזמנה שלי</span><span className="name">עם {partner.short}</span></>;
                } else if (slot) {
                  cls = 'taken';
                  const a = s.partnerObj(slot.a);
                  const b = s.partnerObj(slot.b);
                  inner = <span className="name">{a.short} · {b.short}</span>;
                }
                return (
                  <button key={court} className={`s33-slot ${cls}`} onClick={() => handleTap(court, hour)}>
                    {inner}
                  </button>
                );
              })}
            </div>
          ))}
        </div>

        {preview && (
          <div className="s33-confirm">
            <div className="info">
              <div className="av">{s.partnerObj(s.partner)?.initial}</div>
              <div className="txt">
                <span className="lbl">אישור הזמנה</span>
                <b>{String(preview.hour).padStart(2,'0')}:00 · מגרש {preview.court} <span className="with">עם {s.partnerObj(s.partner)?.short}</span></b>
              </div>
            </div>
            <div className="row">
              <button className="btn cancel" onClick={() => setPreview(null)}>בטל</button>
              <button className="btn confirm" onClick={confirmBooking}>אשר הזמנה</button>
            </div>
          </div>
        )}

        {sheet && (
          <div className="s33-sheet" onClick={() => setSheet(null)}>
            <div className="s33-sheet-card" onClick={(e) => e.stopPropagation()}>
              <h3>{sheet.kind === 'cancel' ? 'לבטל את ההזמנה?' : 'המשבצת תפוסה'}</h3>
              <p className="sub">
                {sheet.kind === 'cancel'
                  ? `${sheet.hour}:00 במגרש ${sheet.court}. ביטול אפשרי עד 3 שעות לפני.`
                  : `${sheet.hour}:00 במגרש ${sheet.court}. אפשר להצטרף לרשימת המתנה.`}
              </p>
              {sheet.kind === 'cancel'
                ? <button className="s33-sheet-btn primary" onClick={() => { s.book(sheet.court, sheet.hour); setSheet(null); }}>כן, בטל הזמנה</button>
                : <button className="s33-sheet-btn primary" onClick={() => { s.showToast('נוספת לרשימת המתנה', 'good'); setSheet(null); }}>הוסף לרשימת המתנה</button>}
              <button className="s33-sheet-btn secondary" onClick={() => setSheet(null)}>סגור</button>
            </div>
          </div>
        )}

        {s.toast && <div className={`s33-toast ${s.toast.kind}`}>{s.toast.msg}</div>}
      </div>
    </>
  );
}

window.VariantSportV33 = VariantSportV33;
