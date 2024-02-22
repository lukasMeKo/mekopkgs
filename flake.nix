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
        jira-edit = pkgs.writeShellApplication {
          name = "jira-edit";
          runtimeInputs = with pkgs;[ curl jq coreutils ];
          text = builtins.readFile ./jira-edit.sh;
        };
      };
      s3cfg = pkgs.writeText ".s3cfg" ''
        [default]
        bucket_location = fra1
        host_base = fra1.digitaloceanspaces.com
        host_bucket = %(bucket)s.fra1.digitaloceanspaces.com
        human_readable_sizes = True
      '';
    in
    {
      inherit overlays packages;
      devShells.default = pkgs.mkShell rec {
        hardeningDisable = [ "fortify" ];
        name = "mekorp-dev";
        nativeBuildInputs = with pkgs; [
          go_1_21
          # use docker from nixos
          postgresql
          kubernetes-helm
          packages.hasura-cli-wrapped
          gh
          jira-cli-go
          packages.jira-edit
          circleci-cli
          yarn
          doctl
          (pkgs.stdenvNoCC.mkDerivation {
            name = "s3cmd-wrapped";
            inherit (s3cmd) pname version meta;
            buildInputs = [ makeWrapper ];
            dontUnpack = true;
            buildPhase = /*bash*/ ''
              mkdir -p $out/bin
              makeWrapper \
                ${pkgs.s3cmd}/bin/${pkgs.s3cmd.pname} \
                $out/bin/${pkgs.s3cmd.pname} \
                --add-flags "-c" \
                --add-flags "${s3cfg}"
            '';
          })
        ];
        # ENV
        passthru.env = rec {
          GOPRIVATE = "github.com/MeKo-Tech";
          PGDATABASE = "appdata";
          PGHOST = "localhost";
          PGPORT = "5433";
          PGPASSWORD = "postgrespassword";
          PGUSER = "postgres";
          PGSSLMODE = "disable";
          PGURL = "postgres://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE}";
          DATABASE_URL = PGURL;
          JIRA_API_USER = "$(pass show api_tokens/jira | sed '1q;d')";
          JIRA_API_TOKEN = "$(pass show api_tokens/jira | sed '2q;d')";
          SQLCMD_USER  = "$(pass show database/ipoffice | sed '2q;d')";
          SQLCMD_PASSWORD  = "$(pass show database/ipoffice | sed '3q;d')";
          PAT = "$(pass show api_tokens/github)";
          CIRCLECI_CLI_TOKEN = "$(pass show api_tokens/circleci)";
          AWS_ACCESS_KEY_ID = "$(pass show api_tokens/digital_ocean | sed '1q;d')";
          AWS_SECRET_ACCESS_KEY = "$(pass show api_tokens/digital_ocean | sed '2q;d')";
          PERSONIO_CLIENT_ID = "$(pass show api_tokens/personio | sed '1q;d')";
          PERSONIO_CLIENT_SECRET = "$(pass show api_tokens/personio | sed '2q;d')";
        };
        shellHook =
          let
            exportEnv = with builtins; concatStringsSep "\n" (attrValues (mapAttrs
              (k: v: ''export ${k}="${v}"'')
              passthru.env));
          in
            /*bash*/
          ''
            ${exportEnv}
            exec fish
          '';
      };
    });
}
