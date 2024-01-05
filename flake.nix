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
        };
      };
    in
    {
      inherit overlays packages;
      devShells.default = pkgs.mkShell rec {
        name = "mekorp-dev";
        nativeBuildInputs = with pkgs; [
          go_1_20
          # use docker from nixos
          postgresql
          packages.hasura-cli-wrapped
        ];
        # ENV
        passthru.env = rec {
          PGDATABASE = "appdata";
          PGHOST = "localhost";
          PGPORT = "5433";
          PGPASSWORD = "postgrespassword";
          PGUSER = "postgres";
          PGSSLMODE = "disable";
          PGURL = "postgres://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}";
        };
        shellHook =
          let
            exportEnv = with builtins; concatStringsSep "\n" (attrValues (mapAttrs
              (k: v: ''export ${k}="${v}"'')
              passthru.env));
          in
            /*bash*/ ''
            ${exportEnv}
          '';
      };
    });
}
