%  TRUNK SCRIPT: Real Data MC-SBD-STM Preprocessing
%  ========================================================================
%  Loads a raw Nanonis .3ds dataset and produces the cleaned volume Y that
%  the decomposition trunk consumes.
%
%  This is the first half of the real-data pipeline:
%
%      real_preprocess.m   .3ds  ->  Y  (this script)
%      real_block.m        Y     ->  kernels / activations / figures
%
%  `historical/real/hist_run_real_data.m` remains available as the retired
%  single-script raw-to-result path; use these two when preprocessing and
%  decomposition happen in separate sittings, which is the common case since
%  preprocessing is slow, interactive, and reused across many
%  decomposition runs.
%
%  This script is the standardized replacement for the retired
%  `historical/real/hist_preprocess.m`, and keeps that script's 2.1/2.2/...
%  step numbering.
%
%  WORKFLOW OVERVIEW:
%  ==================
%  PJ01P    create the project folder and open the session log
%  LR01A    load the .3ds file, build the energy axis
%  PR2.0    initialize the chain, pick the normalization slice
%  PR2.1    remove Bragg peaks
%  PR2.2    crop
%  PR2.2b   select energy slices (optional)
%  PR2.3    local streak removal
%  PR2.4    interpolation
%  PR2.5    defect masking
%  PR2.6a   correct streaks
%  PR2.6b   heal streaks
%  PR2.6c   directional plane subtraction (optional)
%  PR2.end  final normalization -> Y
%  SV01P    save the checkpoint and the handoff file
%
%  Run the section-2 blocks ONE AT A TIME (Ctrl+Enter) and look at each
%  result before deciding whether the next step is needed: every block is
%  optional, and some are worth re-running. The volume being worked on is
%  the local variable `data_carried`; each block overwrites it and shows the
%  result. Every choice you make is recorded in `preprocessing_params`,
%  which is saved alongside Y so a run can be reconstructed later.
%
% =========================================================================
%% SECTION 0: Path Initialization and Config
% =========================================================================

clc; clear; close all;

% Locate repo root even if MATLAB runs an unsaved Editor temp copy
% (mfilename then points at Temp\Editor_*). Fall back to pwd / which.
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
    error(['Could not locate init_sbd.m. cd to the MC-SBD-STM repo ', ...
        '(or a subfolder), save this script to disk if unsaved, then re-run. ', ...
        'Tried: %s'], strjoin(tried, ' | '));
end
addpath(repo_root);
run(fullfile(repo_root, 'init_sbd.m'));

% Initialize or preserve core structs
if ~exist('log', 'var');    log = struct();    end
if ~exist('data', 'var');   data = struct();   end
if ~exist('params', 'var'); params = struct(); end
if ~exist('meta', 'var');   meta = struct();   end

% Initialize/upgrade config schema (checkpoint-first design)
cfg = init_config();


%% =========================================================================
%% PJ01P: Project-01-Preprocess; Create project folder and session log
%  =========================================================================
%  Creates the project folder that owns this dataset's artifacts and opens a
%  fresh log file inside it. Pass this project path to real_block.m so
%  the decomposition runs land in the same project as their input. Set
%  params.project.root = pwd to create real_<timestamp> in the current dir.
%
%  Dependencies: createProjectStructure.m, logUsedBlocks.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
params.project.root = '';   % project root ('' = UI, starting at pwd). Set to pwd to create real_<ts> here.

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
fprintf('Creating project structure...\n');
meta = createProjectStructure('project_root', params.project.root, 'prefix', 'real');
fprintf('Project folder: %s\n\n', meta.project_name);

log.path = meta.project_path;
log.file = sprintf('preprocess_%s', meta.timestamp);
LOGcomment = sprintf("Real preprocessing session: %s", meta.project_name);
LOGcomment = logUsedBlocks(log.path, log.file, "PJ01P", LOGcomment, 1);
fprintf('Session log file: %s\n\n', fullfile(log.path, [log.file '_LOGfile.txt']));
registerTunableRun(log);


