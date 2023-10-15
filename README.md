# [Sqids Elixir](https://sqids.org/elixir)

[![](https://img.shields.io/hexpm/v/sqids.svg?style=flat)](https://hex.pm/packages/sqids)
[![](https://github.com/sqids/sqids-elixir/actions/workflows/ci.yml/badge.svg)](https://github.com/sqids/sqids-elixir/actions/workflows/ci.yml)
[![Elixir Versions](https://img.shields.io/badge/Compatible%20with%20Elixir-1.12%20to%201.15-blue)](https://elixir-lang.org/)

[Sqids](https://sqids.org/python) (*pronounced "squids"*) is a small library
that lets you **generate unique IDs from numbers**. It's good for link
shortening, fast & URL-safe ID generation and decoding back into numbers for
quicker database lookups.

Features:

- **Encode multiple numbers** - generate short IDs from one or several non-negative numbers
- **Quick decoding** - easily decode IDs back into numbers
- **Unique IDs** - generate unique IDs by shuffling the alphabet once
- **ID padding** - provide minimum length to make IDs more uniform
- **URL safe** - auto-generated IDs do not contain common profanity
- **Randomized output** - Sequential input provides nonconsecutive IDs
- **Many implementations** - Support for [40+ programming languages](https://sqids.org/)

## 🧰 Use-cases

Good for:

- Generating IDs for public URLs (eg: link shortening)
- Generating IDs for internal systems (eg: event tracking)
- Decoding for quicker database lookups (eg: by primary keys)

Not good for:

- Sensitive data (this is not an encryption library)
- User IDs (can be decoded revealing user count)

## 🚀 Getting started

The package can be installed by adding `sqids` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sqids, "~> 0.1"} # FIXME not uploaded yet
  ]
end
```

## 👩‍💻 Examples

    iex> # Create a new module to handle your `Sqids` config:
    iex> {:ok, sqids} = Sqids.new()
    iex> # Simple encode & decode:
    iex> numbers = [1, 2, 3]
    iex> id = Sqids.encode!(sqids, numbers)
    iex> ^numbers = Sqids.decode!(sqids, id)

> **Note**
> 🚧 Because of the algorithm's design, **multiple IDs can decode back into the
> same sequence of numbers**. If it's important to your design that IDs are
> canonical, you have to manually re-encode decoded numbers and check that the
> generated ID matches.

Enforce a *minimum* length for IDs:

    iex> {:ok, sqids} = Sqids.new(min_length: 10)
    iex> numbers = [1, 2, 3]
    iex> id = Sqids.encode!(sqids, numbers)
    iex> ^id = "86Rf07xd4z"
    iex> ^numbers = Sqids.decode!(sqids, id)

Randomize IDs by providing a custom alphabet:

    iex> {:ok, sqids} = Sqids.new(alphabet: "FxnXM1kBN6cuhsAvjW3Co7l2RePyY8DwaU04Tzt9fHQrqSVKdpimLGIJOgb5ZE")
    iex> numbers = [1, 2, 3]
    iex> id = Sqids.encode!(sqids, numbers)
    iex> ^id = "B4aajs"
    iex> ^numbers = Sqids.decode!(sqids, id)

Prevent specific words from appearing anywhere in the auto-generated IDs:

    iex> {:ok, sqids} = Sqids.new(blocklist: ["86Rf07"])
    iex> numbers = [1, 2, 3]
    iex> id = Sqids.encode!(sqids, numbers)
    iex> ^id = "se8ojk"
    iex> ^numbers = Sqids.decode!(sqids, id)

Place `sqids` under your supervision tree for convenience:

    iex> defmodule MyApp.Sqids do
    iex>   use Sqids
    iex> end
    iex>
    iex> defmodule MyApp.Application do
    iex>   # ...
    iex>   def start(_type, _args) do
    iex>      children = [
    iex>        MyApp.Sqids # or {MyApp.Sqids, opts}
    iex>        # ...
    iex>      ]
    iex>
    iex>      opts = [strategy: :one_for_one, name: Foobar.Supervisor]
    iex>      Supervisor.start_link(children, opts)
    iex>   end
    iex> end
    iex> {:ok, _} = MyApp.Application.start(:normal, [])
    iex>
    iex>
    iex> numbers = [1, 2, 3]
    iex> id = MyApp.Sqids.encode!(numbers)
    iex> ^id = "86Rf07"
    iex> ^numbers = MyApp.Sqids.decode!(id)

Check the [API reference](https://hexdocs.pm/sqids/api-reference.html) for more details.

## 📝 License

[MIT](LICENSE)
