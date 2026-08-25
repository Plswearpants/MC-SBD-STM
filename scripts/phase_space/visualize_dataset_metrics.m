%% ~~~~~~~~~~~~~ProperGen Results vis~~~~~~~~~~~~~~~~~~~~~
%  One S0 control panel (reproduction). Each %% cell below is a complete
%  MATLAB section: Run Section to execute just that block, or run the
%  whole script to honor every cfg.build.* / cfg.plot.* flag.
%
%  Typical use:
%    1. Edit S0, Run Section on S0 (path init + cfg).
%    2. Run Section on B1 (load), then B4/B5 as needed, then the V cells.
%  Plot-only (metrics already in workspace): set every cfg.build.* false,
%  Run S0, then Run Section on the V cell you want.
%
%  OUTLINE:
%    S0  Config + path init
%    B1  Load Dataset Metrics
%    B2  Build Observation Fidelity
%    B3  Build Normalized Kernel Similarity
%    B4  Recompute Nobs from X0
%    B5  Build Denoising Metric
%    V1  General Heatspace Views          (3 figures if on)
%    V2  Defect-Density / Interpolated    (6 figures if on)
%    V3  Interactive Inspectors           (1 UI + click-spawned details)
%    V4  Denoising + Nobs Heatmaps        (2 figures if on)
%    V5  sqrt(Nobs) vs SigmaRatio scatter (2 + N_snr figures if on)
%    V5b Linear-Fit Coefficient Sweeps    (N_snr + N_side figures if on)
%    V6  Defect Occurrence Diagnostics    (3 figures if on)
%    V8  Optional Combined/Legacy Views   (up to 5 figures if on)
%    --- Exploration (WIP; not part of the main recipe) ---
%    B6  Build NOR/LOO Metrics
%    V7  NOR/LOO vs Density               (1 figure if on; needs B6)

%% S0: Config (Control Panel - edit here)
% Locate repo root even if MATLAB runs an unsaved Editor temp copy.
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
    error(['Could not locate init_sbd.m. cd to the MT-SBD-STM repo ', ...
        '(or a subfolder), save this script if unsaved, then re-run.']);
end
addpath(repo_root);
run(fullfile(repo_root, 'init_sbd.m'));

cfg = default_config();

% ===== Build block switches (B1..B5) =====
% Whole-file run and Run Section both honor these. Flip a flag here, re-run
% S0, then Run Section on that block (or run the whole file).
cfg.build.load_dataset = false;                 % B1: load dataset metrics from disk.
cfg.build.observation_fidelity = false;         % B2: build observation fidelity metric tensors.
cfg.build.normalized_kernel_similarity = false; % B3: optional normalized KS tensors (off if using KS from loaded metrics).
cfg.build.recompute_nobs = true;               % B4: recompute Nobs from nonzero X0 occurrences.
cfg.build.denoising_sigma = true;              % B5: build denoising + sigma + Gaussian GOF metrics.

% ===== Plot block switches (V1..V6, V8) =====
% Each flag gates one %% V cell. See that cell's comment for the figure list.
cfg.plot.v1_general_heatspace = true;              % V1: 3 figures (3D metric picker, SNR=5 line profile, dual kernel|activation 3D).
cfg.plot.v2_defect_density_interpolated = true;    % V2: 6 figures (3 density-slice heatmaps + 3 interpolated-by-SNR heatmaps).
cfg.plot.v3_interactive_inspectors = true;         % V3: 1 inspector UI; click/Enter spawns kernel, residual, visualizeResults figures.
cfg.plot.v4_added_metric_heatmaps = false;          % V4: 2 figures (denoising-ratio heatmaps + Nobs heatmaps; χ²/p-value commented out).
cfg.plot.v5_scatter_stacking_law = true;           % V5: 2 + N_snr figures (mean scatter, per-kernel scatter, then one by-side-ratio figure per SNR).
cfg.plot.v5_fit_parameter_sweeps = true;           % V5b: N_snr + N_side figures (slope/intercept vs side ratio, then vs SNR).
cfg.plot.v6_defect_occurrence = false;              % V6: 3 figures (defects-vs-KS, defects-vs-KS by SNR, occurrence-vs-side-ratio).
cfg.plot.v8_optional_views = false;                 % V8: up to 5 figures if both inner flags below are true.

% ===== Key analysis parameters =====
cfg.axis3_mode = 2;                % 1: N_obs axis, 2: side-length-ratio axis.
cfg.activation_gate_threshold = 0.95; % gate for denoising metric build (activation similarity).
cfg.enable_alignment = true;      % enable shift-search alignment in sigma estimation.
cfg.kplus = [2, 2];               % shift-search half-window [dy dx]; used only when enable_alignment=true.
cfg.energy_stride = 2;             % evaluate every Nth energy slice when building denoising metrics.
cfg.store_residual_kernels = true; % store per-slot residual kernel maps in B5 (memory-heavy).
cfg.sigma_method = 'mad';          % sigma estimator: 'mad' (robust) or 'std'.
cfg.enable_sigma_analysis = true;  % print sigma diagnostics in detailed inspector.
cfg.inspector_fixed_snr = 5;       % fixed SNR shown in unified inspector heatmap.
cfg.inspector_metric_type = 'combined'; % heatmap metric in unified inspector ('kernel'|'combined'|'multiplied').

cfg.scatter_snr_targets = [3, 5, 7]; % target SNRs for scatter diagnostics (nearest bins used).
cfg.scatter_side_ratio_cutoff = 0.23; % in V5 per-side-ratio plot: include side ratios <= this cutoff.

% ===== Plot format handles =====
cfg.plot_format.font_name = 'Arial'; % shared font family for V5 labels/titles.
cfg.plot_format.font_size_axes = 18; % axis label + tick font size.
cfg.plot_format.font_size_title = 15; % subplot title font size.
cfg.plot_format.font_size_sgtitle = 16; % figure super-title font size.
cfg.plot_format.marker_size_mean = 22; % mean-mode marker size.
cfg.plot_format.marker_size_kernel = 20; % per-kernel marker size.
cfg.plot_format.legend_location = 'northwest'; % per-kernel legend location.

