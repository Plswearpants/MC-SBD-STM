%  TRUNK SCRIPT: Real Data MC-SBD-STM Block Run (preprocessed entry)
%  ========================================================================
%  Multi-kernel Tensor Shifted Blind Deconvolution for Scanning Tunneling
%  Microscopy, entered from an ALREADY-PREPROCESSED volume Y stored in a
%  .mat file, rather than from a raw .3ds file.
%
%  This is the second half of the real-data pipeline:
%
%      real_preprocess.m   .3ds  ->  Y
%      real_block.m        Y     ->  kernels / activations / figures (this script)
%
%  Use this trunk when preprocessing (denoising, cropping, streak removal,
%  masking) has already been done and saved. For the combined raw-to-result
%  pipeline in a single script, use `historical/real/hist_run_real_data.m`.
%
%  This script is the standardized replacement for the retired
%  `historical/real/hist_MCSBD_block_realdata1.m`, which remains available
%  for reference (and still carries the retired R-series experiment blocks
%  that are not reproduced here).
%
%  WORKFLOW OVERVIEW (CHECKPOINT STAGES):
%  ======================================
%  preprocess: load the preprocessed Y volume
%  pre-run   : reference slice selection, kernel initialization, ref-slice MC-SBD,
%              all-slice kernel proliferation
%  run       : all-slice MC-SBD over a chosen slice/kernel subset
%  post-run  : visualization (V-blocks) and derived analyses
%
%  Each major phase is handled by a wrapper function in `lib/wrapper` that
%  owns the heavy logic and logs to a project-local log file. The VR-series
%  visualization cells are exploratory and are not logged.
%
%  NOTE: This script is **interactive by default**. Pin the PRESETS marked
%  "[] = ask" to run it non-interactively for exact reproduction.
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
%% PJ01R: Project-01-Real; Create project folder and session log
%  =========================================================================
%  Opens a fresh log file for this decomposition run. Each pipeline block
%  through BR01A appends one entry, so the log records the presets and
%  interactive choices that produced the run. Visualization cells are not
%  logged.
%
%  Set existing_path to the project printed by real_preprocess.m to keep
%  a decomposition run in the same project as the data it consumes; leave it
%  empty to start a new project. Set params.project.root = pwd to land a
%  new project in the current directory.
%
%  Dependencies: createProjectStructure.m, logUsedBlocks.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
params.project.existing_path = '';   % '' = create a new project
params.project.root          = '';   % new-project root ('' = UI, starting at pwd)

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
if ~isempty(params.project.existing_path)
    if ~exist(params.project.existing_path, 'dir')
        error('params.project.existing_path does not exist: %s', params.project.existing_path);
    end
    meta.project_path = params.project.existing_path;
    [meta.project_root, meta.project_name] = fileparts(params.project.existing_path);
    meta.timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    fprintf('Joining existing project: %s\n\n', meta.project_name);
else
    fprintf('Creating project structure...\n');
    meta = createProjectStructure('project_root', params.project.root, 'prefix', 'real');
    fprintf('Project folder: %s\n\n', meta.project_name);
end

log.path = meta.project_path;
log.file = sprintf('realblock_%s', meta.timestamp);
LOGcomment = sprintf("Real block-run session: %s", meta.project_name);
LOGcomment = logUsedBlocks(log.path, log.file, "PJ01R", LOGcomment, 1);
fprintf('Session log file: %s\n\n', fullfile(log.path, [log.file '_LOGfile.txt']));
registerTunableRun(log);


%% =========================================================================
%% LR01B: Load-Real-01-B; Load preprocessed Y volume
%  =========================================================================
%  Loads an already-preprocessed volume Y from a .mat file. Prefer
%  store/real/processed/<sample>_<MMDD>/ (e.g. ZrSiTe_0528). When the file
%  or variable presets are empty, a file dialog opens there (then an entry picker).
%
%  Dependencies: loadRealPreprocessed.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
cfg.load.preprocessed_file = [];   % full path to the .mat ([] = pick via UI)
cfg.load.preprocessed_var  = [];   % variable name inside it ([] = pick via UI)
cfg.io.sample              = 'ZrSiTe';  % material prefix for store/real/processed/
cfg.io.sample_date         = '0528';    % MMDD; picker seeds <sample>_<sample_date>
cfg.io.output_root         = [];   % extra output root ([] = pwd; logs still go to the project folder)

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
[log, data, params, meta, cfg] = loadRealPreprocessed(log, data, params, meta, cfg);

rangetype = 'dynamic';   % display range mode for interactive previews


