{
  description = "Ollama with Intel Arc GPU SYCL backend";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = {self, nixpkgs}: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
    lib.mkPackage = {src}: pkgs.callPackage ./package.nix {inherit src;};

    overlays.default = final: _: {
      ollama-sycl = final.callPackage (self + "/package.nix") {};
    };

    nixosModules.default = import ./module.nix;
  };
}
