# Name

`nix-store --realise` - realise specified store paths

# Synopsis

`nix-store` {`--realise` | `-r`} *paths…* [`--dry-run`]

# Description

Ensure that the given [store paths] are [valid].

Realisation of a store path works as follows:

- If the path is already valid, do nothing.
- If the path leads to a [store derivation]:
  1. Realise the store derivation file itself, as a regular store path.
  2. Realise its [output paths]:
    - Try to fetch from [substituters] the [store objects] associated with the output paths in the store derivation's [closure].
      - With [content-addressed derivations] (experimental): Determine the output paths to realise by querying build certificates in the [Nix database].
    - For any store paths that cannot be substituted, produce the required store objects by first realising all outputs of the derivation's dependencies and then running the derivation's build instructions.
- Otherwise:
 - Try to fetch the associated [store objects] in the paths' [closure] from the [substituters].

If no substitutes are available and no store derivation is given, realisation fails.

[store paths]: ../glossary.md#gloss-store-path
[valid]: ../glossary.md#gloss-validity
[store derivation]: ../glossary.md#gloss-store-derivation
[output paths]: ../glossary.md#gloss-output-path
[store objects]: ../glossary.md#gloss-store-object
[closure]: ../glossary.md#gloss-closure
[substituters]: @docroot/command-ref/conf-file.md#conf-substituters
[content-addressed derivations]: @docroot@/contributing/experimental-features.md#xp-feature-ca-derivations
[Nix database]: @docroot@/glossary.md#gloss-nix-database

The resulting paths are printed on standard output.
For non-derivation arguments, the argument itself is printed.

## Special exit codes

  - `100`\
    Generic build failure, the builder process returned with a non-zero
    exit code.

  - `101`\
    Build timeout, the build was aborted because it did not complete
    within the specified `timeout`.

  - `102`\
    Hash mismatch, the build output was rejected because it does not
    match the [`outputHash` attribute of the
    derivation](@docroot@/language/advanced-attributes.md).

  - `104`\
    Not deterministic, the build succeeded in check mode but the
    resulting output is not binary reproducible.

With the `--keep-going` flag it's possible for multiple failures to
occur, in this case the 1xx status codes are or combined using binary
or.

    1100100
       ^^^^
       |||`- timeout
       ||`-- output hash mismatch
       |`--- build failure
       `---- not deterministic

# Options

  - `--dry-run`\
    Print on standard error a description of what packages would be
    built or downloaded, without actually performing the operation.

  - `--ignore-unknown`\
    If a non-derivation path does not have a substitute, then silently
    ignore it.

  - `--check`\
    This option allows you to check whether a derivation is
    deterministic. It rebuilds the specified derivation and checks
    whether the result is bitwise-identical with the existing outputs,
    printing an error if that’s not the case. The outputs of the
    specified derivation must already exist. When used with `-K`, if an
    output path is not identical to the corresponding output from the
    previous build, the new output path is left in
    `/nix/store/name.check.`

{{#include ./opt-common.md}}

{{#include ../opt-common.md}}

{{#include ../env-common.md}}

# Examples

This operation is typically used to build [store derivation]s produced by
[`nix-instantiate`](@docroot@/command-ref/nix-instantiate.md):

[store derivation]: @docroot@/glossary.md#gloss-store-derivation

```console
$ nix-store -r $(nix-instantiate ./test.nix)
/nix/store/31axcgrlbfsxzmfff1gyj1bf62hvkby2-aterm-2.3.1
```

This is essentially what [`nix-build`](@docroot@/command-ref/nix-build.md) does.

To test whether a previously-built derivation is deterministic:

```console
$ nix-build '<nixpkgs>' -A hello --check -K
```

Use [`nix-store --read-log`](./read-log.md) to show the stderr and stdout of a build:

```console
$ nix-store --read-log $(nix-instantiate ./test.nix)
```
