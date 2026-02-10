%%% @doc Cartwheel status bit flags and flag map.
%%% Include via: -include_lib("manage_cartwheels/include/cartwheel_status.hrl").

-ifndef(CARTWHEEL_STATUS_HRL).
-define(CARTWHEEL_STATUS_HRL, true).

-define(CW_INITIATED,             1).   %% 2^0
-define(CW_DISCOVERY_ACTIVE,      2).   %% 2^1
-define(CW_DISCOVERY_COMPLETE,    4).   %% 2^2
-define(CW_ARCHITECTURE_ACTIVE,   8).   %% 2^3
-define(CW_ARCHITECTURE_COMPLETE,16).   %% 2^4
-define(CW_TESTING_ACTIVE,       32).   %% 2^5
-define(CW_TESTING_COMPLETE,     64).   %% 2^6
-define(CW_DEPLOYMENT_ACTIVE,   128).   %% 2^7
-define(CW_DEPLOYMENT_COMPLETE, 256).   %% 2^8
-define(CW_COMPLETED,           512).   %% 2^9
-define(CW_REVISITING,         1024).   %% 2^10

-define(CW_FLAG_MAP, #{
    0                      => <<"New">>,
    ?CW_INITIATED          => <<"\xf0\x9f\x8c\xb1 Initiated"/utf8>>,
    ?CW_DISCOVERY_ACTIVE   => <<"\xf0\x9f\x94\x8d DnA Active"/utf8>>,
    ?CW_DISCOVERY_COMPLETE => <<"\xe2\x9c\x85 DnA Done"/utf8>>,
    ?CW_ARCHITECTURE_ACTIVE   => <<"\xf0\x9f\x93\x90 AnP Active"/utf8>>,
    ?CW_ARCHITECTURE_COMPLETE => <<"\xe2\x9c\x85 AnP Done"/utf8>>,
    ?CW_TESTING_ACTIVE     => <<"\xf0\x9f\xa7\xaa TnI Active"/utf8>>,
    ?CW_TESTING_COMPLETE   => <<"\xe2\x9c\x85 TnI Done"/utf8>>,
    ?CW_DEPLOYMENT_ACTIVE  => <<"\xf0\x9f\x9a\x80 DnO Active"/utf8>>,
    ?CW_DEPLOYMENT_COMPLETE => <<"\xe2\x9c\x85 DnO Done"/utf8>>,
    ?CW_COMPLETED          => <<"\xf0\x9f\x8f\x81 Completed"/utf8>>,
    ?CW_REVISITING         => <<"\xf0\x9f\x94\x84 Revisiting"/utf8>>
}).

-endif.
