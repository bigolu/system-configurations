# Copy this to <project_root>/.envrc. .envrc is not committed to the git repository
# for the following reasons:
#   - Gives users complete control over the contents of the .envrc file. This seems
#     reasonable since it's configuring _their_ computer.
#   - Gives users a place to set environment variables that influence the behavior of
#     the direnv config without accidentally committing those changes. See the
#     commented lines below starting with 'export' for examples. The effect of those
#     variables can be found in direnv-config.bash.

# export DEV_SHELL=<name>
# export CI=true
source direnv/direnv-config.bash
