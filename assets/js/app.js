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


Hooks.SceneFocusManager = {
    mounted() {
        this.handleEvent("focus_post_input", () => {
            // Use requestAnimationFrame to ensure DOM has updated
            requestAnimationFrame(() => {
                const input = document.getElementById("post-content-input");
                if (input) {
                    input.focus();
                }
            });
        });
    }
}

Hooks.ChatScrollManager = {
    mounted() {
        // Scroll to bottom on mount
        this.scrollToBottom();

        // Listen for new posts from server
        this.handleEvent("new_post_received", ({ is_own_post }) => {
            if (is_own_post) {
                // Always scroll for own posts
                this.scrollToBottom();
            } else {
                // Only scroll if user is near bottom
                if (this.isNearBottom()) {
                    this.scrollToBottom();
                }
            }
        });

        this.handleEvent("scroll_to_bottom", () => {
            if (this.isNearBottom()) {
                this.scrollToBottom();
            }
        })

        // Handle "Load More" - preserve scroll position
        this.handleEvent("posts_loaded", ({ old_first_post_id }) => {
            requestAnimationFrame(() => {
                // Find the old first post and scroll to it
                const oldFirstPost = document.querySelector(`[data-post-id="${old_first_post_id}"]`);
                if (oldFirstPost) {
                    oldFirstPost.scrollIntoView({ block: 'start' });
                }
            });
        });
    },

    updated() {
        // When DOM updates (like scene change), scroll to bottom
        this.scrollToBottom();
    },

    scrollToBottom() {
        requestAnimationFrame(() => {
            this.el.scrollTop = this.el.scrollHeight;
        });
    },

    isNearBottom() {
        const threshold = 200; // pixels from bottom
        return (this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight) < threshold;
    }
}

Hooks.PostContentInput = {
    mounted() {
        // Focus on mount (combining FocusOnMount behavior)
        this.el.focus();

        // Handle Ctrl+Enter to submit
        this.el.addEventListener("keydown", (e) => {
            if (e.key === "Enter" && e.ctrlKey) {
                e.preventDefault();
                // Find the form and submit it
                const form = this.el.closest("form");
                if (form) {
                    // Trigger form submission
                    const submitEvent = new Event("submit", { bubbles: true, cancelable: true });
                    form.dispatchEvent(submitEvent);
                }
            }

            if (e.key === " " && e.ctrlKey) {
                e.preventDefault();
                this.pushEvent("toggle_post_mode", {});
            }

            if (e.key === "." && e.ctrlKey) {
                e.preventDefault();
                this.pushEvent("toggle_narrative_mode", {});
            }
        });
    }
}

