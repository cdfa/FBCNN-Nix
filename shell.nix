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

  # todo: just use python 310 (if we keep using patchify)
  # todo: readme
  # todo: flake
  python = pkgs.python311.override {
    packageOverrides = self: super: {
      poetry = self.callPackage "${pkgsSource}/pkgs/tools/package-management/poetry/unwrapped.nix" { };

      cachecontrol = super.cachecontrol.overridePythonAttrs {
        doCheck = false;
      };

      twisted = super.twisted.overridePythonAttrs {
        doCheck = false;
      };

      platformdirs = super.platformdirs.overridePythonAttrs (old: rec {
        version = "2.6.2";
        src = pkgs.fetchFromGitHub {
          owner = "platformdirs";
          repo = "platformdirs";
          rev = "refs/tags/${version}";
          hash = "sha256-yGpDAwn8Kt6vF2K2zbAs8+fowhYQmvsm/87WJofuhME=";
        };
        SETUPTOOLS_SCM_PRETEND_VERSION = version;
      });

      poetry-core = super.poetry-core.overridePythonAttrs (old: rec {
        version = "1.5.2";
        src = pkgs.fetchFromGitHub {
          owner = "python-poetry";
          repo = "poetry-core";
          rev = version;
          hash = "sha256-GpZ0vMByHTu5kl7KrrFFK2aZMmkNO7xOEc8NI2H9k34=";
        };
      });
    };
  };
  pythonPackages = python.pkgs;

  nixGL = import "${nixGLSource}" { inherit pkgs; };

  patchify = pythonPackages.buildPythonPackage {
    name = "patchify";
    src = builtins.fetchTarball {
      url = "https://github.com/dovahcrow/patchify.py/archive/c9e7e15fc9cb30a5a64d152013de6275d053105b.zip";
      sha256 = "sha256:1nb35i0asx23fx284bbhh16awgpslawz31s3x21q86jpg6790lvp";
    };
    propagatedBuildInputs = with pythonPackages; [
      numpy
      poetry
    ];
    format = "pyproject";
  };
in
pkgs.mkShell {
  buildInputs = with pythonPackages; [
    nixGL.auto.nixGLDefault
    torch-bin
    torchvision-bin
    matplotlib
    requests
    opencv4
    patchify
    numpy
    py3exiv2
  ];
}
