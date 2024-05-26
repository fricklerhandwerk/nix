{ lib
, fetchurl
, stdenv
, releaseTools
, autoconf-archive
, autoreconfHook
, aws-sdk-cpp
, boehmgc
, buildPackages
, nlohmann_json
, bison
, boost
, brotli
, bzip2
, curl
, cmake
, editline
, readline
, fileset
, flex
, git
, gtest
, jq
, doxygen
, libarchive
, libcpuid
, libgit2
, libseccomp
, libsodium
, man
, lowdown
, mdbook
, mdbook-linkcheck
, mercurial
, meson
, ninja
, openssh
, openssl
, pkg-config
, python3
, rapidcheck
, sqlite
, util-linux
, xz

, busybox-sandbox-shell ? null

# Configuration Options
#:
# This probably seems like too many degrees of freedom, but it
# faithfully reflects how the underlying configure + make build system
# work. The top-level flake.nix will choose useful combinations of these
# options to CI.

, pname ? "nix"

, versionSuffix ? ""
, officialRelease ? false

# Whether to build Nix. Useful to skip for tasks like (a) just
# generating API docs or (b) testing existing pre-built versions of Nix
, doBuild ? true

# Run the unit tests as part of the build. See `installUnitTests` for an
# alternative to this.
, doCheck ? __forDefaults.canRunInstalled

# Run the functional tests as part of the build.
, doInstallCheck ? test-client != null || __forDefaults.canRunInstalled

# Check test coverage of Nix. Probably want to use with with at least
# one of `doCHeck` or `doInstallCheck` enabled.
, withCoverageChecks ? false

# Whether to build the regular manual
, enableManual ? __forDefaults.canRunInstalled

# Whether to use garbage collection for the Nix language evaluator.
#
# If it is disabled, we just leak memory, but this is not as bad as it
# sounds so long as evaluation just takes places within short-lived
# processes. (When the process exits, the memory is reclaimed; it is
# only leaked *within* the process.)
#
# Temporarily disabled on Windows because the `GC_throw_bad_alloc`
# symbol is missing during linking.
, enableGC ? !stdenv.hostPlatform.isWindows

# Whether to enable Markdown rendering in the Nix binary.
, enableMarkdown ? !stdenv.hostPlatform.isWindows

# Which interactive line editor library to use for Nix's repl.
#
# Currently supported choices are:
#
# - editline (default)
# - readline
, readlineFlavor ? if stdenv.hostPlatform.isWindows then "readline" else "editline"

# Whether to build the internal/external API docs, can be done separately from
# everything else.
, enableInternalAPIDocs ? forDevShell
, enableExternalAPIDocs ? forDevShell

# Whether to install unit tests. This is useful when cross compiling
# since we cannot run them natively during the build, but can do so
# later.
, installUnitTests ? doBuild && !__forDefaults.canExecuteHost

# For running the functional tests against a pre-built Nix. Probably
# want to use in conjunction with `doBuild = false;`.
, test-daemon ? null
, test-client ? null

# Avoid setting things that would interfere with a functioning devShell
, forDevShell ? false

# Not a real argument, just the only way to approximate let-binding some
# stuff for argument defaults.
, __forDefaults ? {
    canExecuteHost = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
    canRunInstalled = doBuild && __forDefaults.canExecuteHost;
  }
}:

let
  version = lib.fileContents ./.version + versionSuffix;

  # selected attributes with defaults, will be used to define some
  # things which should instead be gotten via `finalAttrs` in order to
  # work with overriding.
  attrs = {
    inherit doBuild doCheck doInstallCheck;
  };

  mkDerivation =
    if withCoverageChecks
    then
      # TODO support `finalAttrs` args function in
      # `releaseTools.coverageAnalysis`.
      argsFun:
         releaseTools.coverageAnalysis (let args = argsFun args; in args)
    else stdenv.mkDerivation;
in

