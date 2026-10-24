// The page editor's hooks, for a site's app.js, through the link
// `mix billboard.assets` makes:
//
//     import {EditCanvas, InlineWords} from "../vendor/billboard/assets/js/billboard.js"
//     import {hooks as billboardHooks} from "phoenix-colocated/billboard"
//
//     hooks: {...colocatedHooks, ...billboardHooks, EditCanvas, InlineWords}
export {EditCanvas} from "./edit_canvas"
export {InlineWords} from "./inline_words"
