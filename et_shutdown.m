function et_shutdown()
% ET_SHUTDOWN  Close the EDF, copy it from the host PC into the data folder,
% and disconnect. Safe to call at any time (also from the error handler) and
% when eye tracking is off.
    S = et_state('get');
    if strcmp(S.mode, 'off')
        return;
    end
    if strcmp(S.mode, 'live')
        try
            Eyelink('Message', 'SESSION_END');
            Eyelink('Command', 'set_idle_mode');
            WaitSecs(0.5);
            Eyelink('CloseFile');
            fprintf('Eye tracking: transferring %s.edf from the host ...\n', S.edf_name);
            % no-argument ReceiveFile = the call used by the working IIT-Bombay script on this
            % kind of set-up: it saves <name>.edf into the CURRENT folder; we then move it to data\
            status = Eyelink('ReceiveFile');
            src = fullfile(pwd, [S.edf_name '.edf']);
            dst = fullfile(S.data_dir, [S.edf_name '.edf']);
            if status > 0 && isfile(src)
                if ~strcmp(src, dst), movefile(src, dst); end
                fprintf('  saved to %s (%d bytes)\n', dst, status);
            else
                warning('et_shutdown:transfer', 'EDF transfer returned %d -- copy %s.edf from the host PC by hand!', status, S.edf_name);
            end
        catch err
            warning('et_shutdown:error', 'Eye-tracker shutdown problem: %s -- the EDF may still be on the host PC.', err.message);
        end
        try
            Eyelink('Shutdown');
        catch
        end
    else
        fprintf('Eye tracking (dummy): message log is in %s\n', S.dummy_log);
    end
    et_state('reset');
    if isappdata(0, 'cfs_et_geom')
        rmappdata(0, 'cfs_et_geom');
    end
end
