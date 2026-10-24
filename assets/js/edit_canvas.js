// The page editor's canvas (`#edit-canvas`, Billboard.EditorLive): the page
// as visitors see it, which the admin clicks to open a section and types
// into. The page's own links, buttons, and phx-clicks are the visitors', so
// while editing they do nothing, whether clicked or pressed with the
// keyboard (Enter on a link and Space on a button arrive as clicks too).
// What the editor draws on the page is marked `data-editor-ui` and works as
// it should: the open section's controls, popovers, and item and photo
// tools, and the label that opens a closed section.
//
// While editing, a click:
//   * on a button in the open section (`data-edit-action`) opens its
//     popover in the section's editor (`edit_action`), instead of
//     following it;
//   * on anything the editor marks as its own goes through untouched;
//   * anywhere in a closed section opens it (`open_section`), and in Two
//     columns, outside its columns, opens the pair. On its words
//     (`data-words-at`), it says which, and the caret goes where the click
//     landed once they can be typed into;
//   * outside every section, as on the site's header or footer, closes the
//     open one (`close_section`);
//   * on the reach of a place to add a section (`.bb-edit-gap`), but not on
//     its button, is a click on the section under it.
// Escape closes the palette, a popover, or a menu, or else the open
// section, unless it is pressed in words being typed, which it leaves
// (`InlineWords`). The places to add a section between the page's
// sections, and the palette they open, are the editor's own.
//
// Viewing as a visitor, the page works as a visitor's does, except that
// its links don't leave the editor.
//
// The sections' wrappers open with their own phx-click without this hook
// (as in tests). A click this hook takes never reaches them.
const ACTIVE =
  "a[href], button, summary, [phx-click], [role='button'], [role='link'], input[type='submit'], input[type='button']"

const MENUS = "details[open]"

// A popover or palette that Escape has already closed waits for the
// server to take it away; a second Escape meanwhile goes on to what's
// under it (`bb-edit-closing`).
const POPOVERS = "#section-button:not([bb-edit-closing]), #section-photo:not([bb-edit-closing])"

const PALETTE = "section-palette"

