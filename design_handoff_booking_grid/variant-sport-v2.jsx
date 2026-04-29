// VARIANT B v2 — Sport / clay, with UX upgrades:
// • Confirm-on-second-tap (preview → commit)
// • Pending/writing state with rollback animation
// • Live weekly-cap counter (18-20h limit) with progress bar
// • Busy-hour heat shading behind popular hours
// • Weather strip per day (temp + heat warning)
// • Locked slots within 3h cancel window get a lock icon
// • Waitlist on taken slots
// • Recurring + "same as last week" shortcuts in partner card
// • Hero adapts to time-of-day with live next-up info

const sport2Styles = `
  .s2-root{
    width:380px;height:820px;background:#fff8f3;color:#1f1715;
    font-family:"Heebo",system-ui,sans-serif;direction:rtl;
    display:flex;flex-direction:column;border:1px solid #e9d8c8;
    border-radius:28px;overflow:hidden;position:relative;
  }
  .s2-hero{padding:16px 20px 14px;background:linear-gradient(180deg,#c0532b 0%,#a8431f 100%);color:#fff;position:relative;overflow:hidden}
  .s2-hero::after{content:"";position:absolute;inset:0;background:repeating-linear-gradient(0deg,rgba(255,255,255,0) 0,rgba(255,255,255,0) 22px,rgba(255,255,255,0.05) 22px,rgba(255,255,255,0.05) 23px);pointer-events:none}
  .s2-hero .row1{display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;position:relative;z-index:1}
  .s2-hero .menu{display:flex;flex-direction:column;gap:4px;cursor:pointer}
  .s2-hero .menu span{display:block;width:22px;height:1.5px;background:#fff}
  .s2-hero .me{display:flex;align-items:center;gap:8px}
  .s2-hero .me .av{width:30px;height:30px;border-radius:50%;background:rgba(255,255,255,0.2);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px}
  .s2-hero .me b{font-size:13px}
  .s2-day{font-weight:800;font-size:30px;letter-spacing:-0.02em;line-height:1;margin:0;position:relative;z-index:1}
  .s2-nextup{font-size:11.5px;opacity:0.92;margin-top:3px;position:relative;z-index:1;font-weight:500}
  .s2-nextup b{font-weight:800}
  .s2-day-sub{display:flex;align-items:end;justify-content:space-between;margin-top:10px;position:relative;z-index:1;gap:8px}
  .s2-toggle{background:rgba(0,0,0,0.18);border-radius:8px;padding:3px;display:flex;gap:2px;flex-shrink:0}
  .s2-toggle button{border:none;background:transparent;color:#fff;padding:6px 10px;font-size:11px;font-weight:700;border-radius:6px;cursor:pointer;font-family:inherit;display:flex;flex-direction:column;align-items:center;gap:1px;line-height:1}
  .s2-toggle button.on{background:#fff;color:#a8431f}
  .s2-toggle .wx{font-size:9px;font-weight:600;opacity:0.85}
  .s2-toggle .wx.warn{color:#ffd6a8}
  .s2-toggle button.on .wx.warn{color:#c0532b}
  .s2-bar{padding:10px 20px;background:#fff;border-bottom:1px solid #f0e3d4;display:flex;align-items:center;gap:10px}
  .s2-bar .av{width:34px;height:34px;border-radius:10px;background:#fbeadb;color:#a8431f;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:14px;flex-shrink:0}
  .s2-bar .who{flex:1;min-width:0}
  .s2-bar .who small{display:block;font-size:9px;letter-spacing:0.12em;text-transform:uppercase;color:#a8431f;font-weight:700}
  .s2-bar .who b{font-weight:700;font-size:13px;display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .s2-bar .actions{display:flex;gap:4px;flex-shrink:0}
  .s2-bar .ico-btn{width:32px;height:32px;border-radius:8px;background:#fbeadb;border:none;color:#a8431f;font-weight:700;cursor:pointer;font-family:inherit;display:flex;align-items:center;justify-content:center;font-size:14px}
  .s2-bar .ico-btn:hover{background:#f5dec5}
  .s2-cap{padding:8px 20px 10px;background:#fff;border-bottom:1px solid #f0e3d4;display:flex;align-items:center;gap:10px;font-size:11px}
  .s2-cap .lbl{color:#7a5447;flex-shrink:0;font-weight:600}
  .s2-cap .lbl b{color:#1f1715}
  .s2-cap .track{flex:1;height:5px;background:#f0e3d4;border-radius:99px;overflow:hidden;position:relative}
  .s2-cap .fill{position:absolute;inset-inline-end:0;top:0;bottom:0;background:linear-gradient(90deg,#c0532b,#1f6f4a);border-radius:99px;transition:width 0.3s}
  .s2-cap .pips{display:flex;gap:3px}
  .s2-cap .pip{width:7px;height:7px;border-radius:50%;background:#f0e3d4}
  .s2-cap .pip.on{background:#c0532b}
  .s2-recents{display:flex;gap:6px;padding:9px 20px;overflow-x:auto;scrollbar-width:none;background:#fff;border-bottom:1px solid #f0e3d4}
  .s2-recents::-webkit-scrollbar{display:none}
  .s2-chip{padding:5px 11px;border-radius:6px;background:#fbeadb;border:none;font-size:11px;color:#a8431f;font-weight:600;white-space:nowrap;cursor:pointer;font-family:inherit;display:inline-flex;align-items:center;gap:4px}
  .s2-chip.on{background:#1f1715;color:#fff}
  .s2-chip .dot{width:5px;height:5px;border-radius:50%;background:#1f6f4a;flex-shrink:0}
  .s2-chip.on .dot{background:#7fbf94}
  .s2-courthdr{display:grid;grid-template-columns:38px 1fr 1fr;padding:10px 20px 4px;font-size:10px;font-weight:800;color:#1f1715;text-transform:uppercase;letter-spacing:0.06em}
  .s2-courthdr > *{text-align:center}
  .s2-grid{flex:1;overflow-y:auto;padding:0 20px 12px;position:relative}
  .s2-row{display:grid;grid-template-columns:38px 1fr 1fr;gap:6px;margin-bottom:5px;align-items:stretch;position:relative}
  .s2-row.busy::before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,rgba(192,83,43,0) 0%,rgba(192,83,43,0.05) 50%,rgba(192,83,43,0.08) 100%);border-radius:8px;pointer-events:none;z-index:0}
  .s2-row .h{font-size:12px;color:#7a5447;display:flex;align-items:center;justify-content:center;font-weight:700;font-variant-numeric:tabular-nums;position:relative;z-index:1}
  .s2-row .h .flame{font-size:8px;color:#c0532b;margin-inline-start:2px}
  .s2-slot{min-height:40px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:600;line-height:1.2;text-align:center;cursor:pointer;border:none;font-family:inherit;padding:6px 8px;position:relative;overflow:hidden;z-index:1;transition:transform 0.08s}
  .s2-slot:active{transform:scale(0.97)}
  .s2-slot.free{background:#1f6f4a;color:#fff}
  .s2-slot.free::before{content:"";position:absolute;inset:0;background:repeating-linear-gradient(45deg,rgba(255,255,255,0) 0,rgba(255,255,255,0) 6px,rgba(255,255,255,0.06) 6px,rgba(255,255,255,0.06) 7px);pointer-events:none}
  .s2-slot.free b{position:relative;z-index:1}
  .s2-slot.taken{background:#fff;color:#7a5447;border:1.5px solid #f0e3d4;flex-direction:column;gap:1px}
  .s2-slot.taken .wait{font-size:9px;color:#c0532b;font-weight:700;display:none}
  .s2-slot.taken:hover .wait{display:block}
  .s2-slot.mine{background:#c0532b;color:#fff;box-shadow:inset 0 -3px 0 rgba(0,0,0,0.18)}
  .s2-slot.mine::after{content:"·שלי";font-size:9px;opacity:0.85;margin-inline-start:4px;font-weight:800}
  .s2-slot.mine.locked::after{content:"·נעול";opacity:0.95}
  .s2-slot.past{background:#f7efe7;color:#c8b8ac;border:1.5px solid #f0e3d4;cursor:not-allowed}
  .s2-slot.preview{background:#fbeadb;color:#a8431f;border:2px dashed #c0532b;animation:s2pulse 1s ease-in-out infinite}
  .s2-slot.preview::after{content:"·אישור?";font-weight:800;margin-inline-start:4px}
  @keyframes s2pulse{0%,100%{box-shadow:0 0 0 0 rgba(192,83,43,0.4)}50%{box-shadow:0 0 0 6px rgba(192,83,43,0)}}
  .s2-slot.pending{background:#1f6f4a;color:#fff;opacity:0.65;cursor:wait;position:relative}
  .s2-slot.pending::before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,transparent 0%,rgba(255,255,255,0.25) 50%,transparent 100%);animation:s2shimmer 1.2s infinite;pointer-events:none}
  @keyframes s2shimmer{from{transform:translateX(100%)}to{transform:translateX(-100%)}}
  .s2-slot.failed{animation:s2shake 0.4s ease-out}
  @keyframes s2shake{0%,100%{transform:translateX(0)}20%{transform:translateX(-4px)}40%{transform:translateX(4px)}60%{transform:translateX(-3px)}80%{transform:translateX(3px)}}
  .s2-now{grid-column:1/-1;display:flex;align-items:center;gap:8px;font-size:9.5px;color:#c0532b;font-weight:800;letter-spacing:0.06em;margin:3px 0;text-transform:uppercase;position:relative;z-index:2}
  .s2-now::before,.s2-now::after{content:"";flex:1;height:2px;background:#c0532b;opacity:0.5}
  .s2-toast{position:absolute;left:20px;right:20px;bottom:14px;padding:10px 14px;border-radius:10px;font-size:12px;font-weight:700;text-align:center;z-index:10;animation:s2slide 0.2s ease-out}
  @keyframes s2slide{from{transform:translateY(8px);opacity:0}to{transform:translateY(0);opacity:1}}
  .s2-toast.good{background:#1f6f4a;color:#fff}
  .s2-toast.info{background:#1f1715;color:#fff}
  .s2-toast.warn{background:#c0532b;color:#fff}
  .s2-sheet{position:absolute;inset:0;background:rgba(31,23,21,0.5);backdrop-filter:blur(2px);display:flex;align-items:flex-end;z-index:20;animation:s2fade 0.18s ease-out}
  @keyframes s2fade{from{opacity:0}to{opacity:1}}
  .s2-sheet-card{background:#fff;width:100%;border-radius:20px 20px 0 0;padding:18px 20px 22px;animation:s2up 0.22s ease-out}
  @keyframes s2up{from{transform:translateY(40px)}to{transform:translateY(0)}}
  .s2-sheet h3{margin:0 0 4px;font-size:18px;font-weight:800}
  .s2-sheet .sub{font-size:12px;color:#7a5447;margin-bottom:14px}
  .s2-sheet-opt{display:flex;align-items:center;gap:10px;padding:10px 0;border-top:1px solid #f0e3d4;cursor:pointer}
  .s2-sheet-opt:first-of-type{border-top:none}
  .s2-sheet-opt .ic{width:32px;height:32px;border-radius:10px;background:#fbeadb;color:#a8431f;display:flex;align-items:center;justify-content:center;font-size:14px;font-weight:800;flex-shrink:0}
  .s2-sheet-opt .lbl{flex:1}
  .s2-sheet-opt .lbl b{display:block;font-size:13px;font-weight:700}
  .s2-sheet-opt .lbl small{font-size:11px;color:#7a5447}
  .s2-sheet-opt .chev{color:#c8b8ac}
`;