cfg.enable_combined_runs_view = true; % V8: pooled defects-vs-KS, by-SNR defects-vs-KS, 3-run 3D overlay.
cfg.enable_legacy_view = false;        % V8: legacy 3D heatspace + prompted Detailed Results.

% ===== Exploration (WIP): NOR/LOO — last cells in this script =====
cfg.build.nor_loo = false;                      % B6: build NOR/LOO overlap metrics (under development).
cfg.plot.v7_nor_loo_density = false;            % V7: 1 figure (NOR | LOO | NOR×LOO vs density). Needs B6.
cfg.selected_snr = 5;                           % SNR used in V7 NOR/LOO-vs-density.
cfg.selected_side_length_ratio = 0.175;         % side-ratio used in V7 NOR/LOO-vs-density.

metric_colormap = slanCM('viridis');
contour_levels = [0.95, 0.85];

%% B1: Load Dataset Metrics
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if cfg.build.load_dataset
    metrics = loadMetricDataset_new(cfg.axis3_mode);
elseif ~exist('metrics', 'var') || isempty(metrics)
    error('cfg.build.load_dataset=false requires seeded metrics in the workspace. Run B1 with load_dataset=true, or load metrics first.');
else
    fprintf('Using existing metrics (cfg.build.load_dataset=false).\n');
end

%% B2: Build Observation Fidelity
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if cfg.build.observation_fidelity
    metrics = build_observation_fidelity_metrics(metrics, cfg.axis3_mode);
else
    fprintf('Skipping B2 (cfg.build.observation_fidelity=false).\n');
end

%% B3: Build Normalized Kernel Similarity
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if cfg.build.normalized_kernel_similarity
    metrics = build_normalized_kernel_similarity(metrics);
else
    fprintf('Skipping B3 (cfg.build.normalized_kernel_similarity=false).\n');
end

%% B4: Recompute Nobs from X0
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if cfg.build.recompute_nobs
    metrics = recompute_nobs_from_x0(metrics);
else
    fprintf('Skipping B4 (cfg.build.recompute_nobs=false).\n');
end

%% B5: Build Denoising Metric
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if cfg.build.denoising_sigma
    metrics = build_denoising_sigma_metrics(metrics, cfg.activation_gate_threshold, ...
        'enableAlignment', cfg.enable_alignment, ...
        'kplus', cfg.kplus, ...
        'energyStride', cfg.energy_stride, ...
        'storeResidualKernels', cfg.store_residual_kernels, ...
        'sigmaMethod', cfg.sigma_method);
else
    fprintf('Skipping B5 (cfg.build.denoising_sigma=false).\n');
end

%% V1: General Heatspace Views
% If cfg.plot.v1_general_heatspace=true, opens 3 figures:
%   1) 3D scatter heatspace — a dialog asks which metric to color by
%      (axes: defect density × axis-3 × SNR).
%   2) Combined-activation line profile at SNR=5 — interpolated 2D map
%      (density × axis-3) plus a live 1D profile after you draw a line.
%   3) Dual 3D heatspace (two panels): kernel similarity | combined
%      activation, averaged over repetitions.
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if ~exist('metric_colormap', 'var')
    metric_colormap = slanCM('viridis');
end
if cfg.plot.v1_general_heatspace
    metrics2heat_general(metrics, 2);
    metrics2heat_general(metrics, 2, ...
        'plot_mode', 'line_profile', ...
        'metric_type', 'combined', ...
        'snr_value', 5, ...
        'interp_factor', 1, ...
        'manual_colormap', metric_colormap);
    metrics2heat_properGen(metrics, cfg.axis3_mode);
else
    fprintf('Skipping V1 (cfg.plot.v1_general_heatspace=false).\n');
end

%% V2: Defect-Density and Interpolated Heatmaps
% If cfg.plot.v2_defect_density_interpolated=true, opens 6 figures:
%   1) Kernel similarity: SNR × axis-3 slices, one subplot per defect density.
%   2) Kernel similarity: interpolated density × axis-3 maps, one subplot
%      per SNR (interp_factor=5, default colormap, no contours).
%   3) Same kernel interpolated maps as (2), viridis + iso-contours 0.95/0.85.
%   4) Combined activation: interpolated density × axis-3 maps, one subplot
%      per SNR (interp_factor=1, viridis, iso-contours 0.95/0.85).
%   5) Combined activation: SNR × axis-3 slices, one subplot per density.
%   6) Kernel × activation product: SNR × axis-3 slices, one subplot per density.
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if ~exist('metric_colormap', 'var')
    metric_colormap = slanCM('viridis');
end
if ~exist('contour_levels', 'var')
    contour_levels = [0.95, 0.85];
end
if cfg.plot.v2_defect_density_interpolated
    metrics2heat_by_defect_density(metrics, 'kernel', cfg.axis3_mode);
    metrics2heat_by_snr_interpolated(metrics, 'kernel', cfg.axis3_mode, 5);
    metrics2heat_by_snr_interpolated(metrics, 'kernel', cfg.axis3_mode, 5, metric_colormap, contour_levels);
    metrics2heat_by_snr_interpolated(metrics, 'combined', cfg.axis3_mode, 1, metric_colormap, contour_levels);
    metrics2heat_by_defect_density(metrics, 'combined', cfg.axis3_mode);
    metrics2heat_by_defect_density(metrics, 'multiplied', cfg.axis3_mode);
else
    fprintf('Skipping V2 (cfg.plot.v2_defect_density_interpolated=false).\n');
end

%% V3: Interactive Inspectors
% If cfg.plot.v3_interactive_inspectors=true, opens 1 figure immediately:
%   Unified Inspector — interpolated heatmap of cfg.inspector_metric_type
%   at cfg.inspector_fixed_snr, with SNR / density / axis-3 / rep fields.
% Click a point (or type values + Enter) to spawn additional figures:
%   visualizeResults details, kernel snapshot (input / GT / output per
%   kernel at one energy slice), and residual kernels from the
%   shift+gain+bias fit (if B5 stored them).
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if cfg.plot.v3_interactive_inspectors
    inspect_dataset_heatmap_unified(metrics, ...
        cfg.inspector_fixed_snr, ...
        cfg.inspector_metric_type, ...
        cfg.axis3_mode, ...
        1, ...
        cfg.enable_sigma_analysis);
