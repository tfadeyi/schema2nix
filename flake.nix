{
  description = "jsonschema codegeneration.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    (flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
          quicktype =  name : lang : pkgs.writeShellScriptBin "${name}_${lang}" ''
              ${pkgs.quicktype}/bin/quicktype -s schema ./schemas/${name}/schema.json -o models.${lang};
              echo 'New model is ready at models.${lang}';
          '';
        in
        {
          packages.pokedex.go = (quicktype "pokedex" "go");
          packages.pokedex.swift = (quicktype "pokedex" "swift");
          packages.pokedex.ts = (quicktype "pokedex" "ts");
        })
    );
}