function VariantSportV2() {
  const s = useBookingState();
  const [preview, setPreview] = React.useState(null);
  const [pending, setPending] = React.useState(null);
  const [failed, setFailed] = React.useState(null);
  const [sheet, setSheet]   = React.useState(null);

  const recents = [
    { id:'noa',   available:true },
    { id:'dani',  available:false },
    { id:'yoav',  available:true },
    { id:'rotem', available:true },
    { id:'maya',  available:false },
    { id:'tom',   available:true },
  ];

  // weekly evening cap (18-20h)
  const usedEvenings = (() => {
    let n = 0;
    for (const day of ['today','tomorrow']) {
      for (const c of [1,2]) {
        for (const h of [18,19,20]) {
          const slot = s.bookings[day]?.[c]?.[h];
          if (slot && (slot.a==='me'||slot.b==='me')) n++;
        }
      }
    }
    return Math.min(n, 3);
  })();

  // busy hours (mock: based on # bookings across both days)
  const busyHours = new Set([13, 18, 19]);

  // weather per day (mock)
  const wx = {
    today:    { temp:28, warn:true,  label:'זהירות' },
    tomorrow: { temp:24, warn:false, label:'נוח' },
  };

  const dayLabel = s.day === 'today' ? 'היום' : 'מחר';
  const dateStr  = s.day === 'today' ? 'ראשון 27.4' : 'שני 28.4';

  // hero "next up" line
  const myNext = (() => {
    for (const h of s.HOURS) {
      for (const c of [1,2]) {
        const slot = s.bookings[s.day]?.[c]?.[h];
        if (slot && (slot.a==='me'||slot.b==='me') && !s.isPast(h)) {
          const partner = s.partnerObj(slot.a==='me'?slot.b:slot.a);
          const hoursAway = (s.day==='today') ? h - s.NOW_HOUR : h + (24-s.NOW_HOUR);
          return { hour:h, court:c, partner, hoursAway };
        }
      }
    }
    return null;
  })();

  const isLocked = (hour) => {
    if (s.day !== 'today') return false;
    return hour - s.NOW_HOUR <= 3 && hour - s.NOW_HOUR > 0;
  };

  const handleSlotTap = (court, hour) => {
    const slot = s.slotAt(court, hour);
    const past = s.isPast(hour);
    if (past) return;

    // mine: confirm cancel via sheet (also check 3h lock)
    if (slot && s.isMine(slot)) {
      if (isLocked(hour)) {
        s.showToast('לא ניתן לבטל פחות מ-3 שעות לפני', 'warn');
        return;
      }
      setSheet({ kind:'cancel', court, hour, slot });
      return;
    }
    // someone else's: offer waitlist
    if (slot) {
      setSheet({ kind:'waitlist', court, hour, slot });
      return;
    }
    // free: confirm-on-second-tap
    const key = `${court}-${hour}`;
    if (preview && preview.key === key) {
      // commit
      setPreview(null);
      setPending(key);
      // simulate latency
      setTimeout(() => {
        // 1-in-12 simulated failure
        if (Math.random() < 0.08) {
          setPending(null);
          setFailed(key);
          s.showToast('נכשל — נסה שוב', 'warn');
          setTimeout(() => setFailed(null), 500);
        } else {
          setPending(null);
          s.book(court, hour);
        }
      }, 700);
      return;
    }
    setPreview({ key, court, hour });
    setTimeout(() => setPreview(p => (p && p.key === key ? null : p)), 3500);
  };

  const sheetClose = () => setSheet(null);
  const sheetCancel = () => {
    if (sheet?.kind === 'cancel') {
      s.book(sheet.court, sheet.hour); // toggles off since it's mine
    } else if (sheet?.kind === 'waitlist') {
      s.showToast('נוספת לרשימת המתנה', 'good');
    }
    sheetClose();
  };

  return (
    <>
      <style>{sport2Styles}</style>
      <div className="s2-root">
        <div className="s2-hero">
          <div className="row1">
            <div className="menu"><span></span><span></span><span></span></div>
            <div className="me"><div className="av">מ</div><b>מיכאל רון</b></div>
          </div>
          <h2 className="s2-day">{dayLabel}</h2>
          {myNext ? (
            <div className="s2-nextup">
              המגרש שלך · <b>{String(myNext.hour).padStart(2,'0')}:00</b> עם <b>{myNext.partner.short}</b>
              {' '}· מגרש {myNext.court}
            </div>
          ) : (
            <div className="s2-nextup">אין לך הזמנה {dayLabel} — לחץ על משבצת ירוקה</div>
          )}
          <div className="s2-day-sub">
            <span style={{fontSize:'11px',opacity:0.85}}>{dateStr} · 13:42</span>
            <div className="s2-toggle">
              <button className={s.day==='today'?'on':''} onClick={()=>s.setDay('today')}>
                <span>היום</span>
                <span className={`wx ${wx.today.warn?'warn':''}`}>{wx.today.temp}° · {wx.today.label}</span>
              </button>
              <button className={s.day==='tomorrow'?'on':''} onClick={()=>s.setDay('tomorrow')}>
                <span>מחר</span>
                <span className={`wx ${wx.tomorrow.warn?'warn':''}`}>{wx.tomorrow.temp}° · {wx.tomorrow.label}</span>
              </button>
            </div>
          </div>
        </div>

        <div className="s2-bar">
          <div className="av">{s.partnerObj(s.partner)?.initial}</div>
          <div className="who">
            <small>שותפ.ה</small>
            <b>{s.partnerObj(s.partner)?.name}</b>
          </div>
          <div className="actions">
            <button className="ico-btn" title="כמו בשבוע שעבר" onClick={()=>{
              s.showToast('שוחזר: נועה לוי · ראשון 18:00', 'info');
            }}>↻</button>
            <button className="ico-btn" title="הזמנה קבועה" onClick={()=>{
              s.showToast('הזמנה קבועה — בקרוב', 'info');
            }}>📌</button>
            <button className="ico-btn" title="החלף" onClick={()=>{
              const idx = s.PARTNERS.findIndex(p=>p.id===s.partner);
              const next = s.PARTNERS[(idx+1) % s.PARTNERS.length];
              s.setPartner(next.id);
            }}>↔</button>
          </div>
        </div>

        <div className="s2-cap">
          <span className="lbl">ערב 18-20: <b>{usedEvenings}</b>/3 השבוע</span>
          <div className="track"><div className="fill" style={{width:`${(usedEvenings/3)*100}%`}}></div></div>
          <div className="pips">
            {[0,1,2].map(i => <div key={i} className={`pip ${i<usedEvenings?'on':''}`}></div>)}
          </div>
        </div>

        <div className="s2-recents">
          {recents.map(({id,available})=>{
            const p = s.partnerObj(id);
            return (
              <button key={id} className={`s2-chip ${s.partner===id?'on':''}`} onClick={()=>s.setPartner(id)}>
                {available && <span className="dot" title="זמין/ה היום"></span>}
                {p.short}
              </button>
            );
          })}
        </div>

        <div className="s2-courthdr"><div></div><div>מגרש 2</div><div>מגרש 1</div></div>

        <div className="s2-grid">
          {s.HOURS.map(h => {
            const showNow = s.day==='today' && h===s.NOW_HOUR+1;
            const busy = busyHours.has(h);
            return (
              <React.Fragment key={h}>
                {showNow && <div className="s2-now">— עכשיו 13:42 —</div>}
                <div className={`s2-row ${busy?'busy':''}`}>
                  <div className="h">
                    {String(h).padStart(2,'0')}
                    {busy && <span className="flame" title="שעה עמוסה">●</span>}
                  </div>
                  {[2,1].map(court=>{
                    const slot = s.slotAt(court,h);
                    const past = s.isPast(h);
                    const mine = s.isMine(slot);
                    const key = `${court}-${h}`;
                    const isPreview = preview?.key === key;
                    const isPending = pending === key;
                    const isFailed  = failed === key;
                    const locked = mine && isLocked(h);

                    let cls='free', label=<b>פנוי</b>;
                    if (slot) {
                      cls = mine?(locked?'mine locked':'mine'):'taken';
                      const a = s.partnerObj(slot.a)?.short;
                      const b = s.partnerObj(slot.b)?.short;
                      if (mine) {
                        label = slot.a==='me' ? b : a;
                      } else {
                        label = (
                          <>
                            <div>{a} · {b}</div>
                            <div className="wait">+ הוסף להמתנה</div>
                          </>
                        );
                      }
                    } else if (past) { cls='past'; label='—'; }
                    if (isPreview) cls = 'preview';
                    if (isPending) cls = 'pending';
                    if (isFailed)  cls += ' failed';

                    return (
                      <button key={court} className={`s2-slot ${cls}`} onClick={()=>handleSlotTap(court,h)}>
                        {label}
                      </button>
                    );
                  })}
                </div>
              </React.Fragment>
            );
          })}
        </div>

        {s.toast && <div className={`s2-toast ${s.toast.kind}`}>{s.toast.msg}</div>}

        {sheet && (
          <div className="s2-sheet" onClick={sheetClose}>
            <div className="s2-sheet-card" onClick={e=>e.stopPropagation()}>
              {sheet.kind==='cancel' ? (
                <>
                  <h3>לבטל את ההזמנה?</h3>
                  <div className="sub">{String(sheet.hour).padStart(2,'0')}:00 · מגרש {sheet.court}</div>
                  <div className="s2-sheet-opt" onClick={sheetCancel}>
                    <div className="ic">✕</div>
                    <div className="lbl"><b>בטל הזמנה</b><small>תישלח התראה לשותפ.ה</small></div>
                    <div className="chev">›</div>
                  </div>
                  <div className="s2-sheet-opt" onClick={()=>{sheetClose();s.showToast('שותפ.ה הוחלפ.ה — בקרוב','info');}}>
                    <div className="ic">↔</div>
                    <div className="lbl"><b>החלף שותפ.ה במקום</b><small>שמור על המשבצת</small></div>
                    <div className="chev">›</div>
                  </div>
                </>
              ) : (
                <>
                  <h3>המשבצת תפוסה</h3>
                  <div className="sub">{s.partnerObj(sheet.slot.a)?.short} · {s.partnerObj(sheet.slot.b)?.short}</div>
                  <div className="s2-sheet-opt" onClick={sheetCancel}>
                    <div className="ic">⏱</div>
                    <div className="lbl"><b>הוסף לרשימת המתנה</b><small>נודיע אם מתפנה</small></div>
                    <div className="chev">›</div>
                  </div>
                  <div className="s2-sheet-opt" onClick={()=>{sheetClose();s.showToast('הצעה נשלחה לשותפ.ה','good');}}>
                    <div className="ic">✦</div>
                    <div className="lbl"><b>שלח הצעה לשעה אחרת</b><small>הצע 17:00 או 20:00 לשותפ.ה</small></div>
                    <div className="chev">›</div>
                  </div>
                </>
              )}
            </div>
          </div>
        )}
      </div>
    </>
  );
}

window.VariantSportV2 = VariantSportV2;
