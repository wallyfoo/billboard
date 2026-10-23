defmodule Billboard.FormatTest do
  @moduledoc "Dates and shortened copy, as the stock sections set them."
  use ExUnit.Case, async: true

  alias Billboard.Format

  describe "trim/2" do
    test "leaves copy that fits as it is" do
      assert Format.trim("Book now", 8) == "Book now"
    end

    test "trims at a word boundary, the ellipsis included in the limit" do
      assert Format.trim("Book your next cut today", 12) == "Book your…"
      assert String.length(Format.trim(String.duplicate("word ", 60), 180)) <= 180
    end

    test "cuts a first word too long to fit, and stays within the limit" do
      assert Format.trim("Supercalifragilistic", 10) == "Supercali…"
      assert String.length(Format.trim("Supercalifragilistic", 10)) == 10
    end
  end

  describe "date/1" do
    test "writes the day, the month in full, and the year" do
      assert Format.date(~D[2026-10-23]) == "23 October 2026"
    end
  end
end