%% =========================================================================
%% RS01A: RefSlice-Real-01-A; Decompose reference slice
%  =========================================================================
%  Selects a reference slice, initializes kernels on it, enforces kernel
%  polarity, estimates the noise level, and runs MC-SBD on that single slice.
%  The kernel centers chosen here are captured so IP01R can reuse the same
%  K1...Kn ordering.
%
%  Dependencies: decomposeRefSliceReal.m, initialize_kernels.m, MC_SBD.m,
%                enforce_kernel_polarity.m, visualizeRealResult.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
params.refSlice.interactive = true;   % false = use the cfg.reference defaults below

% Reference-kernel initialization
cfg.reference.same_size            = true;              % all kernels same size?
cfg.reference.kerneltype           = 'selected';        % 'selected' or 'random'
cfg.reference.window_type          = 'gaussian';        % window applied to kernels
cfg.reference.square_size          = [80, 80];          % [height,width] when same_size
cfg.reference.default_ref_slice    = [];                % used when not interactive
cfg.reference.default_num_kernels  = [];                % used when not interactive

% MC-SBD settings for the reference slice
cfg.sliceRun.miniloop_iteration = 1;
cfg.sliceRun.outerloop_maxIT    = 3;
cfg.sliceRun.lambda1            = [0.02, 0.02, 0.02, 0.02, 0.02];  % Phase I regularization
cfg.sliceRun.phase2             = false;
cfg.sliceRun.kplus_factor       = 0.2;                             % kplus = ceil(factor * kernel_sizes)
cfg.sliceRun.lambda2            = [0.04, 0.04, 0.04, 0.04, 0.04];  % Phase II regularization
cfg.sliceRun.nrefine            = 4;
cfg.sliceRun.signflip           = 0.2;
cfg.sliceRun.xpos               = true;
cfg.sliceRun.getbias            = true;
cfg.sliceRun.Xsolve             = 'FISTA';

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
[log, data, params, meta, cfg] = decomposeRefSliceReal(log, data, params, meta, cfg);


%% =========================================================================
%% IP01R: Initialize-Proliferation-01-R; Initialize kernels for all slices
%  =========================================================================
%  Propagates the reference kernels across every energy slice. The kernel
%  centers can be reused from RS01A (keeping K1...Kn stable) or reselected by
%  hand; 'ask' shows the ordering preview and then prompts.
%
%  Dependencies: initProliferationReal.m, initialize_kernels_proliferation.m,
%                enforce_kernel_polarity.m, estimate_noise3D.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
cfg.blockInit.center_source      = 'ask';   % 'reference' | 'manual' | 'ask'
cfg.blockInit.show_order_preview = true;    % draw the K1...Kn preview figure
cfg.blockInit.reuse_noise_roi    = true;    % reuse the reference background ROI
cfg.blockInit.use_matrix         = true;
cfg.blockInit.change_size        = false;

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
[log, data, params, meta, cfg] = initProliferationReal(log, data, params, meta, cfg);


%% Save pre-run checkpoint (before block run; stakes are high)
% -------------------------------------------------------------------------
% PRESETS: set to false to skip saving before the block run
% -------------------------------------------------------------------------
params.preRun.save_checkpoint = true;

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if params.preRun.save_checkpoint
    prerun_file = fullfile(log.path, sprintf('%s_prerun_checkpoint.mat', log.file));
    save(prerun_file, 'log', 'data', 'params', 'meta', 'cfg', '-v7.3');
    fprintf('Saved pre-run checkpoint to %s (before block run).\n', prerun_file);
    LOGcomment = sprintf("Pre-run checkpoint saved: %s", prerun_file);
    LOGcomment = logUsedBlocks(log.path, log.file, "  ^  ", LOGcomment, 0);
end


%% =========================================================================
%% BR01A: Block-Run-Real-01-A; Decompose all slices (block run)
%  =========================================================================
%  Runs MC-SBD jointly over the selected slice and kernel subset. Kernel-
%  indexed presets (lambda1_base, lambda2) are given over the FULL kernel set
%  and sliced down to the requested subset, so changing kernels_to_run does
%  not require re-editing the lambda vectors.
%
%  Dependencies: runAllSlicesReal.m, MCSBD_all_slice_modified.m,
%                build_auto_trusted_slice_weights.m, notify_allslice_completion.m
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
params.blockRun.interactive    = false;        % true = prompt for slice indices
params.blockRun.slices_to_run  = 121:131;      % [] = all slices
params.blockRun.kernels_to_run = [1, 2, 3];    % [] = all kernels

params.blockRun.save_tagged_output        = true;   % <run_label>_s..._k..._ALL.mat
params.blockRun.plot_observation_fidelity = true;
params.blockRun.save_checkpoint           = false;  % full log/data/params/meta/cfg checkpoint

