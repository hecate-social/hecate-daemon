-define(ITEM_INITIATED, 1).
-define(ITEM_RENAMED,   2).
-define(ITEM_MOVED,     4).
-define(ITEM_ARCHIVED,  8).
-define(ITEM_STARRED,  16).

-define(ITEM_FLAG_MAP, #{
    1  => <<"initiated">>,
    2  => <<"renamed">>,
    4  => <<"moved">>,
    8  => <<"archived">>,
    16 => <<"starred">>
}).
