%%% @doc Torch status bit flags and flag map.
%%% Include via: -include_lib("manage_torches/include/torch_status.hrl").

-ifndef(TORCH_STATUS_HRL).
-define(TORCH_STATUS_HRL, true).

-define(TORCH_INITIATED,     1).   %% 2^0
-define(TORCH_DNA_ACTIVE,    2).   %% 2^1 (Discovery & Analysis active)
-define(TORCH_DNA_COMPLETE,  4).   %% 2^2 (Discovery & Analysis complete)
-define(TORCH_IMPLEMENTING,  8).   %% 2^3
-define(TORCH_COMPLETED,    16).   %% 2^4
-define(TORCH_ARCHIVED,     32).   %% 2^5 (soft deleted)

-define(TORCH_FLAG_MAP, #{
    0                    => <<"New">>,
    ?TORCH_INITIATED     => <<"\xf0\x9f\x8c\xb1 Initiated"/utf8>>,
    ?TORCH_DNA_ACTIVE    => <<"\xf0\x9f\x94\x8d Discovering"/utf8>>,
    ?TORCH_DNA_COMPLETE  => <<"\xe2\x9c\x85 Discovery Done"/utf8>>,
    ?TORCH_IMPLEMENTING  => <<"\xf0\x9f\x94\xa8 Implementing"/utf8>>,
    ?TORCH_COMPLETED     => <<"\xf0\x9f\x8f\x81 Completed"/utf8>>,
    ?TORCH_ARCHIVED      => <<"\xf0\x9f\x93\xa6 Archived"/utf8>>
}).

-endif.
