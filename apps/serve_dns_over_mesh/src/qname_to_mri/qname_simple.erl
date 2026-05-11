%%% @doc Helper for "simple" MRI types whose only construction
%%% concern is calling `macula_mri:new/3' with a Type/Realm/Path
%%% tuple the dispatcher has already assembled.
%%%
%%% The per-type modules (qname_user, qname_app, qname_service,
%%% qname_device, etc.) delegate here via `from_components/3'.
%%% Special-case types (qname_proc, qname_topic, qname_station,
%%% qname_org, qname_reverse_v6) have their own modules.
%%%
%%% This helper exists to keep the per-type modules to 3-line
%%% delegations rather than each duplicating the macula_mri:new
%%% call.
%%% @end
-module(qname_simple).

-export([from_components/3]).

-spec from_components(Type :: atom(), Realm :: binary(),
                      Path :: [binary()]) ->
    {ok, binary()} | {error, atom()}.
from_components(Type, Realm, Path) ->
    case macula_mri:new(Type, Realm, Path) of
        {ok, Mri}      -> {ok, Mri};
        {error, _} = E -> E
    end.
