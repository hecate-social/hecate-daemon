%%% @doc Container-aware host detection.
%%%
%%% Inside a container, os:cmd("whoami") returns "root" and
%%% net_adm:localhost() returns the container hostname. These
%%% functions check HECATE_USER and HECATE_HOSTNAME env vars
%%% first (set by the Quadlet container file from systemd
%%% specifiers), falling back to OS detection.
-module(shared_host).

-export([hostname/0, user/0]).

%% @doc Returns the real hostname.
%% Priority: HECATE_HOSTNAME env var, then net_adm:localhost().
-spec hostname() -> binary().
hostname() ->
    case os:getenv("HECATE_HOSTNAME") of
        false -> list_to_binary(net_adm:localhost());
        "" -> list_to_binary(net_adm:localhost());
        Host -> list_to_binary(Host)
    end.

%% @doc Returns the real OS user.
%% Priority: HECATE_USER env var, then whoami.
-spec user() -> binary().
user() ->
    case os:getenv("HECATE_USER") of
        false -> detect_user();
        "" -> detect_user();
        User -> list_to_binary(User)
    end.

%%% Internal

detect_user() ->
    list_to_binary(string:trim(os:cmd("whoami"), trailing, "\n")).
