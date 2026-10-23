defmodule Billboard.Component.Field do
  @moduledoc """
  One `field` in a component's `editor` section: a setting the editor
  draws in the section's controls, a note, or a part, list, or
  photograph it changes. `Billboard.Component` documents the options.
  """
  defstruct [
    :name,
    :as,
    :label,
    :hint,
    :hide_when,
    :bound,
    :options,
    :only_on,
    :min,
    :max,
    :part,
    :item_label,
    :ratio,
    :text,
    :link,
    :from,
    more: false,
    optional: false,
    except: [],
    __identifier__: nil,
    __spark_metadata__: nil
  ]

  @type t :: %__MODULE__{}
end
