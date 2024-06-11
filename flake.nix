{
  inputs = {
    nixpkgs.url = "nixpkgs";
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
          text = builtins.readFile ./scipts/jira-edit.sh;
        };
        dbutils = pkgs.writeShellApplication {
          name = "dbu";
          runtimeInputs = with pkgs;[ doctl jq ];
          text = builtins.readFile ./scipts/dbu.sh;
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
      devShells =
        let
          baseShell = rec {
            hardeningDisable = [ "fortify" ];
            name = "mekorp-dev";
            nativeBuildInputs = (with packages; [
              hasura-cli-wrapped
              jira-edit
              dbutils
            ]) ++ (with pkgs; [
              go_1_22
              # use docker from nixos
              postgresql
              minikube
              minio
              kubernetes-helm
              gh
              minikube
              kubectl
              jira-cli-go
              gotestsum
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
            ]);
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
              SQLCMD_USER = "$(pass show database/ipoffice | sed '2q;d')";
              SQLCMD_PASSWORD = "$(pass show database/ipoffice | sed '3q;d')";
              PAT = "$(pass show api_tokens/github)";
              CIRCLECI_CLI_TOKEN = "$(pass show api_tokens/circleci)";
              DIGITALOCEAN_ACCESS_TOKEN = "$(pass show api_tokens/digital_ocean | sed '1q;d')";
              AWS_ACCESS_KEY_ID = "$(pass show api_tokens/digital_ocean | sed '2q;d')";
              AWS_SECRET_ACCESS_KEY = "$(pass show api_tokens/digital_ocean | sed '3q;d')";
              PERSONIO_CLIENT_ID = "$(pass show api_tokens/personio | sed '1q;d')";
              PERSONIO_CLIENT_SECRET = "$(pass show api_tokens/personio | sed '2q;d')";
            };
            passthru.dotEnv = pkgs.writeText ".env" (with builtins; concatStringsSep "\n" (attrValues (mapAttrs (k: v: ''export ${k}="${v}"'') passthru.env)));
            passthru.fishHook = /*fish*/ ''
              eval (minikube completion fish)
              eval (helm completion fish)
              # eval (hasura completion fish)
              eval (gh completion fish)
              eval (doctl completion fish)
              eval (kubectl completion fish)
              eval (jira completion fish)
              # eval (circleci completion fish)

              abbr --add "kd" "kubectl --context mekorp-dev"
              abbr --add "kp" "kubectl --context mekorp-prod"
              abbr --add "kl" "kubectl --context minikube"
            '';
            passthru.fishCmd = "fish -C ${pkgs.lib.strings.escapeShellArg passthru.fishHook}";
          };
        in
        {
          default = pkgs.mkShell (baseShell // {
            shellHook = /*bash*/ ''
              . ${baseShell.passthru.dotEnv}
              exec ${baseShell.passthru.fishCmd}
            '';
          });
          recursive = pkgs.mkShell (baseShell // {
            shellHook = /*bash*/ ''
              . ${baseShell.passthru.dotEnv}
              if test -e flake.nix; then
                exec nix develop --command ${baseShell.passthru.fishCmd}
              else
                exec ${baseShell.passthru.fishCmd}
              fi
            '';
          });
        };
    });
}
