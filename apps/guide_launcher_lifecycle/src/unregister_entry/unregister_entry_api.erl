%%% @doc API handler: DELETE /api/launcher/entries/:entry_id
%%%
%%% Unregisters an app entry from the launcher sidebar.
%%% Lives in the unregister_entry desk for vertical slicing.
%%% @end
-module(unregister_entry_api).

-export([init/2, routes/0]).

routes() -> [{"/api/launcher/entries/:entry_id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"DELETE">> -> handle_delete(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_delete(Req0, _State) ->
    EntryId = cowboy_req:binding(entry_id, Req0),
    case EntryId of
        undefined ->
            hecate_api_utils:bad_request(<<"entry_id is required">>, Req0);
        _ ->
            do_unregister(EntryId, Req0)
    end.

do_unregister(EntryId, Req) ->
    CmdParams = #{entry_id => EntryId},
    case unregister_entry_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_unregister_entry:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                entry_id => unregister_entry_v1:get_entry_id(Cmd),
                version  => Version,
                events   => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
