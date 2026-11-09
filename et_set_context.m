function et_set_context(session, block_num, trial_num, attention, awareness, emotion)
% ET_SET_CONTEXT  Tell the eye-tracking module which block/trial is about to
% run (used for the TRIALID label and the per-trial variable messages).
% Call right before run_full_trial.
%
%   et_set_context('main', b, t, block.attention, block.awareness, block.emotion)
%   et_set_context('practice', bi, t, attn, awr, trial.face_emotion)
%   et_set_context('quest', 4+qi, n, attn, 'unaware', emotion)

    S = et_state('get');
    if strcmp(S.mode, 'off')
        return;
    end
    c = struct('session', session, 'block', block_num, 'trial', trial_num, ...
        'attention', attention, 'awareness', awareness, 'emotion', emotion);
    et_state('set', struct('context', c));
end
