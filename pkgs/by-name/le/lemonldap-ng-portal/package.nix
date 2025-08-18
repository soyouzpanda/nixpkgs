{
  lib,
  stdenv,
  fetchFromGitLab,
  perl,
  bash,
}:
let
  lemonldapPerl = perl.withPackages (p: with p; [
    LemonldapNGPortal
    Plack
    Starman
  ]);
in

stdenv.mkDerivation rec {
  pname = "lemonldap-ng-portal";
  version = "2.21.2";

  src = fetchFromGitLab {
    domain = "gitlab.ow2.org";
    owner = "lemonldap-ng";
    repo = "lemonldap-ng";
    tag = "v${version}";
    hash = "sha256-KKWIkmDWq1sigovuhr/OjBXSlmSIr9uKkRJDPUMJpqQ=";
  };

  sourceRoot = "source/lemonldap-ng-portal/site";

  buildInputs = [
    lemonldapPerl
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/{static,templates}
    mkdir -p $out/{bin,lib}

    cp -r htdocs/static/* $out/share/static
    cp -r templates/* $out/share/templates

    cp htdocs/index.psgi $out/lib

    cat ${./wrapper.sh} > $out/bin/lemonldap-ng-portal
    substituteInPlace $out/bin/lemonldap-ng-portal \
      --replace-fail "@bash@" "${lib.getExe bash}" \
      --replace-fail "@plackUp@" "${lib.getExe' lemonldapPerl "plackup"}" \
      --replace-fail "@psgiScript@" "$out/lib/index.psgi"
    chmod +x $out/bin/lemonldap-ng-portal

    runHook postInstall
  '';

  meta = {
    description = "LemonLDAP::NG Web SSO";
    homepage = "https://gitlab.ow2.org/lemonldap-ng/lemonldap-ng/";
    changelog = "https://gitlab.ow2.org/lemonldap-ng/lemonldap-ng/-/blob/${src.tag}/changelog";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ soyouzpanda ];
    mainProgram = "lemonldap-ng-portal";
    platforms = lib.platforms.all;
  };
}
