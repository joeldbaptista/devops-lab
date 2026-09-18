# 000 — How to log in to AWS

This note records how this sandbox obtains AWS credentials for the AWS CLI and
for Terraform. Both tools read the same credential sources, so one login serves
both.

## Prerequisites

This list is exhaustive:

- AWS CLI v2 on the `PATH`. This sandbox used `aws-cli/2.36.44`.
- A default region in `~/.aws/config`. This sandbox uses `eu-west-1`.
- An AWS Management Console account you can sign in to in a browser.

Set the region once:

```sh
aws configure set region eu-west-1
```

## Log in

Run:

```sh
aws login
```

The command opens a browser page, you sign in to the AWS Management Console, and
you select the account to use. The CLI then acquires temporary credentials that
correspond to that console session, plus a refresh token. The CLI refreshes the
temporary credentials on its own while the refresh token stays valid, so you do
not repeat the login on every command.

Use `aws login --remote` instead when no local browser exists, for example over
SSH. That variant prints a URL and asks you to paste back an authorisation code.

The credentials are cached on disk, not in the shell, so every new terminal
inherits them. Override the cache directory with the `AWS_LOGIN_CACHE_DIRECTORY`
environment variable if you need to.

## Log out

```sh
aws logout          # clears the cached credentials for the current profile
aws logout --all    # clears them for every profile
```

## Alternatives, and why this sandbox does not use them

These are mutually exclusive alternatives to `aws login`:

- A static access key pair for an IAM user, stored in `~/.aws/credentials`.
  The keys are long-lived, so they are the weaker option.
- IAM Identity Center (SSO), configured with `aws configure sso` and refreshed
  with `aws sso login`. That path applies when the account is reached through a
  start URL such as `https://d-xxxx.awsapps.com/start`.

This sandbox deliberately has no `~/.aws/credentials` file. The file was
removed so that `aws login` is the single source of credentials.

Never use root account access keys, because a root key cannot be scoped down.

## Troubleshooting

`aws --version` failing with exit code 255 and this message:

```
aws: [ERROR]: Unable to parse config file: /Users/joel/.aws/credentials
```

means `~/.aws/credentials` is malformed, and then **every** `aws` command fails,
including ones that would otherwise need no credentials. Terraform's AWS
provider reads the same file, so it fails too. Two fixes, mutually exclusive:

1. Repair the file. Each section needs a `[profile-name]` header line, and every
   other line needs the form `key = value`.
2. Move the file aside, which is what this sandbox did:

```sh
mv ~/.aws/credentials ~/.aws/credentials.bak
```

## Next

Verify the login before using it. See `001_how-to-test-credentials-work.md`.
