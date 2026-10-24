defmodule Billboard.EditorLive.MessagesTest do
  use ExUnit.Case, async: true

  alias Billboard.EditorLive.Messages

  describe "and_list/1" do
    test "joins one, two, and more words, with the serial comma" do
      assert Messages.and_list([]) == ""
      assert Messages.and_list(["Home"]) == "Home"
      assert Messages.and_list(["Home", "Contact"]) == "Home and Contact"
      assert Messages.and_list(["Home", "Contact", "About"]) == "Home, Contact, and About"

      assert Messages.and_list(["this one", "Home", "Contact", "About"]) ==
               "this one, Home, Contact, and About"
    end
  end
end
