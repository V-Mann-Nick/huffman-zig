{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      name = "zig";
      packages = with pkgs; [zig valgrind kcachegrind];
    };
    formatter.${system} = pkgs.alejandra;
  };
}
