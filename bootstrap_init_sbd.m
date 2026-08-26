function repo_root = bootstrap_init_sbd()
%BOOTSTRAP_INIT_SBD Find repo root and run init_sbd (Editor-temp safe).
%   REPO_ROOT = BOOTSTRAP_INIT_SBD()
%
%   Safe to call from trunk scripts even when MATLAB runs an unsaved Editor
%   buffer under Temp\Editor_*: falls back to pwd and which('init_sbd').

    seeds = {};
    try
        % dbstack often still points at the on-disk file when Editor uses a temp copy
        st = dbstack('-completenames');
        for i = 1:numel(st)
            if isfield(st(i), 'file') && ~isempty(st(i).file)
                seeds{end+1} = fileparts(st(i).file); %#ok<AGROW>
            end
        end
    catch
    end
    try
        seeds{end+1} = fileparts(mfilename('fullpath')); %#ok<AGROW>
    catch
    end
    seeds{end+1} = pwd; %#ok<AGROW>

    w = which('init_sbd');
    if isempty(w)
        w = which('init_sbd.m');
    end
    if ~isempty(w)
        seeds{end+1} = fileparts(w); %#ok<AGROW>
    end

    repo_root = '';
    tried = {};
    for i = 1:numel(seeds)
        start_dir = seeds{i};
        if isempty(start_dir) || any(strcmp(tried, start_dir))
            continue;
        end
        tried{end+1} = start_dir; %#ok<AGROW>
        d = start_dir;
        while true
            if exist(fullfile(d, 'init_sbd.m'), 'file')
                repo_root = d;
                break;
            end
            parent = fileparts(d);
            if isempty(parent) || strcmp(parent, d)
                break;
            end
            d = parent;
        end
        if ~isempty(repo_root)
            break;
        end
    end

    if isempty(repo_root)
        error(['Could not locate init_sbd.m. cd to the MC-SBD-STM repo root ', ...
            'or any subfolder, save this script if it is unsaved, then re-run.\n', ...
            'Tried: %s'], strjoin(tried, ' | '));
    end

    addpath(repo_root);
    run(fullfile(repo_root, 'init_sbd.m'));
end