cfg.io.run_label = 'ZrSiTe0528';   % filename stem for the tagged output

% Trusted-slice weighting is still ALPHA. Keep OFF unless experimenting.
cfg.blockRun.use_trusted_slice_weights       = false;
cfg.blockRun.trusted_ratio_threshold_default = 1.5;
cfg.blockRun.use_default_manual_trusted_slices = false;
cfg.blockRun.show_trusted_plot               = true;

cfg.blockRun.miniloop_iteration = 1;
cfg.blockRun.outerloop_maxIT    = 5;
cfg.blockRun.lambda1_base       = [0.020, 0.02, 0.02, 0.02, 0.018];  % over the FULL kernel set
cfg.blockRun.phase2             = false;
cfg.blockRun.kplus_factor       = 0.2;
cfg.blockRun.lambda2            = [0.04, 0.04, 0.04, 0.04, 0.04];    % over the FULL kernel set
cfg.blockRun.nrefine            = 4;
cfg.blockRun.signflip           = 0.2;
cfg.blockRun.xpos               = true;
cfg.blockRun.getbias            = true;
cfg.blockRun.Xsolve             = 'FISTA';
cfg.blockRun.use_Xregulated     = false;
cfg.blockRun.use_xinit_from_ref = true;    % warm-start X from the reference activations
cfg.blockRun.allow_custom_update_order = true;
cfg.blockRun.notify_on_completion       = true;   % beep/popup + optional webhook/email

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
[log, data, params, meta, cfg] = runAllSlicesReal(log, data, params, meta, cfg);


%% =========================================================================
%% VR00R: Visualize-Real-00; Unpack block-run outputs
%  =========================================================================
%  Brings the block-run results out of data.real.blockRun into the working
%  variables the V-blocks below operate on, and builds the per-slice cell
%  view of the kernels. Run this before any other V-block.
%
%  Dependencies: none
%
% -------------------------------------------------------------------------
% PRESETS: User-configurable parameters
% -------------------------------------------------------------------------
params.visualize.energy_axis = [];   % per-slice energies for VR11R ([] = slice index)

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Y_used            = data.real.blockRun.Y_used;
Aout_ALL          = data.real.blockRun.Aout_ALL;
Xout_ALL          = data.real.blockRun.Xout_ALL;
bout_ALL          = data.real.blockRun.bout_ALL;
ALL_extras        = data.real.blockRun.ALL_extras;
A1_used           = data.real.blockRun.A1_used;
X_ref_used        = data.real.blockRun.X_ref_used;
kernel_sizes_used = data.real.blockRun.kernel_sizes_used;

[num_slices, num_kernels] = size(bout_ALL);
Aout_ALL_cell = cell(num_slices, num_kernels);
for s = 1:num_slices
    for k = 1:num_kernels
        Aout_ALL_cell{s,k} = Aout_ALL{k}(:,:,s);
    end
end


%% VR01R: Kernel movies
for k = 1:length(Aout_ALL)
    figure;
    d3gridDisplay(((Aout_ALL{k})), 'dynamic')
end

%% VR02R: QPI movies (inverted range)
for k = 1:length(Aout_ALL)
    figure;
    d3gridDisplay((qpiCalculate(Aout_ALL{k})), 'dynamic', -1)
end

%% VR03R: Plot Gaussian-broadened activation
Xout_gaussian = zeros(size(Xout_ALL));
kernel_size = size(Aout_ALL_cell{1,1});
for i = 1:size(Xout_ALL, 3)
    Xout_gaussian(:,:,i) = Xout_gaussian_broaden(Xout_ALL(:,:,i), kernel_size);
    figure; imagesc(Xout_gaussian(:,:,i)); colormap("gray"); axis square
    title(sprintf('Kernel type %d', i))
end

%% VR04R: Create reconstruction for all slices
Y_rec = zeros(size(Y_used));
for i = 1:size(Y_used,3)
    for k = 1:num_kernels
        Y_rec(:,:,i) = Y_rec(:,:,i) + convfft2(Aout_ALL_cell{i,k}, Xout_ALL(:,:,k)) + bout_ALL(i,k);
    end
end
figure;
d3gridDisplay(Y_rec, 'dynamic')

%% VR05R: Create reconstruction for initialized all slices
Y_init = zeros(size(Y_used));

tic;
for i = 1:size(Y_used,3)
    for k = 1:num_kernels
        Y_init(:,:,i) = Y_init(:,:,i) + convfft2(A1_used{k}(:,:,i), X_ref_used(:,:,k));
    end
end
toc;

figure;
d3gridDisplay(Y_init, 'dynamic')

