%%% @doc API handler: POST /api/briefcase/files/:file_id/share
%%%
%%% Flips a local file from `private` to `shared`. Optional JSON body:
%%% ```
%%% { "recipients": "realm" }                     → realm-scope grant
%%% { "recipients": ["did:macula:alice", ...] }   → DID-scope per recipient
%%% { "recipients": ["realm", "did:macula:..."] } → realm + DID mix
%%% ```
%%% Default (missing or empty body) is `"realm"`.
%%%
%%% Phase D orchestration: after the briefcase aggregate persists the
%%% `file_shared_v1` event, `issue_licenses_for_share` mints a CEK,
%%% wraps it per recipient, and dispatches one `issue_license_v1` per
%%% grantee. The batched mesh emitter collapses those into a single
%%% `licenses_issued_batch_v1` FACT.
%%%
%%% Response: `{ok: true, file_id, batch_id, license_ids}`.
%%% @end
-module(share_file_api).

-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/files/:file_id/share", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    {Recipients, Req1} = read_recipients(Req0),
    case share(FileId, Recipients) of
        {ok, Result} ->
            hecate_api_utils:json_ok(maps:put(file_id, FileId, Result), Req1);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req1)
    end.

share(FileId, Recipients)
  when is_binary(FileId), byte_size(FileId) > 0, is_list(Recipients),
       Recipients =/= [] ->
    SharedAt = erlang:system_time(millisecond),
    Cmd = share_file_v1:new(FileId, SharedAt, Recipients),
    dispatch_share_and_issue(FileId, Recipients, Cmd);
share(FileId, _) when not is_binary(FileId) ->
    {error, file_id_required};
share(_, []) ->
    {error, no_recipients};
share(_, _) ->
    {error, bad_args}.

dispatch_share_and_issue(FileId, Recipients, Cmd) ->
    case maybe_share_file:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            issue_licenses(FileId, Recipients);
        {error, _} = Err ->
            Err
    end.

issue_licenses(FileId, Recipients) ->
    case identity() of
        {ok, IssuerDid} ->
            Realm = hecate_topics:realm(),
            issue_licenses_for_share:dispatch_for(
                FileId, Realm, IssuerDid, Recipients);
        {error, _} = Err ->
            Err
    end.

identity() ->
    case hecate_identity:get_mri() of
        {ok, Mri}       -> {ok, Mri};
        not_initialized -> {error, identity_not_initialized}
    end.

%%--------------------------------------------------------------------
%% Body parsing
%%--------------------------------------------------------------------

read_recipients(Req0) ->
    case cowboy_req:has_body(Req0) of
        true  -> read_body(Req0);
        false -> {[realm], Req0}
    end.

read_body(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    {parse_recipients(Body), Req1}.

parse_recipients(<<>>) -> [realm];
parse_recipients(Bin) ->
    try json:decode(Bin) of
        #{<<"recipients">> := V}    -> normalize(V);
        #{recipients := V}          -> normalize(V);
        _                           -> [realm]
    catch _:_ -> [realm]
    end.

normalize(<<"realm">>)      -> [realm];
normalize(null)             -> [realm];
normalize(V) when is_list(V) ->
    Clean = [normalize_one(X) || X <- V],
    [X || X <- Clean, X =/= undefined];
normalize(V) when is_binary(V) -> [normalize_one(V)];
normalize(_) -> [realm].

normalize_one(<<"realm">>)    -> realm;
normalize_one(realm)          -> realm;
normalize_one(B) when is_binary(B), byte_size(B) > 0 -> B;
normalize_one(_)              -> undefined.
