%%% @doc Bit flags for briefcase file lifecycle status.
%%%
%%% Use with evoq_bit_flags for status manipulation.
%%% Powers of two — each flag gets a unique bit position.
%%% @end

-define(FILE_UPLOADED,  1).   %% 2^0
-define(FILE_REVISED,   2).   %% 2^1
-define(FILE_MOVED,     4).   %% 2^2
-define(FILE_ARCHIVED,  8).   %% 2^3  (soft delete, recoverable)
-define(FILE_PURGED,   16).   %% 2^4  (hard delete, chunks GCable)
-define(FILE_SHARED,   32).   %% 2^5  (at least one access grant active)
