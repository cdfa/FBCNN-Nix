let
  pkgsSource = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/e7603eba51f2c7820c0a182c6bbb351181caa8e7.zip"; # Most recent nixos-23.05 commit as of 5 Dec 2022 16:18
    sha256 = "sha256:0mwck8jyr74wh1b7g6nac1mxy6a0rkppz8n12andsffybsipz5jw";
  };

  nixGLSource = builtins.fetchTarball {
    url = "https://github.com/guibou/nixGL/archive/main.tar.gz";
    sha256 = "sha256:03kwsz8mf0p1v1clz42zx8cmy6hxka0cqfbfasimbj858lyd930k";
  };

  pkgs = import "${pkgsSource}" {
    config = {
      allowUnfree = true;
      cudaSupport = true;
    };
  };

  # todo: readme
  # todo: flake

  nixGL = import "${nixGLSource}" { inherit pkgs; };
in
pkgs.mkShell {
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
}
