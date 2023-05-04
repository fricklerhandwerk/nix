# Name

`nix-store --export` - export store paths to a Nix Archive

## Synopsis

`nix-store` `--export` *paths…*

## Description

The operation `--export` writes a serialisation of the specified [store paths](@docroot@/glossary.md#gloss-store-path) to standard output in a format that can be imported into another Nix store with [`nix-store --import`](./import.md).
This is like [`nix-store --dump`](./dump.md), except that the NAR archive produced by that command doesn’t contain the necessary meta-information to allow it to be imported into another Nix store (namely, the [set of references](@docroot@/glossary.md#gloss-reference) of the path).

This command does not produce a [closure](@docroot@/glossary.md#gloss-closure) of the specified paths.
If a store path references other store paths that are missing in the target Nix store, the import will fail.

{{#include ./opt-common.md}}

{{#include ../opt-common.md}}

{{#include ../env-common.md}}

# Examples

To copy a whole closure of a `./result` directory produced by [`nix-build`](../nix-build.md), do something like:

```console
$ nix-store --export $(nix-store --query --requisites ./result) > out
```

To import the whole closure again, run:

```console
$ nix-store --import < out
```
