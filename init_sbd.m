function [] = init_sbd( mode, setdefconfig )
%INIT_SBD   Initializes subdirectories and default config settings.
%
%   Optional arguments:
%       mode - to turn off messages, set to 'quiet'.
%           Verbose by default.
%
%       setdefconfig - whether to apply default config settings.
%           Default: true.
%
%   Adds to path: repo root, config/, lib/ (and subdirs, with lib/utils
%   first), historical/solvers/, 3rd party/, and
%   run entrance/scripts/{real,synthetic,phase_space,tool}/.

    if nargin < 1;  mode = 'verbose';       end
    if nargin < 2;  setdefconfig = true;    end

    % Check if ManOpt has been imported
    if exist('trustregions', 'file') ~= 2
        error('Manopt needs to be imported: <a href="http://www.manopt.org">http://www.manopt.org</a>.%s','');
    end

    fp = fileparts(mfilename('fullpath'));
    addpath(fp);

    addIfDir(fullfile(fp, 'config'), true);

    libdir = fullfile(fp, 'lib');
    if isfolder(libdir)
        addpath(genpath(libdir));
        % Prefer lib/utils over any same-named file elsewhere on the path.
        addIfDir(fullfile(libdir, 'utils'), false, '-begin');
    elseif isfolder(fullfile(fp, 'Dong_func'))
        addpath(genpath(fullfile(fp, 'Dong_func')));
    end

    addIfDir(fullfile(fp, 'historical', 'solvers'), false);

    if isfolder(fullfile(fp, '3rd party'))
        addpath(genpath(fullfile(fp, '3rd party')));
    else
        addIfDir(fullfile(fp, 'vendor'), true);
    end

    scripts_root = fullfile(fp, 'run entrance', 'scripts');
    if ~isfolder(scripts_root)
        scripts_root = fullfile(fp, 'scripts');
    end
    if isfolder(scripts_root)
        addIfDir(fullfile(scripts_root, 'real'), false);
        addIfDir(fullfile(scripts_root, 'synthetic'), false);
        addIfDir(fullfile(scripts_root, 'phase_space'), false);
        addIfDir(fullfile(scripts_root, 'tool'), false);
    end

    if setdefconfig;    default_config_settings(mode);  end

    if ~strcmp(mode, 'quiet')
        disp('Subdirectories and config settings initialized.');
    end
end

function addIfDir(p, with_genpath, varargin)
    if ~isfolder(p)
        return;
    end
    if with_genpath
        addpath(genpath(p), varargin{:});
    else
        addpath(p, varargin{:});
    end
end
