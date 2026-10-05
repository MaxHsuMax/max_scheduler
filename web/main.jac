"""Planner web app: a month calendar with event search.

Type in the search bar and the square holding the nearest upcoming match is
selected, jumping to its month if needed. Nothing is selected when no upcoming
event matches.
"""

import from server.main {
    EventView,
    get_events,
    add_event,
    set_done,
    delete_event,
    search_events
}

glob MONTHS: list[str] = [
         "January",
         "February",
         "March",
         "April",
         "May",
         "June",
         "July",
         "August",
         "September",
         "October",
         "November",
         "December"
     ],
     WEEKDAYS: list[str] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

glob CSS: str = """
body { margin: 0; background: #0b0c0f; color: #fff; font: 15px/1.4 system-ui, sans-serif; }
button, input { font: inherit; color: #fff; }
button { cursor: pointer; border: 0; border-radius: 8px; background: #262a34; padding: 8px 12px; }
button:hover { background: #313643; }
input { background: #1d2027; border: 1px solid #353945; border-radius: 8px; padding: 8px 10px; color-scheme: dark; }
input[type=checkbox] { accent-color: #fff; width: 16px; height: 16px; }
input::placeholder { color: #fff; opacity: 0.55; }
:focus-visible { outline: 2px solid #fff; outline-offset: 2px; }
h1, h2 { margin: 0; font-weight: 600; }
h1 { font-size: 18px; }
h2 { font-size: 26px; }
.page { max-width: 1180px; margin: 0 auto; padding: 24px; }
.top, .nav { display: flex; align-items: center; gap: 12px; margin-bottom: 20px; }
.top { justify-content: space-between; }
.search { width: min(340px, 60vw); }
.nav h2 { min-width: 250px; }
.main { display: grid; grid-template-columns: minmax(0, 1fr) 320px; gap: 24px; align-items: start; }
.grid { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 6px; }
.weekday { padding: 0 8px 4px; font-size: 13px; opacity: 0.7; }
.cell { aspect-ratio: 1; display: flex; flex-direction: column; gap: 3px; padding: 8px; overflow: hidden; text-align: left; border-radius: 8px; background: #181a20; font-variant-numeric: tabular-nums; }
.cell:hover { background: #20232b; }
.blank { background: #101115; }
.blank:hover { background: #101115; }
.today { background: #262a34; }
.today .num { font-weight: 700; }
.selected, .selected:hover { background: #3a3f4d; box-shadow: inset 0 0 0 2px #fff; }
.peek, .more { font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.peek { background: rgba(255, 255, 255, 0.08); border-radius: 4px; padding: 1px 5px; }
.more { opacity: 0.7; }
.finished { text-decoration: line-through; opacity: 0.55; }
.panel { background: #14161b; border-radius: 12px; padding: 18px; }
.panel h2 { font-size: 18px; margin-bottom: 12px; }
.panel p { margin: 0 0 12px; opacity: 0.7; }
.event { display: flex; align-items: center; gap: 10px; padding: 7px 0; font-variant-numeric: tabular-nums; }
.event label { flex: 1; display: flex; align-items: center; gap: 10px; cursor: pointer; }
.add { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 12px; }
.add input[type=text] { flex: 1 1 100%; }
.add input[type=time] { flex: 1; }
@media (max-width: 860px) {
    .main { grid-template-columns: 1fr; }
    .page { padding: 14px; }
    .cell { padding: 5px; }
    .peek { display: none; }
}
""";

def pad(n: int) -> str {
    return "0" + str(n) if n < 10 else str(n);
}

def iso(year: int, month: int, day: int) -> str {
    return str(year) + "-" + pad(month) + "-" + pad(day);
}

"""One calendar square: the day number and a peek at its first events."""
def DayCell(
    day: int,
    date: str,
    events: list[EventView],
    isToday: bool,
    isSelected: bool,
    onPick: Callable[[str], None]
) -> JsxElement {
    style = "cell"
        + (" today" if isToday else "")
        + (" selected" if isSelected else "");
    more = len(events) - 2;

    <button type="button" className={style} onClick={lambda { onPick(date); }}>
        <span className="num">{day}</span>
        {[
            <span key={e.id} className={"peek finished" if e.done else "peek"}>
                {e.time + " " + e.title}
            </span> for e in events[:2]
        ]}
        {more > 0 and <span className="more">{"+" + str(more) + " more"}</span>}
    </button>
}

"""A readable heading for an ISO date, e.g. "Tue, October 6"."""
def heading(date: str) -> str {
    month = int(date[5:7]);
    day = int(date[8:10]);
    weekday = int(new(Date, int(date[0:4]), month - 1, day).getDay());
    return WEEKDAYS[weekday] + ", " + MONTHS[month - 1] + " " + str(day);
}

