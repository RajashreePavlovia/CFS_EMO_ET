function et_msg(fmt, varargin)
% ET_MSG  Send a time-stamped message to the EyeLink data file (printf-style).
% Does nothing when eye tracking is off. In 'dummy' mode the message is
% appended, with a GetSecs time stamp, to the dummy log text file instead, so
% you can see exactly what would have been written to the EDF.
%
%   et_msg('STIM_ONSET vbl=%.6f', vbl)
%
% Call it IMMEDIATELY after the Screen('Flip') that put the event on screen.
% Put the flip's VBL time in the text (vbl=...) so the message can later be
% aligned exactly with the display-PC time stamps in the CSV files.

    S = et_state('get');
    if strcmp(S.mode, 'off')
        return;
    end
    txt = sprintf(fmt, varargin{:});
    if strcmp(S.mode, 'live')
        try
            Eyelink('Message', '%s', txt);
        catch
            % never let a failed message stop the experiment
        end
    elseif strcmp(S.mode, 'dummy') && ~isempty(S.dummy_log)
        fid = fopen(S.dummy_log, 'a');
        if fid > 0
            fprintf(fid, '%.4f\t%s\n', GetSecs, txt);
            fclose(fid);
        end
    end
end
