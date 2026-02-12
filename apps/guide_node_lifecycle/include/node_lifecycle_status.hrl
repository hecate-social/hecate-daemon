%%% @doc Status bit flags for node lifecycle aggregate.
%%%
%%% Node-level flags:
-define(NL_REGISTERED, 1).
-define(NL_ARCHIVED,   2).

%%% Connector-level flags (stored per-connector in connectors map):
-define(CONN_REGISTERED, 1).
-define(CONN_ACTIVE,     2).
-define(CONN_SUSPENDED,  4).
-define(CONN_REVOKED,    8).
