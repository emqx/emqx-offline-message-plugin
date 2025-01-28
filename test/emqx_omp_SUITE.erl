%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_omp_SUITE).

-include_lib("eunit/include/eunit.hrl").

-compile(nowarn_export_all).
-compile(export_all).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").

-import(emqx_omp_test_helpers, [api_get/1, api_get_raw/1, api_post/2, api_delete/1]).

all() ->
    emqx_omp_test_helpers:all(?MODULE).

init_per_suite(Config) ->
    ok = emqx_omp_test_helpers:start(),

    %% clean up
    ok = emqx_omp_test_api_helpers:delete_all_rules(),
    ok = emqx_omp_test_api_helpers:delete_all_actions(),
    ok = emqx_omp_test_api_helpers:delete_all_plugins(),
    ok = emqx_omp_test_api_helpers:delete_all_connectors(),

    %% install plugin
    {PluginId, Filename} = emqx_omp_test_api_helpers:find_plugin(),
    ok = emqx_omp_test_api_helpers:upload_plugin(Filename),
    ok = emqx_omp_test_api_helpers:start_plugin(PluginId),

    %% create connectors
    ok = emqx_omp_test_api_helpers:create_connector(redis_connector("omp")),
    ok = emqx_omp_test_api_helpers:create_connector(mysql_connector("omp")),

    [{plugin_id, PluginId}, {plugin_filename, Filename} | Config].

end_per_suite(_Config) ->
    %% cleanup
    % ok = emqx_omp_test_api_helpers:delete_all_plugins(),
    % ok = emqx_omp_test_api_helpers:delete_all_connectors(),

    ok = emqx_omp_test_helpers:stop(),
    ok.

t_ok(_Config) ->
    PublishAction = publish_mysql_action("omp_publish_action", "omp"),
    ct:print("PublishAction: ~p", [PublishAction]),
    ok = emqx_omp_test_api_helpers:create_action(PublishAction),

    PublishRule = publish_mysql_rule("omp_publish_rule", "t/#", "mysql:omp_publish_action"),
    ct:print("PublishRule: ~p", [PublishRule]),
    ok = emqx_omp_test_api_helpers:create_rule(PublishRule),

    SubscribeAckRule = subscribe_ack_rule("omp_subscribe_ack_rule", "t/#", "mysql:omp", #{}),
    ok = emqx_omp_test_api_helpers:create_rule(SubscribeAckRule),

    Payload = emqx_guid:to_hexstr(emqx_guid:gen()),

    ClientPub = emqtt_connect(),
    _ = emqtt:publish(ClientPub, <<"t/1">>, Payload, 1),
    ok = emqtt:stop(ClientPub),

    ct:sleep(1000),

    ClientSub = emqtt_connect(),
    _ = emqtt:subscribe(ClientSub, <<"t/1">>, 1),

    receive
        {publish, #{payload := Payload} = Msg} ->
            ct:print("Received message: ~p", [Msg])
    after 1000 ->
        ct:fail("Message not received")
    end,

    ok = emqtt:stop(ClientSub),

    ok.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

emqtt_connect() ->
    ct:print("Connecting to MQTT broker"),
    {ok, Pid} = emqtt:start_link([{host, "127.0.0.1"}, {port, 1883}]),
    {ok, _} = emqtt:connect(Pid),
    Pid.

redis_connector(Name) ->
    #{
        <<"type">> => <<"redis">>,
        <<"name">> => Name,
        <<"parameters">> => #{
            <<"server">> => <<"redis">>,
            <<"redis_type">> => <<"single">>,
            <<"pool_size">> => 8,
            <<"password">> => <<"public">>,
            <<"database">> => 0
        },
        <<"resource_opts">> => #{
            <<"health_check_interval">> => <<"15s">>,
            <<"start_timeout">> => <<"5s">>
        },
        <<"ssl">> => #{
            <<"enable">> => false,
            <<"verify">> => <<"verify_peer">>
        }
    }.

mysql_connector(Name) ->
    #{
        <<"type">> => <<"mysql">>,
        <<"name">> => iolist_to_binary(Name),
        <<"server">> => <<"mysql">>,
        <<"database">> => <<"emqx">>,
        <<"pool_size">> => 8,
        <<"username">> => <<"emqx">>,
        <<"password">> => <<"public">>,
        <<"ssl">> => #{
            <<"enable">> => false,
            <<"verify">> => <<"verify_peer">>
        },
        <<"resource_opts">> => #{
            <<"health_check_interval">> => <<"15s">>,
            <<"start_timeout">> => <<"5s">>
        }
    }.

publish_mysql_action(Name, ConnectorName) ->
    #{
        <<"type">> => <<"mysql">>,
        <<"name">> => iolist_to_binary(Name),
        <<"parameters">> => #{
            <<"sql">> => <<
                "insert into mqtt_msg(msgid, sender, topic, qos, retain, payload, arrived) values"
                "(${id}, ${clientid}, ${topic}, ${qos}, ${retain}, ${payload}, FROM_UNIXTIME(${timestamp}/1000))"
            >>,
            <<"undefined_vars_as_null">> => false
        },
        <<"enable">> => true,
        <<"connector">> => iolist_to_binary(ConnectorName)
    }.

publish_mysql_rule(Name, TopicFilter, PublishActionName) ->
    PublishSQLTemplate =
        "SELECT id, clientid, topic, qos, payload, timestamp, int(coalesce(flags.retain, 0)) as retain FROM \"~s\"",
    PublishSQL = iolist_to_binary(io_lib:format(PublishSQLTemplate, [TopicFilter])),
    PublishRule = #{
        <<"name">> => iolist_to_binary(Name),
        <<"actions">> => [iolist_to_binary(PublishActionName)],
        <<"description">> => <<"Offline Message Plugin Publish Action">>,
        <<"sql">> => PublishSQL
    },
    PublishRule.

subscribe_ack_rule(Name, TopicFilter, ConnectorName, Opts) ->
    SubscribeAckSQLTemplate =
        "SELECT * FROM \"$events/session_subscribed\", \"$events/message_acked\" WHERE topic =~~ '~s'",
    SubscribeAckSQL = iolist_to_binary(io_lib:format(SubscribeAckSQLTemplate, [TopicFilter])),

    SubscribeAckRule = #{
        <<"name">> => iolist_to_binary(Name),
        <<"actions">> => [
            #{
                <<"function">> => <<"emqx_omp:action">>,
                <<"args">> =>
                    #{
                        <<"connector_name">> => iolist_to_binary(ConnectorName),
                        <<"opts">> => Opts
                    }
            }
        ],
        <<"description">> => <<"Offline Message Plugin Subscribe/Ack Action">>,
        <<"sql">> => SubscribeAckSQL
    },
    SubscribeAckRule.
