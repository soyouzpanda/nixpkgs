{
  lib,
  stdenv,
  fetchFromGitLab,
  perl,
  bash,
}:
let
  lemonldapPerl = perl.withPackages (p: with p; [
    LemonldapNGManager
    Plack
    Starman
  ]);
in

stdenv.mkDerivation rec {
  pname = "lemonldap-ng-manager";
  version = "2.21.2";

  src = fetchFromGitLab {
    domain = "gitlab.ow2.org";
    owner = "lemonldap-ng";
    repo = "lemonldap-ng";
    tag = "v${version}";
    hash = "sha256-KKWIkmDWq1sigovuhr/OjBXSlmSIr9uKkRJDPUMJpqQ=";
  };

  phases = [ "unpackPhase" "patchPhase" "installPhase" ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/{static,templates,doc}
    mkdir -p $out/{bin,lib}

    cp -r lemonldap-ng-manager/site/htdocs/static/* $out/share/static
    cp -r lemonldap-ng-manager/site/templates/* $out/share/templates
    cp -r doc/* $out/share/doc

    cp lemonldap-ng-manager/site/htdocs/manager.psgi $out/lib/index.psgi
    sed -i "s|#!/usr/bin/env plackup||" $out/lib/index.psgi
    cp lemonldap-ng-manager/site/api/api.psgi $out/lib/api.psgi

    cat ${./wrapper.sh} > $out/bin/lemonldap-ng-manager
    substituteInPlace $out/bin/lemonldap-ng-manager \
      --replace-fail "@bash@" "${lib.getExe bash}" \
      --replace-fail "@plackUp@" "${lib.getExe' lemonldapPerl "plackup"}" \
      --replace-fail "@psgiScript@" "$out/lib/index.psgi"
    chmod +x $out/bin/lemonldap-ng-manager

    cat ${./wrapper.sh} > $out/bin/lemonldap-ng-manager-api
    substituteInPlace $out/bin/lemonldap-ng-manager-api \
      --replace-fail "@bash@" "${lib.getExe bash}" \
      --replace-fail "@plackUp@" "${lib.getExe' lemonldapPerl "plackup"}" \
      --replace-fail "@psgiScript@" "$out/lib/api.psgi"
    chmod +x $out/bin/lemonldap-ng-manager-api

    runHook postInstall
  '';

  meta = {
    description = "LemonLDAP::NG Web SSO";
    homepage = "https://gitlab.ow2.org/lemonldap-ng/lemonldap-ng/";
    changelog = "https://gitlab.ow2.org/lemonldap-ng/lemonldap-ng/-/blob/${src.tag}/changelog";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ soyouzpanda ];
    mainProgram = "lemonldap-ng-manager";
    platforms = lib.platforms.all;
  };
}
