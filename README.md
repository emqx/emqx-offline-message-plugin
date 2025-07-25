[![CI](https://github.com/emqx/emqx-offline-message-plugin/actions/workflows/ci.yml/badge.svg)](https://github.com/emqx/emqx-offline-message-plugin/actions/workflows/ci.yml)

# EMQX Offline Message Plugin

This plugin can be used to store messages in a 3rd party database. It allows you to publish messages to a topic even when there are no subscribers online, and the messages will be stored until a subscriber comes online.

Currently supports the following database backends:
- MySQL
- Redis

## Usage

Download the plugin:

<!-- Do not update plugin version manually, use make bump-version-patch/minor/major instead -->
```bash
wget https://github.com/emqx/emqx-offline-message-plugin/releases/download/v1.0.3/emqx_offline_message_plugin-1.0.3.tar.gz
```

Install the plugin:

<!-- Do not update plugin version manually, use make bump-version-patch/minor/major instead -->
```bash
curl -u key:secret -X POST http://localhost:18083/api/v5/plugins/install \
-H "Content-Type: multipart/form-data" \
-F "plugin=@emqx_offline_message_plugin-1.0.3.tar.gz"
```

Check the plugin is installed:

```bash
curl -u key:secret http://localhost:18083/api/v5/plugins | jq
```

Configure the plugin in the Dashboard: http://localhost:18083/#/plugins/detail/emqx_offline_message_plugin-1.0.3

Verify:

```bash
mosquitto_pub -d -q 1 -t 't/2' -m 'hello-from-offline1'
mosquitto_pub -d -q 1 -t 't/2' -m 'hello-from-offline2'
mosquitto_pub -d -q 1 -t 't/2' -m 'hello-from-offline3'

mosquitto_sub -d -q 1 -t 't/2' -i $(pwgen 20 -1)
```

No messages should be received:

```bash
mosquitto_sub -d -q 1 -t 't/2' -i $(pwgen 20 -1)
```


## Release

An EMQX plugin release is a tar file including including a subdirectory of this plugin's name and it's version, that contains:

1. A JSON format metadata file describing the plugin
2. Versioned directories for all applications needed for this plugin (source and binaries).
3. Confirm the OTP version used by EMQX that the plugin will be installed on (See also [./.tool-versions](./.tool-versions)).

In a shell from this plugin's working directory execute `make rel` to have the package created like:

```
_build/default/emqx_plugrel/emqx_plugin_template-<vsn>.tar.gz
```
## Format

Format all the files in your project by running:
```
make fmt
```

See [EMQX documentation](https://docs.emqx.com/en/enterprise/v5.0/extensions/plugins.html) for details on how to deploy custom plugins.
