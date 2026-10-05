"""Planner mobile app: a plain list of upcoming events.

Add an event, or tap one to mark it done. Every call goes to the same planner
server the web app and the CLI use.
"""

import from "@jac/mobui" { ScrollView, View, Text, TextInput, Pressable, StyleSheet }
import from "@jac/runtime" { BridgeError }
import from server.main { EventView, get_events, add_event, set_done }

glob styles = StyleSheet.create(
         {
             "screen": {"flex": 1, "backgroundColor": "#0b0c0f"},
             "body": {"padding": 16, "paddingTop": 56, "gap": 10},
             "heading": {"color": "#ffffff", "fontSize": 28, "fontWeight": "bold"},
             "row": {"flexDirection": "row", "gap": 10},
             "input": {
                 "color": "#ffffff",
                 "fontSize": 16,
                 "backgroundColor": "#1d2027",
                 "borderRadius": 8,
                 "paddingVertical": 10,
                 "paddingHorizontal": 12
             },
             "half": {"flex": 1},
             "button": {
                 "backgroundColor": "#3a3f4d",
                 "borderRadius": 8,
                 "paddingVertical": 12,
                 "alignItems": "center"
             },
             "label": {"color": "#ffffff", "fontSize": 16, "fontWeight": "bold"},
             "note": {"color": "#ffffff", "fontSize": 14, "opacity": 0.7},
             "day": {
                 "color": "#ffffff",
                 "fontSize": 14,
                 "fontWeight": "bold",
                 "marginTop": 14
             },
             "event": {
                 "flexDirection": "row",
                 "gap": 12,
                 "backgroundColor": "#181a20",
                 "borderRadius": 8,
                 "padding": 14
             },
             "finished": {"backgroundColor": "#101115"},
             "text": {"color": "#ffffff", "fontSize": 16},
             "crossed": {"textDecorationLine": "line-through", "opacity": 0.55}
         }
     );

def pad(n: int) -> str {
    return "0" + str(n) if n < 10 else str(n);
}

def today_iso -> str {
    now = new(Date);
    return str(int(now.getFullYear()))
        + "-"
        + pad(int(now.getMonth()) + 1)
        + "-"
        + pad(int(now.getDate()));
}

"""A readable label for an ISO date, e.g. "Tue Oct 06 2026"."""
def day_label(date: str) -> str {
    return new(
        Date, int(date[0:4]), int(date[5:7]) - 1, int(date[8:10])
    ).toDateString();
}

def:pub app -> JsxElement {
    has events: list[EventView] = [],
        title: str = "",
        date: str = "",
        time: str = "",
        note: str = "";

    today = today_iso();
    upcoming = [
        e
        for e in events
        if e.date >= today
    ];

    async def load {
        try {
            events = await get_events();
            note = "";
        } except BridgeError {
            note = "Can't reach the planner server. Check that it is running.";
        }
    }

    async can with entry {
        date = today;
        await load();
    }

    async def add {
        try {
            made = await add_event(title, date, time);
        } except BridgeError {
            note = "Can't reach the planner server. Check that it is running.";
            return;
        }
        if made is None {
            note = "Give a title, a date like 2026-10-06 and a time like 14:30.";
            return;
        }
        title = "";
        time = "";
        await load();
    }

    async def toggle(event: EventView) {
        try {
            await set_done(event.id, not event.done);
        } except BridgeError {
            note = "Can't reach the planner server. Check that it is running.";
            return;
        }
        await load();
    }

    <ScrollView style={styles.screen} contentContainerStyle={styles.body}>
        <Text style={styles.heading}>Planner</Text>
        <TextInput
            style={styles.input}
            value={title}
            placeholder="New event"
            placeholderTextColor="#9a9da6"
            onChangeText={lambda (t: str) { title = t; }}
        />
        <View style={styles.row}>
            <TextInput
                style={[styles.input, styles.half]}
                value={date}
                placeholder="YYYY-MM-DD"
                placeholderTextColor="#9a9da6"
                onChangeText={lambda (t: str) { date = t; }}
            />
            <TextInput
                style={[styles.input, styles.half]}
                value={time}
                placeholder="HH:MM"
                placeholderTextColor="#9a9da6"
                onChangeText={lambda (t: str) { time = t; }}
            />
        </View>
        <Pressable style={styles.button} onPress={lambda { add(); }}>
            <Text style={styles.label}>Add event</Text>
        </Pressable>
        <Pressable style={styles.button} onPress={lambda { load(); }}>
            <Text style={styles.label}>Refresh</Text>
        </Pressable>
        {if note {
            <Text style={styles.note}>{note}</Text>
        }}
        {if not upcoming and not note {
            <Text style={styles.note}>Nothing planned from today on.</Text>
        }}
        {for (i, e) in enumerate(upcoming) {
            if i == 0 or upcoming[i - 1].date != e.date {
                <Text key={e.date} style={styles.day}>{day_label(e.date)}</Text>
            }
            <Pressable
                key={e.id}
                style={[styles.event, styles.finished] if e.done else styles.event}
                onPress={lambda { toggle(e); }}
            >
                <Text style={styles.text}>{"✓" if e.done else "○"}</Text>
                <Text style={[styles.text, styles.crossed] if e.done else styles.text}>
                    {e.time + "  " + e.title}
                </Text>
            </Pressable>
        }}
    </ScrollView>
}
