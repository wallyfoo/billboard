// Words typed in place, in the page editor's open section
// (`Billboard.Sections.Words`). What's typed goes to the section's
// editor (`#section-editor`) as `edit_words` after a pause, and at once
// when the field loses the focus. The field's Markdown survives the trip:
// italic and bold (⌘I and ⌘B, Ctrl elsewhere) become `*` and `**`, and
// links, code, pictures, and line breaks already in the words are kept.
// Markdown typed by hand, such as a `[link](https://…)`, is left for the
// server to render. Anything pasted arrives as plain text. Enter finishes
// the field, since every field is a single run of words.
//
// The span is `phx-update="ignore"`, so the server's redraws never touch
// what's typed. The stored words come in its `data-words` and `data-html`
// attributes, which LiveView still updates. Once the field is left alone
// (not focused, nothing unsent, no save on its way, no refusal showing),
// it shows the server's rendering of them: words saved from here, as the
// site will draw them, or words another admin changed.
//
// The server pushes three events:
//   * `words:refused` (with `{section, path, text, message}`), when a
//     change didn't save; the field shows why and keeps what was typed,
//     and points at the reason in the section's issue strip
//     (`aria-errormessage`, the field's id with `-refused`);
//   * `words:retry` (with `{section, paths}`), once a control's change
//     that held the words back has saved; a field still showing its
//     refusal sends its words again;
//   * `words:reset`, on Discard, to show the stored words even mid-typing.
//
// What the hook sets on the span uses plain attributes
// (`bb-words-count`, `bb-words-over`, `bb-words-refused`), not `data-*`
// ones: on an ignored element LiveView removes every `data-*` attribute
// the server didn't render.
const PAUSE = 600

const MAC = /Mac|iPhone|iPad|iPod/.test(navigator.platform)

// Marks hug their words: `**hello **` isn't bold in Markdown, so the
// spaces at a run's edges go outside it, and a run of nothing but spaces
// is only its spaces.
function hug(inner, wrap) {
  const [, lead, core, trail] = inner.match(/^(\s*)([\s\S]*?)(\s*)$/)
  return core ? lead + wrap(core) + trail : inner
}