else
    fprintf('Skipping V3 (cfg.plot.v3_interactive_inspectors=false).\n');
end

%% V4: Added Metric Heatmaps (Denoising + Nobs)
% If cfg.plot.v4_added_metric_heatmaps=true, opens 2 figures:
%   1) Denoising ratio σ_in/σ_out: interpolated density × axis-3 maps,
%      one subplot per SNR (viridis). Needs B5.
%   2) Nobs: interpolated density × axis-3 maps, one subplot per SNR.
%      Needs B4 (or loader Nobs). Two GOF heatmaps (χ², p-value) are
%      commented out in this cell — uncomment to add them.
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if ~exist('metric_colormap', 'var')
    metric_colormap = slanCM('viridis');
end
if cfg.plot.v4_added_metric_heatmaps
    metrics2heat_by_snr_interpolated(metrics, 'denoising', cfg.axis3_mode, 1, metric_colormap);
    %metrics2heat_by_snr_interpolated(metrics, 'denoising_chi2', cfg.axis3_mode, 1, metric_colormap);
    %metrics2heat_by_snr_interpolated(metrics, 'denoising_pvalue', cfg.axis3_mode, 1, metric_colormap);
    metrics2heat_by_snr_interpolated(metrics, 'nobs', cfg.axis3_mode, 1, metric_colormap);
else
    fprintf('Skipping V4 (cfg.plot.v4_added_metric_heatmaps=false).\n');
end

%% V5: sqrt(Nobs)-vs-SigmaRatio Scatter Diagnostics
% If cfg.plot.v5_scatter_stacking_law=true, opens 2 + N_snr figures
% (N_snr = numel(cfg.scatter_snr_targets); default targets [3, 5, 7]):
%   1) sqrt(Nobs) vs σ_in/σ_out, mean-over-slot mode — one subplot per
%      selected SNR; color = side-length ratio when axis3_mode=2.
%   2) sqrt(Nobs) vs σ_in/σ_out, per-kernel mode — one subplot per SNR,
%      one color/fit per kernel.
%   3..2+N_snr) One figure per selected SNR: per-kernel scatter tiled by
%      side-length ratio (only ratios ≤ cfg.scatter_side_ratio_cutoff).
% Needs B4 and B5. Side-ratio tiling is skipped when axis3_mode≠2.
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if cfg.plot.v5_scatter_stacking_law
    plot_nobs_vs_denoising_scatter(metrics, cfg);
    plot_nobs_vs_denoising_by_side_ratio(metrics, cfg);
else
    fprintf('Skipping V5 (cfg.plot.v5_scatter_stacking_law=false).\n');
end

%% V5b: Linear-Fit Coefficient Sweeps
% If cfg.plot.v5_fit_parameter_sweeps=true, opens N_snr + N_side figures
% (one per SNR grid point, then one per side-length-ratio grid point):
%   Per SNR: two panels — slope a and intercept b vs side-length ratio
%   (one curve per kernel).
%   Per side-length ratio: two panels — slope a and intercept b vs SNR
%   (one curve per kernel).
% Fits are y = a*sqrt(Nobs) + b on the per-kernel V5 scatter points.
% Skipped when axis3_mode≠2. Needs B4 and B5.
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if isfield(cfg.plot, 'v5_fit_parameter_sweeps') && cfg.plot.v5_fit_parameter_sweeps
    plot_v5_fit_parameter_sweeps(metrics, cfg);
else
    fprintf('Skipping V5b (cfg.plot.v5_fit_parameter_sweeps=false).\n');
end

%% V6: Defect Occurrence Diagnostics
% If cfg.plot.v6_defect_occurrence=true, opens 3 figures:
%   1) Average defect count vs kernel similarity, color = SNR
%      (single scatter, log-x).
%   2) Average defect count vs kernel similarity, one subplot per SNR,
%      color = defect density.
%   3) Occurrence vs side-length ratio at a prompted SNR — two panels:
%      color = kernel similarity | color = combined activation.
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if cfg.plot.v6_defect_occurrence
    plot_defects_snr_kernel_similarity(metrics);
    plot_defects_vs_kernel_similarity_by_snr(metrics);
    plot_occurrence_vs_length_ratio_by_snr(metrics);
else
    fprintf('Skipping V6 (cfg.plot.v6_defect_occurrence=false).\n');
end

%% V8: Optional Combined/Legacy Views
% If cfg.plot.v8_optional_views=true and both inner flags are true,
% opens 5 figures. Turn an inner flag off to drop that group.
% Combined runs (cfg.enable_combined_runs_view) — placeholder loads:
%   1) Defects vs kernel similarity, color = SNR (three runs pooled).
%   2) Defects vs kernel similarity, one subplot per SNR, color = density.
%   3) Dual 3D overlay of the three named runs: kernel similarity |
%      combined activation.
% Legacy (cfg.enable_legacy_view) — load_datasets_metrics:
%   4) Dual 3D heatspace (theta × area ratio × SNR): kernel similarity |
%      combined activation.
%   5) Same heatspace again, then prompts for a point and opens
%      Detailed Results (visualizeResults).
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if cfg.plot.v8_optional_views
    if cfg.enable_combined_runs_view
        % Placeholder: three identical loads. Replace with distinct
        % datasets and run_names before using combined-run plots.
        metrics1 = loadMetricDataset_new(1);
        metrics2 = loadMetricDataset_new(1);
        metrics3 = loadMetricDataset_new(1);
        dataset_metrics_array = {metrics1, metrics2, metrics3};
        run_names = {'Experiment 1', 'Experiment 2', 'Experiment 3'};
        combined_metrics = combine_metrics_for_plotting(dataset_metrics_array);
        plot_defects_snr_kernel_similarity(combined_metrics);
        plot_defects_vs_kernel_similarity_by_snr(combined_metrics);
        metrics2heat_multiple_runs(dataset_metrics_array, run_names, cfg.axis3_mode);
    end
    if cfg.enable_legacy_view
        legacy_metrics = load_datasets_metrics();
        metrics2heatspace(legacy_metrics);
        visualize_heatspace_details(legacy_metrics);
    end
