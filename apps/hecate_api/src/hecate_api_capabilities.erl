-module(hecate_api_capabilities).

-export([init/2]).

init(Req0, [announce]) ->
    handle_announce(Req0);
init(Req0, [update]) ->
    handle_update(Req0);
init(Req0, [retract]) ->
    handle_retract(Req0);
init(Req0, [discover]) ->
    handle_discover(Req0);
init(Req0, [get]) ->
    handle_get(Req0).

%% POST /capabilities/announce
handle_announce(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    handle_announce_decoded(Decoded, Req1).

handle_announce_decoded(#{
    <<"capability_mri">> := MRI,
    <<"agent_identity">> := Agent,
    <<"tags">> := Tags,
    <<"description">> := Desc
} = Payload, Req) ->
    Demo = maps:get(<<"demo_procedure">>, Payload, undefined),
    Metadata = maps:get(<<"metadata">>, Payload, #{}),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = #{
        capability_mri => MRI,
        agent_identity => Agent,
        tags => Tags,
        description => Desc,
        demo_procedure => Demo,
        metadata => Metadata#{announced_at => Timestamp}
    },

    handle_announce_command(announce_capability_v1:new(CmdMap), MRI, Req);
handle_announce_decoded(_, Req) ->
    error_response(Req, 400, invalid_request_body).

handle_announce_command({ok, Cmd}, MRI, Req) ->
    handle_announce_dispatch(maybe_announce_capability:dispatch(Cmd), MRI, Req);
handle_announce_command({error, Reason}, _MRI, Req) ->
    error_response(Req, 400, Reason).

handle_announce_dispatch({ok, Version, Events}, MRI, Req) ->
    Response = json:encode(#{
        ok => true,
        version => Version,
        events => Events,
        capability_mri => MRI
    }),
    Req2 = cowboy_req:reply(201,
        #{<<"content-type">> => <<"application/json">>},
        Response,
        Req
    ),
    {ok, Req2, []};
handle_announce_dispatch({error, Reason}, _MRI, Req) ->
    error_response(Req, 400, Reason).

%% POST /capabilities/:mri/update
handle_update(Req0) ->
    MRI = cowboy_req:binding(mri, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_update(MRI, Decoded, Req1).

do_update(MRI, #{<<"agent_identity">> := Agent} = Payload, Req) ->
    Timestamp = erlang:system_time(millisecond),
    CmdMap = #{
        capability_mri => MRI,
        agent_identity => Agent,
        tags => maps:get(<<"tags">>, Payload, undefined),
        description => maps:get(<<"description">>, Payload, undefined),
        demo_procedure => maps:get(<<"demo_procedure">>, Payload, undefined),
        metadata => maps:get(<<"metadata">>, Payload, #{updated_at => Timestamp})
    },
    dispatch_update(update_capability_v1:new(CmdMap), MRI, Req);
do_update(_MRI, _, Req) ->
    error_response(Req, 400, agent_identity_required).

dispatch_update({ok, Cmd}, MRI, Req) ->
    dispatch_result(maybe_update_capability:dispatch(Cmd), 200, MRI, Req);
dispatch_update({error, Reason}, _MRI, Req) ->
    error_response(Req, 400, Reason).

%% DELETE /capabilities/:mri (with body for agent_identity)
handle_retract(Req0) ->
    MRI = cowboy_req:binding(mri, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_retract(MRI, Decoded, Req1).

do_retract(MRI, #{<<"agent_identity">> := Agent} = Payload, Req) ->
    Reason = maps:get(<<"reason">>, Payload, undefined),
    case retract_capability_v1:new(MRI, Agent, Reason) of
        {ok, Cmd} ->
            dispatch_result(maybe_retract_capability:dispatch(Cmd), 200, MRI, Req);
        {error, ErrReason} ->
            error_response(Req, 400, ErrReason)
    end;
do_retract(_MRI, _, Req) ->
    error_response(Req, 400, agent_identity_required).

dispatch_result({ok, Version, Events}, Status, MRI, Req) ->
    Response = json:encode(#{
        ok => true,
        version => Version,
        events => Events,
        capability_mri => MRI
    }),
    Req2 = cowboy_req:reply(Status,
        #{<<"content-type">> => <<"application/json">>},
        Response,
        Req
    ),
    {ok, Req2, []};
dispatch_result({error, Reason}, _Status, _MRI, Req) ->
    error_response(Req, 400, Reason).

%% GET /capabilities/discover?tag=...&agent_id=...&limit=...&offset=...
handle_discover(Req0) ->
    QsVals = cowboy_req:parse_qs(Req0),

    %% Build filters from query string
    Filters0 = #{},

    %% Add tag filter if present
    Filters1 = case proplists:get_value(<<"tag">>, QsVals) of
        undefined -> Filters0;
        TagBin -> Filters0#{tag => TagBin}
    end,

    %% Add agent_id filter if present
    Filters2 = case proplists:get_value(<<"agent_id">>, QsVals) of
        undefined -> Filters1;
        AgentBin -> Filters1#{agent_id => AgentBin}
    end,

    %% Add limit if present
    Filters3 = case proplists:get_value(<<"limit">>, QsVals) of
        undefined -> Filters2;
        LimitBin ->
            Limit = binary_to_integer(LimitBin),
            Filters2#{limit => Limit}
    end,

    %% Add offset if present
    Filters = case proplists:get_value(<<"offset">>, QsVals) of
        undefined -> Filters3;
        OffsetBin ->
            Offset = binary_to_integer(OffsetBin),
            Filters3#{offset => Offset}
    end,

    %% Execute query via query service
    case list_capabilities:execute(Filters) of
        {ok, Results} ->
            Response = json:encode(#{
                ok => true,
                results => Results,
                count => length(Results)
            }),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Response,
                Req0
            ),
            {ok, Req, []};
        {error, Reason} ->
            error_response(Req0, 500, Reason)
    end.

%% GET /capabilities/:mri
handle_get(Req0) ->
    MRI = cowboy_req:binding(mri, Req0),

    %% Execute query via query service
    case find_capability:execute(MRI) of
        {ok, Capability} ->
            Response = json:encode(#{
                ok => true,
                capability => Capability
            }),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Response,
                Req0
            ),
            {ok, Req, []};
        {error, not_found} ->
            error_response(Req0, 404, capability_not_found);
        {error, _Reason} ->
            error_response(Req0, 500, database_error)
    end.

%% Internal functions

error_response(Req, StatusCode, Reason) ->
    Response = json:encode(#{
        ok => false,
        error => atom_to_binary(Reason, utf8)
    }),
    Req2 = cowboy_req:reply(StatusCode,
        #{<<"content-type">> => <<"application/json">>},
        Response,
        Req
    ),
    {ok, Req2, []}.
