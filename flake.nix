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
          quicktype =  name : version : lang : pkgs.writeShellScriptBin "${name}_${lang}" ''
              ${pkgs.quicktype}/bin/quicktype -s schema ./schemas/${name}/${version}/schema.json -o models.${lang};
              echo 'New model is ready at models.${lang}';
          '';
        in
        {
          packages.pokedex.v0_1_0.go = (quicktype "pokedex" "v0.1.0" "go");
          packages.pokedex.v0_1_0.swift = (quicktype "pokedex" "v0.1.0" "swift");
          packages.pokedex.v0_1_0.ts = (quicktype "pokedex" "v0.1.0" "ts");
        })
    );
}


