{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  inherit (pkgs) lib;
  sources = builtins.fromJSON (lib.strings.fileContents ./source.json);

  # mkBinaryInstall makes a derivation that installs Zig from a binary.
  mkBinaryInstall = {
    language,
    name,
    schema_path,
    repo_url,
    rev,
    ref
  }:
  let
    content = pkgs.stdenv.mkDerivation {
      pname = name;
      src = builtins.fetchGit {
          url = repo_url;
          ref = ref;
          rev = rev;
      };
      buildInput = [ pkgs.openssh ];
      version = "v0.1.0";
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;
      installPhase = ''
        mkdir -p $out
        cp ${schema_path} $out/schema.json
      '';
    };
    in
    pkgs.writeShellScriptBin "${name}_${language}" ''
          ${pkgs.quicktype}/bin/quicktype -s schema ${content}/schema.json -o models.${language};
          echo 'New model is ready at models.${language}';
    '';
#https://github.com/error-fyi/fyi-schema/archive/refs/tags/v0.1.0.tar.gz
#https://github.com/tfadeyi/fyi-schema/archive/v0.1.0.tar.gz
  # The master packages
  masterPackages =
    lib.attrsets.mapAttrs (
      key: language:
         lib.attrsets.mapAttrs' (
            name: v:
              lib.attrsets.nameValuePair(name)
                (mkBinaryInstall {inherit language name; inherit (v) schema_path repo_url rev ref; })) sources.master
    ) { go = "go"; ts = "ts"; swift = "swift"; };

in
  # We want the packages but also add a "default" that just points to the
  # latest released version.
  masterPackages // {"default" = masterPackages.go.pokedex;}