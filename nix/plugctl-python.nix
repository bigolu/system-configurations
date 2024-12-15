# TODO: I should be using a python package manager like uv
pkgs:
pkgs.python3.withPackages (
  python-packages: with python-packages; [
    pip
    python-kasa
    diskcache
    ipython
    platformdirs
    psutil
    types-psutil
    mypy
  ]
)