else
    fprintf('Skipping V8 (cfg.plot.v8_optional_views=false).\n');
end

%% B6: Build NOR/LOO Metrics (exploration, WIP)
% Under development. Not part of the main recipe. Run after B1 (and any
% other build cells you need). Writes metrics.NOR and metrics.LOO.
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if cfg.build.nor_loo
    metrics = build_nor_loo_metrics(metrics);
else
    fprintf('Skipping B6 (cfg.build.nor_loo=false).\n');
end

%% V7: NOR/LOO vs Density (exploration, WIP)
% Under development. If cfg.plot.v7_nor_loo_density=true, opens 1 figure
% (needs B6 NOR/LOO):
%   Three panels at cfg.selected_snr and cfg.selected_side_length_ratio:
%   NOR vs defect density | LOO vs defect density | NOR×LOO vs density.
if ~exist('cfg', 'var') || ~isstruct(cfg)
    error('Run S0 (Config) first so cfg is in the workspace.');
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('No metrics in workspace. Run B1 first.');
end
if cfg.plot.v7_nor_loo_density
    plot_nor_loo_vs_density(metrics, cfg.selected_snr, cfg.selected_side_length_ratio);
else
    fprintf('Skipping V7 (cfg.plot.v7_nor_loo_density=false).\n');
end

function metrics = recompute_nobs_from_x0(metrics)
    if ~isfield(metrics, 'X0') || isempty(metrics.X0)
        return;
    end

    nobs_occurrence = nan(size(metrics.X0));
    nobs_per_kernel = cell(size(metrics.X0));

    for linear_idx = 1:numel(metrics.X0)
        X0_slot = metrics.X0{linear_idx};
        if isempty(X0_slot)
            continue;
        end
        if iscell(X0_slot)
            if isempty(X0_slot)
                continue;
            end
            X0_slot = X0_slot{1};
        end
        if ~isnumeric(X0_slot) || ndims(X0_slot) < 2
            continue;
        end

        if ndims(X0_slot) == 2
            counts = nnz(X0_slot ~= 0);
        else
            num_kernels_slot = size(X0_slot, 3);
            counts = zeros(1, num_kernels_slot);
            for k = 1:num_kernels_slot
                counts(k) = nnz(X0_slot(:,:,k) ~= 0);
            end
        end

        nobs_per_kernel{linear_idx} = counts;
        nobs_occurrence(linear_idx) = mean(counts, 'omitnan');
    end

    metrics.Nobs_per_kernel_at_axis3 = nobs_per_kernel;
    metrics.Nobs_at_axis3 = nobs_occurrence;
    metrics.Nobs = nobs_occurrence;
end

