-module(briefcase_item_archived_v1).
-behaviour(evoq_event).
-export([new/1, to_map/1, from_map/1, event_type/0]).
event_type() -> briefcase_item_archived_v1.
new(#{item_id := Id}) ->
    #{event_type => <<"briefcase_item_archived_v1">>, item_id => Id, archived_at => erlang:system_time(millisecond)}.
to_map(M) -> M.
from_map(M) -> {ok, M}.
