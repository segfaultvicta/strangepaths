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