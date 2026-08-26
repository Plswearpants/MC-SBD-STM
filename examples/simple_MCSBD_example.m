%  SIMPLE MCSBD EXAMPLE
%  ========================================================================
%  One 2D synthetic STM observation (a single energy slice), then MCSBD.
%  This is the GD01A + DS01A path from scripts/synthetic/synthetic_data.m,
%  without all-slice proliferation and without session logging.
%
%  Recommended (deterministic, after the dataset is frozen):
%      S0 -> LD01A -> DS01A -> VR01A
%  Generate your own observation (LDoS required):
%      S0 -> GD01A (set force_generate if a freeze already exists)
%          -> DS01A -> VR01A  (skip LD01A so the new draw is kept)
%  Freeze a new bundled example (run once, after GD01A):
%      S0 -> GD01A -> WS01A
%      (set force_generate and overwrite_example_dataset to replace a freeze)
%
%  Frozen file is data + params only. LD01A reloads those two structs.
%  Solver knobs live in DS01A; they are applied after load or generate.
%
%  Requires Manopt. Generation also needs an LDoS .mat (params.synGen.LDoS_path).
%
%  Author: Dong Chen
%  Project: MC-SBD-STM

clc; clear; close all;

%% S0: Path init
repo_root = '';
seeds = {fileparts(mfilename('fullpath')), pwd};
w = which('init_sbd');
if isempty(w); w = which('init_sbd.m'); end
if ~isempty(w); seeds{end+1} = fileparts(w); end %#ok<AGROW>
tried = {};
for i = 1:numel(seeds)
    d = seeds{i};
    if isempty(d) || any(strcmp(tried, d)); continue; end
    tried{end+1} = d; %#ok<AGROW>
    while true
        if exist(fullfile(d, 'init_sbd.m'), 'file')
            repo_root = d;
            break;
        end
        parent = fileparts(d);
        if isempty(parent) || strcmp(parent, d); break; end
        d = parent;
    end
    if ~isempty(repo_root); break; end
end
if isempty(repo_root)
    error(['Could not locate init_sbd.m. cd to the repo root ', ...
        '(or a subfolder), save this script if unsaved, then re-run.']);
end
addpath(repo_root);
run(fullfile(repo_root, 'init_sbd.m'));

example_dataset_dir = fullfile(repo_root, 'examples', 'example_data', 'simple_mcsbd_2d');
example_dataset_name = 'simple_mcsbd_2d';
example_dataset_mat = fullfile(example_dataset_dir, [example_dataset_name '.mat']);

% Wrappers still take a log struct; empty path/file writes nothing.
log = struct('path', '', 'file', '');

%% GD01A: Generate one 2D synthetic slice
% Optional. Same presets as scripts/synthetic/synthetic_data.m, with
% num_slices = 1 so Y is a single observation and MCSBD runs in 2D.
% When the bundled example exists, this cell skips so a full-file run stays
% deterministic (use LD01A). Set force_generate = true to create a new draw.

force_generate = true;

if ~exist('repo_root', 'var') || isempty(repo_root)
    error('GD01A needs S0 first (repo_root / example_dataset_mat).');
end

if exist(example_dataset_mat, 'file') && ~force_generate
    fprintf(['Bundled example exists; skipping GD01A.\n', ...
        'Set force_generate = true in this cell to generate a new draw,\n', ...
        'or run LD01A to load the frozen dataset.\n']);
else
    params = struct();
    params.synGen.SNR = 3;
    params.synGen.N_obs = 50;
    params.synGen.observation_resolution = 3;
    params.synGen.defect_density = 0.01;
    params.synGen.num_slices = 1;
    params.synGen.ref_slice = 1;
    params.synGen.vis_generation = false;
    params.synGen.normalization_type = 'dynamic';

    ldos_default = fullfile(repo_root, 'examples', 'example_data', ...
        'LDoS_single_defects_self=0.3.mat');
    if exist(ldos_default, 'file')
        params.synGen.LDoS_path = ldos_default;
    else
        [ldos_file, ldos_dir] = uigetfile( ...
            {'*.mat', 'LDoS MAT-files (*.mat)'}, ...
            'Select LDoS simulation .mat', ...
            fullfile(repo_root, 'examples'));
        if isequal(ldos_file, 0)
            error('LDoS file is required to generate the 2D synthetic slice.');
        end
        params.synGen.LDoS_path = fullfile(ldos_dir, ldos_file);
    end

    fprintf('Generating 2D synthetic observation (num_slices=1)...\n');
    [data, params] = generateSyntheticData(log, params);
    fprintf('Auto-initializing kernels from ground truth...\n');
    [data, params] = autoInitializeKernels(log, data, params);
