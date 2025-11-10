{
  description = "Omni-Tools module";

  outputs = { self }: {
    nixosModules.default = import ./module.nix;

    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);

    meta = { lib, ... }: {
      spModuleSchemaVersion = 1;
      id = "omnitools";
      name = "Omni-Tools";
      description = "All-in-one tool container with utilities and converters.";
      svgIcon = builtins.readFile ./icon.svg;
      isMovable = true;
      canBeBackedUp = true;
      isRequired = false;
      backupDescription = "Omni-Tools data and configurations.";
      systemdServices = [
        "omnitools.service"
      ];
      folders = [
        "/var/lib/private/omnitools"
      ];
      license = [
        lib.licenses.unfree
      ];
      homepage = "https://github.com/iib0011/omni-tools";
      sourcePage = "https://github.com/iib0011/omni-tools";
      supportLevel = "community";
    };
  };
}
