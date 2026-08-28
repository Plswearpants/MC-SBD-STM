%  PAPER FIGURE SCRIPT: ZrSiTe MT-SBD-STM
%  ========================================================================
%  Assembles Main + SI figures from finished runs. Run cells top-to-bottom;
%  later sections reuse earlier products (especially `Y` and `result`).
%
%  REAL-DATA BUILD-UP
%  ------------------
%  S00   path / repo root
%  S01   shared observation Y
%  F01   Figure 1  (needs Y)
%  S02   load + stitch block-run .mat files  -> Aout, A1
%  S03   QPI / symmetrize / crop            -> result (Y, Aout, *_qpi)
%  F04   Figure 4 display from result
%  F04b  optional reconstruction montages from one S02 block (no reload)
%  F05   Figure 5 from result.Aout_qpi
%  F06   movies from result
%
%  SYNTHETIC TRACK (independent of result; needs workspace `metrics`)
%  -----------------------------------------------------------------
%  SYN0  ensure phase-space helpers on path
%  F03   Figure 3 phase-space heatmaps
%  SI01  SI denoising / stacking-law plots
%
%  Local helpers live at the bottom of this file.
%
% =========================================================================


%% =========================================================================
%% S00: Path / repo root
%  =========================================================================
script_dir = fileparts(mfilename('fullpath'));
repo_root = '';
seeds = {script_dir, pwd};
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
    warning(['Could not locate init_sbd.m. Add the MT-SBD-STM repo to the ', ...
        'path manually if library calls fail. Tried: %s'], strjoin(tried, ' | '));
else
    addpath(repo_root);
    run(fullfile(repo_root, 'init_sbd.m'));
end


%% =========================================================================
%% S01: Shared observation Y
%  =========================================================================
%  One preprocessed volume shared by Figure 1 and the QPI packaging in S03.
%  Prefer an existing workspace Y; otherwise load from the paper freeze or
%  store/real/processed/<Material>_<MMDD>/ (e.g. ZrSiTe_0528). Leave empty to take Y_used from
%  the first S02 block-run file.
%
% -------------------------------------------------------------------------
% PRESETS
% -------------------------------------------------------------------------
Y_handoff_file = '';   % '' = do not load; paper freeze: paper/freeze/real/ZrSiTe0528_Y.mat

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if (~exist('Y', 'var') || isempty(Y)) && ~isempty(Y_handoff_file)
    S_y = load(Y_handoff_file, 'Y');
    if ~isfield(S_y, 'Y')
        error('S01: file %s has no variable Y.', Y_handoff_file);
    end
    Y = S_y.Y;
end
if exist('Y', 'var') && ~isempty(Y)
    fprintf('S01: Y ready, size %s\n', mat2str(size(Y)));
else
    fprintf(['S01: Y not set yet. Figure 1 needs it; S03 can still take ', ...
        'Y_used from the first block-run file.\n']);
end


%% =========================================================================
%% F01: Figure 1 — observation + reference crops
%  =========================================================================
%  Needs: Y (S01)
%  Makes: real-space / QPI panels of one slice, plus two interactive crops.
%
% -------------------------------------------------------------------------
% PRESETS
% -------------------------------------------------------------------------
chosen_slice = 85;
num_kernels_fig1 = 2;
square_size = [80, 80];

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('Y', 'var') || isempty(Y)
    error('F01: Y is required. Run S01 or load Y into the workspace.');
end
obs = Y;
kernel_sizes = repmat(square_size, [num_kernels_fig1, 1]);
[A1_ref, ~] = initialize_kernels(obs(:,:,chosen_slice), num_kernels_fig1, ...
    kernel_sizes, 'selected', '');

fig1_suba = obs(:,:,chosen_slice);
figure('Name', 'Figure 1a — real space');
imagesc(fig1_suba); axis square; colormap('gray');
set(gca, 'XTick', [], 'YTick', []);
title('subplot a');

fig1_subb = qpiCalculate(obs(:,:,chosen_slice));
figure('Name', 'Figure 1b — QPI');
imagesc(fig1_subb); axis square; colormap('invgray');
set(gca, 'XTick', [], 'YTick', [], 'CLim', clipEdgeIntensity(fig1_subb, 1));
title('subplot b');

figure('Name', 'Figure 1 — cropping');
ax1 = subplot(2, 2, 1);
imagesc(A1_ref{1}); axis square; colormap(ax1, 'gray');
set(ax1, 'XTick', [], 'YTick', []);
ax2 = subplot(2, 2, 2);
imagesc(qpiCalculate(A1_ref{1}, 484)); axis square; colormap(ax2, 'invgray');
set(ax2, 'XTick', [], 'YTick', [], ...
    'CLim', clipEdgeIntensity(qpiCalculate(A1_ref{1}), 1));
ax3 = subplot(2, 2, 3);
imagesc(A1_ref{2}); axis square; colormap(ax3, 'gray');
set(ax3, 'XTick', [], 'YTick', []);
ax4 = subplot(2, 2, 4);
imagesc(qpiCalculate(A1_ref{2}, 484)); axis square; colormap(ax4, 'invgray');
set(ax4, 'XTick', [], 'YTick', [], ...
    'CLim', clipEdgeIntensity(qpiCalculate(A1_ref{2}), 1));
sgtitle('cropping');


%% =========================================================================
%% S02: Load + stitch block-run results
%  =========================================================================
%  Needs: folder of all-slice block-run .mat files
%         (picker starts at paper/freeze/real/; lists *_ALL.mat only)
%  Makes: Aout, A1, param; resolves shared Y if still missing
%  Each file must contain:
%      Y_used, Aout_ALL, Xout_ALL, bout_ALL, ALL_extras, A1_used
%
% -------------------------------------------------------------------------
% PRESETS
% -------------------------------------------------------------------------
num_blocks_to_load = 3;

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
s02_start = pwd;
if ~isempty(repo_root)
    s02_cand = fullfile(repo_root, 'paper', 'freeze', 'real');
    if exist(s02_cand, 'dir')
        s02_start = s02_cand;
    end
