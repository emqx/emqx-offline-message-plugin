%%--------------------------------------------------------------------
%% Copyright (c) 2025 EMQ Technologies Co., Ltd. All Rights Reserved.
%%--------------------------------------------------------------------

-module(emqx_omp_mysql).

-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").

-behaviour(emqx_omp).

-export([
    on_message_acked/3,
    on_session_subscribed/3
]).

-define(DELETE_SQL, "DELETE FROM mqtt_msg WHERE msgid = ?").
-define(SELECT_SQL,
    ("SELECT id, topic, msgid, sender, qos, payload, retain, UNIX_TIMESTAMP(arrived) as arrived"
    " FROM mqtt_msg WHERE topic = ?")
).

%%--------------------------------------------------------------------
%% Action
%%--------------------------------------------------------------------

-spec on_message_acked(Envs :: map(), ConnectorName :: binary(), Opts :: map()) -> ok.
on_message_acked(#{id := MsgId} = Envs, ConnectorName, Opts) ->
    ResourceId = resource_id(ConnectorName),

    case emqx_resource:simple_sync_query(ResourceId, {sql, ?DELETE_SQL, [MsgId]}) of
        ok ->
            emqx_metrics_worker:inc(emqx_omp_metrics_worker, message_acked, success),
            ok;
        {error, Reason} ->
            emqx_metrics_worker:inc(emqx_omp_metrics_worker, message_acked, fail),
            ?SLOG(error, #{
                msg => "omp_mysql_on_message_acked_error",
                envs => Envs,
                connector_name => ConnectorName,
                opts => Opts,
                reason => Reason
            }),
            {error, Reason}
    end.

-spec on_session_subscribed(Envs :: map(), ConnectorName :: binary(), Opts :: map()) -> ok.
on_session_subscribed(#{topic := Topic} = Envs, ConnectorName, Opts) ->
    ResourceId = resource_id(ConnectorName),
    case emqx_resource:simple_sync_query(ResourceId, {sql, ?SELECT_SQL, [Topic]}) of
        {ok, Columns, Rows} ->
            Messages = to_messages(Columns, Rows),
            ok = deliver_messages(Topic,Messages),
            emqx_metrics_worker:inc(emqx_omp_metrics_worker, session_subscribed, success),
            ok;
        {error, Reason} ->
            emqx_metrics_worker:inc(emqx_omp_metrics_worker, session_subscribed, fail),
            ?SLOG(error, #{
                msg => "omp_mysql_on_session_subscribed_error",
                envs => Envs,
                connector_name => ConnectorName,
                opts => Opts,
                reason => Reason
            }),
            {error, Reason}
    end.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

deliver_messages(Topic, Messages) ->
    lists:foreach(fun(Message) ->
        self() ! {deliver, Topic, Message}
    end, Messages).

resource_id(ConnectorName) ->
    <<"connector:", ConnectorName/binary>>.

to_messages(Columns, Rows) ->
    [record_to_msg(lists:zip(Columns, Row)) || Row <- Rows].

record_to_msg(Record) ->
    record_to_msg(Record, new_message()).

record_to_msg([], Msg) ->
    Msg;
record_to_msg([{<<"id">>, Id} | Record], Msg) ->
    record_to_msg(Record, emqx_message:set_header(mysql_id, Id, Msg));
record_to_msg([{<<"msgid">>, MsgId} | Record], Msg) ->
    record_to_msg(Record, Msg#message{id = emqx_guid:from_hexstr(MsgId)});
record_to_msg([{<<"topic">>, Topic} | Record], Msg) ->
    record_to_msg(Record, Msg#message{topic = Topic});
record_to_msg([{<<"sender">>, Sender} | Record], Msg) ->
    record_to_msg(Record, Msg#message{from = Sender});
record_to_msg([{<<"qos">>, Qos} | Record], Msg) ->
    record_to_msg(Record, Msg#message{qos = Qos});
record_to_msg([{<<"retain">>, R} | Record], Msg) ->
    record_to_msg(Record, Msg#message{flags = #{retain => to_bool(R)}});
record_to_msg([{<<"payload">>, Payload} | Record], Msg) ->
    record_to_msg(Record, Msg#message{payload = Payload});
record_to_msg([{<<"arrived">>, Arrived} | Record], Msg) ->
    record_to_msg(Record, Msg#message{timestamp = Arrived});
record_to_msg([_ | Record], Msg) ->
    record_to_msg(Record, Msg).

new_message() ->
    #message{
        id = <<>>,
        qos = 0,
        flags = #{},
        topic = <<>>,
        payload = <<>>,
        timestamp = 0,
        headers = #{}
    }.

to_bool(0) -> false;
to_bool(1) -> true;
to_bool(undefined) -> false;
to_bool(null) -> false.
