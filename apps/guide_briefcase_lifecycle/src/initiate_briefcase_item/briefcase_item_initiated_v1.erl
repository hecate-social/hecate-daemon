-module(briefcase_item_initiated_v1).
-behaviour(evoq_event).
-export([new/1, to_map/1, from_map/1, event_type/0]).

event_type() -> briefcase_item_initiated_v1.

new(Params) ->
    Now = erlang:system_time(millisecond),
    #{
        event_type => <<"briefcase_item_initiated_v1">>,
        item_id    => maps:get(item_id, Params),
        name       => maps:get(name, Params),
        kind       => maps:get(kind, Params),
        parent_id  => maps:get(parent_id, Params, undefined),
        plugin     => maps:get(plugin, Params, undefined),
        file_type  => maps:get(file_type, Params, undefined),
        icon       => maps:get(icon, Params, undefined),
        path       => maps:get(path, Params, undefined),
        mime_type  => maps:get(mime_type, Params, undefined),
        size       => maps:get(size, Params, 0),
        created_at => Now
    }.

to_map(M) when is_map(M) -> M.
from_map(M) -> {ok, M}.
