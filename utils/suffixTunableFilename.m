function out = suffixTunableFilename(filename)
%SUFFIXTUNABLEFILENAME Append the active trial suffix to a generic tunable name.
%   OUT = SUFFIXTUNABLEFILENAME(FILENAME)
%
%   If MC_SBD_TUNABLE_ID is set (see registerTunableRun) and FILENAME's
%   basename is Xsolve_config_tunable or Asolve_config_tunable, returns the
%   same path with _<run_id> inserted before the extension.
%   Already-suffixed names and all other files are returned unchanged.

    out = filename;
    if nargin < 1 || isempty(filename)
        return;
    end

    run_id = '';
    if isappdata(0, 'MC_SBD_TUNABLE_ID')
        run_id = getappdata(0, 'MC_SBD_TUNABLE_ID');
    end
    if isempty(run_id)
        run_id = getenv('MC_SBD_TUNABLE_ID');
    end
    if isempty(run_id)
        return;
    end
    run_id = regexprep(char(run_id), '[^A-Za-z0-9_-]', '_');

    filename = char(filename);
    [parent, name, ext] = fileparts(filename);
    if ~ismember(name, {'Xsolve_config_tunable', 'Asolve_config_tunable'})
        return;
    end
    if endsWith(name, ['_' run_id])
        return;
    end
    out = fullfile(parent, [name '_' run_id ext]);
end
