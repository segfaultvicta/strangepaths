// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.Sortable = {
    mounted() {
        new Sortable(this.el, {
            animation: 150,
            ghostClass: "opacity-50",
            onEnd: (event) => {
                this.pushEvent("reorder_song", {
                    new_order: event.newIndex,
                    song_id: event.item.dataset.id
                });
            }
        });
    }
}

Hooks.TooltipUpdater = {
    mounted() {
        const templateId = this.el.dataset.tooltipTemplate;
        const template = document.getElementById(templateId);

        // Create Tippy instance directly
        if (template && window.tippy) {
            this.tippy = window.tippy(this.el, {
                content: template.innerHTML,
                allowHTML: true,
                theme: 'light-border',
                placement: 'bottom'
            });
        } else {
            console.warn('Tippy not available or template not found:', templateId);
        }
    },
    updated() {
        const templateId = this.el.dataset.tooltipTemplate;
        const template = document.getElementById(templateId);

        // Update the Tippy content with fresh template HTML
        if (template && this.tippy) {
            console.log("interior of tooltip updater");
            console.log("Template HTML:", template.innerHTML);

            // Force Tippy to update by destroying and recreating
            this.tippy.destroy();
            this.tippy = window.tippy(this.el, {
                content: template.innerHTML,
                allowHTML: true,
                theme: 'light-border',
                placement: 'bottom'
            });
        }
    },
    destroyed() {
        if (this.tippy) {
            this.tippy.destroy();
        }
    }
}

Hooks.MusicPlayer = {
    mounted() {
        const audio = document.getElementById("audio-player");
        const volumeControl = document.getElementById("volume-control");
        const songTitle = document.getElementById("song-title");
        const queuedBy = document.getElementById("queued-by");
        const queueList = document.getElementById("queue-list");

        this.channel = new BroadcastChannel('strangepaths_music');
        this.isMainTab = true;

        // Check if another tab exists
        console.log("ping")
        this.channel.postMessage({ type: 'ping' });
        // Listen for responses
        this.channel.onmessage = (event) => {
            if (event.data.type === 'pong') {
                // Another tab exists and responded - we should mute
                console.log("get ponged, nerd");
                this.isMainTab = false;
                document.getElementById("manual-play-btn")?.classList.remove("hidden");
                volumeControl.value = 0;
                audio.volume = 0;
            } else if (event.data.type === 'ping') {
                // New tab is asking if we exist - respond
                console.log("pong")
                this.channel.postMessage({ type: 'pong' });
            }
        };

        // Respond to pings from new tabs
        setTimeout(() => {
            if (this.isMainTab) {
                // If no one responded to our ping, we're the main tab
                console.log("I am the main tab");
            }
        }, 100);

        // Add click handler for manual play
        const manualPlayBtn = document.getElementById("manual-play-btn");
        manualPlayBtn.classList.add("hidden"); // hide by default, show if needed
        manualPlayBtn.addEventListener("click", () => {
            audio.volume = 0.5;
            volumeControl.value = 50;
            audio.play();
            manualPlayBtn.classList.add("hidden");
        });

        // Track the current song ID
        let currentSongId = null;

        // Progress bar (read-only, just for display)
        audio.addEventListener("timeupdate", () => {
            const progress = (audio.currentTime / audio.duration) * 100;
            const progressFill = document.getElementById("progress-fill");
            if (progressFill) {
                progressFill.style.width = `${progress || 0}%`;
            }
        });

        // Volume control
        volumeControl.addEventListener("input", (e) => {
            const volume = e.target.value / 100;
            audio.volume = volume;
            localStorage.setItem("volume", volume);

            if (volume == 0) {
                manualPlayBtn.classList.remove("hidden");
            }
        });
        const savedVolume = localStorage.getItem("volume");
        audio.volume = savedVolume !== null ? parseFloat(savedVolume) : 0.5;
        volumeControl.value = audio.volume * 100;

        // Handle incoming broadcasts
        this.handleEvent("play_song", ({ song_id, title, link, queued_by, start_position }) => {
            currentSongId = song_id; // Store the song ID
            audio.src = link;
            audio.currentTime = start_position || 0;
            if (audio.volume == 0) {
                // TODO FIXME i'm not sure this is doing what I want it to be doing and I'm too tired to fix it.
                // I want the Manual Play button to un-hide itself at the appropriate times.
                manualPlayBtn.classList.remove("hidden");
            }

            // Wait for metadata to load before seeking
            audio.addEventListener('loadeddata', () => {
                audio.play().catch(err => {
                    console.warn("Autoplay blocked:", err);
                    document.getElementById("manual-play-btn")?.classList.remove("hidden");
                });
            }, { once: true }); // once: true removes listener after first call

            songTitle.textContent = title;
            queuedBy.textContent = `Queued by ${queued_by}`;
        });

        // When queue updates
        this.handleEvent("queue_update", ({ now_playing, queue, queue_length }) => {
            // Update queue display
            if (queueList) {
                queueList.innerHTML = queue.map((item, i) =>
                    `<li>${i + 1}. ${item.title} (by ${item.queued_by})</li>`
                ).join('');
            }
        });

        this.handleEvent("stopped", () => {
            console.log("handling stopped message, pausing audio");
            audio.pause();
            audio.src = "";
            currentSongId = null;
        });

        // Auto-advance when song ends
        audio.addEventListener("ended", () => {
            // Tell server to advance to next song, including the song ID
            if (currentSongId) {
                console.log("Song ended:", currentSongId);
                this.pushEvent("song_ended", { song_id: currentSongId });
            }
        });
    },

    destroyed() {
        if (this.channel) {
            this.channel.close();
        }
    }

};