// Code goes in a fence one backtick longer than any run inside it.
function code(text) {
  const longest = Math.max(0, ...(text.match(/`+/g) || []).map(run => run.length))
  const fence = "`".repeat(longest + 1)
  const pad = /^`|`$/.test(text) ? " " : ""
  return fence + pad + text + pad + fence
}

// An address the server linked by itself goes back as it was typed, but
// only when typing it would link it the same way again: MDEx links
// `https://…` as it is, `www.…` to `http://www.…`, and an email to
// `mailto:`. Anything else, such as `[example.com](https://example.com)`,
// keeps its Markdown link.
function link(text, href) {
  if (!href) return text
  const auto = text.startsWith("www.")
    ? "http://" + text
    : /^[^\s@]+@[^\s@]+$/.test(text)
      ? "mailto:" + text
      : text
  return text === href || auto === href ? text : `[${text}](${href})`
}

const WRAP = {EM: "*", I: "*", STRONG: "**", B: "**"}

// The span's contents as Markdown. A text node's whitespace is a space, as
// the browser draws it (typing two spaces leaves a no-break space); a <br>
// is a new line. Text goes back unescaped on purpose, so Markdown typed by
// hand works; a backslash escape in the stored words doesn't survive an
// edit. And since Markdown's punctuation is smart, straight quotes and
// `--` typed here come back curly and as a dash once the field shows the
// server's rendering, and are stored that way from the next edit on;
// visitors see the same either way.
function toMarkdown(node) {
  let out = ""
  node.childNodes.forEach(child => {
    const name = child.nodeName

    if (child.nodeType === Node.TEXT_NODE) {
      out += child.textContent.replace(/\s+/g, " ")
    } else if (name === "BR") {
      out += "\n"
    } else if (name === "IMG") {
      out += `![${child.getAttribute("alt") || ""}](${child.getAttribute("src") || ""})`
    } else if (name === "A") {
      out += hug(toMarkdown(child), text => link(text, child.getAttribute("href")))
    } else if (name === "CODE") {
      out += hug(child.textContent.replace(/\s+/g, " "), code)
    } else if (WRAP[name]) {
      out += hug(toMarkdown(child), text => WRAP[name] + text + WRAP[name])
    } else {
      out += toMarkdown(child)
    }
  })
  return out
}

// Words as one run, so that what's read from the span and what's stored
// compare alike: Markdown keeps its line breaks, plain words don't.
function normalise(text, markdown) {
  text = (text || "").replace(/\r\n?/g, "\n")
  if (!markdown) return text.replace(/\s+/g, " ").trim()
  return text.replace(/[^\S\n]+/g, " ").replace(/ *\n */g, "\n").trim()
}

// Characters as a reader counts them, as the server's soft limits do
// (`String.length/1` counts graphemes, so an emoji is one).
function length(text) {
  if (typeof Intl.Segmenter !== "function") return [...text].length
  return [...new Intl.Segmenter().segment(text)].length
}

export const InlineWords = {
  mounted() {
    // The words the server has; the rendering the span shows, while it
    // shows one; whether anything's been typed since the last send; and
    // how many sends the server hasn't answered. Only typing sends: what's
    // read back from the span can differ from what's stored (`_a_` reads
    // as `*a*`), and an untouched field shouldn't save.
    this.sent = this.stored()
    this.shown = this.el.dataset.html
    this.dirty = false
    this.inFlight = 0
    this.count()

    this.el.addEventListener("input", e => {
      if (!e.isComposing) this.typed()
    })
    this.el.addEventListener("compositionend", () => this.typed())
    this.el.addEventListener("blur", () => this.blurred())
    this.el.addEventListener("keydown", e => this.key(e))
    this.el.addEventListener("beforeinput", e => this.beforeInput(e))
    this.el.addEventListener("paste", e => this.paste(e))
    // Dragging a selection out would delete it from the field.
    this.el.addEventListener("dragstart", e => e.preventDefault())

    this.handleEvent("words:refused", payload => this.refused(payload))
    this.handleEvent("words:retry", payload => this.retry(payload))
    this.handleEvent("words:reset", () => this.reset())
  },

  // The server's attributes changed. LiveView applies them to an ignored
  // element at once, even while a send is out, so `sync` decides whether
  // to take them.
  updated() {
    if (document.activeElement !== this.el) this.sync()
  },

  reconnected() {
    if (this.dirty) this.send()
  },

  destroyed() {
    clearTimeout(this.timer)
  },

  markdown() {
    return this.el.dataset.markdown === "true"
  },

  stored() {
    return normalise(this.el.dataset.words, this.markdown())
  },

  read() {
    const text = this.markdown() ? toMarkdown(this.el) : this.el.textContent
    return normalise(text, this.markdown())
  },

  typed() {
    // Emptied, the browser often leaves a lone <br>, which would keep the
    // placeholder (`:empty`) from showing.
    if (this.el.childNodes.length === 1 && this.el.firstChild.nodeName === "BR") {
      this.el.replaceChildren()
    }

    this.dirty = true
    this.shown = null
    this.clearRefusal()
    this.count()
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.send(), PAUSE)
  },

  send() {
    clearTimeout(this.timer)
    if (!this.dirty) return

    // Only this section's editor takes its words. While it isn't there,
    // what's typed waits for the next pause or blur.
    const editor = document.getElementById("section-editor")
    if (!editor || editor.dataset.section !== this.el.dataset.section) return

    const text = this.read()
    this.dirty = false
    if (text === this.sent) return

    this.sent = text
    // Counted until the server answers, so a redraw from before this save
    // can't put older words back meanwhile. The promise always settles,
    // with one result per editor it reached.
    this.inFlight++
    this.pushEventTo(editor, "edit_words", {path: this.el.dataset.path, text}).then(results => {
      this.inFlight--
      // Not saved (the connection dropped, or the editor went): the words
      // are unsent again, so the server's don't replace them, and they go
      // at the next pause, blur, or reconnection.
      if (results.length === 0 || results.some(result => result.status === "rejected")) {
        if (this.sent === text) this.sent = null
        this.dirty = true
      }
      if (document.activeElement !== this.el) this.sync()
    })
  },

  blurred() {
    this.send()
    this.sync()
  },

  // The server's words, shown once the field is left alone: not while it
  // has unsent typing, a save on its way, or a refusal to fix. Callers
  // check the focus.
  sync() {
    if (this.dirty || this.inFlight > 0 || this.el.hasAttribute("bb-words-refused")) return
    this.sent = this.stored()
    if (this.el.dataset.html !== this.shown) this.reset()
  },

  // The stored words, in place of what's shown.
  reset() {
    clearTimeout(this.timer)
    this.dirty = false
    // `data-html` is the server's rendering of the stored words, which
    // `Billboard.Sections.Words` escapes and `Markdown` sanitises; that is
    // what makes it safe as HTML. DOMParser only builds it, without
    // running anything, before it is moved into the span.
    const html = new DOMParser().parseFromString(this.el.dataset.html || "", "text/html")
    this.el.replaceChildren(...html.body.childNodes)
    this.shown = this.el.dataset.html
    this.sent = this.stored()
    this.clearRefusal()
    this.count()
  },

  key(e) {
    // 229 is a key an input method is still composing.
    if (e.isComposing || e.keyCode === 229) return

    if (e.key === "Enter") {
      e.preventDefault()
      this.el.blur()
    } else if (e.key === "Escape") {
      this.el.blur()
    } else if ((MAC ? e.metaKey : e.ctrlKey) && !e.shiftKey && !e.altKey) {
      const key = e.key.toLowerCase()
      if (!["b", "i", "u"].includes(key)) return
      // Underline isn't in the site's Markdown, and words stored as plain
      // text take no formatting at all.
      e.preventDefault()
      if (key === "u" || !this.markdown()) return
      // execCommand is deprecated, but nothing has replaced it for
      // contenteditable: it is the only way to set bold and italic, and to
      // insert text, that keeps the browser's undo history. Its `input`
      // event runs `typed`.
      document.execCommand(key === "i" ? "italic" : "bold")
    }
  },

  // What the keys above don't catch: Enter on a phone's keyboard,
  // formatting offered by the browser's own menus, and drops.
  beforeInput(e) {
    const type = e.inputType

    if (type === "insertParagraph" || type === "insertLineBreak") {
      e.preventDefault()
      this.el.blur()
    } else if (type.startsWith("format")) {
      const kept = this.markdown() && (type === "formatBold" || type === "formatItalic")
      if (!kept) e.preventDefault()
    } else if (type === "insertFromDrop" || type === "deleteByDrag") {
      e.preventDefault()
    }
  },

  paste(e) {
    e.preventDefault()
    const text = e.clipboardData.getData("text/plain").replace(/\s+/g, " ")
    document.execCommand("insertText", false, text)
  },

  // The counter under the focused field, drawn by CSS from `bb-words-count`,
  // so the ignored span gains no elements. Past the field's limit the
  // words are "a little long", and still save. Like the server, it counts
  // what a reader sees, not the Markdown.
  count() {
    const limit = Number(this.el.dataset.limit)
    if (!limit) return

    const n = length(this.el.textContent.replace(/\s+/g, " ").trim())
    const over = n > limit
    this.el.setAttribute("bb-words-count", over ? `${n} / ${limit} · a little long` : `${n} / ${limit}`)
    this.el.toggleAttribute("bb-words-over", over)
  },

  refused({section, path, text, message}) {
    if (section !== this.el.dataset.section || path !== this.el.dataset.path) return
    // Typed over since: what's there now gets its own answer.
    if (text !== this.read()) return

    // Nothing saved, so the server still has its words.
    this.sent = this.stored()
    this.el.setAttribute("bb-words-refused", message)
    this.el.setAttribute("aria-invalid", "true")
    this.el.setAttribute("aria-errormessage", `${this.el.id}-refused`)
    // The refusal takes the counter's place until the next keystroke.
    this.el.removeAttribute("bb-words-count")
  },

  // Typed into since the refusal, the words went on their own; otherwise
  // they're still what was refused, and go again as they are.
  retry({section, paths}) {
    if (section !== this.el.dataset.section || !paths.includes(this.el.dataset.path)) return
    if (!this.el.hasAttribute("bb-words-refused")) return

    this.clearRefusal()
    this.sent = null
    this.dirty = true
    this.send()
  },

  clearRefusal() {
    this.el.removeAttribute("bb-words-refused")
    this.el.removeAttribute("aria-invalid")
    this.el.removeAttribute("aria-errormessage")
  },
}
