defmodule Billboard.ActionsTest do
  @moduledoc "The kinds of action a site offers, a link to one of its pages among them."
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Actions

  test "a site with no actions module has links alone" do
    put_site!(actions: nil)
    assert Actions.kinds() == [link: [label: "A page on this site", words: :own]]
    assert Actions.offered?(:link)
    refute Actions.offered?(:call)
    assert Actions.label_hint() == nil
  end

  test "a site's kinds come after the link, unless it places the link itself" do
    put_site!(actions: Billboard.Test.Actions)

    assert Keyword.keys(Actions.kinds()) == [:visit, :link, :call]
    assert Actions.kinds()[:call] == [label: "Call the shop", words: :site]
    assert Actions.kinds()[:visit][:only_on] == [:item]
    assert Actions.label_hint() == "A visit left blank says “Visit”."
  end
end