%% =========================================================================
%% LR01A: Load-Real-01-A; Load .3ds dataset
%  =========================================================================
%  Loads a raw STM/QPI dataset from a .3ds file and builds the energy axis
%  and basic dimensions. dIdV becomes data.real.data_original, the input to
%  every preprocessing step below.
%
%  Dependencies: loadRealDataset.m, load3dsall.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
cfg.load.data_file       = [];   % raw .3ds file name/path ([] = pick via UI)
cfg.load.smoothing_sigma = 3;    % smoothing sigma for the current data

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
[log, data, params, meta, cfg] = loadRealDataset(log, data, params, meta, cfg);

figure;
d3gridDisplay(data.real.data_original, 'dynamic');
title('Raw dIdV stack');


%% =========================================================================
%% PR2.0: Initialize the preprocessing chain
%  =========================================================================
%  Section 2 runs ONE STEP PER BLOCK, keeping the legacy preprocess.m
%  numbering (2.1, 2.2, ...). Run a block, look at what it did, then decide
%  whether to run the next one; every block is optional and several can be
%  re-run. The volume being worked on is the local variable `data_carried`,
%  and every choice you make is recorded in `preprocessing_params` so the
%  recipe can be saved with the result.
%
%  Block 2.end is what produces Y, so run it after your last step.
%
%  Background ROI: the first call to normalizeBackgroundToZeroMean3D draws
%  a rectangle and stores it in preprocessing_params.normalize_region; every
%  later call reuses that region. Cropping changes the FOV, so PR2.2 clears
%  the stored region and the next normalize redraws on the cropped stack.
%
%  Dependencies: d3gridDisplay.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
rangetype = 'dynamic';   % colour scaling for the step previews

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
preprocessing_params = struct();
preprocessing_params.normalize_region = [];   % filled by the first normalize call
data_carried    = data.real.data_original;
energy_range    = data.real.energy_range;
energy_selected = energy_range;   % narrowed by 2.2b if you select slices
data_cropped    = [];
data_masked     = [];

figure;
d3gridDisplay(data_carried, rangetype);
title('Preprocessing input');
preprocessing_params.slice_normalize = input('slice to normalize: ');

LOGcomment = sprintf("Preprocessing start: size=%s, slice_normalize=%d", ...
    mat2str(size(data_carried)), preprocessing_params.slice_normalize);
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.0", LOGcomment, 0);


%% =========================================================================
%% PR2.1: Remove Bragg peaks
%  =========================================================================
%  Normalizes the background, then removes Bragg peaks in reciprocal space.
%  You mark the peaks; the mask and recipe are kept for reproducibility.
%
%  Dependencies: normalizeBackgroundToZeroMean3D.m, removeBragg.m
%
%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[data_carried, ~, ~, preprocessing_params.normalize_region] = ...
    normalizeBackgroundToZeroMean3D(data_carried, rangetype, ...
    preprocessing_params.slice_normalize, preprocessing_params.normalize_region);

[data_braggremoved, bragg_mask2d, bragg_recipe] = removeBragg(data_carried);
preprocessing_params.bragg.mask2d = bragg_mask2d;
preprocessing_params.bragg.recipe = bragg_recipe;
data_carried = data_braggremoved;

figure; d3gridDisplay(data_carried, rangetype); title('2.1 After Bragg removal');

LOGcomment = sprintf("Bragg removal applied: size=%s", mat2str(size(data_carried)));
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.1", LOGcomment, 0);


%% =========================================================================
%% PR2.2: Crop dataset
%  =========================================================================
%  Crops to a square region, dropping edges damaged by the scan or by
%  earlier corrections. You drag the region on the reference slice.
%
%  Dependencies: maskSquare.m, gridCropMask.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
crop_ref_slice = 85;   % slice the crop region is drawn on

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
crop_ref_slice = min(crop_ref_slice, size(data_carried, 3));
preprocessing_params.crop_ref_slice = crop_ref_slice;

mask = maskSquare(data_carried, 0, crop_ref_slice, 'square');
data_cropped = gridCropMask(data_carried, mask);
data_carried = data_cropped;

% Crop changes the FOV; the pre-crop ROI no longer maps, so clear it and
% let the next normalize redraw on the cropped stack.
preprocessing_params.normalize_region = [];

