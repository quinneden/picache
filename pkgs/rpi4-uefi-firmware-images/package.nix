{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  pname = "rpi4-uefi-firmware-images";
  version = "1.41";

  src = pkgs.fetchzip {
    url = "https://github.com/pftf/RPi4/releases/download/v1.41/RPi4_UEFI_Firmware_v1.41.zip";
    hash = "sha256-MVvoIO26JNEi1maOYcgk0h/Heb9W+Y8mgh7l8GFC4/k=";
    stripRoot = false;
  };

  installPhase = ''
    runHook preInstall
    mkdir $out
    rm Readme.md
    cp -r ./. $out
    runHook postInstall
  '';
}
