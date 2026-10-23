defmodule Billboard.Uploads do
  @moduledoc """
  Stores uploaded photographs on local disk, and serves them under
  `/uploads` through `Billboard.Plugs.UploadsStatic`. It also lists and
  deletes them, for a site's own sweep of the unused ones, which only the
  site can write: it alone knows which of its tables point at a
  photograph.

  The directory comes from `config :billboard, :uploads_dir`. In
  production, set it from `UPLOADS_DIR` in `config/runtime.exs`, pointing
  at a persistent volume: files written inside the release are lost on
  every deploy.
  """

  require Logger

  @image_signatures [
    {".jpg", <<0xFF, 0xD8, 0xFF>>},
    {".png", <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>}
  ]

  @doc """
  The directory photographs are stored in, from
  `config :billboard, :uploads_dir`. Raises, naming the fix, when it
  isn't set.
  """
  def dir do
    Application.get_env(:billboard, :uploads_dir) ||
      raise ArgumentError,
            "billboard doesn't know where photographs go. Add " <>
              "`config :billboard, uploads_dir: Path.expand(\"../priv/uploads\", __DIR__)` " <>
              "to config/config.exs, and in production set it from UPLOADS_DIR in " <>
              "config/runtime.exs, on a volume that outlives a deploy"
  end

  @doc """
  Copies a temporary upload into the uploads directory under a random name,
  after checking its first bytes really are a JPEG, PNG, or WebP image.
  Returns the public path.
  """
  def store_image(tmp_path) do
    with {:ok, ext} <- sniff_image(tmp_path) do
      name = "#{Ecto.UUID.generate()}#{ext}"
      File.mkdir_p!(dir())
      File.cp!(tmp_path, Path.join(dir(), name))
      {:ok, public_path(name)}
    end
  end

  @name ~r/\A[\w-]+\.(jpg|png|webp)\z/

  @doc """
  Whether `name` is one `store_image/1` could have made. Anything else in
  the directory, such as a `.DS_Store`, isn't an upload, and a name with a
  slash or `..` never reaches the filesystem.
  """
  def upload_name?(name), do: is_binary(name) and Regex.match?(@name, name)

  @doc "The Postgres twin of `upload_name?/1`: a pattern capturing the name in an upload's path."
  def path_pattern, do: "/uploads/([A-Za-z0-9_-]+\\.(?:jpg|png|webp))"

  @doc """
  The uploads on disk, as `%{name, path, bytes, uploaded_at}`, in no
  particular order, so callers sort. `uploaded_at` is the file's
  modification time. A symlink isn't an upload, even one with an upload's
  name. A directory that can't be read lists as empty, which only delays
  removals.
  """
  def list(dir \\ dir()) do
    case File.ls(dir) do
      {:ok, names} ->
        for name <- names,
            upload_name?(name),
            {:ok, %{type: :regular} = stat} <- [File.lstat(Path.join(dir, name), time: :posix)] do
          %{
            name: name,
            path: public_path(name),
            bytes: stat.size,
            uploaded_at: DateTime.from_unix!(stat.mtime)
          }
        end

      {:error, :enoent} ->
        []

      {:error, reason} ->
        Logger.warning("Couldn't list uploads in #{dir}: #{inspect(reason)}")
        []
    end
  end

  @doc """
  Deletes the upload called `name`. Returns `{:error, :not_found}` for a
  name that isn't an upload's, or one that's already gone. Any other
  filesystem error comes back as `{:error, reason}`.
  """
  def delete(name, dir \\ dir()) do
    with true <- upload_name?(name),
         :ok <- File.rm(Path.join(dir, name)) do
      :ok
    else
      false -> {:error, :not_found}
      {:error, :enoent} -> {:error, :not_found}
      {:error, _reason} = error -> error
    end
  end

  defp public_path(name), do: "/uploads/" <> name

  defp sniff_image(path) do
    head = File.open!(path, [:read, :binary], &IO.binread(&1, 12))

    case head do
      <<"RIFF", _size::binary-size(4), "WEBP">> ->
        {:ok, ".webp"}

      _ ->
        Enum.find_value(@image_signatures, {:error, :not_an_image}, fn {ext, sig} ->
          if is_binary(head) and String.starts_with?(head, sig), do: {:ok, ext}
        end)
    end
  end
end