end

%% WS01A: Freeze generated dataset (run once after GD01A)
% Temporary save of data + params for later LD01A loads. Does not replace
% GD01A. Default is not to overwrite an existing freeze.

overwrite_example_dataset = false;

if ~exist('repo_root', 'var') || isempty(repo_root)
    error('WS01A needs S0 (repo_root / example_dataset_mat).');
elseif ~exist('data', 'var') || ~isstruct(data) || ~isfield(data, 'synGen') ...
        || ~exist('params', 'var') || ~isstruct(params)
    fprintf(['Skipping WS01A (no in-memory generated dataset).\n', ...
        'Run S0 -> GD01A first, then this cell, to freeze a new example.\n']);
elseif exist(example_dataset_mat, 'file') && ~overwrite_example_dataset
    fprintf(['Bundled example already exists:\n  %s\n', ...
        'Set overwrite_example_dataset = true in WS01A to replace it.\n'], ...
        example_dataset_mat);
else
    if ~exist(example_dataset_dir, 'dir')
        mkdir(example_dataset_dir);
    end
    save(example_dataset_mat, 'data', 'params');
    fprintf('Bundled example saved:\n  %s\n', example_dataset_mat);
end

%% LD01A: Load frozen dataset for a future run
% Default reproduction path. Restores data + params. Solver presets are
% still applied in DS01A (not taken from a frozen params.mcsbd_slice).

if ~exist('repo_root', 'var') || isempty(repo_root)
    error('LD01A needs S0 (repo_root / example_dataset_mat).');
end
if ~exist(example_dataset_mat, 'file')
    error(['Bundled example not found:\n  %s\n', ...
        'Run S0 -> GD01A -> WS01A once to freeze it, or generate with GD01A ', ...
        'and skip this cell.'], example_dataset_mat);
end

loaded = load(example_dataset_mat);
if ~isfield(loaded, 'data') || ~isfield(loaded, 'params')
    error('Bundled example must contain data and params.');
end
data = loaded.data;
params = loaded.params;
if ~isfield(data, 'synGen')
    error('Loaded dataset is missing data.synGen.');
end
if ~exist('log', 'var') || ~isstruct(log)
    log = struct('path', '', 'file', '');
end

fprintf('Loaded bundled example: %s\n', example_dataset_mat);

%% DS01A: Run MCSBD on the 2D slice
% Solver is MCSBD_synthetic (via decomposeReferenceSlice), same as the
% official synthetic trunk's reference-slice block.
% These presets are the run recipe: they apply to loaded or generated data.

params.mcsbd_slice.initial_iteration = 2;
params.mcsbd_slice.maxIT = 15;
params.mcsbd_slice.lambda1 = 0.02;
params.mcsbd_slice.phase2_enable = false;
params.mcsbd_slice.lambda2 = 0.05;
params.mcsbd_slice.nrefine = 5;
params.mcsbd_slice.kplus_factor = 0.5;
params.mcsbd_slice.signflip_threshold = 0.2;
params.mcsbd_slice.xpos = true;
params.mcsbd_slice.getbias = true;
params.mcsbd_slice.Xsolve_method = 'FISTA';
params.mcsbd_slice.use_xinit = [];
params.mcsbd_slice.show_progress = true;

fprintf('Running MCSBD on the 2D reference slice...\n');
[data, params] = decomposeReferenceSlice(log, data, params);

%% VR01A: Visualize reconstruction
% Reconstructed kernels/activations live in mcsbd_slice (A, X, b, extras).
data = organizeData(data, 'extract');
if ~isfield(data, 'A') || isempty(data.A)
    error(['No reconstructed kernels in data.A. Re-run DS01A ', ...
        '(decomposeReferenceSlice now stores A with X/b/extras).']);
end
visualizeResults(data.Y_ref, data.A0_ref, data.A, data.X0_ref, data.X, ...
    data.b, data.extras);

fprintf('\nSimple 2D MCSBD example complete.\n');
