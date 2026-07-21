{
  description = "Cupcakes OS (NixOS base)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      version = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./VERSION);

      overlay = final: prev: {
        anix = final.callPackage ./nix/pkgs/anix.nix {};
        mango = final.callPackage ./nix/pkgs/mango.nix {};
        modularity = final.callPackage ./nix/pkgs/modularity.nix {};
      };

	pkgs = import nixpkgs {
  inherit system;
  overlays = [ overlay ];

  config.allowUnfreePredicate = pkg:
    builtins.elem (nixpkgs.lib.getName pkg) [
      "modularity"
    ];
};

mkLive = liveEdition: nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit version liveEdition; };

  modules = [
    (nixpkgs.outPath + "/nixos/modules/installer/cd-dvd/iso-image.nix")
    ./nix/profiles/live.nix

    {
      nixpkgs = {
        overlays = [ overlay ];

        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "modularity"
          ];
      };
    }
  ];
};

    in {
      overlays.default = overlay;

      nixosModules = {
        installed-base = import ./nix/modules/installed-base.nix;
        anix = import ./nix/modules/anix.nix;
      };

      nixosConfigurations = {
        cupcakes-os-live = mkLive "cosmic";
        cupcakes-os-live-cosmic = mkLive "cosmic";
        cupcakes-os-live-hyprland = mkLive "hyprland";
        cupcakes-os-live-gnome = mkLive "gnome";
        cupcakes-os-live-kde = mkLive "kde";
        cupcakes-os-live-other = mkLive "other";
      };

      packages.${system} = {
        anix = pkgs.anix;

        iso = self.nixosConfigurations.cupcakes-os-live-cosmic.config.system.build.isoImage;
        iso-cosmic = self.nixosConfigurations.cupcakes-os-live-cosmic.config.system.build.isoImage;
        iso-hyprland = self.nixosConfigurations.cupcakes-os-live-hyprland.config.system.build.isoImage;
        iso-gnome = self.nixosConfigurations.cupcakes-os-live-gnome.config.system.build.isoImage;
        iso-kde = self.nixosConfigurations.cupcakes-os-live-kde.config.system.build.isoImage;
        iso-other = self.nixosConfigurations.cupcakes-os-live-other.config.system.build.isoImage;

        mango = pkgs.mango;
        modularity = pkgs.modularity;

        default = self.nixosConfigurations.cupcakes-os-live-cosmic.config.system.build.isoImage;
      };

      apps.${system}.anix = {
        type = "app";
        program = "${self.packages.${system}.anix}/bin/anix";

        meta = {
          description = "ANIX system management tool";
        };
      };
    };
}
