# Renew hook for certbot

This is a simple PERL script which takes care about installing renewed certificates.

## Usage

Intended usage is setting certbot-hook.pl as the --renew-hook and running
``certbot renew`` as usual. The hook will take care of copying the certificates
and running additional hooks if necessary.

## Configuration

### Hook configuration

File certbot-hook.yaml contains main configuration:

1. Location of the domain config file
2. Key file/username for ssh access
3. Definitions of formats (which files to concatenate and hooks to run)

### Domain configuration

Sample configuration for the hook is available in generated-config.yaml. There
is a format type and list of servers to copy the certificate to. The per domain
configuration could be generated from per server configuration via
config-parser.pl

Sample per server configuration is in config.yaml
