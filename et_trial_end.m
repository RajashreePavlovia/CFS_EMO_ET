function et_trial_end()
% ET_TRIAL_END  End of every trial (after the ITI): mark the end of the trial
% in the EDF and stop recording. Does nothing if eye tracking is off.
    S = et_state('get');
    if strcmp(S.mode, 'off')
        return;
    end
    et_msg('TRIAL_RESULT 0');
    if strcmp(S.mode, 'live')
        WaitSecs(0.02);
        Eyelink('StopRecording');
    end
end