export const EditCanvas = {
  mounted() {
    this.onClick = e => this.click(e)
    this.onSubmit = e => this.submit(e)
    this.onKeydown = e => this.keydown(e)
    this.onFocusout = e => this.focusout(e)

    // In the capture phase, before LiveView's own listeners on the window
    // see the click, and before the link or button does anything.
    this.el.addEventListener("click", this.onClick, true)
    this.el.addEventListener("auxclick", this.onClick, true)
    this.el.addEventListener("submit", this.onSubmit, true)
    this.el.addEventListener("focusout", this.onFocusout)
    window.addEventListener("keydown", this.onKeydown)
  },

  destroyed() {
    this.el.removeEventListener("click", this.onClick, true)
    this.el.removeEventListener("auxclick", this.onClick, true)
    this.el.removeEventListener("submit", this.onSubmit, true)
    this.el.removeEventListener("focusout", this.onFocusout)
    window.removeEventListener("keydown", this.onKeydown)
  },

  editing() {
    return this.el.dataset.mode === "edit"
  },

  click(e) {
    const target = e.target instanceof Element ? e.target : e.target.parentElement
    if (!target) return

    if (!this.editing()) {
      const link = target.closest("a[href]")
      if (link && !link.getAttribute("href").startsWith("#")) stop(e)
      return
    }

    const section = target.closest("[data-edit-section]")
    const open = section?.dataset.open === "true"

    const action = open && target.closest("[data-edit-action]")
    if (action && section.contains(action)) {
      stop(e)
      if (e.type === "click") {
        this.pushEventTo("#section-editor", "edit_action", {path: action.dataset.editAction})
      }
      return
    }

    if (target.classList.contains("bb-edit-gap")) {
      this.throughGap(target, e)
      return
    }

    if (target.closest("[data-editor-ui]")) return

    if (section && !open) {
      stop(e)
      if (e.type === "click") this.open(section, e)
      return
    }

    // Words being typed may sit in a link, which mustn't follow. A click
    // stopped here never reaches LiveView's phx-click-away, so a popover,
    // or the palette, is told to close.
    if (target.closest(ACTIVE)) {
      stop(e)
      if (e.type === "click" && document.querySelector(POPOVERS)) {
        this.pushEventTo("#section-editor", "close_popover", {})
      }
      if (e.type === "click" && document.getElementById(PALETTE)) {
        this.pushEvent("close_palette", {})
      }
    }
    if (!section && this.el.hasAttribute("data-has-open") && e.type === "click") {
      this.pushEvent("close_section", {})
    }
  },

  // A click on a gap's reach, which straddles the seam between two
  // sections, opens the closed section under it, as a click there would
  // without the gap. The gap lets the pointer through (`bb-edit-probe`) while
  // the browser finds it.
  throughGap(gap, e) {
    gap.setAttribute("bb-edit-probe", "")

    try {
      const under = document.elementFromPoint(e.clientX, e.clientY)
      const section = under?.closest("[data-edit-section]")
      if (!section || section.dataset.open === "true" || !this.el.contains(section)) return
      stop(e)
      if (e.type === "click") this.open(section, e)
    } finally {
      gap.removeAttribute("bb-edit-probe")
    }
  },

  // Tabbing out of the open palette closes it, leaving the focus where it
  // went. A click elsewhere closes it by itself (`phx-click-away`); a
  // click on one of its entries, which may not take the focus, mustn't.
  focusout(e) {
    const gap = e.target instanceof Element && e.target.closest(".bb-edit-gap.is-open")
    if (!gap || !e.relatedTarget || gap.contains(e.relatedTarget)) return
    this.pushEvent("close_palette", {at: gap.dataset.at, stay: true})
  },

  // The site's own forms, such as a filter, don't send
  // themselves while editing. The editor's own do.
  submit(e) {
    if (this.editing() && !e.target.closest("[data-editor-ui]")) stop(e)
  },

  keydown(e) {
    if (e.key !== "Escape" || e.defaultPrevented || !this.editing()) return
    const target = e.target instanceof Element ? e.target : null
    // In words being typed, Escape leaves them (`InlineWords`).
    if (target?.closest(".bb-inline-words")) return

    const palette = document.getElementById(PALETTE)
    if (palette && !palette.hasAttribute("bb-edit-closing")) {
      palette.setAttribute("bb-edit-closing", "")
      this.pushEvent("close_palette", {})
      return
    }

    // A popover closes first, after its field, if one has the focus,
    // sends what was typed in it, as leaving it does.
    const popover = document.querySelector(POPOVERS)
    if (popover) {
      if (popover.contains(document.activeElement)) document.activeElement.blur()
      popover.setAttribute("bb-edit-closing", "")
      this.pushEventTo("#section-editor", "close_popover", {})
      return
    }

    const menu = target?.closest(MENUS)
    if (menu) {
      menu.removeAttribute("open")
      menu.querySelector("summary")?.focus()
      return
    }

    if (this.el.hasAttribute("data-has-open")) this.pushEvent("close_section", {})
  },

  // Opens a closed section, with the caret where the click landed if it
  // landed on its words. A keyboard's click has no place on the page. A
  // click on Two columns outside its columns, in the gutter between them
  // or the padding around them, opens the pair, even while one of its
  // columns is open. (Without this hook, the pair's wrapper drops its own
  // click while it holds the open column, `holds_open?`, as that click
  // would come from inside the column too.)
  open(section, e) {
    const key = section.dataset.editSection
    const at = e.detail > 0 ? wordsAt(section, e.clientX, e.clientY) : null

    this.pushEvent("open_section", at ? {key, words: at.path} : {key}, () => {
      if (at) placeCaret(document.getElementById(wordsId(key, at.path)), at.offset)
    })
  },
}

function stop(e) {
  e.preventDefault()
  e.stopPropagation()
}

// The id `Billboard.Sections.Words.id/2` gives the words at `path` in
// the section `key`; keep the two alike.
function wordsId(key, path) {
  return `words-${key}-${path.replaceAll(".", "-")}`
}

// The words under the pointer in a closed section, by their path, and how
// many characters into them it is. The section's overlay takes the click,
// so it lets the pointer through (`bb-edit-probe`) while the browser finds
// the place.
function wordsAt(section, x, y) {
  section.setAttribute("bb-edit-probe", "")

  try {
    const caret = caretAt(x, y)
    if (!caret) return null

    const node = caret.node.nodeType === Node.TEXT_NODE ? caret.node.parentElement : caret.node
    const words = node?.closest("[data-words-at]")
    if (!words || words.closest("[data-edit-section]") !== section) return null

    const range = document.createRange()
    range.setStart(words, 0)
    range.setEnd(caret.node, caret.offset)
    return {path: words.dataset.wordsAt, offset: range.toString().length}
  } finally {
    section.removeAttribute("bb-edit-probe")
  }
}

function caretAt(x, y) {
  if (document.caretPositionFromPoint) {
    const position = document.caretPositionFromPoint(x, y)
    return position && {node: position.offsetNode, offset: position.offset}
  }
  if (document.caretRangeFromPoint) {
    const range = document.caretRangeFromPoint(x, y)
    return range && {node: range.startContainer, offset: range.startOffset}
  }
  return null
}

// Puts the caret `offset` characters into the words `el` holds, once
// they can be typed into. They hold what the closed section showed, so
// the characters line up.
function placeCaret(el, offset) {
  if (!el) return
  if (document.activeElement !== el) el.focus({preventScroll: true})

  const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT)
  let left = offset
  let node

  while ((node = walker.nextNode())) {
    if (left <= node.length) {
      window.getSelection().collapse(node, left)
      return
    }
    left -= node.length
  }

  window.getSelection().collapse(el, el.childNodes.length)
}
