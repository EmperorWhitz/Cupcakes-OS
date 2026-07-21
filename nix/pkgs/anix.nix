{ lib
, stdenvNoCC
, makeWrapper
, bashInteractive
, coreutils
, diffutils
, findutils
, gawk
, git
, gnugrep
, gnused
, nix
, procps
, util-linux
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "anix";
  version = "1.0.5-demo";

  src = ../../.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/anix/docs/wiki" "$out/share/anix/assets"

    install -Dm0755 "$src/scripts/anix.sh" "$out/share/anix/anix.sh"
    install -Dm0644 "$src/scripts/cupcakes-os-ui.sh" "$out/share/anix/cupcakes-os-ui.sh"
    install -Dm0644 "$src/nix/modules/anix.nix" "$out/share/anix/anix-module.nix"

    install -Dm0644 "$src/docs/wiki/ANIX-V1.md" "$out/share/anix/docs/wiki/ANIX-V1.md"
    install -Dm0644 "$src/docs/wiki/TinyPM-V4.md" "$out/share/anix/docs/wiki/TinyPM-V4.md"
    install -Dm0644 "$src/docs/wiki/Cupcakes-OS-Tools.md" "$out/share/anix/docs/wiki/Cupcakes-OS-Tools.md"
    install -Dm0644 "$src/docs/wiki/Recovery.md" "$out/share/anix/docs/wiki/Recovery.md"

    if [ -d "$src/vendor/tinypm" ]; then
      mkdir -p "$out/share/anix/tinypm"
      cp -a "$src/vendor/tinypm/." "$out/share/anix/tinypm/"
    fi

    if [ -d "$src/assets/wallpapers/collection" ]; then
      mkdir -p "$out/share/anix/wallpapers"
      cp -a "$src/assets/wallpapers/collection/." "$out/share/anix/wallpapers/"
    fi

    if [ -f "$src/assets/Effects/v3StartingCupcakes-OS.mp3" ]; then
      mkdir -p "$out/share/anix/effects"
      install -Dm0644 "$src/assets/Effects/v3StartingCupcakes-OS.mp3" \
        "$out/share/anix/effects/v3StartingCupcakes-OS.mp3"
    fi

    makeWrapper "${bashInteractive}/bin/bash" "$out/bin/anix" \
      --add-flags "$out/share/anix/anix.sh" \
      --prefix PATH : "${lib.makeBinPath [
        bashInteractive
        coreutils
        diffutils
        findutils
        gawk
        git
        gnugrep
        gnused
        nix
        procps
        util-linux
      ]}" \
      --set ANIX_UI_LIB "$out/share/anix/cupcakes-os-ui.sh" \
      --set ANIX_DOCS_DIR "$out/share/anix/docs/wiki" \
      --set ANIX_TINYPM_SOURCE "$out/share/anix/tinypm" \
      --set ANIX_WALLPAPER_DIR "$out/share/anix/wallpapers" \
      --set ANIX_SOUND_FILE "$out/share/anix/effects/v3StartingCupcakes-OS.mp3"

    cat > "$out/share/anix/README.md" <<'EOF'
    ANIX standalone package

    CLI:
      anix

    Standalone module path:
      $out/share/anix/anix-module.nix

    Flake users can also consume this repository directly:
      inputs.cupcakesOs.url = "github:EmperorWhitz/cupcakes-os";
      imports = [ cupcakesOs.nixosModules.anix ];
      environment.systemPackages = [ cupcakesOs.packages.''${pkgs.system}.anix ];
    EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "Friendly NixOS profile and rebuild helper";
    homepage = "https://github.com/EmperorWhitz/cupcakes-os";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "anix";
  };
})