Hooks.OOCContentInput = {
    mounted() {
        // Handle Ctrl+Enter to submit
        this.el.addEventListener("keydown", (e) => {
            if (e.key === "Enter" && e.ctrlKey) {
                e.preventDefault();
                // Find the form and submit it
                const form = this.el.closest("form");
                if (form) {
                    // Trigger form submission
                    const submitEvent = new Event("submit", { bubbles: true, cancelable: true });
                    form.dispatchEvent(submitEvent);
                }
            }

            if (e.key === " " && e.ctrlKey) {
                e.preventDefault();
                this.pushEvent("toggle_post_mode", {});
            }
        });
    }
}

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
        this.channel.postMessage({ type: 'ping' });
        // Listen for responses
        this.channel.onmessage = (event) => {
            if (event.data.type === 'pong') {
                // Another tab exists and responded - we should mute
                this.isMainTab = false;
                document.getElementById("manual-play-btn")?.classList.remove("hidden");
                volumeControl.value = 0;
                audio.volume = 0;
            } else if (event.data.type === 'ping') {
                // New tab is asking if we exist - respond
                this.channel.postMessage({ type: 'pong' });
            }
        };

        // Respond to pings from new tabs
        setTimeout(() => {
            if (this.isMainTab) {
                // If no one responded to our ping, we're the main tab
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
            audio.pause();
            audio.src = "";
            currentSongId = null;
        });

        // Auto-advance when song ends
        audio.addEventListener("ended", () => {
            // Tell server to advance to next song, including the song ID
            if (currentSongId) {
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

// Rumor Map Hooks
Hooks.RumorMapViewport = {
    mounted() {
        let isPanning = false;
        let hasDragged = false;
        let startX, startY;
        let mouseDownX, mouseDownY;
        const world = document.getElementById('rumor-map-world');

        // Zoom with mouse wheel - follow cursor
        this.el.addEventListener('wheel', (e) => {
            e.preventDefault();

            const rect = this.el.getBoundingClientRect();
            const mouseX = e.clientX - rect.left;
            const mouseY = e.clientY - rect.top;

            const delta = e.deltaY > 0 ? 0.9 : 1.1;

            this.pushEvent('zoom', {
                delta: delta,
                mouseX: mouseX,
                mouseY: mouseY
            });
        });

        // Pan with click-drag on background
        this.el.addEventListener('mousedown', (e) => {
            // Only pan if clicking the viewport or world div (not nodes)
            if (e.target === this.el || e.target.id === 'rumor-map-world') {
                isPanning = true;
                hasDragged = false;
                startX = e.clientX;
                startY = e.clientY;
                mouseDownX = e.clientX;
                mouseDownY = e.clientY;
                this.el.style.cursor = 'grabbing';
            }
        });

        this.el.addEventListener('mousemove', (e) => {
            if (isPanning) {
                const dx = e.clientX - startX;
                const dy = e.clientY - startY;

                // If we've moved more than 3 pixels, consider it a drag
                if (Math.abs(e.clientX - mouseDownX) > 3 || Math.abs(e.clientY - mouseDownY) > 3) {
                    hasDragged = true;
                }

                startX = e.clientX;
                startY = e.clientY;
                this.pushEvent('pan', { dx: dx, dy: dy });
            }
        });

        const endPan = () => {
            isPanning = false;
            this.el.style.cursor = 'default';

            // Reset drag flag after a short delay to prevent click event
            setTimeout(() => {
                hasDragged = false;
            }, 50);
        };

        this.el.addEventListener('mouseup', endPan);
        this.el.addEventListener('mouseleave', endPan);

        // Click empty space - either create node (Shift+Click) or deselect (plain click)
        this.el.addEventListener('click', (e) => {
            // Only handle clicks on viewport or world (not nodes or buttons) AND we didn't just drag
            if ((e.target === this.el || e.target.id === 'rumor-map-world') && !hasDragged) {
                if (e.shiftKey) {
                    // Shift+Click to create node
                    const rect = this.el.getBoundingClientRect();
                    const transform = window.getComputedStyle(world).transform;

                    // Parse transform matrix
                    const matrix = new DOMMatrix(transform);

                    // Convert screen to world coordinates (in pixels)
                    const screenX = e.clientX - rect.left;
                    const screenY = e.clientY - rect.top;

                    const worldX = (screenX - matrix.e) / matrix.a;
                    const worldY = (screenY - matrix.f) / matrix.d;

                    // Send pixel coordinates (infinite canvas - no bounds checking)
                    this.pushEvent('create_node', { x: worldX, y: worldY });
                } else {
                    // Plain click to deselect
                    this.pushEvent('deselect_node', {});
                }
            }
        });
    },

    updated() {
        // Whenever LiveView updates the viewport (pan/zoom changes), update line positions
        window.dispatchEvent(new CustomEvent('viewport-transformed'));
    }
}

Hooks.RumorMapNode = {
    mounted() {
        let isDragging = false;
        let startX, startY;
        let initialNodeX, initialNodeY;

        const dragHandle = this.el.querySelector('.node-drag-handle');
        const isAnchor = this.el.dataset.isAnchor === 'true';

        // Change cursor for anchors
        if (isAnchor) {
            dragHandle.style.cursor = 'default';
        }

        dragHandle.addEventListener('mousedown', (e) => {
            // Don't allow dragging anchor nodes
            if (isAnchor) {
                return;
            }

            // Only start drag if clicking directly on the handle (not buttons)
            if (e.target === dragHandle || e.target.closest('.node-drag-handle') === dragHandle) {
                isDragging = true;
                e.stopPropagation(); // Prevent map panning

                startX = e.clientX;
                startY = e.clientY;

                // Get current position
                initialNodeX = parseFloat(this.el.style.left) || 0;
                initialNodeY = parseFloat(this.el.style.top) || 0;

                this.el.classList.add('dragging');
                dragHandle.style.cursor = 'grabbing';
            }
        });

        document.addEventListener('mousemove', (e) => {
            if (isDragging) {
                e.preventDefault();

                // Calculate delta in screen space
                const dx = e.clientX - startX;
                const dy = e.clientY - startY;

                // Get world transform to account for zoom
                const world = document.getElementById('rumor-map-world');
                const transform = window.getComputedStyle(world).transform;
                const matrix = new DOMMatrix(transform);
                const zoom = matrix.a;

                // Delta in pixels (accounting for zoom)
                const deltaXPixels = dx / zoom;
                const deltaYPixels = dy / zoom;

                // New position in pixels (no constraints - infinite canvas)
                const newX = initialNodeX + deltaXPixels;
                const newY = initialNodeY + deltaYPixels;

                // Update position immediately for smooth dragging
                this.el.style.left = `${newX}px`;
                this.el.style.top = `${newY}px`;

                // Update initialNodeX/Y for next move event
                initialNodeX = newX;
                initialNodeY = newY;
                startX = e.clientX;
                startY = e.clientY;

                // Update LeaderLines
                window.dispatchEvent(new CustomEvent('node-moved', {
                    detail: { nodeId: this.el.dataset.nodeId }
                }));
            }
        });

        document.addEventListener('mouseup', () => {
            if (isDragging) {
                isDragging = false;
                this.el.classList.remove('dragging');
                dragHandle.style.cursor = 'move';

                // Send final position to server
                const nodeId = this.el.dataset.nodeId;
                const finalX = parseFloat(this.el.style.left);
                const finalY = parseFloat(this.el.style.top);

                this.pushEvent('update_node_position', {
                    node_id: nodeId,
                    x: finalX,
                    y: finalY
                });
            }
        });

        // Listen for position updates from other users
        this.handleEvent('node_position_updated', ({ node_id }) => {
            if (this.el.dataset.nodeId === node_id.toString()) {
                window.dispatchEvent(new CustomEvent('node-moved', {
                    detail: { nodeId: node_id.toString() }
                }));
            }
        });
    }
}

Hooks.RumorMap = {
    mounted() {
        this.lines = {}; // Track LeaderLine instances by connection ID

        // Method to update all line positions
        this.updateAllLines = () => {
            Object.entries(this.lines).forEach(([connId, lineData]) => {
                if (lineData.svg) {
                    clickablePath = lineData.svg.childNodes[2];
                    clickablePath.remove();
                    this.createClickableOverlay(lineData.instance, lineData.conn, lineData.svg);
                }
                lineData.instance.position();
            });
        };

        // Listen for node movement to update lines
        window.addEventListener('node-moved', (e) => {
            const nodeId = e.detail.nodeId;

            // Update all lines connected to this node
            Object.entries(this.lines).forEach(([connId, lineData]) => {
                if (lineData.startNodeId == nodeId || lineData.endNodeId == nodeId) {
                    // remove lineData.svg's 2nd child (clickable path)
                    clickablePath = lineData.svg.childNodes[2];
                    clickablePath.remove();

                    this.createClickableOverlay(lineData.instance, lineData.conn, lineData.svg);
                    lineData.instance.position();
                }
            });
        });

        // Listen for viewport transformations (pan/zoom) to update all lines
        window.addEventListener('viewport-transformed', () => {
            this.updateAllLines();
        });

        // Draw a new connection
        this.handleEvent('draw_connection', (conn) => {
            const startEl = document.getElementById(`node-${conn.from_id}`);
            const endEl = document.getElementById(`node-${conn.to_id}`);

            if (!startEl || !endEl) {
                console.error('Could not find nodes for connection', conn);
                return;
            }

            const color = this.getColorForCategory(conn.category);

            const lineOpts = {
                color: color,
                size: 3,
                path: 'straight',
                startPlug: 'disc',
                endPlug: 'arrow2',
                ...conn.line_style
            };

            const line = new LeaderLine(startEl, endEl, lineOpts);

            // Store initial SVG count to find the newly created one
            const svgCountBefore = document.querySelectorAll('svg.leader-line').length;

            this.lines[conn.id] = {
                instance: line,
                startNodeId: conn.from_id.toString(),
                endNodeId: conn.to_id.toString(),
                conn: conn  // Store connection data for recreating overlay if needed
            };

            // this is a sin against G-d

            const allSvgs = document.querySelectorAll('svg.leader-line');
            // If a new SVG was created, find the one without our marker
            if (allSvgs.length >= svgCountBefore) {
                let svg = null;
                for (let i = 0; i < allSvgs.length; i++) {
                    if (!allSvgs[i].dataset.connectionId) {
                        svg = allSvgs[i];
                        break;
                    }
                }
                if (svg) {
                    svg.dataset.connectionId = conn.id;
                    this.lines[conn.id].svg = svg;
                    this.createClickableOverlay(line, conn, svg);
                    return;
                }
            }

            // Small delay to let LeaderLine create the SVG
            createOverlay();
        });

        // Remove a connection
        this.handleEvent('remove_connection', ({ connection_id }) => {
            if (this.lines[connection_id]) {
                this.lines[connection_id].instance.remove();
                delete this.lines[connection_id];
            }
        });

        // Remove all connections to/from a deleted node
        this.handleEvent('remove_deleted_node_connections', ({ node_id }) => {
            Object.entries(this.lines).forEach(([connId, lineData]) => {
                if (lineData.startNodeId == node_id.toString() || lineData.endNodeId == node_id.toString()) {
                    lineData.instance.remove();
                    delete this.lines[connId];
                }
            });
        });

        // Remove a node from DOM
        this.handleEvent('remove_node_element', ({ node_id }) => {
            const nodeEl = document.getElementById(`node-${node_id}`);
            if (nodeEl) {
                nodeEl.remove();
            }
        });
    },

    getColorForCategory(category) {
        const colors = {
            'red': '#ef4444',
            'blue': '#3b82f6',
            'green': '#22c55e',
            'white': '#f3f4f6',
            'black': '#1f2937',
            'secret': '#a855f7'
        };
        return colors[category] || '#9ca3af';
    },

    createClickableOverlay(line, conn, svg) {
        if (!svg) {
            console.error('SVG not ready for connection', conn.id);
            return;
        }

        const path = svg.querySelector('path');

        if (path) {
            // Clone path for click detection
            const clickPath = path.cloneNode(true);
            clickPath.setAttribute('stroke-width', '20');
            // Very subtle white overlay - barely visible but clickable
            clickPath.setAttribute('stroke', 'rgba(255, 255, 255, 0.01)');
            clickPath.setAttribute('fill', 'none');
            clickPath.style.cursor = 'pointer';
            clickPath.setAttribute('data-connection-id', conn.id);
            clickPath.style.pointerEvents = 'auto'; // Ensure it receives pointer events

            svg.appendChild(clickPath);

            // Add tooltip if there's a label
            if (conn.label && window.tippy) {
                tippy(clickPath, {
                    content: conn.label,
                    theme: 'translucent',
                    placement: 'top'
                });
            }

            // Click handler
            clickPath.addEventListener('click', (e) => {
                console.log('Connection clicked:', conn.id);
                e.stopPropagation();
                this.pushEvent('connection_clicked', { 'connection-id': conn.id.toString() });
            });

            // Also ensure the SVG itself allows pointer events
            svg.style.pointerEvents = 'auto';
        }
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
        },
        onNodeAdded(node) {
            // Initialize Alpine on newly added nodes
            if (window.Alpine && node.nodeType === 1) {
                window.Alpine.initTree(node);
            }
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