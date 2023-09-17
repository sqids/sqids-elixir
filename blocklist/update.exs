#!/usr/bin/env elixir

defmodule Sqids.BlocklistUpdater do
  @moduledoc false
  import ExUnit.Assertions

  require Logger

  @canonical_path "blocklist/canonical.json"
  @one_word_per_line_path "blocklist/one_word_per_line.txt"

  def run do
    install_script_deps()
    update_blocklist_repo()
    generate_canonical_list()
    convert_from_canonical_list()
  end

  defp install_script_deps do
    log_step("Installing and compiling this script's dependencies...")

    Mix.install([{:jason, "~> 1.4"}])
  end

  defp update_blocklist_repo do
    log_step("Updating blocklist repo...")
    :ok = run_cmd(~w(mix deps.update sqids_blocklist))
  end

  defp generate_canonical_list do
    log_step("Generating canonical list...")

    file = File.stream!(@canonical_path)

    :ok =
      run_cmd(
        ~w(cargo run),
        cd: "deps/sqids_blocklist",
        into: file
      )
  end

  defp convert_from_canonical_list do
    log_step("Converting canonical blocklist...")

    @canonical_path
    |> File.read!()
    |> Jason.decode!()
    |> :lists.usort()
    |> Enum.reduce(
      _acc0 = "",
      fn word, acc ->
        refute match?(
                 {true, _},
                 {String.contains?(word, ["\n", "\r"]), word}
               )

        [acc, word, "\n"]
      end
    )
    |> then(fn blocklist ->
      File.write!(@one_word_per_line_path, blocklist)
    end)
  end

  defp run_cmd([cmd | args], opts \\ []) when is_list(args) do
    cd = opts[:cd]
    into = opts[:into] || IO.stream(:stderr, :line)
    stderr_to_stdout = !opts[:into]

    cmd_opts = [into: into, stderr_to_stdout: stderr_to_stdout]

    cmd_opts =
      if cd do
        cmd_opts ++ [cd: cd]
      else
        cmd_opts
      end

    case System.cmd(cmd, args, cmd_opts) do
      {_, 0} ->
        :ok

      {_, exit_status} ->
        {:error, exit_status}
    end
  end

  defp log_step(msg), do: Logger.info("\n#{msg}\n")
end

Sqids.BlocklistUpdater.run()