figure; d3gridDisplay(data_carried, rangetype); title('2.2 After crop');

LOGcomment = sprintf("Crop applied: ref_slice=%d, size=%s (normalize_region cleared)", ...
    crop_ref_slice, mat2str(size(data_carried)));
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.2", LOGcomment, 0);


%% =========================================================================
%% PR2.2b: Select energy slices (optional)
%  =========================================================================
%  Keeps only the slices worth decomposing, and narrows energy_selected to
%  match. Skip this block to carry the full energy range, which is what the
%  legacy preprocess.m did. Everything downstream works on the reduced
%  stack, so cutting dead slices here speeds up every later step.
%
%  Prompts for a slice list, e.g. 20:120 or [5 9 14].
%
%  Dependencies: d3gridDisplay.m
%
%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure;
d3gridDisplay(data_carried, rangetype);
title('2.2b Pick slices to keep');
preprocessing_params.slices = input('input a list of slices: ');
close;

data_carried    = data_carried(:,:,preprocessing_params.slices);
energy_selected = energy_range(preprocessing_params.slices);

figure; d3gridDisplay(data_carried, rangetype); title('2.2b After slice selection');

LOGcomment = sprintf("Slice selection: slices=%s, size=%s", ...
    mat2str(preprocessing_params.slices), mat2str(size(data_carried)));
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.2b", LOGcomment, 0);


%% =========================================================================
%% PR2.3: Local streak removal (single reference slice)
%  =========================================================================
%  Marks streaks on one reference slice and applies the same correction to
%  every slice, looping manual-then-auto until you end it.
%
%  Dependencies: streakRemovalWorkflow.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
streak_interactive = true;      % false = replay a recorded recipe
streak_opts        = struct();  % to replay: struct('streak_params', <saved streak_params>)

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[data_carried, preprocessing_params.streak_params] = ...
    streakRemovalWorkflow(data_carried, streak_interactive, streak_opts);

figure; d3gridDisplay(data_carried, rangetype); title('2.3 After streak removal');

LOGcomment = sprintf("Streak removal: interactive=%d, size=%s", ...
    streak_interactive, mat2str(size(data_carried)));
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.3", LOGcomment, 0);


%% =========================================================================
%% PR2.4: Interpolation (single reference slice)
%  =========================================================================
%  Fills the lines emptied by 2.3. Worth running only if streak removal
%  left visible gaps.
%
%  Dependencies: interpRemovalWorkflow.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
interp_interactive = true;      % false = replay a recorded recipe
interp_opts        = struct();  % to replay: struct('interp_params', <saved interp_params>)

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[data_carried, preprocessing_params.interp_params] = ...
    interpRemovalWorkflow(data_carried, interp_interactive, interp_opts);

figure; d3gridDisplay(data_carried, rangetype); title('2.4 After interpolation');

LOGcomment = sprintf("Interpolation: interactive=%d, size=%s", ...
    interp_interactive, mat2str(size(data_carried)));
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.4", LOGcomment, 0);


%% =========================================================================
%% PR2.5: Defect masking
%  =========================================================================
%  Normalizes, then masks defect features so they do not dominate the
%  deconvolution. You pick the slice to work from and how many defect types
%  to mask.
%
%  Methods: 'gw' Gaussian window, 'tg' truncated Gaussian smoothing,
%  'threshold' threshold-and-remove.
%
%  Dependencies: normalizeBackgroundToZeroMean3D.m, gaussianMaskDefects.m,
%                defect_masking.m, thresholdDefects.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
preprocessing_params.defect_masking_method = 'tg';   % 'gw' | 'tg' | 'threshold'

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[data_carried, ~, ~, preprocessing_params.normalize_region] = ...
    normalizeBackgroundToZeroMean3D(data_carried, rangetype, ...
    preprocessing_params.slice_normalize, preprocessing_params.normalize_region);

f1 = figure;
d3gridDisplay(data_carried, rangetype);
title('2.5 Inspect defects');
preprocessing_params.defect_slice    = input('Enter defect slice number: ');
preprocessing_params.num_defect_type = input('enter how many types of defects to mask: ');
close(f1);

