defmodule Sqids.Hacks do
  @moduledoc "Workarounds"
  @moduledoc since: "0.1.2"

  require Logger

  @doc """
  Function to work around Dialyzer warnings on violating
  type opacity when Sqids context is placed in a module attribute, since it
  becomes "hardcoded" from Dialyzer's point of view.
  """
  @spec dialyzed_ctx(term) :: Sqids.t()
  def dialyzed_ctx(sqids), do: Sqids.dialyzed_ctx(sqids)

  @doc false
  @spec raise_exception_if_missed_desired_options(Sqids.opts(), Sqids.opts(), module) :: :ok
  def raise_exception_if_missed_desired_options(opts, desired_opts, using_mod) do
    missed_opts = Sqids.different_opts(opts, desired_opts)
    using_mod_str = inspect(using_mod)

    if missed_opts === [] do
      log_warning("""
      Direct call of #{using_mod_str}.child_spec/1 may lead to unintended results in the future.

      Update #{using_mod_str}'s entry under your supervisor,
      from:
        [
          #{using_mod_str}
        ]

      To:
        [
          #{using_mod_str}.child_spec()
        ]

      Apologies for the disruption. Context for the issue:
      * https://github.com/sqids/sqids-elixir/issues/32
      """)
    else
      raise """
      Inconsistent options for #{using_mod_str}.

      In #{using_mod_str}.child_spec/0 you declared the following options:
      * #{inspect(desired_opts, pretty: true)}

      However, these are the ones in use:
      * #{inspect(opts, pretty: true)}

      Noticeably, the following are missing or different:
      * #{inspect(missed_opts, pretty: true)}

      ---------
      You can solve this by changing #{using_mod_str}.child_spec/0 in either of two ways:
      A) SAFEST: declare the options in use: #{inspect(opts)}, or
      B) UNSAFE: keep the options you intended, WHICH BREAKS COMPATIBILITY
         WITH PREVIOUSLY ENCODED IDs.

      Then, update #{using_mod_str}'s entry under its Supervisor, from:
        [
          #{using_mod_str}
        ]

      To:
        [
          #{using_mod_str}.child_spec()
        ]

      Apologies for the disruption. Context for the issue:
      * https://github.com/sqids/sqids-elixir/issues/32
      """
    end
  end

  if Version.match?(System.version(), "~> 1.11") do
    def log_warning(msg), do: Logger.warning(msg)
  else
    def log_warning(msg), do: Logger.warning(msg)
  end
end
