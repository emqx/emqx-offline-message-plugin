# EMQX Offline Message Plugin

## Usage

Download the plugin:

```bash
wget https://github.com/savonarola/emqx-offline-message-plugin/releases/download/v0.0.4/emqx_offline_message_plugin-1.0.0.tar.gz
```

Install the plugin:

```bash
curl -u key:secret -X POST http://localhost:18083/api/v5/plugins/install \
-H "Content-Type: multipart/form-data" \
-F "plugin=@emqx_offline_message_plugin-1.0.0.tar.gz"
```

Check the plugin is installed:

```bash
curl -u key:secret http://localhost:18083/api/v5/plugins | jq
```

Add connector:

```bash
curl -u key:secret -X POST http://localhost:18083/api/v5/connectors \
-H "Content-Type: application/json" \
-d '{"type":"mysql","name":"omp","server":"mysql","database":"emqx","pool_size":8,"username":"emqx","password":"public","resource_opts":{"start_timeout":"5s","health_check_interval":"15s"}}'

curl -s -u key:secret http://localhost:18083/api/v5/connectors | jq
```

Add publish action:

```bash
curl -u key:secret -X POST http://localhost:18083/api/v5/actions \
-H "Content-Type: application/json" \
-d '{"type":"mysql","parameters":{"undefined_vars_as_null":false,"sql":"insert into mqtt_msg(msgid, sender, topic, qos, retain, payload, arrived) values(${id}, ${clientid}, ${topic}, ${qos}, ${retain}, ${payload}, FROM_UNIXTIME(${timestamp}/1000))"},"name":"omp_publish_action","enable":true,"connector":"omp"}'

curl -s -u key:secret http://localhost:18083/api/v5/actions | jq
```

Add publish rule:

```bash
curl -u key:secret -X POST http://localhost:18083/api/v5/rules \
-H "Content-Type: application/json" \
-d '{"sql":"SELECT id, clientid, topic, qos, payload, timestamp, int(coalesce(flags.retain, 0)) as retain FROM \"t/#\" WHERE qos = 1 or qos = 2","name":"omp_publish_rule","description":"Offline Message Plugin Publish Action","actions":["mysql:omp_publish_action"]}'

curl -s -u key:secret http://localhost:18083/api/v5/rules | jq
```

Add subscribe/ack rule.
This the only configuration change that is unavailable from the Dashboard.

```bash
curl -u key:secret -X POST http://localhost:18083/api/v5/rules \
-H "Content-Type: application/json" \
-d '{"sql":"SELECT * FROM \"$events/session_subscribed\", \"$events/message_acked\" WHERE topic =~ '"'"'t/#'"'"'","name":"omp_subscribe_ack_rule","description":"Offline Message Plugin Subscribe/Ack Action","actions":[{"function":"emqx_omp:action","args":{"opts":{},"connector_name":"mysql:omp"}}]}'

curl -s -u key:secret http://localhost:18083/api/v5/rules | jq
```

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