def:pub app -> JsxElement {
    has events: list[EventView] = [],
        offset: int = 0,
        selected: str = "",
        query: str = "",
        title: str = "",
        time: str = "09:00";

    # The month on screen is `offset` months away from the current one.
    now = new(Date);
    thisYear = int(now.getFullYear());
    thisMonth = int(now.getMonth()) + 1;
    today = iso(thisYear, thisMonth, int(now.getDate()));
    first = new(Date, thisYear, thisMonth - 1 + offset, 1);
    year = int(first.getFullYear());
    month = int(first.getMonth()) + 1;
    blanks = int(first.getDay());
    days = int(new(Date, year, month, 0).getDate());
    trailing = (7 - (blanks + days) % 7) % 7;
    dayEvents = [
        e
        for e in events
        if e.date == selected
    ];

    async can with entry {
        selected = today;
        events = await get_events();
    }

    async def search(text: str) {
        query = text;
        if not text.strip() {
            return;
        }
        hit = await search_events(text, today);
        if query != text {
            return;
        }
        if hit is None {
            selected = "";
            return;
        }
        selected = hit.date;
        offset = (int(hit.date[0:4]) - thisYear) * 12 + int(hit.date[5:7]) - thisMonth;
    }

    async def add(e: FormEvent) {
        e.preventDefault();
        if not title.strip() or not time {
            return;
        }
        await add_event(title, selected, time);
        title = "";
        events = await get_events();
    }

    async def toggle(event: EventView) {
        await set_done(event.id, not event.done);
        events = await get_events();
    }

    async def remove(event: EventView) {
        await delete_event(event.id);
        events = await get_events();
    }

    <div className="page">
        <style>{CSS}</style>
        <header className="top">
            <h1>Planner</h1>
            <input
                className="search"
                type="search"
                placeholder="Search events"
                aria-label="Search events"
                value={query}
                onChange={lambda (e: ChangeEvent) { search(e.target.value); }}
            />
        </header>
        <div className="nav">
            <h2>{MONTHS[month - 1] + " " + str(year)}</h2>
            <button
                type="button"
                aria-label="Previous month"
                onClick={lambda { offset = offset - 1; }}
            >
                {"‹"}
            </button>
            <button
                type="button"
                aria-label="Next month"
                onClick={lambda { offset = offset + 1; }}
            >
                {"›"}
            </button>
            <button
                type="button"
                onClick={lambda {
                    offset = 0;
                    selected = today;
                }}
            >
                Today
            </button>
        </div>
        <div className="main">
            <div className="grid">
                {[<div key={w} className="weekday">{w}</div> for w in WEEKDAYS]}{[
                    <div key={"before" + str(i)} className="cell blank"></div>
                    for i in range(blanks)
                ]}{[
                    <DayCell
                        key={d}
                        day={d}
                        date={iso(year, month, d)}
                        events={[
                            e
                            for e in events
                            if e.date == iso(year, month, d)
                        ]}
                        isToday={iso(year, month, d) == today}
                        isSelected={iso(year, month, d) == selected}
                        onPick={lambda (date: str) { selected = date; }}
                    /> for d in range(1, days + 1)
                ]}{[
                    <div key={"after" + str(i)} className="cell blank"></div>
                    for i in range(trailing)
                ]}
            </div>
            <aside className="panel">
                {if not selected {
                    <p>Select a day to see its events.</p>
                } else {
                    <h2>{heading(selected)}</h2>
                    if not dayEvents {
                        <p>Nothing planned.</p>
                    }
                    for e in dayEvents {
                        <div key={e.id} className="event">
                            <label className={"finished" if e.done else ""}>
                                <input
                                    type="checkbox"
                                    checked={e.done}
                                    onChange={lambda { toggle(e); }}
                                />
                                {e.time + "  " + e.title}
                            </label>
                            <button
                                type="button"
                                aria-label={"Remove " + e.title}
                                onClick={lambda { remove(e); }}
                            >
                                {"×"}
                            </button>
                        </div>
                    }
                    <form className="add" onSubmit={add}>
                        <input
                            type="text"
                            placeholder="New event"
                            aria-label="Event title"
                            value={title}
                            onChange={lambda (e: ChangeEvent) { title = e.target.value; }}
                        />
                        <input
                            type="time"
                            aria-label="Time"
                            value={time}
                            onChange={lambda (e: ChangeEvent) { time = e.target.value; }}
                        />
                        <button type="submit">Add event</button>
                    </form>
                } }
            </aside>
        </div>
    </div>
}
