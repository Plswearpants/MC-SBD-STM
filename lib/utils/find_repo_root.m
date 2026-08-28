function repo_root = find_repo_root(varargin)
%FIND_REPO_ROOT Locate MC-SBD-STM repo root (directory containing init_sbd.m).
%   REPO_ROOT = FIND_REPO_ROOT()
%   REPO_ROOT = FIND_REPO_ROOT(START_DIR)
%   REPO_ROOT = FIND_REPO_ROOT(START_DIR1, START_DIR2, ...)
%
%   Tries each start directory (walking parents), then pwd, then which('init_sbd').
%   This survives MATLAB Editor temp copies (Temp\Editor_*) when pwd is inside
%   the repo or init_sbd is already on the path.

    seeds = {};
    for i = 1:nargin
        if ~isempty(varargin{i})
            seeds{end+1} = char(varargin{i}); %#ok<AGROW>
        end
    end
    seeds{end+1} = pwd; %#ok<AGROW>

    w = which('init_sbd');
    if isempty(w)
        w = which('init_sbd.m');
    end
    if ~isempty(w)
        seeds{end+1} = fileparts(w); %#ok<AGROW>
    end

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
                return;
            end
            parent = fileparts(d);
            if isempty(parent) || strcmp(parent, d)
                break;
            end
            d = parent;
        end
    end

    error(['Could not locate init_sbd.m. cd to the MC-SBD-STM repo (or a ', ...
        'subfolder), save the script to disk if it is unsaved, then re-run. ', ...
        'Seeds tried: %s'], strjoin(tried, ' | '));
end
