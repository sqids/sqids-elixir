defmodule Mix.Tasks.UpdateBlocklist do
  @moduledoc false
  use Mix.Task

  def run(_) do
    "blocklist.json"
    |> File.read!()
    |> Jason.decode!()
    |> Enum.reduce(
      _acc0 = "",
      fn word, acc ->
        [acc, word, "\n"]
      end
    )
    |> then(fn blocklist ->
      File.write!("blocklist.txt", blocklist)
    end)
  end
end
