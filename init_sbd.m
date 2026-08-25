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
%   Adds to path: repo root, core/, utils/, config/, lib/ (or Dong_func/),
%   solvers/, vendor/, colormap/, and scripts/{real,synthetic,phase_space}/.

    if nargin < 1;  mode = 'verbose';       end
    if nargin < 2;  setdefconfig = true;    end

    % Check if ManOpt has been imported
    if exist('trustregions', 'file') ~= 2
        error('Manopt needs to be imported: <a href="http://www.manopt.org">http://www.manopt.org</a>.%s','');
    end

    fp = [fileparts(mfilename('fullpath')) '/'];
    addpath(fp);

    for d = {'core', 'utils', 'config'}
        addpath(genpath([fp d{1}]));
    end

    % Domain library: prefer lib/ after rename; fall back to Dong_func/.
    if isfolder([fp 'lib'])
        addpath(genpath([fp 'lib']));
    elseif isfolder([fp 'Dong_func'])
        addpath(genpath([fp 'Dong_func']));
    end

    if isfolder([fp 'solvers'])
        addpath(genpath([fp 'solvers']));
    end

    if isfolder([fp 'vendor'])
        addpath(genpath([fp 'vendor']));
    end

    if isfolder([fp 'colormap'])
        addpath(genpath([fp 'colormap']));
    end

    if isfolder([fp 'scripts'])
        addpath([fp 'scripts' filesep 'real']);
        addpath([fp 'scripts' filesep 'synthetic']);
        addpath([fp 'scripts' filesep 'phase_space']);
    end

    % Ensure utils/update_config wins over any lib shim.
    addpath([fp 'utils'], '-begin');

    if setdefconfig;    default_config_settings(mode);  end

    if ~strcmp(mode, 'quiet')
        disp('Subdirectories and config settings initialized.');
    end
end