switch preprocessing_params.defect_masking_method
    case 'gw'
        [data_masked, ~] = defect_masking(data_carried, preprocessing_params.defect_slice);
    case 'tg'
        [data_masked, preprocessing_params.defect_mask, ...
            preprocessing_params.defect_centers, preprocessing_params.defect_sigmas] = ...
            gaussianMaskDefects(data_carried, preprocessing_params.defect_slice, ...
            preprocessing_params.num_defect_type);
    case 'threshold'
        [data_masked, preprocessing_params.defect_mask] = ...
            thresholdDefects(data_carried, preprocessing_params.defect_slice);
    otherwise
        error('Unknown defect masking method. Choose "gw", "tg", or "threshold".');
end
data_carried = data_masked;

figure; d3gridDisplay(data_carried, rangetype); title('2.5 After defect masking');

LOGcomment = sprintf("Defect masking: method=%s, defect_slice=%d, num_types=%d", ...
    preprocessing_params.defect_masking_method, preprocessing_params.defect_slice, ...
    preprocessing_params.num_defect_type);
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.5", LOGcomment, 0);


%% =========================================================================
%% PR2.6a: Correct streaks
%  =========================================================================
%  Second-pass, whole-stack streak suppression in Fourier space.
%
%  Dependencies: normalizeBackgroundToZeroMean3D.m, RemoveStreaks.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
streak_correct_direction = 'vertical';   % 'vertical' | 'horizontal'

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[data_carried, ~, ~, preprocessing_params.normalize_region] = ...
    normalizeBackgroundToZeroMean3D(data_carried, rangetype, ...
    preprocessing_params.slice_normalize, preprocessing_params.normalize_region);

preprocessing_params.streak_correct_direction = streak_correct_direction;
[data_streakremoved, ~] = RemoveStreaks(data_carried, 'Direction', streak_correct_direction);
data_carried = data_streakremoved;

figure; d3gridDisplay(data_carried, rangetype); title('2.6a After streak correction');

LOGcomment = sprintf("Streak correction: direction=%s", streak_correct_direction);
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.6a", LOGcomment, 0);


%% =========================================================================
%% PR2.6b: Heal streaks
%  =========================================================================
%  Blends residual streak scars along one direction. Prompts for
%  horizontal, vertical, or none.
%
%  Dependencies: normalizeBackgroundToZeroMean3D.m, heal_streaks.m
%
%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[data_carried, ~, ~, preprocessing_params.normalize_region] = ...
    normalizeBackgroundToZeroMean3D(data_carried, rangetype, ...
    preprocessing_params.slice_normalize, preprocessing_params.normalize_region);

preprocessing_params.heal_direction = ...
    input('Enter direction to heal (horizontal/vertical/none): ', 's');
data_carried = heal_streaks(data_carried, preprocessing_params.heal_direction);

figure; d3gridDisplay(data_carried, rangetype); title('2.6b After healing');

LOGcomment = sprintf("Heal streaks: direction=%s", preprocessing_params.heal_direction);
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.6b", LOGcomment, 0);


%% =========================================================================
%% PR2.6c: Directional plane subtraction (optional)
%  =========================================================================
%  Forces zero slope along one real-space direction. Off the default path;
%  run only when a directional background survives the earlier steps.
%
%  Dependencies: normalizeBackgroundToZeroMean3D.m, d3plane_directional.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
preprocessing_params.real_space_direction = 'horizontal';   % 'horizontal' | 'vertical'
plane_line_width = 5;

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[data_carried, ~, ~, preprocessing_params.normalize_region] = ...
    normalizeBackgroundToZeroMean3D(data_carried, rangetype, ...
    preprocessing_params.slice_normalize, preprocessing_params.normalize_region);

[data_plane, ~] = d3plane_directional(data_carried, ...
    preprocessing_params.real_space_direction, 'LineWidth', plane_line_width);
data_carried = data_plane;

figure; d3gridDisplay(data_carried, rangetype); title('2.6c After plane subtraction');

LOGcomment = sprintf("Directional plane: direction=%s, line_width=%d", ...
    preprocessing_params.real_space_direction, plane_line_width);
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.6c", LOGcomment, 0);