function plot_nobs_vs_denoising_scatter(metrics, cfg)
    if ~isfield(metrics, 'Nobs_at_axis3') || ...
            ~isfield(metrics, 'denoising_sigma_ratio_final')
        return;
    end

    [snr_indices, snr_vals] = select_snr_indices(metrics.SNR_values, cfg.scatter_snr_targets);
    [num_rows, num_cols] = choose_subplot_layout(numel(snr_vals));
    scatter_modes = {'mean', 'per_kernel'};

    for mode_idx = 1:numel(scatter_modes)
        mode_name = scatter_modes{mode_idx};
        figure('Name', sprintf('sqrt(Nobs) vs sigma_{in}/sigma_{out} (%s)', mode_name), ...
            'Position', [120 120 430*num_cols 360*num_rows]);

        for s = 1:numel(snr_vals)
            s_idx = snr_indices(s);
            subplot(num_rows, num_cols, s);
            hold on;

            if strcmp(mode_name, 'mean')
                [xv, yv, sidev] = collect_mean_mode_points(metrics, s_idx, cfg.axis3_mode, cfg.scatter_side_ratio_cutoff);
                if isempty(xv)
                    hold off;
                    continue;
                end
                if cfg.axis3_mode == 2 && isfield(metrics, 'side_length_ratio_values') && ...
                        ~isempty(sidev) && any(isfinite(sidev))
                    scatter(xv, yv, cfg.plot_format.marker_size_mean, sidev, 'filled', ...
                        'MarkerFaceAlpha', 0.75, ...
                        'MarkerEdgeAlpha', 0.75);
                    colormap(gca, turbo);
                    side_ticks = unique(sidev(isfinite(sidev)));
                    side_ticks = sort(side_ticks(:)');
                    if numel(side_ticks) == 1
                        caxis([side_ticks(1)-1e-12, side_ticks(1)+1e-12]);
                    else
                        caxis([side_ticks(1), side_ticks(end)]);
                    end
                    cb = colorbar;
                    cb.Ticks = side_ticks;
                    cb.TickLabels = arrayfun(@(v) sprintf('%.3f', v), side_ticks, 'UniformOutput', false);
                    ylabel(cb, 'side length ratio');
                    apply_colorbar_format(cb, cfg.plot_format);
                else
                    scatter(xv, yv, cfg.plot_format.marker_size_mean, 'filled', ...
                        'MarkerFaceColor', [0.15 0.5 0.85], ...
                        'MarkerFaceAlpha', 0.65);
                end
            else
                if ~isfield(metrics, 'Nobs_per_kernel_at_axis3') || ...
                        ~isfield(metrics, 'denoising_sigma_ratio_per_kernel')
                    warning('Per-kernel scatter requested but per-kernel metric fields are unavailable.');
                    hold off;
                    continue;
                end
                [x_by_kernel, y_by_kernel] = collect_per_kernel_points( ...
                    squeeze(metrics.Nobs_per_kernel_at_axis3(s_idx,:,:,:)), ...
                    squeeze(metrics.denoising_sigma_ratio_per_kernel(s_idx,:,:,:)));
                fit_stats = scatter_per_kernel_groups(x_by_kernel, y_by_kernel, 'sqrt', ...
                    cfg.plot_format.marker_size_kernel, cfg.plot_format.legend_location);
                add_compact_fit_summary(gca, fit_stats);
                print_fit_summary_to_console(sprintf('V5 per-kernel | SNR=%.3g', snr_vals(s)), fit_stats);
            end

            hold off;
            grid on;
            xlabel('sqrt(Nobs)');
            ylabel('\sigma_{in}/\sigma_{out}');
            title(sprintf('SNR = %.2f', snr_vals(s)));
            apply_axes_format(gca, cfg.plot_format);
        end
        st = sgtitle(sprintf('sqrt(Nobs) vs sigma_in/sigma_out (%s mode)', ...
            strrep(mode_name, '_', ' ')));
        apply_text_format(st, cfg.plot_format.font_name, cfg.plot_format.font_size_sgtitle);
    end
end

function [xv, yv, sidev] = collect_mean_mode_points(metrics, snr_idx, axis3_mode, side_ratio_cutoff)
    sidev = [];
    if ndims(metrics.Nobs_at_axis3) == 4
        x_block = squeeze(metrics.Nobs_at_axis3(snr_idx, :, :, :));
        y_block = squeeze(metrics.denoising_sigma_ratio_final(snr_idx, :, :, :));
    else
        x_block = squeeze(metrics.Nobs_at_axis3(snr_idx, :, :));
        y_block = squeeze(metrics.denoising_sigma_ratio_final(snr_idx, :, :));
    end
    x = x_block(:);
    y = y_block(:);
    valid = isfinite(x) & isfinite(y) & (x > 0);
    xv = sqrt(x(valid));
    yv = y(valid);

    if axis3_mode ~= 2 || ~isfield(metrics, 'side_length_ratio_values')
        return;
    end
    side_vals = metrics.side_length_ratio_values(:)';
    if isempty(side_vals)
        return;
    end
    side_block = build_side_ratio_block(size(x_block), side_vals);
    side = side_block(:);
    sidev = side(valid);
    if nargin >= 4 && isfinite(side_ratio_cutoff)
        keep = isfinite(sidev) & (sidev <= side_ratio_cutoff);
        xv = xv(keep);
        yv = yv(keep);
        sidev = sidev(keep);
    end
end

function side_block = build_side_ratio_block(block_size, side_vals)
    if isempty(block_size)
        side_block = [];
        return;
    end
    if numel(block_size) == 1
        side_block = nan(block_size);
        return;
    end
    n_den = block_size(1);
    n_side = block_size(2);
    if numel(block_size) >= 3
        n_rep = block_size(3);
    else
        n_rep = 1;
    end
    n_use = min(n_side, numel(side_vals));
    vals_use = nan(1, n_side);
    vals_use(1:n_use) = side_vals(1:n_use);
    base = reshape(vals_use, [1, n_side, 1]);
    side_block = repmat(base, [n_den, 1, n_rep]);
end

function plot_nobs_vs_denoising_by_side_ratio(metrics, cfg)
    if cfg.axis3_mode ~= 2 || ~isfield(metrics, 'side_length_ratio_values') || ...
            ~isfield(metrics, 'Nobs_per_kernel_at_axis3') || ...
            ~isfield(metrics, 'denoising_sigma_ratio_per_kernel')
        return;
    end

    [snr_indices, snr_vals] = select_snr_indices(metrics.SNR_values, cfg.scatter_snr_targets);
    side_vals_all = metrics.side_length_ratio_values(:)';
    side_mask = isfinite(side_vals_all) & (side_vals_all <= cfg.scatter_side_ratio_cutoff);
    side_idx_sel = find(side_mask);
    side_vals = side_vals_all(side_idx_sel);
    if isempty(side_vals)
        warning('No side-length-ratio values <= %.4g for V5 side-ratio scatter.', cfg.scatter_side_ratio_cutoff);
        return;
    end
    [num_rows, num_cols] = choose_subplot_layout_wide(numel(side_vals));

    for s = 1:numel(snr_indices)
        s_idx = snr_indices(s);
        figure('Name', sprintf('sqrt(Nobs) vs sigma_{in}/sigma_{out} by side ratio <= %.3f (SNR=%.2f)', ...
            cfg.scatter_side_ratio_cutoff, snr_vals(s)), ...
            'Position', [120 120 430*num_cols 360*num_rows]);

        for r = 1:numel(side_idx_sel)
            side_idx = side_idx_sel(r);
            subplot(num_rows, num_cols, r);
            hold on;
            [x_by_kernel, y_by_kernel] = collect_per_kernel_points( ...
                squeeze(metrics.Nobs_per_kernel_at_axis3(s_idx, :, side_idx, :)), ...
                squeeze(metrics.denoising_sigma_ratio_per_kernel(s_idx, :, side_idx, :)));
            fit_stats = scatter_per_kernel_groups(x_by_kernel, y_by_kernel, 'sqrt', ...
                cfg.plot_format.marker_size_kernel, cfg.plot_format.legend_location);
            add_compact_fit_summary(gca, fit_stats);
            print_fit_summary_to_console(sprintf('V5 by-side-ratio | SNR=%.3g | side=%.4f', ...
                snr_vals(s), side_vals(r)), fit_stats);
            hold off;
            grid on;
            xlabel('sqrt(Nobs)');
            ylabel('\sigma_{in}/\sigma_{out}');
            title(sprintf('side ratio = %.4f', side_vals(r)));
            apply_axes_format(gca, cfg.plot_format);
        end
        st = sgtitle(sprintf('sqrt(Nobs) vs sigma_in/sigma_out, side ratio <= %.3f (SNR=%.2f, per-kernel)', ...
            cfg.scatter_side_ratio_cutoff, snr_vals(s)));
        apply_text_format(st, cfg.plot_format.font_name, cfg.plot_format.font_size_sgtitle);
    end
end

function [x_by_kernel, y_by_kernel] = collect_per_kernel_points(nobs_cells, y_cells)
    x_by_kernel = {};
    y_by_kernel = {};
    for ii = 1:numel(nobs_cells)
        n_k = nobs_cells{ii};
        y_k = y_cells{ii};
        if isempty(n_k) || isempty(y_k)
            continue;
        end
        n_k = n_k(:);
        y_k = y_k(:);
        nk = min([numel(n_k), numel(y_k)]);
        if nk < 1
            continue;
        end
        for kk = 1:nk
            if numel(x_by_kernel) < kk || isempty(x_by_kernel{kk})
                x_by_kernel{kk} = n_k(kk);
                y_by_kernel{kk} = y_k(kk);
            else
                x_by_kernel{kk}(end+1,1) = n_k(kk); %#ok<AGROW>
                y_by_kernel{kk}(end+1,1) = y_k(kk); %#ok<AGROW>
            end
        end
    end
end

function fit_stats = scatter_per_kernel_groups(x_by_kernel, y_by_kernel, x_mode, marker_size, legend_location)
    num_kernels = numel(x_by_kernel);
    cmap = lines(max(1, num_kernels));
    fit_stats = repmat(struct('kernel', NaN, 'n', 0, 'slope', NaN, 'intercept', NaN, ...
        'r2', NaN, 'rmse', NaN), 1, num_kernels);
    for kk = 1:num_kernels
        if isempty(x_by_kernel{kk}) || isempty(y_by_kernel{kk})
            continue;
        end
        xv = x_by_kernel{kk};
        yv = y_by_kernel{kk};
        valid = isfinite(xv) & isfinite(yv) & (xv > 0);
        xv = xv(valid);
        yv = yv(valid);
        if isempty(xv)
            continue;
        end
        if strcmpi(x_mode, 'inv_sqrt')
            xv = 1 ./ sqrt(xv);
        elseif strcmpi(x_mode, 'sqrt')
            xv = sqrt(xv);
        end
        scatter(xv, yv, marker_size, 'filled', ...
            'MarkerFaceColor', cmap(kk,:), ...
            'MarkerFaceAlpha', 0.65, ...
            'DisplayName', sprintf('Kernel %d', kk));

        fit_stats(kk) = compute_linear_fit_stats(xv, yv, kk);
        if fit_stats(kk).n >= 2 && isfinite(fit_stats(kk).slope) && isfinite(fit_stats(kk).intercept)
            x_line = linspace(min(xv), max(xv), 100);
            y_line = fit_stats(kk).slope .* x_line + fit_stats(kk).intercept;
            plot(x_line, y_line, '-', 'LineWidth', 1.4, ...
                'Color', cmap(kk,:), 'HandleVisibility', 'off');
        end
    end
    if num_kernels > 0
        if nargin < 5 || isempty(legend_location)
            legend_location = 'best';
        end
        legend('Location', legend_location);
    end
end

function fit_stat = compute_linear_fit_stats(xv, yv, kernel_idx)
    fit_stat = struct('kernel', kernel_idx, 'n', 0, 'slope', NaN, 'intercept', NaN, ...
        'r2', NaN, 'rmse', NaN);
    valid = isfinite(xv) & isfinite(yv);
    xv = xv(valid);
    yv = yv(valid);
    fit_stat.n = numel(xv);
    if fit_stat.n < 2 || numel(unique(xv)) < 2
        return;
    end

    p = polyfit(xv, yv, 1);
    yhat = polyval(p, xv);
    residual = yv - yhat;
    ss_res = sum(residual.^2);
    ss_tot = sum((yv - mean(yv)).^2);

    fit_stat.slope = p(1);
    fit_stat.intercept = p(2);
    fit_stat.rmse = sqrt(mean(residual.^2));
    if ss_tot > 0
        fit_stat.r2 = 1 - ss_res / ss_tot;
    end
end

function add_compact_fit_summary(ax, fit_stats)
    if nargin < 2 || isempty(fit_stats) || ~isgraphics(ax, 'axes')
        return;
    end
    valid_idx = find(arrayfun(@(s) s.n >= 2 && isfinite(s.r2), fit_stats));
    if isempty(valid_idx)
        text(ax, 0.02, 0.98, 'fit: insufficient data', ...
            'Units', 'normalized', ...
            'VerticalAlignment', 'top', ...
            'HorizontalAlignment', 'left', ...
            'FontSize', max(8, ax.FontSize - 2), ...
            'BackgroundColor', [1 1 1], ...
            'Margin', 3, ...
            'Interpreter', 'none');
        return;
    end

    summary_lines = cell(1, numel(valid_idx) + 1);
    summary_lines{1} = 'linear fit: K[a,b,R^2]';
    for i = 1:numel(valid_idx)
        fs = fit_stats(valid_idx(i));
        summary_lines{i+1} = sprintf('K%d[%.3g,%.3g,%.3f]', fs.kernel, fs.slope, fs.intercept, fs.r2);
    end
    summary_text = strjoin(summary_lines, newline);
    text(ax, 0.02, 0.98, summary_text, ...
        'Units', 'normalized', ...
        'VerticalAlignment', 'top', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', max(8, ax.FontSize - 2), ...
        'BackgroundColor', [1 1 1], ...
        'Margin', 3, ...
        'Interpreter', 'none');
end

function print_fit_summary_to_console(context_label, fit_stats)
    if nargin < 2 || isempty(fit_stats)
        return;
    end
    valid_idx = find(arrayfun(@(s) s.n >= 2 && isfinite(s.slope) && isfinite(s.intercept), fit_stats));
    if isempty(valid_idx)
        fprintf('[fit] %s -> insufficient data for linear fit.\n', context_label);
        return;
    end

    for i = 1:numel(valid_idx)
        fs = fit_stats(valid_idx(i));
        fprintf('[fit] %s | K%d: y = %.6g*x + %.6g (a=%.6g, b=%.6g, R^2=%.4f, RMSE=%.4g, n=%d)\n', ...
            context_label, fs.kernel, fs.slope, fs.intercept, fs.slope, fs.intercept, fs.r2, fs.rmse, fs.n);
    end
end

function plot_v5_fit_parameter_sweeps(metrics, cfg)
    if cfg.axis3_mode ~= 2 || ~isfield(metrics, 'SNR_values') || ...
            ~isfield(metrics, 'side_length_ratio_values') || ...
            ~isfield(metrics, 'Nobs_per_kernel_at_axis3') || ...
            ~isfield(metrics, 'denoising_sigma_ratio_per_kernel')
        return;
    end

    snr_vals_all = metrics.SNR_values(:)';
    side_vals_all = metrics.side_length_ratio_values(:)';
    if isempty(snr_vals_all) || isempty(side_vals_all)
        return;
    end

    snr_indices_all = find(isfinite(snr_vals_all));
    side_indices_all = find(isfinite(side_vals_all));
    if isempty(snr_indices_all) || isempty(side_indices_all)
        return;
    end

    % Sweep 1: for every SNR, plot side-length-ratio vs slope/intercept.
    side_vals_for_snr = side_vals_all(side_indices_all);
    for ii = 1:numel(snr_indices_all)
        s_idx = snr_indices_all(ii);
        [slope_vs_side, intercept_vs_side] = build_fit_coeff_matrices(metrics, s_idx, side_indices_all);
        plot_fit_coefficients( ...
            side_vals_for_snr, slope_vs_side, intercept_vs_side, cfg, ...
            'side length ratio', ...
            sprintf('Fixed SNR = %.3g', snr_vals_all(s_idx)));
    end

    % Sweep 2: for every side ratio, plot SNR vs slope/intercept.
    snr_vals_for_side = snr_vals_all(snr_indices_all);
    for jj = 1:numel(side_indices_all)
        side_idx = side_indices_all(jj);
        [slope_vs_snr, intercept_vs_snr] = build_fit_coeff_matrices(metrics, snr_indices_all, side_idx);
        plot_fit_coefficients( ...
            snr_vals_for_side, slope_vs_snr, intercept_vs_snr, cfg, ...
            'SNR', ...
            sprintf('Fixed side ratio = %.4f', side_vals_all(side_idx)));
    end
end

function [slope_mat, intercept_mat] = build_fit_coeff_matrices(metrics, snr_indices, side_indices)
    slope_mat = nan(0, numel(snr_indices) * numel(side_indices));
    intercept_mat = nan(0, numel(snr_indices) * numel(side_indices));
    col = 0;
    for ii = 1:numel(snr_indices)
        s_idx = snr_indices(ii);
        for jj = 1:numel(side_indices)
            side_idx = side_indices(jj);
            col = col + 1;
            [slope_vec, intercept_vec] = fit_coefficients_for_slice(metrics, s_idx, side_idx);
            n_kernel = numel(slope_vec);
            if size(slope_mat, 1) < n_kernel
                slope_mat(size(slope_mat, 1)+1:n_kernel, :) = nan;
                intercept_mat(size(intercept_mat, 1)+1:n_kernel, :) = nan;
            end
            if n_kernel > 0
                slope_mat(1:n_kernel, col) = slope_vec(:);
                intercept_mat(1:n_kernel, col) = intercept_vec(:);
            end
        end
    end
end

function [slope_vec, intercept_vec] = fit_coefficients_for_slice(metrics, snr_idx, side_idx)
    [x_by_kernel, y_by_kernel] = collect_per_kernel_points( ...
        squeeze(metrics.Nobs_per_kernel_at_axis3(snr_idx, :, side_idx, :)), ...
        squeeze(metrics.denoising_sigma_ratio_per_kernel(snr_idx, :, side_idx, :)));

    num_kernels = numel(x_by_kernel);
    slope_vec = nan(1, num_kernels);
    intercept_vec = nan(1, num_kernels);
    for kk = 1:num_kernels
        if isempty(x_by_kernel{kk}) || isempty(y_by_kernel{kk})
            continue;
        end
        xv = x_by_kernel{kk};
        yv = y_by_kernel{kk};
        valid = isfinite(xv) & isfinite(yv) & (xv > 0);
        xv = sqrt(xv(valid));
        yv = yv(valid);
        fit_stat = compute_linear_fit_stats(xv, yv, kk);
        if fit_stat.n >= 2 && isfinite(fit_stat.slope) && isfinite(fit_stat.intercept)
            slope_vec(kk) = fit_stat.slope;
            intercept_vec(kk) = fit_stat.intercept;
        end
    end
end

function plot_fit_coefficients(x_values, slope_mat, intercept_mat, cfg, x_label, context_title)
    if isempty(x_values) || isempty(slope_mat)
        return;
    end
    num_kernels = size(slope_mat, 1);
    if num_kernels < 1
        return;
    end

    cmap = lines(max(1, num_kernels));
    fig = figure('Name', sprintf('V5b Fit Coefficients (%s)', context_title), ...
        'Position', [140 140 980 420]);
    t = tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    ax1 = nexttile(t, 1);
    hold(ax1, 'on');
    for kk = 1:num_kernels
        yk = slope_mat(kk, :);
        valid = isfinite(x_values) & isfinite(yk);
        if any(valid)
            plot(ax1, x_values(valid), yk(valid), '-o', ...
                'LineWidth', 1.2, ...
                'MarkerSize', 4, ...
                'Color', cmap(kk,:), ...
                'DisplayName', sprintf('Kernel %d', kk));
        end
    end
    hold(ax1, 'off');
    grid(ax1, 'on');
    xlabel(ax1, x_label);
    ylabel(ax1, 'slope a');
    title(ax1, 'y = ax + b: slope (a)');
    apply_axes_format(ax1, cfg.plot_format);

    ax2 = nexttile(t, 2);
    hold(ax2, 'on');
    for kk = 1:num_kernels
        yk = intercept_mat(kk, :);
        valid = isfinite(x_values) & isfinite(yk);
        if any(valid)
            plot(ax2, x_values(valid), yk(valid), '-o', ...
                'LineWidth', 1.2, ...
                'MarkerSize', 4, ...
                'Color', cmap(kk,:), ...
                'DisplayName', sprintf('Kernel %d', kk));
        end
    end
    hold(ax2, 'off');
    grid(ax2, 'on');
    xlabel(ax2, x_label);
    ylabel(ax2, 'intercept b');
    title(ax2, 'y = ax + b: intercept (b)');
    apply_axes_format(ax2, cfg.plot_format);
    legend(ax2, 'Location', cfg.plot_format.legend_location);

    st = sgtitle(t, sprintf('V5b Linear-Fit Coefficients | %s', context_title));
    apply_text_format(st, cfg.plot_format.font_name, cfg.plot_format.font_size_sgtitle);
end

function apply_axes_format(ax, fmt)
    if ~isgraphics(ax, 'axes')
        return;
    end
    if isfield(fmt, 'font_name') && ~isempty(fmt.font_name)
        ax.FontName = fmt.font_name;
    end
    if isfield(fmt, 'font_size_axes') && isfinite(fmt.font_size_axes)
        ax.FontSize = fmt.font_size_axes;
        ax.TitleFontSizeMultiplier = 1;
        ax.LabelFontSizeMultiplier = 1;
        if isgraphics(ax.Title)
            ax.Title.FontSize = fmt.font_size_title;
        end
        if isgraphics(ax.XLabel)
            ax.XLabel.FontSize = fmt.font_size_axes;
        end
        if isgraphics(ax.YLabel)
            ax.YLabel.FontSize = fmt.font_size_axes;
        end
    end
end

function apply_colorbar_format(cb, fmt)
    if ~isgraphics(cb, 'colorbar')
        return;
    end
    if isfield(fmt, 'font_name') && ~isempty(fmt.font_name)
        cb.FontName = fmt.font_name;
    end
    if isfield(fmt, 'font_size_axes') && isfinite(fmt.font_size_axes)
        cb.FontSize = fmt.font_size_axes;
        if isgraphics(cb.Label)
            cb.Label.FontSize = fmt.font_size_axes;
        end
    end
end

function apply_text_format(txt_handle, font_name, font_size)
    if ~isgraphics(txt_handle)
        return;
    end
    if ~isempty(font_name)
        txt_handle.FontName = font_name;
    end
    if isfinite(font_size)
        txt_handle.FontSize = font_size;
    end
end

%% --------------------------- Utilities -------------------------------
function [indices, values] = select_snr_indices(snr_values, targets)
    snr_all = snr_values(:)';
    idx = zeros(1, numel(targets));
    for i = 1:numel(targets)
        [~, idx(i)] = min(abs(snr_all - targets(i)));
    end
    indices = unique(idx, 'stable');
    values = snr_all(indices);
end

function [nrow, ncol] = choose_subplot_layout(nplots)
    if nplots <= 0
        nrow = 1;
        ncol = 1;
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

function [nrow, ncol] = choose_subplot_layout_wide(nplots)
    if nplots <= 1
        nrow = 1;
        ncol = 1;
        return;
    end
    nplots = round(nplots);
    best = [];
    for r = 1:floor(sqrt(nplots))
        if mod(nplots, r) == 0
            c = nplots / r;
            if r < c
                if isempty(best) || abs(c - r) < abs(best(2) - best(1))
                    best = [r, c];
                end
            end
        end
    end
    if ~isempty(best)
        nrow = best(1);
        ncol = best(2);
        return;
    end
    nrow = floor(sqrt(nplots));
    if nrow < 1
        nrow = 1;
    end
    ncol = ceil(nplots / nrow);
    if nrow >= ncol
        nrow = max(1, nrow - 1);
        ncol = ceil(nplots / nrow);
    end
end

function cfg = default_config()
    % Fallback recipe. S0 overrides every field after this call; keep the
    % two in sync so a missed S0 line does not silently change behavior.

    % Build control panel (B1..B5). NOR/LOO (B6) is exploration/WIP.
    cfg.build = struct( ...
        'load_dataset', false, ...
        'observation_fidelity', false, ...
        'normalized_kernel_similarity', false, ...
        'recompute_nobs', true, ...
        'denoising_sigma', true, ...
        'nor_loo', false);

    % Plot control panel (V1..V6, V8). V7 NOR/LOO is exploration/WIP.
    cfg.plot = struct( ...
        'v1_general_heatspace', true, ...
        'v2_defect_density_interpolated', true, ...
        'v3_interactive_inspectors', true, ...
        'v4_added_metric_heatmaps', false, ...
        'v5_scatter_stacking_law', true, ...
        'v5_fit_parameter_sweeps', true, ...
        'v6_defect_occurrence', false, ...
        'v8_optional_views', false, ...
        'v7_nor_loo_density', false);

    % Axis-3 interpretation for loaded datasets:
    % 1 -> N_obs axis, 2 -> side-length-ratio axis.
    cfg.axis3_mode = 2;

    % Activation-similarity gate for denoising metric construction.
    % Slots below this threshold are excluded (set to NaN).
    cfg.activation_gate_threshold = 0.95;

    % If true, allow shift-search alignment when estimating sigma vs GT.
    % If false, sigma is computed without alignment.
    cfg.enable_alignment = true;

    % Alignment search half-window [dy dx] in pixels.
    % Actual shifts tested are dy in [-kplus(1), kplus(1)],
    % dx in [-kplus(2), kplus(2)] when enable_alignment=true.
    cfg.kplus = [2, 2];

    % Evaluate denoising sigma every Nth energy slice (speed/accuracy tradeoff).
    % 1 means use all slices; 2 means every other slice, etc.
    cfg.energy_stride = 2;

    % If true, B5 stores mean residual kernel maps per slot/kernel in metrics.
    % This can increase memory use for large parameter sweeps.
    cfg.store_residual_kernels = true;

    % Noise estimator used in sigma computation: 'mad' (robust) or 'std'.
    cfg.sigma_method = 'mad';

    % If true, detailed-point explorer also prints sigma denoising diagnostics.
    cfg.enable_sigma_analysis = true;

    % Fixed SNR / metric shown in the unified inspector (V3).
    cfg.inspector_fixed_snr = 5;
    cfg.inspector_metric_type = 'combined';

    % Target SNR values for scatter diagnostics; nearest available SNR bins are used.
    cfg.scatter_snr_targets = [3, 5, 7];

    % In V5 side-ratio scatter, include only side ratios <= this cutoff.
    cfg.scatter_side_ratio_cutoff = 0.23;

    % Shared V5 plot formatting handles (font + marker style).
    cfg.plot_format = struct( ...
        'font_name', 'Arial', ...
        'font_size_axes', 18, ...
        'font_size_title', 15, ...
        'font_size_sgtitle', 16, ...
        'marker_size_mean', 22, ...
        'marker_size_kernel', 20, ...
        'legend_location', 'northwest');

    % SNR / side-ratio filters used by the V7 NOR/LOO-vs-density exploration plot.
    cfg.selected_snr = 5;
    cfg.selected_side_length_ratio = 0.175;

    % If true, build and visualize combined plots across three loaded runs.
    cfg.enable_combined_runs_view = true;

    % If true, also execute the legacy metrics visualization section.
    cfg.enable_legacy_view = false;
end

