%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_omp_SUITE).

-include_lib("eunit/include/eunit.hrl").

-compile(nowarn_export_all).
-compile(export_all).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

-define(set_config(KEY, VALUE, CONFIG), lists:keyreplace(KEY, 1, CONFIG, {KEY, VALUE})).

-import(emqx_omp_test_helpers, [api_get/1, api_get_raw/1, api_post/2, api_delete/1]).

%%--------------------------------------------------------------------
%% CT Setup
%%--------------------------------------------------------------------

all() ->
    [
        {group, mysql_tcp},
        {group, mysql_ssl},
        {group, redis_tcp},
        {group, redis_ssl}
    ].

groups() ->
    emqx_omp_test_helpers:nested_groups([
        [mysql_tcp, mysql_ssl, redis_tcp, redis_ssl],
        [sync, async],
        [buffered, unbuffered],
        emqx_omp_test_helpers:all(?MODULE)
    ]).

init_per_suite(Config) ->
    ok = emqx_omp_test_helpers:start(),

    %% clean up
    ok = emqx_omp_test_api_helpers:delete_all_plugins(),

    %% install plugin
    {PluginId, Filename} = emqx_omp_test_api_helpers:find_plugin(),
    ok = emqx_omp_test_api_helpers:upload_plugin(Filename),
    ok = emqx_omp_test_api_helpers:start_plugin(PluginId),
    PluginConfig = plugin_config(),
    [{plugin_id, PluginId}, {plugin_filename, Filename}, {plugin_config, PluginConfig} | Config].

end_per_suite(_Config) ->
    ok = emqx_omp_test_api_helpers:delete_all_plugins(),
    ok = emqx_omp_test_helpers:stop(),
    ok.

