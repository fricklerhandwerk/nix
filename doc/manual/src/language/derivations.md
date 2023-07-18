# Derivations

The most important built-in function is `derivation`, which is used to describe a single derivation:
a specification for running an executable on precisely defined input files to repeatably produce output files at uniquely determined file system paths.

It takes as input an attribute set, the attributes of which specify the inputs to the process.
It outputs an attribute set, and produces a [store derivation] as a side effect of evaluation.

[store derivation]: @docroot@/glossary.md#gloss-store-derivation

## Input attributes

### Required

- [`name`]{#attr-name} ([String](@docroot@/language/values.md#type-string))

  A symbolic name for the derivation.
  It is added to the [store path] of the corresponding [store derivation] as well as to its [output paths](@docroot@/glossary.md#gloss-output-path).

  [store path]: @docroot@/glossary.md#gloss-store-path

  > **Example**
  >
  > ```nix
  > derivation {
  >   name = "hello";
  >   # ...
  > }
  > ```
  >
  > The store derivation's path will be `/nix/store/<hash>-hello.drv`.
  > The [output](#attr-outputs) paths will be of the form `/nix/store/<hash>-hello[-<output>]`

- [`system`]{#attr-system} ([String](@docroot@/language/values.md#type-string))

  The system type on which the [`builder`](#attr-builder) executable is meant to be run.

  A necessary condition for Nix to build derivations locally is that the `system` attribute matches the current [`system` configuration option].
  It can automatically [build on other platforms](../advanced-topics/distributed-builds.md) by forwarding build requests to other machines.

  [`system` configuration option]: @docroot@/command-ref/conf-file.md#conf-system

  > **Example**
  >
  > Declare a derivation to be built on a specific system type:
  >
  > ```nix
  > derivation {
  >   # ...
  >   system = "x86_64-linux";
  >   # ...
  > }
  > ```

  > **Example**
  >
  > Declare a derivation to be built on the system type that evaluates the expression:
  >
  > ```nix
  > derivation {
  >   # ...
  >   system = builtins.currentSystem;
  >   # ...
  > }
  > ```
  >
  > [`builtins.currentSystem`](@docroot@/language/builtin-constants.md#builtins-currentSystem) has the value of the [`system` configuration option], and defaults to the system type of the current Nix installation.

- [`builder`]{#attr-builder} ([Path](@docroot@/language/values.md#type-path) | [String](@docroot@/language/values.md#type-string))

  Path to an executable that will perform the build.

  > **Example**
  >
  > Use the file located at `/bin/bash` as the builder executable:
  >
  > ```nix
  > derivation {
  >   # ...
  >   builder = "/bin/bash";
  >   # ...
  > };
  > ```

  <!-- -->

  > **Example**
  >
  > Copy a local file to the Nix store for use as the builder executable:
  >
  > ```nix
  > derivation {
  >   # ...
  >   builder = ./builder.sh;
  >   # ...
  > };
  > ```

  <!-- -->

  > **Example**
  >
  > Use a file from another derivation as the builder executable:
  >
  > ```nix
  > let pkgs = import <nixpkgs> {}; in
  > derivation {
  >   # ...
  >   builder = "${pkgs.python}/bin/python";
  >   # ...
  > };
  > ```

### Optional

- [`args`]{#attr-args} ([List](@docroot@/language/values.md#list) of [String](@docroot@/language/values.md#type-string))

  Default: `[ ]`

  Command-line arguments to be passed to the [`builder`](#attr-builder) executable.

  > **Example**
  >
  > Pass arguments to Bash to interpret a shell command:
  >
  > ```nix
  > derivation {
  >   # ...
  >   builder = "/bin/bash";
  >   args = [ "-c" "echo hello world > $out" ];
  >   # ...
  > };
  > ```

- [`outputs`]{#attr-outputs} ([List](@docroot@/language/values.md#list) of [String](@docroot@/language/values.md#type-string))

  Default: `[ "out" ]`

  Symbolic outputs of the derivation.
  Each output name is passed to the [`builder`](#attr-builder) executable as an environment variable with its value set to the corresponding [store path].

  By default, a derivation produces a single output called `out`.
  However, derivations can produce multiple outputs.
  This allows the associated [store objects](@docroot@/glossary.md#gloss-store-object) and their [closures](@docroot@/glossary.md#gloss-closure) to be copied or garbage-collected separately.

  > **Example**
  >
  > Imagine a library package that provides a dynamic library, header files, and documentation.
  > A program that links against such a library doesn’t need the header files and documentation at runtime, and it doesn’t need the documentation at build time.
  > Thus, the library package could specify:
  >
  > ```nix
  > derivation {
  >   # ...
  >   outputs = [ "lib" "dev" "doc" ];
  >   # ...
  > }
  > ```
  >
  > This will cause Nix to pass environment variables `lib`, `dev`, and `doc` to the builder containing the intended store paths of each output.
  > The builder would typically do something like
  >
  > ```bash
  > ./configure \
  >   --libdir=$lib/lib \
  >   --includedir=$dev/include \
  >   --docdir=$doc/share/doc
  > ```
  >
  > for an Autoconf-style package.

  The name of an output is combined with the name of the derivation to create the name part of the output's store path, unless it is `out`, in which case just the name of the derivation is used.

  > **Example**
  >
  >
  > ```nix
  > derivation {
  >   name = "example";
  >   outputs = [ "lib" "dev" "doc" "out" ];
  >   # ...
  > }
  > ```
  >
  > The store derivation path will be `/nix/store/<hash>-example.drv`.
  > The output paths will be
  > - `/nix/store/<hash>-example-lib`
  > - `/nix/store/<hash>-example-dev`
  > - `/nix/store/<hash>-example-doc`
  > - `/nix/store/<hash>-example`

  You can refer to each output of a derivation by selecting it as an attribute.
  The first element of `outputs` determines the *default output* and ends up at the top-level.

  > **Example**
  >
  > Select an output by attribute name:
  >
  > ```nix
  > let
  >   myPackage = derivation {
  >     name = "example";
  >     outputs = [ "lib" "dev" "doc" "out" ];
  >     # ...
  >   };
  > in myPackage.dev
  > ```
  >
  > Since `lib` is the first output, `myPackage` is equivalent to `myPackage.lib`.

  <!-- FIXME: refer to the output attributes when we have one -->

### Optional

- [`args`]{#attr-args} ([List](@docroot@/language/values.md#list) of [String](@docroot@/language/values.md#type-string)) Default: `[ ]`

  Command-line arguments to be passed to the builder.

  Example: `args = [ "-c" "echo hello world > $out" ];`

- [`outputs`]{#attr-outputs} ([List](@docroot@/language/values.md#list) of [String](@docroot@/language/values.md#type-string)) Default: `[ "out" ]`

  Symbolic outputs of the derivation.
  Each output name is passed to the [`builder`](#attr-builder) executable as an environment variable with its value set to the corresponding [output path].

  [output path]: @docroot@/glossary.md#gloss-output-path

  By default, a derivation produces a single output path called `out`.
  However, derivations can produce multiple output paths.
  This allows the associated [store objects](@docroot@/glossary.md#gloss-store-object) and their [closures](@docroot@/glossary.md#gloss-closure) to be copied or garbage-collected separately.

  Examples:

  Imagine a library package that provides a dynamic library, header files, and documentation.
  A program that links against the library doesn’t need the header files and documentation at runtime, and it doesn’t need the documentation at build time.
  Thus, the library package could specify:

  ```nix
  outputs = [ "lib" "headers" "doc" ];
  ```
  
  This will cause Nix to pass environment variables `lib`, `headers`, and `doc` to the builder containing the intended store paths of each output.
  The builder would typically do something like
  
  ```bash
  ./configure \
    --libdir=$lib/lib \
    --includedir=$headers/include \
    --docdir=$doc/share/doc
  ```
  
  for an Autoconf-style package.

  You can refer to each output of a
  derivation by selecting it as an attribute, e.g.
  
  ```nix
  buildInputs = [ pkg.lib pkg.headers ];
  ```
  
  <!-- TODO: move this to the output attributes section when we have one -->

  The first element of `outputs` determines the *default output*.
  Thus, you could also write
  
  ```nix
  buildInputs = [ pkg pkg.headers ];
  ```
  
  since `pkg` is equivalent to `pkg.lib`.


- [`allowedReferences`]{#adv-attr-allowedReferences}

  The optional attribute `allowedReferences` specifies a list of legal
  references (dependencies) of the output of the builder. For example,

  ```nix
  allowedReferences = [];
  ```

  enforces that the output of a derivation cannot have any runtime
  dependencies on its inputs. To allow an output to have a runtime
  dependency on itself, use `"out"` as a list item. This is used in
  NixOS to check that generated files such as initial ramdisks for
  booting Linux don’t have accidental dependencies on other paths in
  the Nix store.

- [`allowedRequisites`]{#adv-attr-allowedRequisites}\
  This attribute is similar to `allowedReferences`, but it specifies
  the legal requisites of the whole closure, so all the dependencies
  recursively. For example,

  ```nix
  allowedRequisites = [ foobar ];
  ```

  enforces that the output of a derivation cannot have any other
  runtime dependency than `foobar`, and in addition it enforces that
  `foobar` itself doesn't introduce any other dependency itself.

- [`disallowedReferences`]{#adv-attr-disallowedReferences}\
  The optional attribute `disallowedReferences` specifies a list of
  illegal references (dependencies) of the output of the builder. For
  example,

  ```nix
  disallowedReferences = [ foo ];
  ```

  enforces that the output of a derivation cannot have a direct
  runtime dependencies on the derivation `foo`.

- [`disallowedRequisites`]{#adv-attr-disallowedRequisites}\
  This attribute is similar to `disallowedReferences`, but it
  specifies illegal requisites for the whole closure, so all the
  dependencies recursively. For example,

  ```nix
  disallowedRequisites = [ foobar ];
  ```

  enforces that the output of a derivation cannot have any runtime
  dependency on `foobar` or any other derivation depending recursively
  on `foobar`.

- [`exportReferencesGraph`]{#adv-attr-exportReferencesGraph}\
  This attribute allows builders access to the references graph of
  their inputs. The attribute is a list of inputs in the Nix store
  whose references graph the builder needs to know. The value of
  this attribute should be a list of pairs `[ name1 path1 name2
  path2 ...  ]`. The references graph of each *pathN* will be stored
  in a text file *nameN* in the temporary build directory. The text
  files have the format used by `nix-store --register-validity`
  (with the deriver fields left empty). For example, when the
  following derivation is built:

  ```nix
  derivation {
    ...
    exportReferencesGraph = [ "libfoo-graph" libfoo ];
  };
  ```

  the references graph of `libfoo` is placed in the file
  `libfoo-graph` in the temporary build directory.

  `exportReferencesGraph` is useful for builders that want to do
  something with the closure of a store path. Examples include the
  builders in NixOS that generate the initial ramdisk for booting
  Linux (a `cpio` archive containing the closure of the boot script)
  and the ISO-9660 image for the installation CD (which is populated
  with a Nix store containing the closure of a bootable NixOS
  configuration).

- [`impureEnvVars`]{#adv-attr-impureEnvVars}\
  This attribute allows you to specify a list of environment variables
  that should be passed from the environment of the calling user to
  the builder. Usually, the environment is cleared completely when the
  builder is executed, but with this attribute you can allow specific
  environment variables to be passed unmodified. For example,
  `fetchurl` in Nixpkgs has the line

  ```nix
  impureEnvVars = [ "http_proxy" "https_proxy" ... ];
  ```

  to make it use the proxy server configuration specified by the user
  in the environment variables `http_proxy` and friends.

  This attribute is only allowed in *fixed-output derivations* (see
  below), where impurities such as these are okay since (the hash
  of) the output is known in advance. It is ignored for all other
  derivations.

  > **Warning**
  >
  > `impureEnvVars` implementation takes environment variables from
  > the current builder process. When a daemon is building its
  > environmental variables are used. Without the daemon, the
  > environmental variables come from the environment of the
  > `nix-build`.

- [`outputHash`]{#adv-attr-outputHash}; [`outputHashAlgo`]{#adv-attr-outputHashAlgo}; [`outputHashMode`]{#adv-attr-outputHashMode}\
  These attributes declare that the derivation is a so-called
  *fixed-output derivation*, which means that a cryptographic hash of
  the output is already known in advance. When the build of a
  fixed-output derivation finishes, Nix computes the cryptographic
  hash of the output and compares it to the hash declared with these
  attributes. If there is a mismatch, the build fails.

  The rationale for fixed-output derivations is derivations such as
  those produced by the `fetchurl` function. This function downloads a
  file from a given URL. To ensure that the downloaded file has not
  been modified, the caller must also specify a cryptographic hash of
  the file. For example,

  ```nix
  fetchurl {
    url = "http://ftp.gnu.org/pub/gnu/hello/hello-2.1.1.tar.gz";
    sha256 = "1md7jsfd8pa45z73bz1kszpp01yw6x5ljkjk2hx7wl800any6465";
  }
  ```

  It sometimes happens that the URL of the file changes, e.g., because
  servers are reorganised or no longer available. We then must update
  the call to `fetchurl`, e.g.,

  ```nix
  fetchurl {
    url = "ftp://ftp.nluug.nl/pub/gnu/hello/hello-2.1.1.tar.gz";
    sha256 = "1md7jsfd8pa45z73bz1kszpp01yw6x5ljkjk2hx7wl800any6465";
  }
  ```

  If a `fetchurl` derivation was treated like a normal derivation, the
  output paths of the derivation and *all derivations depending on it*
  would change. For instance, if we were to change the URL of the
  Glibc source distribution in Nixpkgs (a package on which almost all
  other packages depend) massive rebuilds would be needed. This is
  unfortunate for a change which we know cannot have a real effect as
  it propagates upwards through the dependency graph.

  For fixed-output derivations, on the other hand, the name of the
  output path only depends on the `outputHash*` and `name` attributes,
  while all other attributes are ignored for the purpose of computing
  the output path. (The `name` attribute is included because it is
  part of the path.)

  As an example, here is the (simplified) Nix expression for
  `fetchurl`:

  ```nix
  { stdenv, curl }: # The curl program is used for downloading.

  { url, sha256 }:

  stdenv.mkDerivation {
    name = baseNameOf (toString url);
    builder = ./builder.sh;
    buildInputs = [ curl ];

    # This is a fixed-output derivation; the output must be a regular
    # file with SHA256 hash sha256.
    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = sha256;

    inherit url;
  }
  ```

  The `outputHashAlgo` attribute specifies the hash algorithm used to
  compute the hash. It can currently be `"sha1"`, `"sha256"` or
  `"sha512"`.

  The `outputHashMode` attribute determines how the hash is computed.
  It must be one of the following two values:

    - `"flat"`\
      The output must be a non-executable regular file. If it isn’t,
      the build fails. The hash is simply computed over the contents
      of that file (so it’s equal to what Unix commands like
      `sha256sum` or `sha1sum` produce).

      This is the default.

    - `"recursive"`\
      The hash is computed over the NAR archive dump of the output
      (i.e., the result of [`nix-store --dump`](@docroot@/command-ref/nix-store/dump.md)). In
      this case, the output can be anything, including a directory
      tree.

  The `outputHash` attribute, finally, must be a string containing
  the hash in either hexadecimal or base-32 notation. (See the
  [`nix-hash` command](../command-ref/nix-hash.md) for information
  about converting to and from base-32 notation.)

- [`__contentAddressed`]{#adv-attr-__contentAddressed}
  > **Warning**
  > This attribute is part of an [experimental feature](@docroot@/contributing/experimental-features.md).
  >
  > To use this attribute, you must enable the
  > [`ca-derivations`](@docroot@/contributing/experimental-features.md#xp-feature-ca-derivations) experimental feature.
  > For example, in [nix.conf](../command-ref/conf-file.md) you could add:
  >
  > ```
  > extra-experimental-features = ca-derivations
  > ```

  If this attribute is set to `true`, then the derivation
  outputs will be stored in a content-addressed location rather than the
  traditional input-addressed one.

  Setting this attribute also requires setting
  [`outputHashMode`](#adv-attr-outputHashMode)
  and
  [`outputHashAlgo`](#adv-attr-outputHashAlgo)
  like for *fixed-output derivations* (see above).

- [`passAsFile`]{#adv-attr-passAsFile}\
  A list of names of attributes that should be passed via files rather
  than environment variables. For example, if you have

  ```nix
  passAsFile = ["big"];
  big = "a very long string";
  ```

  then when the builder runs, the environment variable `bigPath`
  will contain the absolute path to a temporary file containing `a
  very long string`. That is, for any attribute *x* listed in
  `passAsFile`, Nix will pass an environment variable `xPath`
  holding the path of the file containing the value of attribute
  *x*. This is useful when you need to pass large strings to a
  builder, since most operating systems impose a limit on the size
  of the environment (typically, a few hundred kilobyte).

- [`preferLocalBuild`]{#adv-attr-preferLocalBuild}\
  If this attribute is set to `true` and [distributed building is
  enabled](../advanced-topics/distributed-builds.md), then, if
  possible, the derivation will be built locally instead of forwarded
  to a remote machine. This is appropriate for trivial builders
  where the cost of doing a download or remote build would exceed
  the cost of building locally.

- [`allowSubstitutes`]{#adv-attr-allowSubstitutes}\
  If this attribute is set to `false`, then Nix will always build this
  derivation; it will not try to substitute its outputs. This is
  useful for very trivial derivations (such as `writeText` in Nixpkgs)
  that are cheaper to build than to substitute from a binary cache.

  > **Note**
  >
  > You need to have a builder configured which satisfies the
  > derivation’s `system` attribute, since the derivation cannot be
  > substituted. Thus it is usually a good idea to align `system` with
  > `builtins.currentSystem` when setting `allowSubstitutes` to
  > `false`. For most trivial derivations this should be the case.

- [`__structuredAttrs`]{#adv-attr-structuredAttrs}\
  If the special attribute `__structuredAttrs` is set to `true`, the other derivation
  attributes are serialised in JSON format and made available to the
  builder via the file `.attrs.json` in the builder’s temporary
  directory. This obviates the need for [`passAsFile`](#adv-attr-passAsFile) since JSON files
  have no size restrictions, unlike process environments.

  It also makes it possible to tweak derivation settings in a structured way; see
  [`outputChecks`](#adv-attr-outputChecks) for example.

  As a convenience to Bash builders,
  Nix writes a script named `.attrs.sh` to the builder’s directory
  that initialises shell variables corresponding to all attributes
  that are representable in Bash. This includes non-nested
  (associative) arrays. For example, the attribute `hardening.format = true`
  ends up as the Bash associative array element `${hardening[format]}`.

- [`outputChecks`]{#adv-attr-outputChecks}\
  When using [structured attributes](#adv-attr-structuredAttrs), the `outputChecks`
  attribute allows defining checks per-output.

  In addition to
  [`allowedReferences`](#adv-attr-allowedReferences), [`allowedRequisites`](#adv-attr-allowedRequisites),
  [`disallowedReferences`](#adv-attr-disallowedReferences) and [`disallowedRequisites`](#adv-attr-disallowedRequisites),
  the following attributes are available:

  - `maxSize` defines the maximum size of the resulting [store object](../glossary.md#gloss-store-object).
  - `maxClosureSize` defines the maximum size of the output's closure.
  - `ignoreSelfRefs` controls whether self-references should be considered when
    checking for allowed references/requisites.

  Example:

  ```nix
  __structuredAttrs = true;

  outputChecks.out = {
    # The closure of 'out' must not be larger than 256 MiB.
    maxClosureSize = 256 * 1024 * 1024;

    # It must not refer to the C compiler or to the 'dev' output.
    disallowedRequisites = [ stdenv.cc "dev" ];
  };

  outputChecks.dev = {
    # The 'dev' output must not be larger than 128 KiB.
    maxSize = 128 * 1024;
  };
  ```

- [`unsafeDiscardReferences`]{#adv-attr-unsafeDiscardReferences}\
  > **Warning**
  > This attribute is part of an [experimental feature](@docroot@/contributing/experimental-features.md).
  >
  > To use this attribute, you must enable the
  > [`discard-references`](@docroot@/contributing/experimental-features.md#xp-feature-discard-references) experimental feature.
  > For example, in [nix.conf](../command-ref/conf-file.md) you could add:
  >
  > ```
  > extra-experimental-features = discard-references
  > ```

  When using [structured attributes](#adv-attr-structuredAttrs), the
  attribute `unsafeDiscardReferences` is an attribute set with a boolean value for each output name.
  If set to `true`, it disables scanning the output for runtime dependencies.

  Example:

  ```nix
  __structuredAttrs = true;
  unsafeDiscardReferences.out = true;
  ```

  This is useful, for example, when generating self-contained filesystem images with
  their own embedded Nix store: hashes found inside such an image refer
  to the embedded store and not to the host's Nix store.

- [Every other attribute]{#attr-others} is passed as an environment variable to the builder.

  Attribute values are translated to environment variables as follows:

    - Strings are passed unchanged.

    - Integral numbers are converted to decimal notation.

    - Floating point numbers are converted to simple decimal or scientific notation with a preset precision.

    - A *path* (e.g., `../foo/sources.tar`) causes the referenced file
      to be copied to the store; its location in the store is put in
      the environment variable. The idea is that all sources should
      reside in the Nix store, since all inputs to a derivation should
      reside in the Nix store.

    - A *derivation* causes that derivation to be built prior to the
      present derivation. The environment variable is set to the [store path] of the derivation's default [output](#attr-outputs).

    - Lists of the previous types are also allowed. They are simply
      concatenated, separated by spaces.

    - `true` is passed as the string `1`, `false` and `null` are
      passed as an empty string.


## Builder execution

The [`builder`](#attr-builder) is executed as follows:

- A temporary directory is created under the directory specified by
  `TMPDIR` (default `/tmp`) where the build will take place. The
  current directory is changed to this directory.

- The environment is cleared and set to the derivation attributes, as
  specified above.

- In addition, the following variables are set:

  - `NIX_BUILD_TOP` contains the path of the temporary directory for
    this build.

  - Also, `TMPDIR`, `TEMPDIR`, `TMP`, `TEMP` are set to point to the
    temporary directory. This is to prevent the builder from
    accidentally writing temporary files anywhere else. Doing so
    might cause interference by other processes.

  - `PATH` is set to `/path-not-set` to prevent shells from
    initialising it to their built-in default value.

  - `HOME` is set to `/homeless-shelter` to prevent programs from
    using `/etc/passwd` or the like to find the user's home
    directory, which could cause impurity. Usually, when `HOME` is
    set, it is used as the location of the home directory, even if
    it points to a non-existent path.

  - `NIX_STORE` is set to the path of the top-level Nix store
    directory (typically, `/nix/store`).

  - `NIX_ATTRS_JSON_FILE` & `NIX_ATTRS_SH_FILE` if `__structuredAttrs`
    is set to `true` for the dervation. A detailed explanation of this
    behavior can be found in the
    [section about structured attrs](./advanced-attributes.md#adv-attr-structuredAttrs).

  - For each output declared in `outputs`, the corresponding
    environment variable is set to point to the intended path in the
    Nix store for that output. Each output path is a concatenation
    of the cryptographic hash of all build inputs, the `name`
    attribute and the output name. (The output name is omitted if
    it’s `out`.)

- If an output path already exists, it is removed. Also, locks are
  acquired to prevent multiple Nix instances from performing the same
  build at the same time.

- A log of the combined standard output and error is written to
  `/nix/var/log/nix`.

- The builder is executed with the arguments specified by the
  attribute `args`. If it exits with exit code 0, it is considered to
  have succeeded.

- The temporary directory is removed (unless the `-K` option was
  specified).

- If the build was successful, Nix scans each output path for
  references to input paths by looking for the hash parts of the input
  paths. Since these are potential runtime dependencies, Nix registers
  them as dependencies of the output paths.

- After the build, Nix sets the last-modified timestamp on all files
  in the build result to 1 (00:00:01 1/1/1970 UTC), sets the group to
  the default group, and sets the mode of the file to 0444 or 0555
  (i.e., read-only, with execute permission enabled if the file was
  originally executable). Note that possible `setuid` and `setgid`
  bits are cleared. Setuid and setgid programs are not currently
  supported by Nix. This is because the Nix archives used in
  deployment have no concept of ownership information, and because it
  makes the build result dependent on the user performing the build.

## Examples

This is a minimal derivation that produces a file with contents `hello world` when built:

```
# derivation.nix
derivation {
    name = "hello";
    system = builtins.currentSystem;
    builder = "/bin/sh";
    args = [ "-c" "echo hello world > $out" ];
  }
```

Run [`nix-instantiate`](@docroot@/command-ref/nix-instantiate.md) to evaluate the Nix expression and output the path to the [store derivation] that is produced as a side effect:

```console
$ nix-instantiate derivation.nix
/nix/store/gra1r61k2mg0hrw3j1cxvagrzkgy8rkz-hello.drv
```

Run [`nix-store --realise`](@docroot@/command-ref/nix-store/realise.md) to build the derivation:

```console
$ nix-store --realise /nix/store/gra1r61k2mg0hrw3j1cxvagrzkgy8rkz-hello.drv
this derivation will be built:
  /nix/store/gra1r61k2mg0hrw3j1cxvagrzkgy8rkz-hello.drv
building '/nix/store/gra1r61k2mg0hrw3j1cxvagrzkgy8rkz-hello.drv'...
/nix/store/p1w78qgjkmdihai23jmi7ldvh1xmg4zq-hello
```

Check the contents of the build result:

```console
$ cat /nix/store/p1w78qgjkmdihai23jmi7ldvh1xmg4zq-hello
hello world
```

Inspect the derivation's output attributes with [`nix repl`](@docroot@/command-ref/new-cli/nix3-repl.md):

```console
$ nix repl
Welcome to Nix 2.16.1. Type :? for help.

nix-repl> drv = import ./derivation.nix

nix-repl> builtins.attrNames drv
[ "all" "args" "builder" "drvAttrs" "drvPath" "name" "out" "outPath" "outputName" "system" "type" ]

nix-repl> drv.drvAttrs
{ args = [ ... ]; builder = "/bin/sh"; name = "hello"; system = "x86_64-darwin"; }
```