end
selected_filenames = chooseOrderedFilesFromFolder(num_blocks_to_load, s02_start, '*_ALL.mat');
myVars = {"Y_used", "Aout_ALL", "Xout_ALL", "bout_ALL", "ALL_extras", "A1_used"};

data = struct();
for b = 1:num_blocks_to_load
    data.(sprintf('block%d', b)) = load(selected_filenames{b}, myVars{:});
end

[Aout, A1, param] = mergeAoutBlocksManualCutoff(data, selected_filenames);

if ~exist('Y', 'var') || isempty(Y)
    if isfield(data.block1, 'Y_used') && ~isempty(data.block1.Y_used)
        Y = data.block1.Y_used;
        fprintf('S02: took shared Y from block1.Y_used, size %s\n', mat2str(size(Y)));
    else
        error('S02: shared observation Y unavailable. Set Y in S01 or ensure block1 has Y_used.');
    end
end


%% =========================================================================
%% S03: Build result (QPI → symmetrize → crop → package)
%  =========================================================================
%  Needs: Y (S01/S02), Aout (S02)
%  Makes: result with fields
%      .Y, .Aout, .Y_qpi, .Aout_qpi, .comparison_qpi
%  This is the handoff used by F04, F05, F06.
%
% -------------------------------------------------------------------------
% PRESETS
% -------------------------------------------------------------------------
angle = 122.5741;          % Bragg alignment rotation (deg)
target_size = [245, 245];  % final QPI crop

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Y_xydim = size(Y, [1, 2]);
radius = target_size(1) / 2;
num_kernels_stitched = size(Aout, 4);
num_total_slices = size(Aout, 3);

Aout_qpi_each = zeros([num_kernels_stitched, Y_xydim, num_total_slices]);
for i = 1:num_kernels_stitched
    Aout_qpi_each(i, :, :, :) = qpiCalculate(Aout(:, :, :, i), size(Y, [1, 2]));
end

[~, Y_qpi_symm_45, ~, angle] = Symmetrizing2(squeeze(qpiCalculate(Y)), '', angle, 'default');
A_qpi_symm_45 = cell(1, num_kernels_stitched);
for k = 1:num_kernels_stitched
    % Kernels 3 and 4 historically use the extra Symmetrizing2 flag.
    if k == 3 || k == 4
        [~, A_qpi_symm_45{k}, ~, angle] = Symmetrizing2( ...
            squeeze(Aout_qpi_each(k, :, :, :)), '', angle, 'default', true);
    else
        [~, A_qpi_symm_45{k}, ~, angle] = Symmetrizing2( ...
            squeeze(Aout_qpi_each(k, :, :, :)), '', angle, 'default');
    end
end

Y_qpi_cropped = centerCropToTargetSize(Y_qpi_symm_45, target_size);
A_qpi_cropped = cell(1, num_kernels_stitched);
for k = 1:num_kernels_stitched
    A_qpi_cropped{k} = centerCropToTargetSize(A_qpi_symm_45{k}, target_size);
end

Y_qpi_norm = normalizeForDisplay(Y_qpi_cropped);
comparison_qpi = Y_qpi_norm;
for k = 1:num_kernels_stitched
    comparison_qpi = [comparison_qpi, normalizeForDisplay(A_qpi_cropped{k})]; %#ok<AGROW>
end

result = struct();
result.Y = Y;
result.Aout = Aout;
result.A1 = A1;
result.param = param;
result.Y_qpi = Y_qpi_cropped;
result.Aout_qpi = zeros([size(A_qpi_cropped{1}), num_kernels_stitched]);
for k = 1:num_kernels_stitched
    result.Aout_qpi(:, :, :, k) = A_qpi_cropped{k};
end
result.comparison_qpi = comparison_qpi;
result.radius = radius;
result.angle = angle;
result.target_size = target_size;
result.energy_range = [-800, 800];

clear Aout_qpi_each Y_qpi_symm_45 A_qpi_symm_45 ...
    Y_qpi_cropped A_qpi_cropped Y_qpi_norm comparison_qpi;

fprintf('S03: result ready — Aout_qpi size %s\n', mat2str(size(result.Aout_qpi)));


%% =========================================================================
%% F04: Figure 4 — QPI comparison montage
%  =========================================================================
%  Needs: result (S03)
%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('result', 'var') || ~isfield(result, 'comparison_qpi')
    error('F04: result.comparison_qpi missing. Run S03 first.');
end
figure('Name', 'Figure 4 — comparison QPI');
d3gridDisplay(result.comparison_qpi, 'dynamic', -1);


%% =========================================================================
%% F04b: Optional — single-block reconstruction components
%  =========================================================================
%  Needs: data from S02 (no extra load). Uses one of the already-loaded
%  blocks — typically the middle energy window — and builds per-kernel
%  real-space / QPI reconstruction montages. Skip if you only need the
%  stitched QPI panels from F04.
%
% -------------------------------------------------------------------------
% PRESETS
% -------------------------------------------------------------------------
fig4b_block_idx = 2;   % which S02 block to use (2 = middle of 3)

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('data', 'var') || ~isstruct(data)
    error('F04b: data missing. Run S02 first.');
end
block_name = sprintf('block%d', fig4b_block_idx);
if ~isfield(data, block_name)
    error('F04b: %s not found. Loaded blocks: %s', ...
        block_name, strjoin(fieldnames(data), ', '));
end
blk = data.(block_name);
required = {'Y_used', 'Aout_ALL', 'Xout_ALL', 'bout_ALL'};
for ii = 1:numel(required)
    if ~isfield(blk, required{ii}) || isempty(blk.(required{ii}))
        error('F04b: %s.%s is missing. Re-run S02.', block_name, required{ii});
    end