%%
%% Different backends
%%
init_per_group(mysql_tcp, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    PluginConfig1 = emqx_utils_maps:deep_put([mysql, enable], PluginConfig0, true),
    PluginConfig2 = emqx_utils_maps:deep_put([mysql, ssl, enable], PluginConfig1, false),
    PluginConfig3 = set_server(mysql_tcp, PluginConfig2),
    [{backend, mysql} | ?set_config(plugin_config, PluginConfig3, Config)];
init_per_group(mysql_ssl, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    PluginConfig1 = emqx_utils_maps:deep_put([mysql, enable], PluginConfig0, true),
    PluginConfig2 = emqx_utils_maps:deep_put([mysql, ssl, enable], PluginConfig1, true),
    PluginConfig3 = set_server(mysql_ssl, PluginConfig2),
    [{backend, mysql} | ?set_config(plugin_config, PluginConfig3, Config)];
init_per_group(redis_tcp, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    PluginConfig1 = emqx_utils_maps:deep_put([redis, enable], PluginConfig0, true),
    PluginConfig2 = emqx_utils_maps:deep_put([redis, ssl, enable], PluginConfig1, false),
    PluginConfig3 = set_server(redis_tcp, PluginConfig2),
    [{backend, redis} | ?set_config(plugin_config, PluginConfig3, Config)];
init_per_group(redis_ssl, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    PluginConfig1 = emqx_utils_maps:deep_put([redis, enable], PluginConfig0, true),
    PluginConfig2 = emqx_utils_maps:deep_put([redis, ssl, enable], PluginConfig1, true),
    PluginConfig3 = set_server(redis_ssl, PluginConfig2),
    [{backend, redis} | ?set_config(plugin_config, PluginConfig3, Config)];
%%
%% buffered/unbuffered
%%
init_per_group(buffered, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    Backend = ?config(backend, Config),
    PluginConfig = emqx_utils_maps:deep_put([Backend, batch_size], PluginConfig0, 10),
    ?set_config(plugin_config, PluginConfig, Config);
init_per_group(unbuffered, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    Backend = ?config(backend, Config),
    PluginConfig = emqx_utils_maps:deep_put([Backend, batch_size], PluginConfig0, 1),
    ?set_config(plugin_config, PluginConfig, Config);
%%
%% sync/async
%%
init_per_group(sync, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    Backend = ?config(backend, Config),
    PluginConfig = emqx_utils_maps:deep_put([Backend, query_mode], PluginConfig0, <<"sync">>),
    ?set_config(plugin_config, PluginConfig, Config);
init_per_group(async, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    Backend = ?config(backend, Config),
    PluginConfig = emqx_utils_maps:deep_put([Backend, query_mode], PluginConfig0, <<"async">>),
    ?set_config(plugin_config, PluginConfig, Config).

end_per_group(_Group, _Config) ->
    ok.

init_per_testcase(_Case, Config) ->
    PluginId = ?config(plugin_id, Config),
    PluginConfig = ?config(plugin_config, Config),
    ok = emqx_omp_test_api_helpers:configure_plugin(PluginId, PluginConfig),
    Config.

end_per_testcase(_Case, _Config) ->
    PluginId = ?config(plugin_id, _Config),
    ok = emqx_omp_test_api_helpers:configure_plugin(PluginId, empty_plugin_config()),
    ok.

%%--------------------------------------------------------------------
%% Test cases
%%--------------------------------------------------------------------

t_different_subscribers(_Config) ->
    % publish message
    Payload = emqx_guid:to_hexstr(emqx_guid:gen()),
    ClientPub = emqtt_connect(),
    _ = emqtt:publish(ClientPub, <<"t/1">>, Payload, 1),
    ok = emqtt:stop(ClientPub),
    ct:sleep(500),

    % A new subscriber should receive the message
    ClientSub0 = emqtt_connect(),
    _ = emqtt:subscribe(ClientSub0, <<"t/1">>, 1),
    receive
        {publish, #{payload := Payload}} ->
            ok
    after 1000 ->
        ct:fail("Message not received")
    end,
    ok = emqtt:stop(ClientSub0),
    ct:sleep(500),

    %% Another subscriber should NOT receive the message:
    %% it should be deleted.
    ClientSub1 = emqtt_connect(),
    _ = emqtt:subscribe(ClientSub1, <<"t/1">>, 1),
    receive
        {publish, #{payload := Payload} = Msg1} ->
            ct:fail("Message received: ~p", [Msg1])
    after 1000 ->
        ok
    end,
    ok = emqtt:stop(ClientSub1).

t_subscribition_persistence(_Config) ->
    SubscriberOpts = [{clientid, <<"subscriber">>}, {clean_start, true}],

    %% Subscribe to topic and disconnect loosing session (clean_start = true)
    ClientSub0 = emqtt_connect(SubscriberOpts),
    _ = emqtt:subscribe(ClientSub0, <<"t/2">>, 1),
    ok = emqtt:stop(ClientSub0),

    %% Publish message to topic
    Payload0 = emqx_guid:to_hexstr(emqx_guid:gen()),
    ClientPub = emqtt_connect(),
    _ = emqtt:publish(ClientPub, <<"t/2">>, Payload0, 1),
    ct:sleep(500),

    %% Reconnect subscriber
    %% It should revive the subscription
    %% and receive the message
    ClientSub1 = emqtt_connect(SubscriberOpts),
    receive
        {publish, #{payload := Payload0}} ->
            ok
    after 1000 ->
        ct:fail("Message not received")
    end,
    ok = emqtt:stop(ClientSub1),

    %% Reconnect subscriber again
    %% It should NOT receive the old message
    %% but receive the new ones
    ClientSub2 = emqtt_connect(SubscriberOpts),
    receive
        {publish, #{payload := Payload0}} ->
            ct:fail("Message received")
    after 1000 ->
        ok
    end,
    Payload1 = emqx_guid:to_hexstr(emqx_guid:gen()),
    _ = emqtt:publish(ClientPub, <<"t/2">>, Payload1, 1),
    receive
        {publish, #{payload := Payload1}} ->
            ok
    after 1000 ->
        ct:fail("Message not received")
    end,

    %% Cleanup
    ok = emqtt:stop(ClientPub),
    ok = emqtt:stop(ClientSub2).

%% TODO
%% Test message order

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

emqtt_connect() ->
    emqtt_connect([]).

emqtt_connect(Opts) ->
    {ok, Pid} = emqtt:start_link(Opts ++ [{host, "127.0.0.1"}, {port, 1883}]),
    {ok, _} = emqtt:connect(Pid),
    Pid.

plugin_config() ->
    DefaultSSLConfig = #{
        enable => false,
        verify => <<"verify_peer">>,
        cacertfile => <<"/certs/ca.crt">>,
        certfile => <<"/certs/mysql-client.crt">>,
        keyfile => <<"/certs/mysql-client.key">>
    },

    #{
        redis => #{
            enable => false,
            ssl => DefaultSSLConfig#{server_name_indication => <<"redis-server">>},
            servers => <<"invalid-host:6379">>,
            topics => [<<"t/#">>],
            redis_type => <<"single">>,
            pool_size => 8,
            username => <<"">>,
            password => <<"public">>,
            database => 0,
            message_key_prefix => <<"mqtt:msg">>,
            subscription_key_prefix => <<"mqtt:sub">>,
            message_ttl => 7200,
            batch_size => 1,
            batch_time => 50,
            query_mode => <<"sync">>
        },
        mysql => #{
            enable => false,
            ssl => DefaultSSLConfig#{server_name_indication => <<"mysql-server">>},
            topics => [<<"t/#">>],
            server => <<"invalid-host:3306">>,
            password => <<"public">>,
            username => <<"emqx">>,
            pool_size => 8,
            database => <<"emqx">>,
            select_message_sql => <<"select * from mqtt_msg where topic = ${topic}">>,
            delete_message_sql => <<"delete from mqtt_msg where msgid = ${id}">>,
            insert_message_sql => <<
                "insert into mqtt_msg(msgid, sender, topic, qos, retain, payload, arrived)"
                "values(${id}, ${from}, ${topic}, ${qos}, ${flags.retain}, ${payload}, FROM_UNIXTIME(${timestamp}/1000))"
            >>,
            insert_subscription_sql => <<
                "insert into mqtt_sub(clientid, topic, qos)"
                "values(${clientid}, ${topic}, ${qos}) on duplicate key update qos = ${qos}"
            >>,
            select_subscriptions_sql => <<
                "select topic, qos from mqtt_sub where clientid = ${clientid}"
            >>,
            batch_size => 1,
            batch_time => 50,
            query_mode => <<"sync">>
        }
    }.

empty_plugin_config() ->
    PluginConfig0 = plugin_config(),
    PluginConfig1 = emqx_utils_maps:deep_put([mysql, enable], PluginConfig0, false),
    PluginConfig2 = emqx_utils_maps:deep_put([redis, enable], PluginConfig1, false),
    PluginConfig2.

set_server(mysql_tcp, Config) ->
    emqx_utils_maps:deep_put([mysql, server], Config, <<"mysql:3306">>);
set_server(mysql_ssl, Config) ->
    emqx_utils_maps:deep_put([mysql, server], Config, <<"mysql-ssl:3306">>);
set_server(redis_tcp, Config) ->
    emqx_utils_maps:deep_put([redis, servers], Config, <<"redis:6379">>);
set_server(redis_ssl, Config) ->
    emqx_utils_maps:deep_put([redis, servers], Config, <<"redis-ssl:6380">>).
