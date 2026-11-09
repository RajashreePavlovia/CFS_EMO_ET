function order = build_probe1_order(cfg, participant_id)
% BUILD_PROBE1_ORDER  Counterbalance the on-screen order of the 5 Probe-1
% options (on-task / SDT / TRI / SIT / blank-mind) across participants, so
% response-key mapping doesn't get confounded with a fixed button meaning.
%
%   order = build_probe1_order(cfg, participant_id)
%
% INPUT
%   cfg            - struct from config_experiment()
%   participant_id - positive integer participant number
%
% OUTPUT
%   order - 1x5 cell array giving cfg.probe1_options in the on-screen
%           order this participant should see them (key 1 = order{1}, etc.)
%
% METHOD: cyclic (Latin-square-style) rotation keyed to participant_id,
% so options rotate through all 5 starting positions across participants
% 1-5, then repeats for 6-10, etc. This guarantees perfectly even
% counterbalancing across every 5 consecutive participant IDs, unlike a
% random shuffle (which only balances on average over many participants).

    opts = cfg.probe1_options;
    n = numel(opts);
    shift = mod(participant_id - 1, n); % participant 1 -> shift 0, participant 2 -> shift 1, ...
    order = opts([ (shift+1):n, 1:shift ]);
end
