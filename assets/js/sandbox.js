
import {Socket} from "phoenix"

export default SandboxHooks = {
    mounted() {
        console.log("Sandbox executed on mount");
        console.log(window.location.pathname);

        const socket = new Socket("/socket", {params: {token: window.userToken}});
        socket.connect();

        console.log("socket connected");
    },

    updated() {
        console.log("Sandbox executed on update");
    }
}