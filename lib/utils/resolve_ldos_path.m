function ldos_path = resolve_ldos_path(hint, varargin)
%RESOLVE_LDOS_PATH Locate an LDoS simulation .mat for synthetic generation.
%   PATH = RESOLVE_LDOS_PATH()
%   PATH = RESOLVE_LDOS_PATH(HINT)
%   PATH = RESOLVE_LDOS_PATH(..., 'interactive', TF)
%
%   HINT may be empty, a filename, a relative path, or an absolute path.
%   Search order when HINT is missing:
%     1) store/synthetic/ldos/
%     2) examples/
%     3) examples/example_data/
%   Preferred filename: LDoS_single_defects_self=0.6_save.mat, then any
%   *LDoS*.mat. If nothing is found and interactive is true, opens a file
%   picker starting at store/synthetic/ldos/.

    if nargin < 1
        hint = '';
    end
    p = inputParser;
    addParameter(p, 'interactive', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    interactive = p.Results.interactive;

    paths = repo_payload_paths(fileparts(mfilename('fullpath')));
    search_dirs = {paths.ldos, paths.examples, paths.examples_data};
    preferred = { ...
        'LDoS_single_defects_self=0.6_save.mat', ...
        'LDoS_single_defects_self=0.3.mat', ...
        'LDoS_sim.mat', ...
        'LDoS_multi_1_defects_20260325_105344.mat' ...
        };

    hint = char(hint);
    if ~isempty(hint)
        if exist(hint, 'file') == 2
            ldos_path = hint;
            return;
        end
        [~, hint_name, hint_ext] = fileparts(hint);
        basename = [hint_name hint_ext];
        found = search_named(search_dirs, {basename});
        if ~isempty(found)
            ldos_path = found;
            return;
        end
    end

    found = search_named(search_dirs, preferred);
    if isempty(found)
        found = search_glob(search_dirs, '*LDoS*.mat');
    end
    if ~isempty(found)
        ldos_path = found;
        return;
    end

    start_dir = first_existing_dir(search_dirs, pwd);
    if interactive
        [fname, fpath] = uigetfile({'*.mat', 'LDoS MAT-files (*.mat)'}, ...
            'Select LDoS simulation .mat', start_dir);
        if isequal(fname, 0)
            error('resolve_ldos_path:NoFile', ...
                'LDoS .mat is required. Looked in: %s', strjoin(search_dirs, ' | '));
        end
        ldos_path = fullfile(fpath, fname);
        return;
    end

    error('resolve_ldos_path:NotFound', ...
        'LDoS .mat not found. Looked in: %s', strjoin(search_dirs, ' | '));
end

function found = search_named(dirs, names)
    found = '';
    for di = 1:numel(dirs)
        if ~isfolder(dirs{di})
            continue;
        end
        for ni = 1:numel(names)
            cand = fullfile(dirs{di}, names{ni});
            if exist(cand, 'file') == 2
                found = cand;
                return;
            end
        end
    end
end

function found = search_glob(dirs, pattern)
    found = '';
    for di = 1:numel(dirs)
        if ~isfolder(dirs{di})
            continue;
        end
        hits = dir(fullfile(dirs{di}, pattern));
        hits = hits(~[hits.isdir]);
        if ~isempty(hits)
            found = fullfile(dirs{di}, hits(1).name);
            return;
        end
    end
end