%% =========================================================================
%% PR2.end: Final normalization -> Y
%  =========================================================================
%  Normalizes the background one last time and publishes the result as Y
%  (also stored in data.real.Y). Run this after the last preprocessing block
%  you used; it is what SV01P saves and what run_real_block.m consumes.
%
%  Dependencies: normalizeBackgroundToZeroMean3D.m
%
%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[Y, ~, ~, preprocessing_params.normalize_region] = ...
    normalizeBackgroundToZeroMean3D(data_carried, rangetype, ...
    preprocessing_params.slice_normalize, preprocessing_params.normalize_region);

data.real.Y               = Y;
data.real.preprocessing   = preprocessing_params;
data.real.energy_selected = energy_selected;
data.real.data_cropped    = data_cropped;
data.real.data_masked     = data_masked;
meta.stage                = "preprocess";

figure;
d3gridDisplay(Y, rangetype);
title('Preprocessed Y (final)');

LOGcomment = sprintf("Final normalization: Y size=%s, slices kept=%d", ...
    mat2str(size(Y)), numel(energy_selected));
LOGcomment = logUsedBlocks(log.path, log.file, "PR2.end", LOGcomment, 0);


%% =========================================================================
%% SV01P: Save-01-Preprocess; Write the preprocessed dataset
%  =========================================================================
%  Writes two files into the project folder:
%    <log.file>_preprocess_checkpoint.mat - full log/data/params/meta/cfg,
%        resumable and replayable
%    <run_label>_FULL.mat - plain variables (Y, data_original, energy_range,
%        preprocessing_params, ...), the handoff file that run_real_block.m
%        picks up through its LR01B variable picker
%
%  Dependencies: none
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
cfg.io.run_label            = 'ZrSiTe0528';   % stem for the handoff .mat
params.preprocessing.save_checkpoint  = true; % full resumable checkpoint
params.preprocessing.save_handoff     = true; % plain-variable file for run_real_block

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if params.preprocessing.save_checkpoint
    checkpoint_file = fullfile(log.path, sprintf('%s_preprocess_checkpoint.mat', log.file));
    save(checkpoint_file, 'log', 'data', 'params', 'meta', 'cfg', '-v7.3');
    fprintf('Saved preprocess checkpoint to %s\n', checkpoint_file);
    LOGcomment = sprintf("Preprocess checkpoint saved: %s", checkpoint_file);
    LOGcomment = logUsedBlocks(log.path, log.file, "SV01P", LOGcomment, 0);
end

if params.preprocessing.save_handoff
    data_original = data.real.data_original;

    handoff_file = fullfile(log.path, sprintf('%s_FULL.mat', cfg.io.run_label));
    if exist(handoff_file, 'file')
        ts = datestr(now, 'yyyymmdd_HHMMSS');
        [fpath, fname, fext] = fileparts(handoff_file);
        handoff_file = fullfile(fpath, sprintf('%s_%s%s', fname, ts, fext));
    end
    save(handoff_file, 'Y', 'data_original', 'data_cropped', 'data_masked', ...
        'energy_range', 'energy_selected', 'preprocessing_params', '-v7.3');
    fprintf('Saved handoff dataset to %s\n', handoff_file);
    LOGcomment = sprintf("Handoff dataset saved: %s", handoff_file);
    LOGcomment = logUsedBlocks(log.path, log.file, "  ^  ", LOGcomment, 0);
end


%% =========================================================================
%% FINAL: Real-data preprocessing complete
%  =========================================================================
LOGcomment = logUsedBlocks(log.path, log.file, "DONE ", "Real preprocessing script finished", 0);

fprintf('========================================\n');
fprintf('Real-data MC-SBD-STM preprocessing finished.\n');
fprintf('Project: %s\n', meta.project_path);
fprintf('Log file: %s_LOGfile.txt\n', log.file);
fprintf('\nNext step: run scripts/real/run_real_block.m and set\n');
fprintf('  params.project.existing_path = ''%s'';\n', meta.project_path);
fprintf('to keep the decomposition run in this project.\n');
fprintf('========================================\n');
