function paths = registerTunableRun(log)
%REGISTERTUNABLERUN Bind worker tunables to this trial and log their names.
%   PATHS = REGISTERTUNABLERUN(LOG)
%
%   Sets MT_SBD_TUNABLE_ID from log.file so update_config / resolve_tunable_config
%   write and read:
%     config/runtime_tunables/Xsolve_config_tunable_<log.file>.mat
%     config/runtime_tunables/Asolve_config_tunable_<log.file>.mat
%
%   Copies the immutable templates into those files if they do not exist yet,
%   then appends a CFG01 line to the trial log with directory and filenames.
%   The suffix matches log.file, so the log and the .mat names trace each other.
%
%   See also: suffixTunableFilename, update_config, resolve_tunable_config

    paths = struct('dir', '', 'xsolve', '', 'asolve', '', 'run_id', '');
    if nargin < 1 || ~isstruct(log) || ~isfield(log, 'file') || isempty(log.file)
        warning('registerTunableRun:NoLogFile', ...
            'log.file is empty; worker tunables will keep the unsuffixed names.');
        return;
    end

    run_id = regexprep(char(log.file), '[^A-Za-z0-9_-]', '_');
    setappdata(0, 'MT_SBD_TUNABLE_ID', run_id);
    setenv('MT_SBD_TUNABLE_ID', run_id);

    repo_root = fileparts(fileparts(mfilename('fullpath')));
    tun_dir = fullfile(repo_root, 'config', 'runtime_tunables');
    if ~exist(tun_dir, 'dir')
        mkdir(tun_dir);
    end

    xname = sprintf('Xsolve_config_tunable_%s.mat', run_id);
    aname = sprintf('Asolve_config_tunable_%s.mat', run_id);
    xpath = fullfile(tun_dir, xname);
    apath = fullfile(tun_dir, aname);

    xsrc = fullfile(repo_root, 'config', 'Xsolve_config.mat');
    asrc = fullfile(repo_root, 'config', 'Asolve_config.mat');
    if exist(xsrc, 'file') && exist(xpath, 'file') ~= 2
        copyfile(xsrc, xpath);
    end
    if exist(asrc, 'file') && exist(apath, 'file') ~= 2
        copyfile(asrc, apath);
    end

    comment = sprintf('Worker tunables saved in %s as %s and %s (suffix=%s)', ...
        tun_dir, xname, aname, run_id);
    if isfield(log, 'path') && ~isempty(log.path)
        logUsedBlocks(log.path, log.file, 'CFG01', comment, 0);
    end
    fprintf('%s\n', comment);

    paths.dir = tun_dir;
    paths.xsolve = xpath;
    paths.asolve = apath;
    paths.run_id = run_id;
end