%% VR06R: Reconstruction for per-kernel initialization
Y_init_perkernel = zeros(size(Y_used,1),size(Y_used,2),size(Y_used,3),num_kernels);

tic;
for k = 1:num_kernels
    Y_init_perkernel(:,:,:,k) = convfft3(A1_used{k}, X_ref_used(:,:,k));
end
toc;

%% VR07R: Create reconstruction for each kernel type
Y_rec_each = zeros([num_kernels,size(Y_used)]);
for i = 1:size(Y_used,3)
    for k = 1:num_kernels
        Y_rec_each(k,:,:,i) = convfft2(Aout_ALL_cell{i,k}, Xout_ALL(:,:,k));
    end
end

% create fft of Y_rec_each
FT_QPI_Y_rec_each = zeros([num_kernels,size(Y_used)]);
for k = 1:num_kernels
    FT_QPI_Y_rec_each(k,:,:,:) = qpiCalculate(squeeze(Y_rec_each(k,:,:,:)));
end

%% VR08R: Normalize and combine the per-kernel QPI montage
% Montage is QPI-only; the matching Y_rec_each row is left out on purpose.
qpi_Y_rec_show_Full = [];
for k = 1:num_kernels
    qpi_Y_rec_show_Full = [qpi_Y_rec_show_Full, squeeze(FT_QPI_Y_rec_each(k,:,:,:))]; %#ok<AGROW>
end

% Normalize each slice across all kernels
for i = 1:size(qpi_Y_rec_show_Full,3)
    qpi_Y_rec_show_Full(:,:,i) = 1-mat2gray(qpi_Y_rec_show_Full(:,:,i),[0,1]);
end

Y_rec_ALL_show_norm = qpi_Y_rec_show_Full;

%% VR09R: Display the normalized and combined results
figure;
d3gridDisplay(Y_rec_ALL_show_norm, 'dynamic');
title('Normalized Y_{rec} per kernel, FT-QPI combined');

%% VR10R: Y, Y_rec and Y residual
Y_resi = ALL_extras.phase1.residuals(:,:,:,end);
Y_full_visualize = [Y_used, Y_rec, Y_resi];
qpi_Y_full_visualize = [qpiCalculate(Y_used), qpiCalculate(Y_rec), qpiCalculate(Y_resi)];

% Normalize each slice across all panels
for i = 1:size(Y_full_visualize,3)
    Y_full_visualize(:,:,i) = mat2gray(Y_full_visualize(:,:,i));
    qpi_Y_full_visualize(:,:,i) = 1-mat2gray(qpi_Y_full_visualize(:,:,i),[0,1]);
end

% Combine normalized reconstructions and their FT-QPI
Y_show_norm = [Y_full_visualize; qpi_Y_full_visualize];

figure;
d3gridDisplay(Y_show_norm, 'dynamic');
title('Y | Y_{rec} | residual, with FT-QPI below');

%% VR11R: Write the video
% V labels each frame; fall back to the slice index when no energy axis is set.
V = params.visualize.energy_axis;
if isempty(V)
    V = 1:size(Y_show_norm, 3);
end

video_file = fullfile(log.path, sprintf('%s_Y_rec_residual.mp4', log.file));
if exist('gridVideoWriter', 'file') == 2
    gridVideoWriter(rot90(Y_show_norm), V, 'dynamic', 100, 'invgray', 0, [800 800]);
else
    writePixelVideo(rot90(Y_show_norm), V, video_file, ...
        'Colormap', 'invgray', 'Range', 'dynamic');
    fprintf('Wrote video to %s\n', video_file);
end

%% VR12R: QPI movies (standard range)
for k = 1:length(Aout_ALL)
    figure;
    d3gridDisplay(qpiCalculate(Aout_ALL{k}), 'dynamic')
end


%% =========================================================================
%% FINAL: Real-data block run complete
%  =========================================================================
LOGcomment = logUsedBlocks(log.path, log.file, "DONE ", "Real block-run script finished", 0);

fprintf('========================================\n');
fprintf('Real-data MC-SBD-STM block-run script finished.\n');
fprintf('Project: %s\n', meta.project_path);
fprintf('Log file: %s_LOGfile.txt\n', log.file);
if isfield(cfg, 'io') && isfield(cfg.io, 'sample_date') && ~isempty(cfg.io.sample_date)
    run_folder = char(cfg.io.sample_date);
    if isfield(cfg.io, 'sample') && ~isempty(cfg.io.sample)
        run_folder = [char(cfg.io.sample) '_' run_folder];
    end
    fprintf('Promote tagged ALL.mat to store/real/runs/%s/ when this run is a keeper.\n', ...
        run_folder);
end
fprintf('========================================\n');