Hooks.Temenos = {
    mounted() {
        this.handleEvent("loadAvatarMenu", e => {
            var template = document.getElementById('avatarmenuTemplate');
            var a = template.cloneNode(true);
            a.id = "avatarmenu";
            a.style.position = "fixed";
            a.style.height = 400 + "px";
            a.style.left = e.x + "px";
            a.style.top = e.y + "px";
            this.el.parentNode.appendChild(a);
            // thus positioned, build an avatar menu around it
            var avatarmenu = new wheelnav('avatarmenu');
            avatarmenu.wheelRadius = avatarmenu.wheelRadius * 0.83;
            avatarmenu.createWheel();
            avatarmenu.setTooltips(['Hand', 'Move', 'Stress', 'Pierce', 'Recover', 'Destroy', 'Defend']);
        })

        this.handleEvent("loadTemenosMenu", e => {
            var template = document.getElementById('temenosmenuTemplate');
            var a = template.cloneNode(true);
            a.id = "temenosmenu";
            a.style.position = "fixed";
            a.style.height = 400 + "px";
            a.style.left = e.x + "px";
            a.style.top = e.y + "px";
            this.el.parentNode.appendChild(a);
            var temenosmenu = new wheelnav('temenosmenu');
            temenosmenu.wheelRadius = temenosmenu.wheelRadius * 0.83;
            temenosmenu.createWheel();
            temenosmenu.setTooltips(['Place Avatar', 'Counters', 'Show/Hide (GM Only)', 'Target']);
        })

        this.handleEvent("loadCardMenu", e => {
            console.log("foo");
            var template = document.getElementById('cardmenuTemplate');
            var a = template.cloneNode(true);
            a.id = "cardmenu";
            a.style.position = "fixed";
            a.style.height = 400 + "px";
            a.style.left = e.x + "px";
            a.style.top = e.y + "px";
            this.el.parentNode.appendChild(a);
            var cardmenu = new wheelnav('cardmenu');
            cardmenu.wheelRadius = cardmenu.wheelRadius * 0.83;
            cardmenu.createWheel();
            cardmenu.setTooltips(['Discard', 'Destroy', 'Copy', 'Move', 'Add To Deck', 'Add To Top Of Deck', 'Add To Hand']);
        })

        this.handleEvent("drawLeaderLine", e => {
            console.log("request to draw leader line:")
            console.log(e);
            lineOpts = { hide: true, gradient: true, startPlugColor: 'rgba(90, 90, 255, 0.8', endPlugColor: 'rgba(255, 30, 100, 1.0)', dash: { animation: true } }
            var line = new LeaderLine(document.getElementById(e.src), document.getElementById(e.tgt), lineOpts)
            line.show("draw");
            setTimeout(() => {
                console.log("triggering timeout");
                line.hide("fade");
                setTimeout(() => {
                    line.remove();
                }, 1000);
            }, 10000);
        })

        this.el.addEventListener("menuClick", e => {
            this.pushEvent("menuClick", { e: e.detail })
        })

        this.handleEvent("unloadAvatarMenu", e => {
            //document.getElementById('avatarmenu').remove();
        })

        this.handleEvent("unloadTemenosMenu", e => {
            //document.getElementById('avatarmenu').remove();
        })

        this.pushEvent("context", this.el.getBoundingClientRect());

        this.el.addEventListener("click", e => {
            this.pushEvent("click", getMousePosition(this.el, e))
        })

        this.el.addEventListener("mousemove", e => {
            this.pushEvent("move", getMousePosition(this.el, e))
        })
    }
}

function getMousePosition(canvas, e) {
    var rect = canvas.getBoundingClientRect();
    return {
        //x: Math.round(((e.clientX - rect.left) / (rect.right - rect.left) * 20000 / 100) - 100),
        //y: Math.round(((e.clientY - rect.top) / (rect.bottom - rect.top) * 20000 / 100) - 100),
        x: Math.round((e.clientX - rect.left) / (rect.right - rect.left) * 100),
        y: Math.round((e.clientY - rect.top) / (rect.bottom - rect.top) * 100),
        context: rect
    }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
    dom: {
        onBeforeElUpdated(from, to) {
            if (from._x_dataStack) { window.Alpine.clone(from, to) }
        }
    },
    params: { _csrf_token: csrfToken },
    hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket