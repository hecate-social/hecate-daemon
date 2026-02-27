%%% @doc Status bit flags for settings lifecycle aggregate.
-define(SETTINGS_INITIATED, 1).   %% 2^0
%% Bit 1 (value 2) was SETTINGS_PAIRED — removed, now in membership_aggregate
-define(SETTINGS_ARCHIVED,  4).   %% 2^2