mkDerivation (finalAttrs: let

  inherit (finalAttrs)
    doCheck
    doInstallCheck
    ;

  doBuild = !finalAttrs.dontBuild;

  # Either running the unit tests during the build, or installing them
  # to be run later, requiresthe unit tests to be built.
  buildUnitTests = doCheck || installUnitTests;


  # Reimplementation of Nixpkgs' Meson cross file, with some additions to make
  # it actually work.
  mesonCrossFile =
    let
      cpuFamily =
        platform:
        with platform;
        if isAarch32 then
          "arm"
        else if isx86_32 then
          "x86"
        else
          platform.uname.processor;
    in
    builtins.toFile "lix-cross-file.conf" ''
      [properties]
      # Meson is convinced that if !buildPlatform.canExecute hostPlatform then we cannot
      # build anything at all, which is not at all correct. If we can't execute the host
      # platform, we'll just disable tests and doc gen.
      needs_exe_wrapper = false

      [binaries]
      # Meson refuses to consider any CMake binary during cross compilation if it's
      # not explicitly specified here, in the cross file.
      # https://github.com/mesonbuild/meson/blob/0ed78cf6fa6d87c0738f67ae43525e661b50a8a2/mesonbuild/cmake/executor.py#L72
      cmake = 'cmake'
    '';

  configureFiles = fileset.unions [ ./.version ];

  topLevelBuildFiles = fileset.unions ([
    ./meson.build
    ./meson.options
    ./meson
    ./scripts/meson.build
  ]);

  functionalTestFiles = fileset.unions [
    ./tests/functional
    ./tests/unit
    (fileset.fileFilter (f: lib.strings.hasPrefix "nix-profile" f.name) ./scripts)
  ];

  propagatedBuildInputs = [
    nlohmann_json
  ] ++ lib.optional enableGC boehmgc;
in {
  inherit pname version;

  src =
    let
      baseFiles = fileset.fileFilter (f: f.name != ".gitignore") ./.;
    in
      fileset.toSource {
        root = ./.;
        fileset = fileset.intersection baseFiles (fileset.unions ([
          configureFiles
          topLevelBuildFiles
          functionalTestFiles
          # For configure
          ./.version
          ./configure.ac
          ./m4
          # TODO: do we really need README.md? It doesn't seem used in the build.
          ./README.md
          # This could be put behind a conditional
          ./maintainers/local.mk
          # For make, regardless of what we are building
          ./local.mk
          ./Makefile
          ./Makefile.config.in
          ./mk
          (fileset.fileFilter (f: lib.strings.hasPrefix "nix-profile" f.name) ./scripts)
        ] ++ lib.optionals doBuild [
          ./doc
          ./misc
          ./precompiled-headers.h
          ./src
          ./COPYING
          ./scripts/local.mk
        ] ++ lib.optionals buildUnitTests [
          ./doc/manual
        ] ++ lib.optionals enableInternalAPIDocs [
          ./doc/internal-api
        ] ++ lib.optionals enableExternalAPIDocs [
          ./doc/external-api
        ] ++ lib.optionals (enableInternalAPIDocs || enableExternalAPIDocs) [
          # Source might not be compiled, but still must be available
          # for Doxygen to gather comments.
          ./src
          ./tests/unit
        ] ++ lib.optionals buildUnitTests [
          ./tests/unit
        ] ++ lib.optionals doInstallCheck [
          ./tests/functional
        ]));
      };

  VERSION_SUFFIX = versionSuffix;

  outputs = [ "out" ]
    ++ lib.optional doBuild "dev"
    # If we are doing just build or just docs, the one thing will use
    # "out". We only need additional outputs if we are doing both.
    ++ lib.optional (doBuild && (enableManual || enableInternalAPIDocs || enableExternalAPIDocs)) "doc"
    ++ lib.optional installUnitTests "check";

  mesonFlags =
    lib.optionals stdenv.hostPlatform.isLinux [
      # You'd think meson could just find this in PATH, but busybox is in buildInputs,
      # which don't actually get added to PATH. And buildInputs is correct over
      # nativeBuildInputs since this should be a busybox executable on the host.
      "-Dsandbox-shell=${lib.getExe' busybox-sandbox-shell "busybox"}"
    ]
    ++ lib.optional stdenv.hostPlatform.isStatic "-Denable-embedded-sandbox-shell=true"
    ++ lib.optional (finalAttrs.dontBuild) "-Denable-build=false"
    ++ [
      # mesonConfigurePhase automatically passes -Dauto_features=enabled,
      # so we must explicitly enable or disable features that we are not passing
      # dependencies for.
      (lib.mesonEnable "internal-api-docs" internalApiDocs)
      (lib.mesonBool "enable-tests" finalAttrs.doCheck)
      (lib.mesonBool "enable-docs" canRunInstalled)
    ]
    ++ lib.optional (stdenv.hostPlatform != stdenv.buildPlatform) "--cross-file=${mesonCrossFile}";

  # We only include CMake so that Meson can locate toml11, which only ships CMake dependency metadata.
  dontUseCmakeConfigure = true;

  nativeBuildInputs = [
    autoconf-archive
    autoreconfHook
    pkg-config
  ] ++ lib.optionals doBuild [
    bison
    flex
    ninja
    cmake
    meson
    python3
  ] ++ lib.optionals enableManual [
    (lib.getBin lowdown)
    mdbook
    mdbook-linkcheck
  ] ++ lib.optionals doInstallCheck [
    git
    mercurial
    openssh
    man # for testing `nix-* --help`
  ] ++ lib.optionals (doInstallCheck || enableManual) [
    jq # Also for custom mdBook preprocessor.
  ] ++ lib.optional stdenv.hostPlatform.isLinux util-linux
    ++ lib.optional (enableInternalAPIDocs || enableExternalAPIDocs) doxygen
  ;

  buildInputs = lib.optionals doBuild [
    boost
    brotli
    bzip2
    curl
    libarchive
    libgit2
    libsodium
    openssl
    sqlite
    xz
    ({ inherit readline editline; }.${readlineFlavor})
  ] ++ lib.optionals enableMarkdown [
    lowdown
  ] ++ lib.optionals buildUnitTests [
    gtest
    rapidcheck
  ] ++ lib.optional stdenv.isLinux libseccomp
    ++ lib.optional stdenv.hostPlatform.isx86_64 libcpuid
    # There have been issues building these dependencies
    ++ lib.optional (stdenv.hostPlatform == stdenv.buildPlatform && (stdenv.isLinux || stdenv.isDarwin))
      (aws-sdk-cpp.override {
        apis = ["s3" "transfer"];
        customMemoryManagement = false;
      })
  ;

  dontBuild = !attrs.doBuild;
  doCheck = attrs.doCheck;

  disallowedReferences = [ boost ];

  preConfigure = lib.optionalString (doBuild && ! stdenv.hostPlatform.isStatic) (
    ''
      # Copy libboost_context so we don't get all of Boost in our closure.
      # https://github.com/NixOS/nixpkgs/issues/45462
      mkdir -p $out/lib
      cp -pd ${boost}/lib/{libboost_context*,libboost_thread*,libboost_system*} $out/lib
      rm -f $out/lib/*.a
    '' + lib.optionalString stdenv.hostPlatform.isLinux ''
      chmod u+w $out/lib/*.so.*
      patchelf --set-rpath $out/lib:${stdenv.cc.cc.lib}/lib $out/lib/libboost_thread.so.*
    '' + lib.optionalString stdenv.hostPlatform.isDarwin ''
      for LIB in $out/lib/*.dylib; do
        chmod u+w $LIB
        install_name_tool -id $LIB $LIB
        install_name_tool -delete_rpath ${boost}/lib/ $LIB || true
      done
      install_name_tool -change ${boost}/lib/libboost_system.dylib $out/lib/libboost_system.dylib $out/lib/libboost_thread.dylib
    ''
  );

  mesonBuildType = "debugoptimized";

  mesonCheckFlags = [
    "--suite=check"
    "--print-errorlogs"
  ];

  # Make sure the internal API docs are already built, because mesonInstallPhase
  # won't let us build them there. They would normally be built in buildPhase,
  # but the internal API docs are conventionally built with doBuild = false.
  preInstall = lib.optional internalApiDocs ''
    meson ''${mesonBuildFlags:-} compile "$installTargets"
  '';

  enableParallelBuilding = true;

  makeFlags = "profiledir=$(out)/etc/profile.d PRECOMPILE_HEADERS=1";

  installTargets = lib.optional doBuild "install"
    ++ lib.optional enableInternalAPIDocs "internal-api-html"
    ++ lib.optional enableExternalAPIDocs "external-api-html";

  installFlags = "sysconfdir=$(out)/etc";

  # In this case we are probably just running tests, and so there isn't
  # anything to install, we just make an empty directory to signify tests
  # succeeded.
  installPhase = if finalAttrs.installTargets != [] then null else ''
    mkdir -p $out
  '';

  postInstall = lib.optionalString doBuild (
    lib.optionalString stdenv.hostPlatform.isStatic ''
      mkdir -p $out/nix-support
      echo "file binary-dist $out/bin/nix" >> $out/nix-support/hydra-build-products
    '' + lib.optionalString stdenv.isDarwin ''
      install_name_tool \
      -change ${boost}/lib/libboost_context.dylib \
      $out/lib/libboost_context.dylib \
      $out/lib/libnixutil.dylib
    ''
  ) + lib.optionalString enableManual ''
    mkdir -p ''${!outputDoc}/nix-support
    echo "doc manual ''${!outputDoc}/share/doc/nix/manual" >> ''${!outputDoc}/nix-support/hydra-build-products
  '' + lib.optionalString enableInternalAPIDocs ''
    mkdir -p ''${!outputDoc}/nix-support
    echo "doc internal-api-docs $out/share/doc/nix/internal-api/html" >> ''${!outputDoc}/nix-support/hydra-build-products
  ''
    + lib.optionalString enableExternalAPIDocs ''
    mkdir -p ''${!outputDoc}/nix-support
    echo "doc external-api-docs $out/share/doc/nix/external-api/html" >> ''${!outputDoc}/nix-support/hydra-build-products
  '';

  # So the check output gets links for DLLs in the out output.
  preFixup = lib.optionalString (stdenv.hostPlatform.isWindows && builtins.elem "check" finalAttrs.outputs) ''
    ln -s "$check/lib/"*.dll "$check/bin"
    ln -s "$out/bin/"*.dll "$check/bin"
  '';

  doInstallCheck = attrs.doInstallCheck;

  installCheckFlags = "sysconfdir=$(out)/etc";
  # Work around buggy detection in stdenv.
  installCheckTarget = "installcheck";

  installCheckPhase = ''
    runHook preInstallCheck
    flagsArray=($mesonInstallCheckFlags "''${mesonInstallCheckFlagsArray[@]}")
    meson test --no-rebuild "''${flagsArray[@]}"
    runHook postInstallCheck
  '';

  # Needed for tests if we are not doing a build, but testing existing
  # built Nix.
  preInstallCheck =
    lib.optionalString (! doBuild) ''
      mkdir -p src/nix-channel
    ''
    # See https://github.com/NixOS/nix/issues/2523
    # Occurs often in tests since https://github.com/NixOS/nix/pull/9900
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
    '';

  separateDebugInfo = !stdenv.hostPlatform.isStatic;

  # TODO `releaseTools.coverageAnalysis` in Nixpkgs needs to be updated
  # to work with `strictDeps`.
  strictDeps = !withCoverageChecks;

  hardeningDisable = lib.optional stdenv.hostPlatform.isStatic "pie";

  meta = {
    platforms = lib.platforms.unix ++ lib.platforms.windows;
    mainProgram = "nix";
    broken = !(lib.all (a: a) [
      # We cannot run or install unit tests if we don't build them or
      # Nix proper (which they depend on).
      (installUnitTests -> doBuild)
      (doCheck -> doBuild)
      # The build process for the manual currently requires extracting
      # data from the Nix executable we are trying to document.
      (enableManual -> doBuild)
    ]);
  };

} // lib.optionalAttrs withCoverageChecks {
  lcovFilter = [ "*/boost/*" "*-tab.*" ];

  hardeningDisable = ["fortify"];

  NIX_CFLAGS_COMPILE = "-DCOVERAGE=1";

  dontInstall = false;
} // lib.optionalAttrs (test-daemon != null) {
  NIX_DAEMON_PACKAGE = test-daemon;
} // lib.optionalAttrs (test-client != null) {
  NIX_CLIENT_PACKAGE = test-client;
})
