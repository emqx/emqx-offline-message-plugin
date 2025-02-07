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
        % {group, mysql},
        {group, redis}
    ].

groups() ->
    All = emqx_omp_test_helpers:all(?MODULE),
    [
        {mysql, [], [{group, buffered}, {group, unbuffered}]},
        {redis, [], [{group, buffered}, {group, unbuffered}]},
        {buffered, [], [{group, tcp}, {group, ssl}]},
        {unbuffered, [], [{group, tcp}, {group, ssl}]},
        {tcp, [], All},
        {ssl, [], []}
    ].

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

init_per_group(mysql, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    PluginConfig = emqx_utils_maps:deep_put([mysql, enable], PluginConfig0, true),
    [{backend, mysql} | ?set_config(plugin_config, PluginConfig, Config)];
init_per_group(redis, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    PluginConfig = emqx_utils_maps:deep_put([redis, enable], PluginConfig0, true),
    [{backend, redis} | ?set_config(plugin_config, PluginConfig, Config)];
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
init_per_group(tcp, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    Backend = ?config(backend, Config),
    PluginConfig1 = emqx_utils_maps:deep_put([Backend, ssl, enable], PluginConfig0, false),
    PluginConfig2 = set_server(Backend, tcp, PluginConfig1),
    ?set_config(plugin_config, PluginConfig2, Config);
init_per_group(ssl, Config) ->
    PluginConfig0 = ?config(plugin_config, Config),
    Backend = ?config(backend, Config),
    PluginConfig1 = emqx_utils_maps:deep_put([Backend, ssl, enable], PluginConfig0, true),
    PluginConfig2 = set_server(Backend, ssl, PluginConfig1),
    ?set_config(plugin_config, PluginConfig2, Config).

end_per_group(_Group, _Config) ->
    ok.

init_per_testcase(_Case, Config) ->
    PluginId = ?config(plugin_id, Config),
    PluginConfig = ?config(plugin_config, Config),
    ok = emqx_omp_test_api_helpers:configure_plugin(PluginId, PluginConfig),
    ct:print("PluginConfig: ~p", [PluginConfig]),
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
            redis_type => <<"single">>,
            pool_size => 8,
            username => <<"">>,
            password => <<"">>,
            database => 0,
            batch_size => 1,
            batch_time => 50
        },
        mysql => #{
            enable => false,
            ssl => DefaultSSLConfig#{server_name_indication => <<"mysql-server">>},
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
            batch_time => 50
        }
    }.

empty_plugin_config() ->
    PluginConfig0 = plugin_config(),
    PluginConfig1 = emqx_utils_maps:deep_put([mysql, enable], PluginConfig0, false),
    PluginConfig2 = emqx_utils_maps:deep_put([redis, enable], PluginConfig1, false),
    PluginConfig2.

set_server(mysql, tcp, Config) ->
    emqx_utils_maps:deep_put([mysql, server], Config, <<"mysql:3306">>);
set_server(mysql, ssl, Config) ->
    emqx_utils_maps:deep_put([mysql, server], Config, <<"mysql-ssl:3306">>);
set_server(redis, tcp, Config) ->
    emqx_utils_maps:deep_put([redis, servers], Config, <<"redis:6379">>);
set_server(redis, ssl, Config) ->
    emqx_utils_maps:deep_put([redis, servers], Config, <<"redis-ssl:6379">>).
