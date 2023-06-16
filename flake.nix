{
  description = "Flexible Blind JPEG Artifacts Removal (FBCNN, ICCV 2021) ";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/e7603eba51f2c7820c0a182c6bbb351181caa8e7";
    flake-utils.url = "github:numtide/flake-utils";
    nixGLSource.url = "github:guibou/nixGL";
  };

  outputs = { self, nixpkgs, flake-utils, nixGLSource }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import "${nixpkgs}" {
            inherit system;
            config = {
              allowUnfree = true;
              cudaSupport = true;
            };
          };

          nixGL = import "${nixGLSource}" { inherit pkgs; };
        in
        {
          devShells.default = pkgs.mkShell
            {
              buildInputs = with pkgs.python311Packages; [
                nixGL.auto.nixGLDefault
                torch-bin
                torchvision-bin
                matplotlib
                requests
                opencv4
                numpy
                py3exiv2
              ];
            };
        }
      );
}

