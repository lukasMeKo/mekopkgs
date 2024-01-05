{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    { self
    , nixpkgs
    , flake-utils
    }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
      };
      overlays = {
        hasura-cli-with-cli-ext-wrapper = final: prev: prev // {
          hasura-cli = packages.hasura-cli-wrapped;
        };
      };
      packages = {
        hasura-cli_ext-bin = import ./hasura-cli_ext.nix {
          version = "v2.0.0-alpha.4";
          inherit (pkgs.stdenv) cc mkDerivation;
          inherit (pkgs) fetchurl autoPatchelfHook;
        };
        hasura-cli-wrapped = import ./hasura-cli-wrapped.nix {
          inherit (pkgs.stdenv) mkDerivation;
          inherit (pkgs) hasura-cli makeWrapper;
          inherit (packages) hasura-cli_ext-bin;
        };
      };
    in
    {
      inherit overlays packages;
    });
}
