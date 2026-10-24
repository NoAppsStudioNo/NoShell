pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.State
import qs.utils

// Live Wallpaper Engine wallpapers from the Steam Workshop, rendered by waywallen behind the shell
// (utils/scripts/wallpaper-engine.py). While one is on, the background window hides the normal wallpaper.
// The pick lives in ~/.local/state/caelestia/wallpaper-engine.json and is reapplied when the shell starts.
// The Steam account, Workshop search and wallpaper properties go through waywallen too.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("utils/scripts/wallpaper-engine.py")

    property string current // Workshop id
    property bool enabled
    property list<var> projects: [] // { id, title, type, preview }
    property list<string> downloading: [] // subscribed here, waiting for Steam to download
    property var status: ({}) // { engine, steam }: waywallen / Wallpaper Engine installed
    property var account: ({}) // { signedIn, name }
    property var login: null // { state: starting|scan|confirm|done|expired|failed|cancelled, qr (data url), error } while signing in

    property list<var> results: [] // Workshop search: { id, title, preview, author, type, subscribed }
    property bool moreResults
    property string searchError
    property var lastSearch: ({})

    property var schema: ({}) // live wallpaper's properties: key -> { text, type, value, min, max, step, options, order }
    property var overrides: ({}) // key -> value (string) the user changed
    property var pendingProps: ({}) // waiting for propTimer

    readonly property bool ready: !!status.engine && !!status.steam
    readonly property bool playing: PersistentState.wallpaperPlaying // the utilities "play wallpaper" toggle
    readonly property list<string> applyArgs: ["apply", current, ...(playing ? [] : ["--paused"])]
    readonly property bool searching: searchProc.running
    readonly property var currentProject: projects.find(p => p.id === current) ?? null

    // Also makes the preview the normal wallpaper, so the colour scheme follows the live one
    function apply(id: string): void {
        current = id;
        enabled = true;
        schema = {};
        overrides = {};
        save();
        run(applyArgs);
        const preview = projects.find(p => p.id === id)?.preview;
        if (preview)
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", preview, ...Wallpapers.smartArg]);
        propsTimer.tries = 0;
        propsTimer.restart();
    }

    function stop(): void {
        if (!enabled)
            return;
        enabled = false;
        schema = {};
        save();
        run(["stop"]);
    }

    function refresh(): void {
        listProc.running = true;
        statusProc.running = true;
    }

    function refreshAccount(): void {
        if (ready)
            accountProc.running = true;
    }

    function signIn(): void {
        login = {
            state: "starting"
        };
        loginProc.running = true;
    }

    function cancelSignIn(): void {
        loginProc.running = false;
        login = null;
    }

    function signOut(): void {
        account = {};
        Quickshell.execDetached(["sh", "-c", `python3 "$0" logout; true`, script]);
        results = [];
    }

    function search(query: string, sort: string, page: int): void {
        lastSearch = {
            query,
            sort,
            page
        };
        if (page === 1)
            results = [];
        searchError = "";
        searchProc.command = ["python3", script, "search", sort, String(page), query];
        searchProc.running = true;
    }

    function setSubscribed(id: string, on: bool): void {
        results = results.map(r => r.id === id ? Object.assign({}, r, {
                subscribed: on
            }) : r);
        downloading = on ? [...downloading, id] : downloading.filter(d => d !== id);
        run(["subscribe", id, on ? "on" : "off"]);
    }

    function loadProps(): void {
        if (enabled)
            propsProc.running = true;
    }

    // The renderer gets the new value right away; sliders are throttled
    function setProp(key: string, value: string): void {
        overrides = Object.assign({}, overrides, {
            [key]: value
        });
        pendingProps[key] = value;
        propTimer.start();
    }

    function resetProp(key: string): void {
        const o = Object.assign({}, overrides);
        delete o[key];
        overrides = o;
        delete pendingProps[key];
        run(["reset", current, key]);
    }

    function run(args: list<string>): void {
        Quickshell.execDetached(["sh", "-c", `err=$(python3 "$@" 2>&1) || notify-send -a "Wallpaper Engine" "Wallpaper Engine" "$err"`, "sh", script, ...args]);
    }

    function save(): void {
        storage.setText(JSON.stringify({
            id: current,
            enabled
        }));
    }

    onReadyChanged: refreshAccount()
    onPlayingChanged: {
        if (enabled)
            run([playing ? "resume" : "pause"]);
    }

    // ponytail: a download Steam never finishes (Steam closed) is polled until the shell restarts
    Timer {
        interval: 5000
        running: root.downloading.length > 0
        repeat: true
        onTriggered: listProc.running = true
    }

    Timer {
        id: propTimer

        interval: 150
        onTriggered: {
            for (const key in root.pendingProps)
                root.run(["set", root.current, key, root.pendingProps[key]]);
            root.pendingProps = {};
        }
    }

    // The renderer publishes the properties once it has started
    Timer {
        id: propsTimer

        property int tries

        interval: 2000
        onTriggered: root.loadProps()
    }

    component Json: StdioCollector {
        signal parsed(data: var)

        onStreamFinished: {
            try {
                parsed(JSON.parse(text));
            } catch (e) {}
        }
    }

    Process {
        id: listProc

        running: true
        command: ["python3", root.script, "list"]
        stdout: Json {
            onParsed: data => {
                // Replacing the list rebuilds every tile and reloads its preview
                if (JSON.stringify(data) !== JSON.stringify(root.projects))
                    root.projects = data;
                root.downloading = root.downloading.filter(id => !data.some(p => p.id === id));
            }
        }
    }

    Process {
        id: statusProc

        running: true
        command: ["python3", root.script, "status"]
        stdout: Json {
            onParsed: data => root.status = data
        }
    }

    Process {
        id: accountProc

        command: ["python3", root.script, "account"]
        stdout: Json {
            onParsed: data => root.account = data
        }
    }

    Process {
        id: loginProc

        command: ["python3", root.script, "login"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.login = JSON.parse(line);
                } catch (e) {}
                if (root.login?.state === "done")
                    root.refreshAccount();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.login = {
                        state: "failed",
                        error: text.trim().split("\n").pop()
                    };
            }
        }
    }

    Process {
        id: searchProc

        stdout: Json {
            onParsed: data => {
                root.results = [...root.results, ...data.items];
                root.moreResults = data.more;
                root.searchError = data.error;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.searchError = text.trim().split("\n").pop();
            }
        }
    }

    Process {
        id: propsProc

        command: ["python3", root.script, "props", root.current]
        stdout: Json {
            onParsed: data => {
                root.schema = data.schema;
                root.overrides = data.overrides;
                if (Object.keys(data.schema).length === 0 && propsTimer.tries++ < 5)
                    propsTimer.restart();
            }
        }
    }

    // Read while the singleton is created: the background window picks its layer then and misses a later change
    Component.onCompleted: {
        try {
            const data = JSON.parse(storage.text());
            current = data.id ?? "";
            enabled = !!data.enabled && !!current;
        } catch (e) {}
        if (enabled)
            run(applyArgs);
    }

    FileView {
        id: storage

        blockLoading: true
        printErrors: false
        path: `${Paths.state}/wallpaper-engine.json`
    }
}
