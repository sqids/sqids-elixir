#!/usr/bin/env elixir

defmodule Sqids.BlocklistUpdater do
  @moduledoc false

  import ExUnit.Assertions

  require Logger

  @path_of_canonical_json Path.join(["deps", "sqids_blocklist", "output", "blocklist.json"])
  @path_of_txt_copy Path.join("priv", "blocklist.txt")
  @path_of_changelog "CHANGELOG.md"

  def run do
    install_script_deps()
    update_blocklist_repo()
    convert_from_canonical_list()
    maybe_update_changelog()
  end

  defp install_script_deps do
    log_step("Installing and compiling this script's dependencies...")

    Mix.install([
      {:changelog_updater, github: "g-andrade/changelog_updater", branch: "master"},
      {:jason, "~> 1.4"}
    ])
  end

  defp update_blocklist_repo do
    log_step("Updating blocklist repo...")
    {:ok, _} = run_cmd(~w(mix deps.update sqids_blocklist))
    :ok
  end

  defp convert_from_canonical_list do
    log_step("Converting canonical blocklist...")

    blocklist =
      @path_of_canonical_json
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

    File.write!(@path_of_txt_copy, blocklist)
  end

  defp maybe_update_changelog do
    {:ok, git_status} = run_cmd(~w(git status -s #{@path_of_txt_copy}))

    case git_status |> String.split(["\n", "\r"]) |> Enum.join("") |> String.trim() do
      "" ->
        :ok

      changed ->
        log_step("Updating changelog: #{inspect(changed)}")
        changelog = File.read!(@path_of_changelog)
        {:ok, new_blocklist_ref} = run_cmd(~w(git rev-parse --short HEAD), cd: Path.join("deps", "sqids_blocklist"))
        change_entry = "default blocklist to #{new_blocklist_ref}"
        {:ok, changelog} = :changelog_updater.insert_change(change_entry, changelog)
        File.write!(@path_of_changelog, changelog)
    end
  end

  defp run_cmd([cmd | args], opts \\ []) do
    cd = opts[:cd]

    cmd_opts = [stderr_to_stdout: true]

    cmd_opts =
      if cd do
        [{:cd, cd} | cmd_opts]
      else
        cmd_opts
      end

    case System.cmd(cmd, args, cmd_opts) do
      {output, 0} ->
        {:ok, output}

      {_, exit_status} ->
        {:error, exit_status}
    end
  end

  defp log_step(msg), do: Logger.info("\n#{msg}\n")
end

Sqids.BlocklistUpdater.run()
