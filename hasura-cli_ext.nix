{ mkDerivation
, fetchurl
, cc
, autoPatchelfHook
, version
}:
mkDerivation rec {
  inherit version;
  pname = "hasura-cli_ext";
  name = "${pname}-${version}-bin";
  src = fetchurl {
    name = "hasura-cli_ext-bin.tar.gz";
    url = "https://github.com/hasura/graphql-engine/releases/download/${version}/cli-ext-hasura-linux.tar.gz";
    sha256 = "bdb9501404959c4b424391ba58b239b2c6f120ab428daacba6c6f8288f73d197";
  };
  nativeBuildInputs = [
    autoPatchelfHook
  ];
  buildInputs = [
    cc.cc.lib
  ];
  dontUnpack = true;
  installPhase = /*bash*/ ''
    runHook preInstall
    mkdir -p $out/bin
    tar -Oxvf $src > $out/bin/$pname
    chmod +x $out/bin/$pname
    runHook postInstall
    '';
}
