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

    if missed_opts === [] do
      Logger.warning("""
      Direct call of #{inspect(using_mod)}.child_spec/1 may lead to unintended results in the future.

      Update #{inspect(using_mod)}'s entry under your supervisor,
      from:
        [
          #{inspect(using_mod)}
        ]

      To:
        [
          #{inspect(using_mod)}.child_spec()
        ]

      Apologies for the disruption. Context for the issue:
      * https://github.com/sqids/sqids-elixir/issues/32
      """)
    else
      raise """

      The following Sqids options were declared but are not being used:
      * #{inspect(missed_opts, pretty: true)}

      IF YOU START USING THEM NOW IT WILL BREAK COMPATIBILITY WITH PREVIOUSLY ENCODED IDS.

      How can I fix this?

      First step is optional: if you don't want to breaking existing IDs,
      update your #{inspect(using_mod)} options to match the ones in use:

        ```
        defmodule #{using_mod} do
          def child_spec do
            # Was: child_spec(#{inspect(desired_opts)})

            child_spec(
              #{inspect(opts, pretty: true)}
            )
          end
        end
        ```

      Second step: update #{inspect(using_mod)}'s entry under your supervisor, from:
        [
          #{inspect(using_mod)}
        ]

      To:
        [
          #{inspect(using_mod)}.child_spec()
        ]

      Apologies for the disruption. Context for the issue:
      * https://github.com/sqids/sqids-elixir/issues/32
      """
    end
  end
end
