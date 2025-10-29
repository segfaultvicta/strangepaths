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


Hooks.TemenosMoveReporter = {
    mounted() {
        canvas = document.getElementById("temenos");
        this.el.addEventListener("mousemove", e => {
            this.pushEvent("move", getMousePosition(canvas, e));
        });
    }
}

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
            avatarmenu.selectedNavItemIndex = null;
            avatarmenu.slicePathFunction = slicePath().MenuSliceWithoutLine;
            avatarmenu.navAngle = 270;
            avatarmenu.titleHeight = 40;
            avatarmenu.hoverPercent = 1.0;
            avatarmenu.animateeffect = "none";
            avatarmenu.clickModeRotate = false;
            avatarmenu.colors = [
                '#b11c98', // hand
                '#f5f5f5', // move
                '#CC6644', // stress
                '#c1c76f', // pierce
                '#66CC44', // recover
                '#CCCCCC', // defend
                '#FF5555', // delete
            ];
            avatarmenu.wheelRadius = avatarmenu.wheelRadius * 0.83;
            avatarmenu.createWheel(['📖', '➡️', '⚔️', '🏹', '➕', '🛡️', '✖️']);
            avatarmenu.navItems[0].navigateFunction = () => menuClick('avatarHand');
            avatarmenu.navItems[1].navigateFunction = () => menuClick('avatarMove');
            avatarmenu.navItems[2].navigateFunction = () => menuClick('avatarStress');
            avatarmenu.navItems[3].navigateFunction = () => menuClick('avatarPierce');
            avatarmenu.navItems[4].navigateFunction = () => menuClick('avatarRecover');
            avatarmenu.navItems[5].navigateFunction = () => menuClick('avatarDefend');
            avatarmenu.navItems[6].navigateFunction = () => menuClick('avatarDelete');
            avatarmenu.setTooltips(['Hand', 'Move', 'Stress', 'Pierce', 'Recover', 'Defend', 'Delete']);
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
            temenosmenu.selectedNavItemIndex = null;
            temenosmenu.slicePathFunction = slicePath().MenuSliceWithoutLine;
            temenosmenu.navAngle = 270;
            temenosmenu.titleHeight = 40;
            temenosmenu.hoverPercent = 1.3;
            temenosmenu.clickModeRotate = false;
            temenosmenu.wheelRadius = temenosmenu.wheelRadius * 0.83;
            if (e.gm) {
                if (e.current_showhide) {
                    // GM avatars are SHOWN, button should HIDE them
                    temenosmenu.createWheel(['➕', '📍', '🙈', '🎯']);
                    temenosmenu.navItems[0].navigateFunction = () => menuClick("temenosPlace");
                    temenosmenu.navItems[1].navigateFunction = () => menuClick("temenosCounter");
                    temenosmenu.navItems[2].navigateFunction = () => menuClick("temenosToggleHide");
                    temenosmenu.navItems[3].navigateFunction = () => menuClick("temenosTarget");
                    temenosmenu.setTooltips(['Place Avatar', 'Counters', 'GM Screen', 'Target']);
                } else {
                    // GM avatars are HIDDEN, button should SHOW them
                    temenosmenu.createWheel(['➕', '📍', '👁️', '🎯']);
                    temenosmenu.navItems[0].navigateFunction = () => menuClick("temenosPlace");
                    temenosmenu.navItems[1].navigateFunction = () => menuClick("temenosCounter");
                    temenosmenu.navItems[2].navigateFunction = () => menuClick("temenosToggleHide");
                    temenosmenu.navItems[3].navigateFunction = () => menuClick("temenosTarget");
                    temenosmenu.setTooltips(['Place Avatar', 'Counters', 'Reveal', 'Target']);
                }
            } else {
                // don't show show/hide button at all
                temenosmenu.createWheel(['➕', '📍', '🎯']);
                temenosmenu.navItems[0].navigateFunction = () => menuClick("temenosPlace");
                temenosmenu.navItems[1].navigateFunction = () => menuClick("temenosCounter");
                temenosmenu.navItems[2].navigateFunction = () => menuClick("temenosTarget");
                temenosmenu.setTooltips(['Place Avatar', 'Counters', 'Target']);
            }
        })

        this.handleEvent("loadCardMenu", e => {
            var template = document.getElementById('cardmenuTemplate');
            var a = template.cloneNode(true);
            a.id = "cardmenu";
            a.style.position = "fixed";
            a.style.height = 400 + "px";
            a.style.left = e.x + "px";
            a.style.top = e.y + "px";
            this.el.parentNode.appendChild(a);
            var cardmenu = new wheelnav('cardmenu');
            cardmenu.selectedNavItemIndex = null;
            cardmenu.slicePathFunction = slicePath().MenuSliceWithoutLine;
            cardmenu.navAngle = 270;
            cardmenu.titleHeight = 40;
            cardmenu.hoverPercent = 1.0;
            cardmenu.animateeffect = "none";
            cardmenu.clickModeRotate = false;
            cardmenu.wheelRadius = cardmenu.wheelRadius * 0.83;
            cardmenu.colors = [
                '#5555FF', // discard
                '#f5f5f5', // move
                '#2D9E46', // copy
                '#000000', // to deck
                '#000000', // to top of deck
                '#b11c98', // to hand
                '#FF5555', // destroy
            ];
            cardmenu.createWheel(['🗑️', '➡️', '↔️', '📘', '👑📘', '📖', '✖️']);
            cardmenu.navItems[0].navigateFunction = () => menuClick("cardDiscard");
            cardmenu.navItems[1].navigateFunction = () => menuClick("cardMove");
            cardmenu.navItems[2].navigateFunction = () => menuClick("cardCopy");
            cardmenu.navItems[3].navigateFunction = () => menuClick("cardToDeck");
            cardmenu.navItems[4].navigateFunction = () => menuClick("cardToTopDeck");
            cardmenu.navItems[5].navigateFunction = () => menuClick("cardToHand");
            cardmenu.navItems[6].navigateFunction = () => menuClick("cardDestroy");
            cardmenu.setTooltips(['Discard', 'Move', 'Copy', 'Add To Deck', 'Add To Top Of Deck', 'Add To Hand', 'Destroy']);
        })

        this.handleEvent("loadAmountSubmenu", e => {
            console.log("in loadAmountSubmenu");
            console.log(e);
            var template = document.getElementById('amountSubmenuTemplate');
            var submenu = template.cloneNode(true);
            submenu.id = "amountSubmenu";
            submenu.style.position = "fixed";
            submenu.style.height = 500 + "px";
            submenu.style.left = (e.x - 305) + "px";
            submenu.style.top = (e.y - 55) + "px";
            this.el.parentNode.appendChild(submenu);
            var amountSubmenu = new wheelnav('amountSubmenu');
            amountSubmenu.slicePathFunction = slicePath().StarSlice;
            // can we find out WHICH submenu we're invoking?
            var baseColor;
            var variance;
            var angle;
            console.log(e.type);
            switch (e.type) {
                case "Defend":
                    baseColor = "#CCCCCC"
                    variance = 10;
                    angle = 160;
                    break;

                case "Recover":
                    baseColor = "#66CC44"
                    variance = 30;
                    angle = 110;
                    break;

                case "Stress":
                    baseColor = "#CC6644"
                    variance = 20;
                    angle = 10;
                    break;

                case "Pierce":
                    baseColor = "#c1c76f"
                    variance = 30;
                    angle = 60;
                    break;

                default:
                    baseColor = "#222222"
                    variance = 0;
                    angle = 0;
                    break;
            }
            amountSubmenu.colors = [];
            for (let i = 0; i < 10; i++) {
                amountSubmenu.colors.push(...[randomCloseColor(baseColor, variance)]);
            }
            amountSubmenu.hoverPercent = 1.3;
            amountSubmenu.animateeffect = "linear";
            amountSubmenu.animatetime = 300;
            amountSubmenu.clickModeRotate = false;
            amountSubmenu.navAngle = angle;
            amountSubmenu.sliceSelectedAttr = {};
            amountSubmenu.lineSelectedAttr = {};
            amountSubmenu.titleSelectedAttr = {};
            amountSubmenu.wheelRadius = amountSubmenu.wheelRadius * 0.65;
            amountSubmenu.selectedNavItemIndex = null;
            amountSubmenu.createWheel(['Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ', 'Ⅷ', 'Ⅸ', 'Ⅹ']);
            for (let i = 0; i < amountSubmenu.navItems.length; i++) {
                amountSubmenu.navItems[i].navigateFunction = (function (index) {
                    return function () {
                        menuClick("amount" + (index + 1));
                    };
                })(i);
            }
            amountSubmenu.setTooltips(['1', '2', '3', '4', '5', '6', '7', '8', '9', '10']);
        })

        this.handleEvent("drawLeaderLine", e => {
            lineOpts = { hide: true, gradient: true, startPlugColor: 'rgba(90, 90, 255, 0.8', endPlugColor: 'rgba(255, 30, 100, 1.0)', dash: { animation: true } }
            var line = new LeaderLine(document.getElementById(e.src), document.getElementById(e.tgt), lineOpts)
            line.show("draw");
            setTimeout(() => {
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
            var submenu = document.getElementById('avatarmenu');
            if (submenu) {
                submenu.remove();
            }
        })

        this.handleEvent("unloadTemenosMenu", e => {
            var submenu = document.getElementById('temenosmenu');
            if (submenu) {
                submenu.remove();
            }

        })

        this.handleEvent("unloadAmountSubmenu", () => {
            var submenu = document.getElementById('amountSubmenu');
            if (submenu) {
                submenu.remove();
            }
        })

        this.pushEvent("context", this.el.getBoundingClientRect());

        this.el.addEventListener("click", e => {
            this.pushEvent("click", getMousePosition(this.el, e))
        })

        this.el.addEventListener("mousemove", e => {
            this.pushEvent("move", getMousePosition(this.el, e))
        })

        // draw two equally-spaced vertical lines on the canvas for Lanes
        var ctx = this.el.getContext("2d");
        ctx.strokeStyle = "black";
        ctx.lineWidth = 1;
        ctx.moveTo(200, 0);
        ctx.lineTo(200, 200);
        ctx.moveTo(100, 0);
        ctx.lineTo(100, 200);
        ctx.stroke();
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

function randomCloseColor(inputColor, variance = 10) {
    // Parse the input color to RGB
    let r, g, b;

    if (inputColor.startsWith('#')) {
        // Handle hex colors
        const hex = inputColor.replace('#', '');
        r = parseInt(hex.substr(0, 2), 16);
        g = parseInt(hex.substr(2, 2), 16);
        b = parseInt(hex.substr(4, 2), 16);
    } else if (inputColor.startsWith('rgb')) {
        // Handle rgb/rgba colors
        const matches = inputColor.match(/\d+/g);
        r = parseInt(matches[0]);
        g = parseInt(matches[1]);
        b = parseInt(matches[2]);
    } else {
        throw new Error('Invalid color format. Use hex (#RRGGBB) or rgb(r, g, b)');
    }

    // Helper to get a random offset within variance
    const randomOffset = () => Math.random() * variance * 2 - variance;

    // Apply random offsets and clamp to 0-255
    const clamp = (val) => Math.max(0, Math.min(255, Math.round(val)));

    const newR = clamp(r + randomOffset());
    const newG = clamp(g + randomOffset());
    const newB = clamp(b + randomOffset());

    // Convert back to hex
    const toHex = (n) => n.toString(16).padStart(2, '0');
    return `#${toHex(newR)}${toHex(newG)}${toHex(newB)}`;
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