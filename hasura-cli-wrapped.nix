{ mkDerivation
, hasura-cli
, hasura-cli_ext-bin
, makeWrapper
}:
let
  bin = drv: "${drv}/bin/${drv.pname}";
in
mkDerivation {
  inherit (hasura-cli) meta version pname;
  name = "${hasura-cli.pname}-wrapped";
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ hasura-cli hasura-cli_ext-bin ];
  dontUnpack = true;
  buildPhase = /*bash*/ ''
    mkdir -p $out/bin/
    makeWrapper ${bin hasura-cli} $out/bin/$pname \
      --add-flags "--cli-ext-path=${bin hasura-cli_ext-bin}"
  '';
}
