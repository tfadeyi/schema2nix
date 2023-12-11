# schema2nix

This is simple POC using Nix for Openapi/Jsonschema schema management and client generation within an org where is difficult to maintain clients
for different services.

> Note: This is just an experiment. I welcome any feedback, just raise an issue.

## Prerequisite

* Nix. (`curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`)

> Note: supports only darwin and linux (arm,x86)

## Motivation

* The organization has many different openapi and jsonschema schemas, and most don't have code clients present next to the schema.
* Different teams must copy those schemas to their individual projects and generate clients that can interact with the services.
* Copying and pasting schemas is cumbersome and might allow for schemas to fall out of sync (dev overhead).
* Has the company grows so does the number of services and schemas, using git submodule might not be the best if you have a project that
  requires many clients from many services.

## Solution

Goal:
* It should allow teams that own schemas to keep their schemas in their repos, as they are going to require to make changes to it more often,
  and it's probably used to generate the service they own.
* It should not impact the workflow of a team that owns the schema.
* It should allow teams that want to generate clients from schemas to do so without having to copy and paste schemas.

> Ideally each team that owns a schema generates and maintain clients that are owned by others.

## Centralized Schema Repository

If we centralized where the schemas are stored we could:
* Generate common clients that different projects can then use.
* Generate docker images with schemas copied into the image and bake in a code generation tool. This would allow other projects to use the new docker image for client generation.
* Use Nix flakes.

In the first 2 cases we might require additional mechanism, maybe a CI jobs, to pull/push changes to schemas and keep the schemas in sync.

Nix flakes allows us to tell nix which repos and schemas to pull at runtime.

## Simple explanation

Nix takes the different schema sources present in `sources.json`, and generate a Nix package (like a brew package) containing the blueprint
for pulling the openapi schema mentioned in `sources.json` and command to generate the client from the schema.

```nix
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
```

Output Packages
```shell
# linux outputs, (other arch/os are present too)
outputs.packages.x86_64-linux.go.pokedex
outputs.packages.x86_64-linux.go.petstore
outputs.packages.x86_64-linux.go.jokes
outputs.packages.x86_64-linux.go.jokes
```

This package is then built at runtime on the host machine, allowing to use the host authentication to access the private repos mentioned in the source.

```shell
nix run github.com/tfadeyi/schema2nix#go.petstore
```

## Usage

The run command needs to point to the repository containing the `flake.nix`, we can use `#<package_name>` to specify which package to built
and run.

```shell
nix run github.com/tfadeyi/schema2nix#go.petstore
```

> Note: no need to specify the os/arch combination, nix should take care of selecting the one for the current system.

## Improvements

Make the example more generic if useful to others and make a template.
