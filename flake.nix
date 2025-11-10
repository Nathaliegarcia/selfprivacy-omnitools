{
  description = "SelfPrivacy Omni-Tools Module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      nixosModules.default = import ./module.nix;

      configPathsNeeded = import ./config-paths-needed.json;

      metadata = {
        name = "Omni-Tools";
        description = "All-in-one tool container";
        version = "1.0.0";
      };
    };
}
