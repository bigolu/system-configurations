# Service token for Bitwarden Secrets Manager.
#
# Why: To get secrets in the future without having to provide this token.
#
# Get yours here: https://bitwarden.com/products/secrets-manager/
export BWS_ACCESS_TOKEN='<secret>'

# Personal access token for GitHub.
#
# Permissions: All that's needed is a fine-grained token with no permissions
# given. This will only allow the token read access to public repositories on
# github.com.
#
# Why: To avoid being rate-limited by GitHub when using `lychee`.
#
# Learn how to get yours here:
# https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token
export GITHUB_TOKEN='<secret>'