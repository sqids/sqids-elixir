# [Sqids Elixir](https://sqids.org/elixir)

[![Hex downloads](https://img.shields.io/hexpm/dt/sqids.svg)](https://hex.pm/packages/sqids)
[![License](https://img.shields.io/hexpm/l/sqids.svg)](https://github.com/sqids/sqids-elixir/blob/main/LICENSE)
[![Elixir Versions](https://img.shields.io/badge/Elixir-1.7%20to%201.17-blue)](https://elixir-lang.org/)
[![Erlang Versions](https://img.shields.io/badge/Erlang%2FOTP-21.3%20to%2027-blue)](https://www.erlang.org)
[![CI status](https://github.com/sqids/sqids-elixir/actions/workflows/ci.yml/badge.svg)](https://github.com/sqids/sqids-elixir/actions/workflows/ci.yml)

[Sqids](https://sqids.org/elixir) (*pronounced "squids"*) for Elixir is a
library for generating YouTube-looking IDs from numbers. These IDs are short,
can be generated with a custom alphabet and are collision-free. [Read
more](https://sqids.org/faq).

This is what they look like in URLs:
```
https://example.com/LchsyE
https://example.com/Uxmq8Y
https://example.com/3CwlG7
```

## Why use them?

The main purpose is visual: you can use Sqids if you'd like to expose integer
identifiers in your software as alphanumeric strings.

### ✅ Use Cases

* **Link shortening**: default alphabet is safe to use in URLs, and common
  profanity is avoided
* **Event IDs**: collision-free ID generation
* **Database lookups**: by decoding IDs back into numbers

### ❌ Not Good For

* **Sensitive data**: this it not an encryption library
* **User IDs** generated in sequence, or equivalents, which can be decoded,
  revealing user count and/or business growth

## Features

* 🆔 Generate short IDs from non-negative integers
* 🤬 Avoid common profanity in generated IDs
* 🎲 IDs appear randomized when encoding incremental numbers
* 🧰 Decode IDs back into numbers
* ↔️ Generate IDs with a minimum length, making them more uniform
* 🔤 Generate IDs with a custom alphabet
* 👩‍💻 Available in [multiple programming languages](https://sqids.org)
* 👯‍♀️ Equally configured implementations produce the same IDs
* 🍻 Small library with a permissive license

## 🚀 Getting started

[![Latest version](https://img.shields.io/hexpm/v/sqids.svg?style=flat)](https://hex.pm/packages/sqids)
[![API reference](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/sqids/)
[![Last commit](https://img.shields.io/github/last-commit/sqids/sqids-elixir.svg)](https://github.com/sqids/sqids-elixir/commits/main)

The package can be installed by adding `sqids` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:sqids, "~> 0.1.0"}
  ]
end
```

## 👩‍💻 Examples

### Default configuration

```elixir
iex> {:ok, sqids} = Sqids.new()
iex> numbers = [1, 2, 3]
iex> id = Sqids.encode!(sqids, numbers)
iex> ^id = "86Rf07"
iex> ^numbers = Sqids.decode!(sqids, id)
```

> **Note**
> 🚧 Because of the algorithm's design, **multiple IDs can decode back into the
> same sequence of numbers**. If it's important to your design that IDs are
> canonical, you have to re-encode decoded numbers and check that the
> generated ID matches.

### Convenience: create context at compile time

Having to pass `sqids` context on every encode and decode call can be
cumbersome.

To work around this, you can create context with `new!/0` or `new!/1` at compile
time if all options are either default or known at that moment:

```elixir
iex> defmodule MyApp.CompileTimeSqids do
iex>   import Sqids.Hacks, only: [dialyzed_ctx: 1]
iex>   @context Sqids.new!()
iex>
iex>   def encode!(numbers), do: Sqids.encode!(dialyzed_ctx(@context), numbers)
iex>   def decode!(id), do: Sqids.decode!(dialyzed_ctx(@context), id)
iex> end
iex>
iex> numbers = [1, 2, 3]
iex> id = MyApp.CompileTimeSqids.encode!(numbers)
iex> ^id = "86Rf07"
iex> ^numbers = MyApp.CompileTimeSqids.decode!(id)
```

### Convenience: place context under your supervision tree

This also allows you to encode and decode IDs without managing context.

If not all options are known at compile time but you'd still like to not pass
context on every encode and decode call, you can `use Sqids`, which will
generate functions that retrieve the underlying context transparently and call
`Sqids` for you.

The context is stored in a uniquely named
[`persistent_term`](https://www.erlang.org/doc/man/persistent_term), managed by
a uniquely named process, which is to be placed under your application's
supervision tree. Both names are derived from your module's.

```elixir
iex> defmodule MyApp.SupervisedSqids do
iex>   use Sqids
iex>   # Functions encode/1, encode!/1, decode/1, decode!/1, etc
iex>   # will be generated.
iex>
iex>   @impl true
iex>   def child_spec() do
iex>       child_spec([
iex>           # alphabet: alphabet,     # Custom alphabet
iex>           # min_length: min_length, # Padding
iex>           # blocklist: blocklist    # Custom blocklist
iex>       ])
iex>   end
iex> end
iex>
iex>
iex> defmodule MyApp.Application do
iex>   # ...
iex>   def start(_type, _args) do
iex>      children = [
iex>        MyApp.SupervisedSqids.child_spec(),
iex>        # ...
iex>      ]
iex>
iex>      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
iex>      Supervisor.start_link(children, opts)
iex>   end
iex> end
iex>
iex>
iex> {:ok, _} = MyApp.Application.start(:normal, [])
iex> numbers = [1, 2, 3]
iex> id = MyApp.SupervisedSqids.encode!(numbers)
iex> ^id = "86Rf07"
iex> ^numbers = MyApp.SupervisedSqids.decode!(id)
```

### Custom configuration

Examples of custom configuration follow. All options are applicable to the two
convenient ways of creating context shown above.

Note that different options can be used together for further customization.
Check the [API reference](https://hexdocs.pm/sqids/api-reference.html) for
details.

### Padding: generated IDs have a minimum length

```elixir
iex> {:ok, sqids} = Sqids.new(min_length: 10)
iex> numbers = [1, 2, 3]
iex> id = Sqids.encode!(sqids, numbers)
iex> ^id = "86Rf07xd4z" # instead of "86Rf07"
iex> ^numbers = Sqids.decode!(sqids, id)
```

(Older IDs, for ex. generated with a previous configuration in which padding
was not yet enforced or a different length was configured, can still be
decoded.)

### Using a custom alphabet

Generated IDs will only contain characters from the chosen alphabet, which is
sensitive to both case and order.

```elixir
iex> {:ok, sqids} = Sqids.new(alphabet: "cdefhjkmnprtvwxy2345689")
iex> numbers = [1, 2, 3]
iex> id = Sqids.encode!(sqids, numbers)
iex> ^id = "wc9xdr"
iex> ^numbers = Sqids.decode!(sqids, id)
```

In order to decode IDs back, they need to be in the same alphabet.

For practical reasons, the standard limits custom alphabets to ASCII
characters.

(Thanks to @benjiwheeler for his suggestion for [a set of unambiguous looking
characters](https://stackoverflow.com/questions/11919708/set-of-unambiguous-looking-letters-numbers-for-user-input/58098360#58098360)
on Stack Overflow.)

### Profanity: excluding specific words from the IDs

As an example, set [the ID generated with default
options](#default-configuration) as the blocklist.

```elixir
iex> {:ok, sqids} = Sqids.new(blocklist: ["86Rf07"])
iex> numbers = [1, 2, 3]
iex> id = Sqids.encode!(sqids, numbers)
iex> ^id = "se8ojk" # see how "86Rf07" was censored
iex> ^numbers = Sqids.decode!(sqids, id)
```

## 📚 API Reference

The API reference can be found on
[HexDocs](https://hexdocs.pm/sqids/api-reference.html).

## 📝 License

[MIT](LICENSE)