end

Y_used   = blk.Y_used;
Aout_ALL = blk.Aout_ALL;
Xout_ALL = blk.Xout_ALL;
bout_ALL = blk.bout_ALL;

[num_slices_4b, num_kernels_4b] = size(bout_ALL);
Aout_ALL_cell = cell(num_slices_4b, num_kernels_4b);
for s = 1:num_slices_4b
    for k = 1:num_kernels_4b
        Aout_ALL_cell{s, k} = Aout_ALL{k}(:, :, s);
    end
end

Y_rec = zeros(size(Y_used));
for i = 1:size(Y_used, 3)
    for k = 1:num_kernels_4b
        Y_rec(:, :, i) = Y_rec(:, :, i) + ...
            convfft2(Aout_ALL_cell{i, k}, Xout_ALL(:, :, k)) + bout_ALL(i, k);
    end
end

Y_rec_each = zeros([num_kernels_4b, size(Y_used)]);
for i = 1:size(Y_used, 3)
    for k = 1:num_kernels_4b
        Y_rec_each(k, :, :, i) = convfft2(Aout_ALL_cell{i, k}, Xout_ALL(:, :, k));
    end
end

FT_QPI_Y_rec_each = zeros([num_kernels_4b, size(Y_used)]);
for k = 1:num_kernels_4b
    FT_QPI_Y_rec_each(k, :, :, :) = qpiCalculate(squeeze(Y_rec_each(k, :, :, :)));
end

Y_rec_show_Full = [];
qpi_Y_rec_show_Full = [];
for k = 1:num_kernels_4b
    Y_rec_show_Full = [Y_rec_show_Full, squeeze(Y_rec_each(k, :, :, :))]; %#ok<AGROW>
    qpi_Y_rec_show_Full = [qpi_Y_rec_show_Full, squeeze(FT_QPI_Y_rec_each(k, :, :, :))]; %#ok<AGROW>
end
for i = 1:size(Y_rec_show_Full, 3)
    Y_rec_show_Full(:, :, i) = mat2gray(Y_rec_show_Full(:, :, i));
    qpi_Y_rec_show_Full(:, :, i) = 1 - mat2gray(qpi_Y_rec_show_Full(:, :, i), [0, 1]);
end

src_name = selected_filenames{fig4b_block_idx};
fprintf('F04b: used %s (%s) -> Y_rec_show_Full, qpi_Y_rec_show_Full.\n', ...
    block_name, src_name);

figure; d3gridDisplay(Y_rec_show_Full,'dynamic')
%% =========================================================================
%% F05: Figure 5 — Type-1 (Zr) dispersion and energy cuts
%  =========================================================================
%  Needs: result.Aout_qpi (S03), result.radius
%
% -------------------------------------------------------------------------
% PRESETS
% -------------------------------------------------------------------------
naked = true;              % false = keep axis labels / titles
nos = 8;                   % clipAndNormalize std multiplier
energy_range = [-800, 800];
target_energies = [280, 220, 164];

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('result', 'var') || ~isfield(result, 'Aout_qpi')
    error('F05: result.Aout_qpi missing. Run S03 first.');
end
if isfield(result, 'radius')
    radius = result.radius;
elseif ~exist('radius', 'var')
    error('F05: radius missing. Run S03 first.');
end

if ndims(result.Aout_qpi) >= 4
    Aout_type1 = result.Aout_qpi(:, :, :, 1);
else
    Aout_type1 = result.Aout_qpi;
end

energy_axis = linspace(energy_range(1), energy_range(2), size(Aout_type1, 3));
[A1_rot2D, A1_angles, ~] = rotationalslices(Aout_type1, 'global', 1, radius, naked, energy_range);

