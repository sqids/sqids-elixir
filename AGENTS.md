# Sqids Elixir — Agent Guide

Sqids is a library for generating short, YouTube-looking IDs from non-negative integers. IDs are reversible (decode back to numbers), collision-free, and profanity-filtered via a blocklist.

## Commands

```bash
mix test              # run test suite
mix format            # format code (via Styler)
mix credo             # lint
mix dialyzer          # type-check
mix docs              # generate HexDocs
elixir scripts/update_blocklist.exs  # pull latest blocklist from sqids/sqids-blocklist
```

## Structure

```
lib/sqids.ex           # public API: new/1, encode/2, decode/2, and bang variants
lib/sqids/agent.ex     # GenServer powering the `use Sqids` macro (supervised usage)
lib/sqids/alphabet.ex  # alphabet shuffling and manipulation
lib/sqids/blocklist.ex # profanity blocklist filtering
lib/sqids/hacks.ex     # Dialyzer workaround for opaque-type compile-time contexts
priv/blocklist.txt     # ~560 blocked words, one per line
scripts/update_blocklist.exs  # fetches canonical blocklist JSON and rewrites priv/blocklist.txt
test/sqids_test.exs    # main test file
test/extra/            # compile-time Dialyzer correctness checks
```

## Key conventions

**Cross-language compatibility.** Sqids is a multi-language project. Equally configured implementations must produce identical IDs. Any change to encoding/decoding logic must remain consistent with the [spec](https://github.com/sqids/sqids-spec).

**Three usage modes, all tested.** Tests run every scenario through three access patterns — direct API (`Sqids.new/1` + passing context), `new!` with a module attribute, and `use Sqids` (supervised, via `persistent_term`) — to ensure all public surfaces behave identically.

**Warnings as errors in test.** `elixirc_options` sets `warnings_as_errors: true` under `Mix.env() == :test`. Keep the code warning-free.

**Elixir version range.** The library targets Elixir 1.11+, but Credo, Dialyxir, and Styler are only added as deps on 1.12+ and 1.14+ respectively. Avoid syntax or stdlib calls that break on 1.11.
