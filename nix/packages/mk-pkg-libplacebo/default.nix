{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "libplacebo";
  packageLock = (import ../../../packages.lock.nix).${name};
  inherit (packageLock) version;

  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix { };

  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };

  lock = import ../../../packages.lock.nix;

  vulkan_headers_tarball = builtins.fetchurl {
    inherit (lock.Vulkan-Headers) url sha256;
  };
  fast_float_tarball = builtins.fetchurl {
    inherit (lock.fast_float) url sha256;
  };
  glad_tarball = builtins.fetchurl {
    inherit (lock.glad) url sha256;
  };
  jinja_tarball = builtins.fetchurl {
    inherit (lock.jinja) url sha256;
  };
  markupsafe_tarball = builtins.fetchurl {
    inherit (lock.markupsafe) url sha256;
  };

  patchedSource =
    pkgs.runCommand "${pname}-patched-source-${version}"
      {
        nativeBuildInputs = [
          pkgs.gnutar
          pkgs.gzip
        ];
      }
      ''
        cp -r ${src} src
        export src=$PWD/src
        chmod -R 777 $src

        rm -rf $src/3rdparty
        mkdir -p $src/3rdparty

        tar -xzvf "${vulkan_headers_tarball}" -C $src/3rdparty/
        mv $src/3rdparty/Vulkan-Headers-* $src/3rdparty/Vulkan-Headers

        tar -xzvf "${fast_float_tarball}" -C $src/3rdparty/
        mv $src/3rdparty/fast_float-* $src/3rdparty/fast_float

        tar -xzvf "${glad_tarball}" -C $src/3rdparty/
        mv $src/3rdparty/glad-* $src/3rdparty/glad

        tar -xzvf "${jinja_tarball}" -C $src/3rdparty/
        mv $src/3rdparty/jinja-* $src/3rdparty/jinja

        tar -xzvf "${markupsafe_tarball}" -C $src/3rdparty/
        mv $src/3rdparty/markupsafe-* $src/3rdparty/markupsafe

        cp -r $src $out
      '';
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  src = patchedSource;
  dontUnpack = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
  ];
  configurePhase = ''
    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out \
      -Dvulkan=disabled
  '';
  buildPhase = ''
    meson compile -vC build
  '';
  installPhase = ''
    meson install -C build
  '';
}