[~, angle_idx_180] = min(abs(rad2deg(A1_angles) - 180));
dispersion_180 = clipAndNormalize(A1_rot2D(:, :, angle_idx_180)', nos);
figure('Name', 'Figure 5a - Type1 dispersion (180 deg)');
imagesc(dispersion_180);
set(gca, 'YDir', 'normal');
axis image;
colormap(invgray);
caxis([0, 1]);
if naked
    axis off;
else
    title('Type 1 (Zr): vertical cut at 180 deg');
    xlabel('Position along cut');
    ylabel('Energy index');
end

for ii = 1:numel(target_energies)
    [~, eidx] = min(abs(energy_axis - target_energies(ii)));
    map_e = clipAndNormalize(Aout_type1(:, :, eidx), nos);
    figure('Name', sprintf('Figure 5%c - Type1 energy cut %.0f meV', ...
        char('a' + ii), target_energies(ii)));
    imagesc(map_e);
    axis image;
    colormap(invgray);
    caxis([0, 1]);
    if naked
        axis off;
    else
        title(sprintf('Type 1 (Zr): energy cut %.0f meV (actual %.1f meV)', ...
            target_energies(ii), energy_axis(eidx)));
        xlabel('q_x pixel');
        ylabel('q_y pixel');
    end
end

% Optional snapshot for replaying F05 without rebuilding result
fig5_inputs = struct();
fig5_inputs.result = result;
fig5_inputs.radius = radius;
fig5_inputs.naked = naked;
fig5_inputs.nos = nos;
fig5_inputs.energy_range = energy_range;
fig5_inputs.target_energies = target_energies;


%% =========================================================================
%% F06: Movies from result- Extended data movies
%  =========================================================================
%  Needs: result.Aout, result.comparison_qpi (S03)
%
% -------------------------------------------------------------------------
% PRESETS
% -------------------------------------------------------------------------
movie_energy = linspace(-800, 800, 200);
kernel_labels = {'Zr_2', 'Te_1', 'Si_1h', 'Si_1v', 'Te_2'};
qpi_labels = [{'All'}, kernel_labels];

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('result', 'var') || ~isfield(result, 'Aout') || ~isfield(result, 'comparison_qpi')
    error('F06: result missing. Run S03 first.');
end
nk = size(result.Aout, 4);
Aout_all = result.Aout(:, :, :, 1);
for k = 2:nk
    Aout_all = [Aout_all, result.Aout(:, :, :, k)]; %#ok<AGROW>
end

writePixelVideo(Aout_all, movie_energy, 'Aout_movie.mp4', [1 nk], 'bl', ...
    kernel_labels(1:nk), 'Unit', 'mV', 'colormap', 'gray');
writePixelVideo(result.comparison_qpi, movie_energy, 'qpi_movie.mp4', ...
    [1, nk + 1], 'bl', qpi_labels(1:(nk + 1)), 'Unit', 'mV', 'colormap', 'invgray');


%% =========================================================================
%% SYN0: Synthetic track — path check
%  =========================================================================
%  Independent of the real-data `result`. Needs workspace `metrics`.
%  Paper freeze: paper/freeze/phase_space/snr=3,5,7.mat
%  (same bytes as store/phase_space/metrics/snr=3,5,7.mat).
%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('build_denoising_sigma_metrics', 'file') || ~exist('metrics2heat_by_snr_interpolated', 'file')
    if ~isempty(repo_root)
        addpath(fullfile(repo_root, 'lib'));
        addpath(fullfile(repo_root, 'lib', 'phase_space'));
    else
        addpath(fullfile(script_dir, '..', '..', 'lib'));
        addpath(fullfile(script_dir, '..', '..', 'lib', 'phase_space'));
    end
end
if ~exist('metrics', 'var') || isempty(metrics)
    warning(['SYN0: workspace ''metrics'' is missing. Figure 3 and SI01 will ', ...
        'error until you load a metrics .mat.']);
end


%% =========================================================================
%% F03: Figure 3 — phase-space heatmaps
%  =========================================================================
%  Needs: metrics (SYN0)
%  Layout: activation combined + kernel similarity at the chosen SNR slice,
%  viridis colormap, 0.95 contour on combined (working/failure boundary).
%
% -------------------------------------------------------------------------
% PRESETS
% -------------------------------------------------------------------------
metric_colormap = slanCM('viridis');
contour_levels = [0.95];
axis3_mode = 2;
snr_index_fig3 = 1;   % which SNR slice of metrics to plot

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('metrics', 'var') || isempty(metrics)
    error('F03: metrics required. Load a phase-space metrics .mat first.');
end
metrics2heat_by_snr_interpolated(metrics, 'combined', axis3_mode, ...
    snr_index_fig3, metric_colormap, contour_levels);
metrics2heat_by_snr_interpolated(metrics, 'kernel', axis3_mode, ...
    snr_index_fig3, metric_colormap, contour_levels);


%% =========================================================================
%% SI01: SI — synthetic denoising / stacking-law plots
%  =========================================================================
%  Needs: metrics (SYN0 / F03). Rebuilds denoising fields only if missing.
%
% -------------------------------------------------------------------------
% PRESETS
% -------------------------------------------------------------------------
si_axis3_mode = 2;
si_activation_gate = 0.95;
si_metric_colormap = slanCM('viridis');
si_snr_targets = [3, 5, 7];
si_font_default = 18;
si_side_ratio_default = 0.2233;

%%%%%%%%%%%%%%%%%% DO NOT EDIT BELOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('metrics', 'var') || isempty(metrics)
    error('SI01: metrics required.');
end

si_font_size = input(sprintf('Font size for SI synthetic plots (default=%d): ', si_font_default));
if isempty(si_font_size)
    si_font_size = si_font_default;
end
si_font_size = double(si_font_size);

si_side_ratio_max = input(sprintf(['Side-length-ratio cutoff for SI 1/sqrt(Nobs) scatter ' ...
    '(default=%.4f): '], si_side_ratio_default));
if isempty(si_side_ratio_max)
    si_side_ratio_max = si_side_ratio_default;
end
si_side_ratio_max = double(si_side_ratio_max);

if ~isfield(metrics, 'denoising_sigma_ratio_final') || isempty(metrics.denoising_sigma_ratio_final) || ...
        ~isfield(metrics, 'denoising_sigma_ratio_per_kernel') || isempty(metrics.denoising_sigma_ratio_per_kernel)
    metrics = build_denoising_sigma_metrics(metrics, si_activation_gate, ...
        'enableAlignment', false, ...
        'energyStride', 2, ...
        'sigmaMethod', 'mad');
end
metrics2heat_by_snr_interpolated(metrics, 'denoising', si_axis3_mode, 1, si_metric_colormap);
set(findall(gcf, '-property', 'FontSize'), 'FontSize', si_font_size);

if ~isfield(metrics, 'Nobs_per_kernel_at_axis3') || isempty(metrics.Nobs_per_kernel_at_axis3)
    nobs_per_kernel_tmp = cell(size(metrics.X0));
    for linear_idx = 1:numel(metrics.X0)
        X0_slot = metrics.X0{linear_idx};
        if isempty(X0_slot), continue; end
        if iscell(X0_slot)
            if isempty(X0_slot), continue; end
            X0_slot = X0_slot{1};
        end
        if ~isnumeric(X0_slot), continue; end
        if ndims(X0_slot) == 2
            nobs_per_kernel_tmp{linear_idx} = nnz(X0_slot ~= 0);
        elseif ndims(X0_slot) >= 3
            nk = size(X0_slot, 3);
            cnt = zeros(1, nk);
            for k = 1:nk
                cnt(k) = nnz(X0_slot(:, :, k) ~= 0);
            end
            nobs_per_kernel_tmp{linear_idx} = cnt;
        end
    end
    metrics.Nobs_per_kernel_at_axis3 = nobs_per_kernel_tmp;
end

if isfield(metrics, 'side_length_ratio_values') && ...
        isfield(metrics, 'Nobs_per_kernel_at_axis3') && ...
        isfield(metrics, 'denoising_sigma_out_per_kernel') && ...
        isfield(metrics, 'denoising_sigma_in_per_kernel')
    side_vals = metrics.side_length_ratio_values(:)';
    side_sel = find(side_vals <= si_side_ratio_max);
    if isempty(side_sel)
        warning('No side-length-ratio bins <= %.4f found for SI scatter plot.', si_side_ratio_max);
    else
        fprintf('SI side-ratio cutoff %.4f selects %d subplot bins.\n', ...
            si_side_ratio_max, numel(side_sel));
        if abs(si_side_ratio_max - 0.2233) < 1e-10 && numel(side_sel) ~= 8
            warning(['Expected 8 side-ratio subplots at cutoff 0.2233, but selected %d. ' ...
                'Check side_length_ratio_values grid for this metrics set.'], numel(side_sel));
        end
        disp('Selected side_length_ratio values:');
        disp(side_vals(side_sel));

        snr_all = metrics.SNR_values(:)';
        snr_idx = zeros(1, numel(si_snr_targets));
        for i = 1:numel(si_snr_targets)
            [~, snr_idx(i)] = min(abs(snr_all - si_snr_targets(i)));
        end
        snr_idx = unique(snr_idx, 'stable');

        for si = 1:numel(snr_idx)
            s = snr_idx(si);
            nside = numel(side_sel);
            [nrow, ncol] = choose_integer_subplot_layout(nside);
            figure('Name', sprintf('SI 1/sqrt(Nobs) vs sigma_{out} by side ratio | SNR=%.2f', snr_all(s)), ...
                'Position', [120 120 430 * ncol 360 * nrow]);

            for jj = 1:nside
                r = side_sel(jj);
                subplot(nrow, ncol, jj);
                nobs_cells = squeeze(metrics.Nobs_per_kernel_at_axis3(s, :, r, :));
                sigma_out_cells = squeeze(metrics.denoising_sigma_out_per_kernel(s, :, r, :));
                sigma_in_cells = squeeze(metrics.denoising_sigma_in_per_kernel(s, :, r, :));
                x_by_kernel = {};
                y_by_kernel = {};
                s_by_kernel = {};

                for ii = 1:numel(nobs_cells)
                    n_k = nobs_cells{ii};
                    d_k = sigma_out_cells{ii};
                    s_k = sigma_in_cells{ii};
                    if isempty(n_k) || isempty(d_k) || isempty(s_k), continue; end
                    n_k = n_k(:);
                    d_k = d_k(:);
                    s_k = s_k(:);
                    nk = min([numel(n_k), numel(d_k), numel(s_k)]);
                    if nk < 1, continue; end
                    for kk = 1:nk
                        if numel(x_by_kernel) < kk || isempty(x_by_kernel{kk})
                            x_by_kernel{kk} = n_k(kk);
                            y_by_kernel{kk} = d_k(kk);
                            s_by_kernel{kk} = s_k(kk);
                        else
                            x_by_kernel{kk}(end + 1, 1) = n_k(kk); %#ok<AGROW>
                            y_by_kernel{kk}(end + 1, 1) = d_k(kk); %#ok<AGROW>
                            s_by_kernel{kk}(end + 1, 1) = s_k(kk); %#ok<AGROW>
                        end
                    end
                end

                hold on;
                num_k = numel(x_by_kernel);
                cmap = lines(max(1, num_k));
                x_all = [];
                s_all = [];
                for kk = 1:num_k
                    if isempty(x_by_kernel{kk}) || isempty(y_by_kernel{kk}) || ...
                            numel(s_by_kernel) < kk || isempty(s_by_kernel{kk}), continue; end
                    xv = x_by_kernel{kk};
                    yv = y_by_kernel{kk};
                    sv = s_by_kernel{kk};
                    valid = isfinite(xv) & isfinite(yv) & isfinite(sv) & (xv > 0);
                    xv = xv(valid); yv = yv(valid); sv = sv(valid);
                    if isempty(xv), continue; end
                    xv_plot = 1 ./ sqrt(xv);
                    scatter(xv_plot, yv, 20, 'filled', ...
                        'MarkerFaceColor', cmap(kk, :), ...
                        'MarkerFaceAlpha', 0.65, ...
                        'DisplayName', sprintf('Kernel %d', kk));
                    x_all = [x_all; xv_plot(:)]; %#ok<AGROW>
                    s_all = [s_all; sv(:)]; %#ok<AGROW>
                end
                valid_h = isfinite(x_all) & isfinite(s_all) & (x_all > 0);
                if any(valid_h)
                    slope_hat = median(s_all(valid_h), 'omitnan');
                    xline_vals = linspace(min(x_all(valid_h)), max(x_all(valid_h)), 100);
                    yline_vals = slope_hat .* xline_vals;
                    plot(xline_vals, yline_vals, '--', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.3, ...
                        'DisplayName', sprintf('Hypothesis: y=%.3g x', slope_hat));
                end
                hold off; grid on;
                xlabel('1/sqrt(Nobs)');
                ylabel('\sigma_{out}');
                title(sprintf('side ratio = %.4f', side_vals(r)));
                set(gca, 'FontSize', si_font_size);
                if num_k > 0
                    lg = legend('Location', 'northwest');
                    lg.FontSize = max(8, si_font_size - 2);
                end
            end
            st = sgtitle(sprintf('SI 1/sqrt(Nobs) vs \\sigma_{out} by side ratio (<= %.4f), SNR=%.2f', ...
                si_side_ratio_max, snr_all(s)));
            st.FontSize = si_font_size;
        end
    end
end


%% =========================================================================
%% DONE
%  =========================================================================
fprintf('plotting_paper.m finished (run remaining cells as needed).\n');



%% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Helper~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%% -------------------------------------------------------------------------
% Helper: clip intensity to (n, 100-n) percentiles for better readability
% Usage: clim = clipEdgeIntensity(Z, n);  clim(ax, clim);  % or caxis(clim)
function clim = clipEdgeIntensity(Z, n)
    if nargin < 2, n = 2; end
    n = max(0, min(50, n));
    clim = [prctile(Z(:), n), prctile(Z(:), 100 - n)];
end

%% -------------------------------------------------------------------------
% Helper: set second axes intensity window to match the first (reference)
% Usage: unifyIntensityWindow(ax_ref, ax_to_update)
function unifyIntensityWindow(ax_ref, ax_to_update)
    set(ax_to_update, 'CLim', get(ax_ref, 'CLim'));
end

%% -------------------------------------------------------------------------
% Helper: crop center region of 3D data to target [rows, cols]
% Usage: out = centerCropToTargetSize(data3d, [m, n])
function data_cropped = centerCropToTargetSize(data_tobe_cropped, target_size)
    validateattributes(data_tobe_cropped, {'numeric'}, {'nonempty'});
    validateattributes(target_size, {'numeric'}, {'vector','numel',2,'integer','positive','finite','real'});

    size_data = [size(data_tobe_cropped,1), size(data_tobe_cropped,2)];
    if any(target_size > size_data)
        error('centerCropToTargetSize:TargetTooLarge', ...
            'target_size [%d %d] exceeds data size [%d %d].', ...
            target_size(1), target_size(2), size_data(1), size_data(2));
    end

    x_range = [1 + floor((size_data(1)-target_size(1))/2), floor((size_data(1)+target_size(1))/2)];
    y_range = [1 + floor((size_data(2)-target_size(2))/2), floor((size_data(2)+target_size(2))/2)];
    data_cropped = data_tobe_cropped(x_range(1):x_range(2), y_range(1):y_range(2), :);
end

%% -------------------------------------------------------------------------
% Helper: normalize numeric array to [0, 1] for visualization
% Usage: out = normalizeForDisplay(data)
function data_norm = normalizeForDisplay(data_in)
    validateattributes(data_in, {'numeric'}, {'nonempty', 'real', 'finite'});
    data_norm = zeros(size(data_in), 'like', data_in);

    if ndims(data_in) < 3
        min_val = min(data_in(:));
        max_val = max(data_in(:));
        range_val = max_val - min_val;
        if range_val == 0
            data_norm = zeros(size(data_in), 'like', data_in);
        else
            data_norm = (data_in - min_val) ./ range_val;
        end
        return;
    end

    for i = 1:size(data_in,3)
        slice_i = data_in(:,:,i);
        min_val = min(slice_i(:));
        max_val = max(slice_i(:));
        range_val = max_val - min_val;
        if range_val == 0
            data_norm(:,:,i) = zeros(size(slice_i), 'like', data_in);
        else
            data_norm(:,:,i) = (slice_i - min_val) ./ range_val;
        end
    end
end

%% -------------------------------------------------------------------------
% Helper: clip to mean ± nstd*std, then normalize to [0,1]
function out = clipAndNormalize(data_in, nstd)
    if nargin < 2
        nstd = 6;
    end
    mu = mean(data_in(:), 'omitnan');
    sigma = std(data_in(:), 0, 'omitnan');
    lo = mu - nstd * sigma;
    hi = mu + nstd * sigma;
    clipped = min(max(data_in, lo), hi);
    out = normalizeForDisplay(clipped);
end

%% -------------------------------------------------------------------------
% Helper: sum and count points in 2D map above threshold
% Usage: [sum_points, num_points] = collectAboveThreshold(Xout, 0.1)
function [sum_points, num_points] = collectAboveThreshold(Xout, threshold)
    if nargin < 2
        threshold = 0.1;
    end
    validateattributes(Xout, {'numeric'}, {'2d', 'nonempty', 'real'});
    validateattributes(threshold, {'numeric'}, {'scalar', 'real', 'finite'});

    selected_points = Xout(Xout > threshold);
    sum_points = sum(selected_points(:));
    num_points = numel(selected_points);
end

%% -------------------------------------------------------------------------
% Helper: choose MAT files from a folder in a user-defined load order.
% Example order input: [2 5 1]
function selected_paths = chooseOrderedFilesFromFolder(num_required, start_dir, name_filter)
    if nargin < 1
        num_required = 3;
    end
    if nargin < 2 || isempty(start_dir)
        start_dir = pwd;
    end
    if nargin < 3 || isempty(name_filter)
        name_filter = '*.mat';
    end

    folder_path = uigetdir(start_dir, 'Select folder containing run result MAT files');
    if isequal(folder_path, 0)
        error('No folder selected.');
    end

    entries = dir(fullfile(folder_path, name_filter));
    if isempty(entries)
        error('Selected folder has no files matching %s: %s', name_filter, folder_path);
    end

    fprintf('\nAvailable files in %s:\n', folder_path);
    for i = 1:numel(entries)
        fprintf('  %d) %s\n', i, entries(i).name);
    end

    prompt = sprintf(['Enter ordered file indices for %d blocks ', ...
        '(e.g. [2 5 1]): '], num_required);
    idx = input(prompt);

    if isempty(idx) || ~isnumeric(idx)
        error('You must provide numeric indices, e.g. [2 5 1].');
    end
    idx = idx(:).';
    if numel(idx) ~= num_required
        error('Expected exactly %d indices, got %d.', num_required, numel(idx));
    end
    if any(idx < 1) || any(idx > numel(entries)) || any(mod(idx,1) ~= 0)
        error('Indices must be integers between 1 and %d.', numel(entries));
    end

    selected_paths = cell(1, num_required);
    for i = 1:num_required
        selected_paths{i} = fullfile(folder_path, entries(idx(i)).name);
    end

    fprintf('Chosen load order:\n');
    for i = 1:num_required
        fprintf('  block%d <- %s\n', i, selected_paths{i});
    end
    fprintf('\n');
end

%% -------------------------------------------------------------------------
% Helper: merge selected blocks using strict manual global cutoffs.
% File names must contain a token like s21to141.
function [Aout, A1, param] = mergeAoutBlocksManualCutoff(data, selected_filenames)
    block_fields = fieldnames(data);
    num_blocks = numel(block_fields);
    if num_blocks < 2
        error('Need at least 2 blocks to stitch.');
    end

    meta = struct([]);
    max_end = 0;
    for b = 1:num_blocks
        block_name = block_fields{b};
        block_data = data.(block_name);
        [s_start, s_end] = parseSliceRangeFromFilename(selected_filenames{b});
        expected_local = s_end - s_start + 1;
        actual_local = size(block_data.Aout_ALL{1,1}, 3);
        if ~isfield(block_data, 'A1_used') || isempty(block_data.A1_used)
            error('Block %d is missing required field A1_used.', b);
        end
        actual_local_a1 = size(block_data.A1_used{1}, 3);
        if actual_local ~= expected_local
            error(['Block %d slice count mismatch. Filename implies %d slices ', ...
                '(%d:%d), but data has %d slices.'], ...
                b, expected_local, s_start, s_end, actual_local);
        end
        if actual_local_a1 ~= expected_local
            error(['Block %d A1_used slice count mismatch. Filename implies %d slices ', ...
                '(%d:%d), but A1_used has %d slices.'], ...
                b, expected_local, s_start, s_end, actual_local_a1);
        end
        meta(b).block_name = block_name; %#ok<AGROW>
        meta(b).path = selected_filenames{b}; %#ok<AGROW>
        meta(b).s_start = s_start; %#ok<AGROW>
        meta(b).s_end = s_end; %#ok<AGROW>
        meta(b).num_local = actual_local; %#ok<AGROW>
        meta(b).num_kernels = numel(block_data.Aout_ALL); %#ok<AGROW>
        meta(b).num_kernels_a1 = numel(block_data.A1_used); %#ok<AGROW>
        max_end = max(max_end, s_end);
    end

    fprintf('\nDetected block slice ranges (from filename):\n');
    for b = 1:num_blocks
        fprintf('  block%d: [%d:%d]  file=%s\n', ...
            b, meta(b).s_start, meta(b).s_end, meta(b).path);
    end

    total_slices = input(sprintf('Enter total global slice count (e.g. %d): ', max_end));
    validateattributes(total_slices, {'numeric'}, {'scalar','integer','positive','finite'});

    cutoff_prompt = sprintf(['Enter %d increasing cutoff indices for %d blocks ', ...
        '(e.g. [20 140] for 3 blocks): '], num_blocks-1, num_blocks);
    cutoffs = input(cutoff_prompt);
    if isempty(cutoffs) || ~isnumeric(cutoffs)
        error('Cutoffs must be numeric, e.g. [20 140].');
    end
    cutoffs = cutoffs(:).';
    if numel(cutoffs) ~= num_blocks-1
        error('Expected exactly %d cutoffs, got %d.', num_blocks-1, numel(cutoffs));
    end
    if any(mod(cutoffs,1) ~= 0) || any(diff(cutoffs) <= 0)
        error('Cutoffs must be strictly increasing integers.');
    end
    if cutoffs(1) < 1 || cutoffs(end) >= total_slices
        error('Cutoffs must satisfy 1 <= cutoffs < total_slices.');
    end

    segment_starts = [1, cutoffs + 1];
    segment_ends = [cutoffs, total_slices];

    for b = 1:num_blocks
        g_start = segment_starts(b);
        g_end = segment_ends(b);
        if g_start < meta(b).s_start || g_end > meta(b).s_end
            error(['Invalid cutoff for block%d. Assigned global segment [%d:%d] ', ...
                'is not fully covered by block range [%d:%d].'], ...
                b, g_start, g_end, meta(b).s_start, meta(b).s_end);
        end
    end

    sample_block = data.(block_fields{1});
    [h, w, ~] = size(sample_block.Aout_ALL{1,1});
    num_kernels_total = max([meta.num_kernels]);
    num_kernels_a1_total = max([meta.num_kernels_a1]);
    Aout = zeros(h, w, total_slices, num_kernels_total);
    A1 = zeros(h, w, total_slices, num_kernels_a1_total);

    % Stitch Aout and A1 strictly by manual cutoffs.
    for b = 1:num_blocks
        block_data = data.(block_fields{b});
        g_idx = segment_starts(b):segment_ends(b);
        l_idx = g_idx - meta(b).s_start + 1;
        for k = 1:numel(block_data.Aout_ALL)
            Aout(:,:,g_idx,k) = block_data.Aout_ALL{k,1}(:,:,l_idx);
        end
        for k = 1:numel(block_data.A1_used)
            A1(:,:,g_idx,k) = block_data.A1_used{k}(:,:,l_idx);
        end
    end

    param = struct();
    param.total_slices = total_slices;
    param.cutoffs = cutoffs;
    param.segment_starts = segment_starts;
    param.segment_ends = segment_ends;
    param.meta = meta;

    fprintf('Manual stitch segments applied:\n');
    for b = 1:num_blocks
        fprintf('  block%d -> global [%d:%d] using local [%d:%d]\n', ...
            b, segment_starts(b), segment_ends(b), ...
            segment_starts(b)-meta(b).s_start+1, segment_ends(b)-meta(b).s_start+1);
    end
    fprintf('\n');
end

%% -------------------------------------------------------------------------
% Helper: parse "sXtoY" slice token from filename.
function [s_start, s_end] = parseSliceRangeFromFilename(file_path)
    [~, name, ~] = fileparts(file_path);
    tok = regexp(name, 's(\d+)to(\d+)', 'tokens', 'once');
    if isempty(tok)
        error('Filename must contain token like s1to41: %s', file_path);
    end
    s_start = str2double(tok{1});
    s_end = str2double(tok{2});
    if isnan(s_start) || isnan(s_end) || s_start < 1 || s_end < s_start
        error('Invalid slice token in filename: %s', file_path);
    end
end

%% -------------------------------------------------------------------------
% Helper: user-select a rectangle used for noise estimation.
function noise_roi_position = select_noise_rectangle(slice_img)
    f = figure('Name', 'Select Noise Region', 'Position', [120, 120, 900, 750]);
    imagesc(slice_img); axis image; colormap(gray); colorbar; hold on;
    title({'Draw a rectangular ROI for noise estimation.', ...
        'Use a background region with minimal signal, then double-click to confirm.'});

    h = drawrectangle('Color', 'c', 'FixedAspectRatio', false, ...
        'Label', 'Noise ROI', 'Rotatable', false);
    wait(h);
    pos = h.Position;
    pos(1:2) = round(pos(1:2));
    pos(3:4) = max(2, round(pos(3:4)));
    noise_roi_position = pos;

    rectangle('Position', pos, 'EdgeColor', 'c', 'LineWidth', 1.4, 'LineStyle', '--');
    hold off;
    if isvalid(f), close(f); end
end

%% -------------------------------------------------------------------------
% Helper: estimate sigma_noise per energy slice from one fixed noise ROI.
function noise_std_per_slice = estimate_noise_std_from_roi(Y, noise_roi_position)
    [h, w, e] = size(Y);
    x = max(1, round(noise_roi_position(1)));
    y = max(1, round(noise_roi_position(2)));
    rw = max(2, round(noise_roi_position(3)));
    rh = max(2, round(noise_roi_position(4)));
    x = min(x, w - 1);
    y = min(y, h - 1);
    rw = min(rw, w - x + 1);
    rh = min(rh, h - y + 1);

    noise_std_per_slice = nan(1, e);
    for s = 1:e
        roi_vals = Y(y:y+rh-1, x:x+rw-1, s);
        sigma_noise = robust_std_from_mad(roi_vals(:));
        if ~isfinite(sigma_noise) || sigma_noise <= 0
            sigma_noise = std(roi_vals(:), 0, 'omitnan');
        end
        noise_std_per_slice(s) = max(sigma_noise, eps);
    end
end

%% -------------------------------------------------------------------------
% Helper: robust std estimate using MAD (same convention as SNR script).
function sigma = robust_std_from_mad(x)
    x = x(:);
    medx = median(x, 'omitnan');
    abs_dev = abs(x - medx);
    mad_raw = median(abs_dev, 'omitnan');
    sigma = 1.4826 * mad_raw;
end

%% -------------------------------------------------------------------------
% Helper: convert kernel data into a format accepted by SNR estimator.
function kernel_input = normalize_kernel_input_for_snr(kernel_input_raw)
    kernel_input = kernel_input_raw;
    if isnumeric(kernel_input_raw)
        if ndims(kernel_input_raw) == 2
            kernel_input = reshape(kernel_input_raw, size(kernel_input_raw,1), size(kernel_input_raw,2), 1);
        elseif ndims(kernel_input_raw) ~= 3 && ndims(kernel_input_raw) ~= 4
            error('Kernel input must be 2D, 3D, 4D, or cell.');
        end
    elseif ~iscell(kernel_input_raw)
        error('Kernel input must be numeric or cell.');
    end
end

%% -------------------------------------------------------------------------
% Helper: infer number of energy slices in kernel input.
function depth = infer_kernel_depth(kernel_input)
    if isnumeric(kernel_input)
        if ndims(kernel_input) < 3
            depth = 1;
        else
            depth = size(kernel_input, 3);
        end
        return;
    end

    if isempty(kernel_input)
        depth = 1;
        return;
    end

    first_kernel = kernel_input{1};
    if ndims(first_kernel) < 3
        depth = 1;
    else
        depth = size(first_kernel, 3);
    end
end

%% -------------------------------------------------------------------------
% Helper: resize noise sigma vector to requested depth.
function noise_std_out = match_noise_std_length(noise_std_in, target_depth)
    if isempty(noise_std_in)
        noise_std_out = ones(1, target_depth);
        return;
    end
    noise_std_in = reshape(noise_std_in, 1, []);
    if numel(noise_std_in) >= target_depth
        noise_std_out = noise_std_in(1:target_depth);
    else
        noise_std_out = [noise_std_in, repmat(noise_std_in(end), 1, target_depth - numel(noise_std_in))];
    end
end

%% -------------------------------------------------------------------------
% Helper: align SNR matrices to common energy axis for plotting/factor.
function [snr_before_plot, snr_after_plot, energy_axis] = align_snr_matrices_for_plot(snr_before_raw, snr_after_raw)
    ncols = min(size(snr_before_raw, 2), size(snr_after_raw, 2));
    if ncols < 1
        error('SNR matrices must contain at least one energy slice.');
    end
    snr_before_plot = snr_before_raw(:, 1:ncols);
    snr_after_plot = snr_after_raw(:, 1:ncols);
    energy_axis = 1:ncols;
end

%% -------------------------------------------------------------------------
% Helper: choose subplot layout prioritizing exact integer factor grids.
% Example: n=8 -> [2,4].
function [nrow, ncol] = choose_integer_subplot_layout(nplots)
    if nplots <= 0
        nrow = 1; ncol = 1;
        return;
    end
    nplots = round(nplots);
    best = [];
    for r = 1:floor(sqrt(nplots))
        if mod(nplots, r) == 0
            c = nplots / r;
            if isempty(best) || abs(c - r) < abs(best(2) - best(1))
                best = [r, c];
            end
        end
    end
    if ~isempty(best)
        nrow = best(1);
        ncol = best(2);
    else
        ncol = ceil(sqrt(nplots));
        nrow = ceil(nplots / ncol);
    end
end
