defmodule Billboard.UploadsTest do
  @moduledoc """
  Photographs stored, listed, and deleted. "stores a real image" writes
  to `Uploads.dir()`, and one test changes application env, so not async.
  """
  use ExUnit.Case, async: false

  import Billboard.Test.Env

  alias Billboard.Uploads

  @png <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13>>

  setup do
    path = Path.join(System.tmp_dir!(), "upload-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)
    %{path: path}
  end

  test "stores a real image under a random name", %{path: path} do
    File.write!(path, @png)
    assert {:ok, "/uploads/" <> name} = Uploads.store_image(path)
    stored = Path.join(Uploads.dir(), name)
    on_exit(fn -> File.rm(stored) end)

    assert String.ends_with?(name, ".png")
    assert File.exists?(stored)
  end

  test "rejects a file that is not an image, whatever its name", %{path: path} do
    File.write!(path, "<script>alert(1)</script>")
    assert {:error, :not_an_image} = Uploads.store_image(path)
  end

  test "says where to set the directory when none is set" do
    put_env_for_test(:billboard, :uploads_dir, nil)

    assert_raise ArgumentError, ~r/config :billboard, uploads_dir:/, fn -> Uploads.dir() end
  end

  describe "list/1 and delete/2" do
    setup do
      root = Path.join(System.tmp_dir!(), "uploads-#{System.unique_integer([:positive])}")
      dir = Path.join(root, "uploads")
      File.mkdir_p!(Path.join(dir, "a"))
      on_exit(fn -> File.rm_rf(root) end)
      %{dir: dir, root: root}
    end

    defp put(dir, name, at \\ ~U[2026-09-01 10:00:00Z]) do
      path = Path.join(dir, name)
      File.write!(path, @png)
      File.touch!(path, DateTime.to_unix(at))
      name
    end

    test "lists uploads with their size and when they arrived", %{dir: dir} do
      name = put(dir, "#{Ecto.UUID.generate()}.png")

      assert [%{name: ^name, path: path, bytes: 12, uploaded_at: ~U[2026-09-01 10:00:00Z]}] =
               Uploads.list(dir)

      assert path == "/uploads/#{name}"
    end

    test "leaves out anything that isn't an upload", %{dir: dir} do
      put(dir, ".DS_Store")
      put(dir, "notes.txt")
      File.mkdir_p!(Path.join(dir, "#{Ecto.UUID.generate()}.png"))

      assert Uploads.list(dir) == []
    end

    test "lists nothing when the directory doesn't exist yet", %{dir: dir} do
      assert Uploads.list(Path.join(dir, "missing")) == []
    end

    test "deletes an upload by name", %{dir: dir} do
      name = put(dir, "#{Ecto.UUID.generate()}.png")

      assert :ok = Uploads.delete(name, dir)
      refute File.exists?(Path.join(dir, name))
      assert {:error, :not_found} = Uploads.delete(name, dir)
    end

    test "refuses names that could reach outside the directory", %{dir: dir, root: root} do
      # Real files at each target, so a missing guard would delete them.
      targets = [
        Path.join(root, put(root, "secret.png")),
        Path.join(dir, put(dir, "a/b.png")),
        Path.join(dir, put(dir, "x.exe"))
      ]

      for name <- ["../secret.png", "a/b.png", "x.exe", "x.png\n", nil] do
        assert {:error, :not_found} = Uploads.delete(name, dir)
      end

      for target <- targets, do: assert(File.exists?(target))
    end

    test "knows an upload's name from anything else" do
      assert Uploads.upload_name?("#{Ecto.UUID.generate()}.webp")
      refute Uploads.upload_name?("x.png\n")
      refute Uploads.upload_name?("..png")
    end
  end
end
