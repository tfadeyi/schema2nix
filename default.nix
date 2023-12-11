{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./sources.json);

  # mkCodegen makes a derivation that pull the repo containing the schema,`schema_path`, and installs the codegen `tool`
  # specified by the source and runs it against the schema_path. Using the `args` defined in the sources.json
  mkCodegen = {
    language, # certain tools support generating multiple languages
    name, # name of the package
    schema_path, # local/remote path of the schema, i.e: api/api.yaml
    repo_url, # url of the repo containing the schema
    rev, # revision of the repo, usually a commit SHA
    ref, # branch or tag to pull
    type, # schema type (openapi, jsonschema)
    tool, # name of the tool to run against the schema (must be present in https://search.nixos.org/packages)
    args # arguments to pass to the tool
  }:
  let
    content = pkgs.stdenv.mkDerivation {
      pname = name;
      src = builtins.fetchGit {
          url = repo_url;
          ref = ref;
          rev = rev;
      };
      version = rev;

      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;

      installPhase = ''
        mkdir -p $out/$(dirname ${schema_path})
        cp ${schema_path} $out/$(dirname ${schema_path})
      '';
    };
    in
    if type == "openapi" # openapi codegen
     then pkgs.writeShellScriptBin "${name}_${language}" ''
          ${pkgs.${tool}}/bin/${tool} ${args} ${content}/${schema_path};
          echo 'Done';
          ''
     else # default to jsoschema model generator
        pkgs.writeShellScriptBin "${name}_${language}" ''
        ${pkgs.${tool}}/bin/${tool} ${args} ${content}/${schema_path} -o models.${language};
        echo 'Done';
        '';

  schemaPackages =
    lib.attrsets.mapAttrs (
      key: language:
         lib.attrsets.mapAttrs' (
            name: v:
              lib.attrsets.nameValuePair(name)
                (mkCodegen {inherit language name; inherit (v) schema_path repo_url rev ref type tool args; })) sources.schemas
    ) sources.languages; # if the codegen tool supports multiple langs you can list them here

in
  # We want the packages but also add a "default" that just points to an existing derivation
  schemaPackages // {"default" = schemaPackages.go.petstore;}
