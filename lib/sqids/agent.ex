defmodule Sqids.Agent do
  @moduledoc """
  Storage for `Sqids` shared state. 
  Like stdlib's [Agent](https://hexdocs.pm/elixir/1.15/Agent.html) but using 
  OTP's [`persistent_term`](https://www.erlang.org/doc/man/persistent_term).
  """

  use GenServer

  require Record

  ## Types

  @type shared_state_init :: {function(), list()}

  @typep init_args :: [
           sqids_module: module,
           shared_state_init: shared_state_init
         ]

  Record.defrecordp(:state, [:shared_state_key])

  @typep state :: record(:state, shared_state_key: atom)

  ## API

  @doc false
  @spec start_link(module, shared_state_init) :: {:ok, pid} | {:error, term}
  def start_link(sqids_module, shared_state_init) do
    init_args = [
      sqids_module: sqids_module,
      shared_state_init: shared_state_init
    ]

    server_name = server_name(sqids_module)
    GenServer.start_link(__MODULE__, init_args, name: server_name)
  end

  @doc false
  @spec get(module) :: term
  def get(sqids_module) do
    shared_state_key = shared_state_key(sqids_module)

    try do
      :persistent_term.get(shared_state_key)
    catch
      :error, :badarg when is_atom(shared_state_key) ->
        raise """
        Sqids shared state not found: your app might be stopped, or
        #{inspect(sqids_module)} may be missing from your supervision tree.
        """
    end
  end

  ## GenServer callbacks

  @doc false
  @impl true
  @spec init(init_args) :: {:ok, state} | no_return()
  def init(init_args) do
    sqids_module = Keyword.fetch!(init_args, :sqids_module)
    {shared_state_init_fun, shared_state_args} = Keyword.fetch!(init_args, :shared_state_init)

    case apply(shared_state_init_fun, shared_state_args) do
      {:ok, shared_state} ->
        # Ensure `:terminate/2` gets called unless we're killed
        _ = Process.flag(:trap_exit, true)

        shared_state_key = shared_state_key(sqids_module)
        :persistent_term.put(shared_state_key, shared_state)
        state = state(shared_state_key: shared_state_key)
        {:ok, state}

      {:error, _} = error ->
        init_fail(error, sqids_module)
    end
  end

  @doc false
  @impl true
  @spec terminate(term, state) :: term
  def terminate(reason, state) do
    # We avoid erasing shared state when stopping for unhealthy reasons to
    # avoid pressuring the GC, as frequent process restarts might be taking
    # place.
    #
    # Namely, when the reason for the crash - whether in us or somewhere else
    # in the supervision tree - hasn't gone away by simply restarting.

    if not crashing?(reason) do
      shared_state_key = state(state, :shared_state_key)
      :persistent_term.erase(shared_state_key)
    end
  end

  ## Internal

  defp init_fail(error, sqids_module) do
    # Use proc_lib:init_fail/2 instead of {:stop, reason} to avoid
    # polluting the logs: our supervisor will fail to start us and this
    # will already produce log messages with the relevant info.
    :proc_lib.init_fail(error, {:exit, :normal})
  catch
    :error, :undef ->
      # Fallback for pre- OTP 26
      server_name = server_name(sqids_module)
      Process.unregister(server_name)
      :proc_lib.init_ack(error)
      :erlang.exit(:normal)
  end

  defp server_name(sqids_module) when is_atom(sqids_module) do
    String.to_atom("sqids.agent." <> Atom.to_string(sqids_module))
  end

  defp shared_state_key(sqids_module) do
    random_suffix = sqids_module |> :erlang.phash2() |> Integer.to_string(36)
    String.to_atom("__$sqids_shared_state." <> Atom.to_string(sqids_module) <> "." <> random_suffix)
  end

  defp crashing?(termination_reason) do
    case termination_reason do
      :normal -> false
      :shutdown -> false
      {:shutdown, _} -> false
      _ -> true
    end
  end
end
