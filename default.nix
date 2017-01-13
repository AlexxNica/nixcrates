with import <nixpkgs> { };
with stdenv.lib;

let
  allCrates = recurseIntoAttrs (callPackage ../nix-crates-index { });
  normalizeName = builtins.replaceStrings [ "-"] ["_"];
  depsStringCalc = pkgs.lib.fold ( dep: str: "${str} --extern ${normalizeName dep.name}=${dep}/lib${normalizeName dep.name}.rlib") "";
  cratesDeps = pkgs.lib.fold ( recursiveDeps : newCratesDeps: newCratesDeps ++ recursiveDeps.cratesDeps  );
  # symlinkCalc creates a mylibs folder and symlinks all the buildInputs's libraries from there for rustc to link them into the final binary
  symlinkCalc = pkgs.lib.fold ( dep: str: "${str} ln -fs ${dep}/lib${normalizeName dep.name}.rlib mylibs/ \n") "mkdir mylibs\n ";
  rustNightly = rustNightlyBin.rustc;
in

rec {
  nixcrates = stdenv.mkDerivation rec {
    name = "nixcrates";
    src = ./src;

    deps = [ allCrates.walkdir allCrates.rustc-serialize allCrates.rustache ];
    crates = depsStringCalc deps;
    crateDeps = cratesDeps [] deps;
    buildInputs = with allCrates; crateDeps ++ deps;
    buildPhase = ''
      ${symlinkCalc buildInputs}
#       du -a
      ${rustNightly}/bin/rustc $src/main.rs --crate-type "bin" --emit=dep-info,link --crate-name nixcrates -L dependency=mylibs ${depsStringCalc deps}
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp nixcrates $out/bin
    '';
  };

  getopts-example = stdenv.mkDerivation rec {
    name = "getopts-example";
    src = ./example/src;

    depsString = depsStringCalc buildInputs;
    buildInputs = with allCrates; [ getopts ];

    buildPhase = ''
      ${rustNightly}/bin/rustc $src/main.rs ${depsString}
      ./main

    '';
    installPhase=''
      mkdir $out
    '';
  };

  # flate2 example uses native c code (not using nipxkgs's packages but brings its own bundled c-code instead)
  # FIXME still fails to build
  flate2-example = stdenv.mkDerivation rec {
    name = "flate2-example";
    src = ./example/src2;
    depsString = depsStringCalc buildInputs;
    buildInputs = with allCrates; [ flate2 libc miniz-sys gcc ];

    buildPhase = ''
      ${symlinkCalc buildInputs}
#       du -a mylibs
#       ls -lathr mylibs
#       echo ${depsString}
# [pid 14162] execve("/nix/store/fff3jbf9vbqhmf6qjrmzhliq516x7yrf-rustc-1.11.0/bin/rustc", ["rustc", "src/main.rs", "--crate-name", "hello_flate2", "--crate-type", "bin", "-g", "--out-dir", "/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug", "--emit=dep-info,link", "-L", "dependency=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug", "-L", "dependency=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug/deps", "--extern", "flate2=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug/deps/libflate2-d719035eaa7c6a88.rlib", "-L", "native=/home/joachim/Desktop/projects/fractalide/fetchUrl/hello_flate2/target/debug/build/miniz-sys-60c8d67696f63a43/out"], [/* 105 vars */]) = 0

      ${rustNightly}/bin/rustc $src/main.rs --crate-type "bin" --emit=dep-info,link --crate-name main -L dependency=mylibs ${depsString} -L native= #flate2=${allCrates.flate2_0_2_14}/libflate2.rlib
      ./main
      exit 1
    '';
  };

  tar-example = stdenv.mkDerivation rec {
    name = "tar-example";
    src = ./example/src3;
    buildInputs = with allCrates; [ tar filetime libc xattr ];
    buildPhase = ''
      ${symlinkCalc buildInputs}

      echo "hu" > file1.txt
      echo "bar" > file2.txt
      echo "batz" > file3.txt

      ${rustNightly}/bin/rustc $src/main.rs --crate-type "bin" --emit=dep-info,link --crate-name main -L dependency=mylibs --extern tar=${allCrates.tar}/libtar.rlib
#       du -a
#       /run/current-system/sw/bin/ldd ./main
      ./main
#       du -a
      if [ -f foo.tar ]; then
        echo -e "---------\nSUCCESS: tar-example was executed successfully!   \n--------"
      else
        echo "FAIL: not working!"
      fi
    '';
    installPhase=''
      mkdir $out
    '';
  };
  # with this you can do: nix-build -A allCrates.getopts to compile single dependencies
  inherit allCrates;

  allTargets = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ nixcrates nom capnp regex json tiny_http tar-example getopts-example rustfbp rusqlite ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0432 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0432
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ tokio-core pnacl-build-helper heapsize_plugin serde_yaml ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0463 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0463
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ kernel32-sys user32-sys ws2_32-sys gl_generator wayland-scanner
    dbghelp-sys dwmapi-sys xmltree tendril piston-viewport vecmath rpassword jsonrpc-core ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0460 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0460
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ regex iron gfx_core nickel ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  cant_find_build = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [  advapi32-sys gdi32-sys miniz-sys libz-sys rust-crypto backtrace-sys ole32-sys ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0425 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0425
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ env_logger serde_codegen_internals log4rs post-expansion fern ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0259 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0259
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ quickersort ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0412 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0412
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ aster quasi clippy_lints];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  E0455 = stdenv.mkDerivation rec { # https://doc.rust-lang.org/error-index.html#E0455
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ core-graphics objc-foundation fsevent-sys ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  issue27783 = stdenv.mkDerivation rec { # https://github.com/rust-lang/rust/issues/27783
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ term_size gl_common clock_ticks ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  no_such_file = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ mime_guess ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  not_found_librs = stdenv.mkDerivation rec { # note must build first time (run nix-collect-garbage to replicate error)
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ sdl2 c_vec protobuf compiletest_rs xdg untrusted ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  NotPresent = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ openssl-sys html5ever-atoms harfbuzz-sys ring # (ring depends on "untrusted" that seems to be why it fails)
    ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  PkgConfig = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ libsodium-sys glib-sys dbus cairo-sys-rs ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  EnvVarNotSet = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ x11 bzip2-sys expat-sys servo-freetype-sys4 ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  UnstableLibraryFeature = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ mmap ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  MismatchSHA256 = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ multipart ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
  Retired = stdenv.mkDerivation rec {
    name="allTargets";
    version="1";
    buildInputs = with allCrates; [ tenatious ];
    src = ./.;
    buildPhase=''
    '';
    installPhase=''
      mkdir $out
    '';
  };
}
