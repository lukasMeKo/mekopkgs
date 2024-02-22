{ mkDerivation
, hasura-cli
, makeWrapper
}:
mkDerivation {
  inherit (hasura-cli) meta version pname;
  name = "${hasura-cli.pname}-wrapped";
  nativeBuildInputs = [ makeWrapper ];
  dontUnpack = true;
  buildPhase = /*bash*/ ''
    mkdir -p $out/bin/
    makeWrapper ${hasura-cli}/bin/hasura $out/bin/$pname \
      --add-flags "--cli-ext-path=~/.hasura/plugins/bin/hasura-cli_ext"
  '';
}
