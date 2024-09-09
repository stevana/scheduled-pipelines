let
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/24.05.tar.gz";
  pkgs = import nixpkgs { config = {}; overlays = []; };
in

pkgs.mkShell {
  packages = with pkgs; [
    haskell.compiler.ghc9101
    haskellPackages.cabal-fmt
    stylish-haskell
    pandoc
    plantuml-c4
    zlib
  ];
}
