
%% Figure 1 
% def params
obs = Y_used;
chosen_slice = 85; 
num_kernels = 2;

%% produce cropping 
square_size = [80,80];
kernel_sizes = repmat(square_size,[num_kernels,1]);
[A1_ref, ~] = initialize_kernels(obs(:,:,chosen_slice), num_kernels, kernel_sizes, 'selected', '');

%% Make plot
fig1_suba = obs(:,:,chosen_slice);

figure;
title('subplot a')
imagesc(fig1_suba); axis square; colormap('gray');
set(gca,'XTick', [], 'YTick', [])

fig1_subb = qpiCalculate(obs(:,:,chosen_slice));
figure; 
title('subplot b')
imagesc(fig1_subb); axis square; colormap('invgray');
clim = clipEdgeIntensity(fig1_subb, 1);
set(gca,'XTick', [], 'YTick', [], 'CLim', clim)

figure; 
title('cropping')
ax1 = subplot(2,2,1);
imagesc(A1_ref{1});axis square; colormap(ax1,'gray');
set(ax1, 'XTick', [], 'YTick', []);
ax2 = subplot(2,2,2);
imagesc(qpiCalculate(A1_ref{1},484));axis square; colormap(ax2,'invgray');
set(ax2, 'XTick', [], 'YTick', [], 'Clim', clipEdgeIntensity(qpiCalculate(A1_ref{1}), 1))
ax3 = subplot(2,2,3);
imagesc(A1_ref{2});axis square; colormap(ax3, 'gray');
set(ax3, 'XTick', [], 'YTick', [])
ax4 = subplot(2,2,4);
imagesc(qpiCalculate(A1_ref{2},484));axis square; colormap(ax4,'invgray');
set(ax4, 'XTick', [], 'YTick', [], 'Clim', clipEdgeIntensity(qpiCalculate(A1_ref{2}), 1))

%% Make components Figure 4
filename_fig4 = "Chosen_ZrSiTe0304_s21to140_k12345_ALL.mat";
load(filename_fig4);

% convert Aout_ALL to cell format
[num_slices, num_kernels] = size(bout_ALL);
Aout_ALL_cell = cell(num_slices, num_kernels);
for s = 1:num_slices
    for k = 1:num_kernels
        Aout_ALL_cell{s,k} = Aout_ALL{k}(:,:,s);
    end
end

% Create reconstruction for all slices
Y_rec = zeros(size(Y_used));
for i = 1:size(Y_used,3)
    for k = 1:num_kernels
        Y_rec(:,:,i) = Y_rec(:,:,i) + convfft2(Aout_ALL_cell{i,k}, Xout_ALL(:,:,k)) + bout_ALL(i,k);
    end
end

% Create reconstruction for each kernel type
Y_rec_each = zeros([num_kernels,size(Y_used)]);
for i = 1:size(Y_used,3)
    for k = 1:num_kernels
        %Y_rec_each(k,:,:,i) = convfft2(Aout_ALL_cell{i,k}, Xout_ALL(:,:,k)) + bout_ALL(i,k);
        Y_rec_each(k,:,:,i) = convfft2(Aout_ALL_cell{i,k}, Xout_ALL(:,:,k));
    end
end

% create fft of Y_rec_each
FT_QPI_Y_rec_each = zeros([num_kernels,size(Y_used)]);
for k = 1:num_kernels
    FT_QPI_Y_rec_each(k,:,:,:) = qpiCalculate(squeeze(Y_rec_each(k,:,:,:)));
end

% Normalize and combine Y_rec_each and its FT-QPI using method 2 
% Reshape Y_rec_each and FT_QPI_Y_rec_each to combine all kernels
Y_rec_show_Full = [];
qpi_Y_rec_show_Full = [];
for k = 1:num_kernels
    Y_rec_show_Full = [Y_rec_show_Full, squeeze(Y_rec_each(k,:,:,:))];
    qpi_Y_rec_show_Full = [qpi_Y_rec_show_Full, squeeze(FT_QPI_Y_rec_each(k,:,:,:))];
end

% Normalize each slice across all kernels
for i = 1:size(Y_rec_show_Full,3)
    Y_rec_show_Full(:,:,i) = mat2gray(Y_rec_show_Full(:,:,i));
    qpi_Y_rec_show_Full(:,:,i) = 1-mat2gray(qpi_Y_rec_show_Full(:,:,i),[0,1]);
end
%% Figure 3 - Phase space and examples of synthetic data 
% Layout: first row: panel a) b) being the activation combined metric and
% the kernel similarity metric of SNR =5. The colormap should be viridis
% and we plot contour of 0.95(in the color map, the map is 
% normalized to 0-1) on the activation combined, and then overlay that 
% countour onto panel b) indicating the working/failure region. 

%fig3_loaded = load('snr=3,5,7.mat');
metric_colormap = slanCM('viridis');
contour_levels =[0.95];
axis3_mode = 2;

metrics2heat_by_snr_interpolated(metrics, 'combined', axis3_mode, 1, metric_colormap, contour_levels);
% Overlay on your kernel plot for matching SNR index s:

metrics2heat_by_snr_interpolated(metrics, 'kernel', axis3_mode, 1, metric_colormap,contour_levels);

%% Plot figure 4 subplots 
%% Combine and preprocess Aout
% setting parameters
angle = 122.5741;
target_size =[245,245];
Y_xydim = size(Y, [1,2]);
radius = target_size(1)/2;
%%
% load chosen runs from user-selected folder and ordered index list
num_blocks_to_load = 3;
selected_filenames = chooseOrderedFilesFromFolder(num_blocks_to_load);
filename1 = selected_filenames{1};
filename2 = selected_filenames{2};
filename3 = selected_filenames{3};
myVars = {"Y_used","Aout_ALL","Xout_ALL","bout_ALL","ALL_extras","A1_used"};

data = struct();
data.block1 = load(filename1,myVars{:});
data.block2 = load(filename2,myVars{:});
data.block3 = load(filename3,myVars{:});

%% Merge Aout_ALL and A1_used from all blocks
[Aout, A1, param] = mergeAoutBlocksManualCutoff(data, selected_filenames);

% Use one shared observation volume (do not stitch observations).
if ~exist('Y', 'var') || isempty(Y)
    if exist('Y_used', 'var') && ~isempty(Y_used)
        Y = Y_used;
    elseif isfield(data.block1, 'Y_used') && ~isempty(data.block1.Y_used)
        Y = data.block1.Y_used;
    else
        error('Shared observation Y is unavailable. Please define Y or Y_used.');
    end
end

%% pad QPI
num_total_slices = size(Aout,3);
Aout_qpi_each = zeros([size(Aout,4),[Y_xydim,num_total_slices]]);
for i = 1:size(Aout,4)
    Aout_qpi_each(i,:,:,:) = qpiCalculate(Aout(:,:,:,i),size(Y,[1,2]));
end

%% Symmetrize the data
[Y_qpi_symm, Y_qpi_symm_45,tform0, angle]   = Symmetrizing2(squeeze(qpiCalculate(Y)),'',angle, 'default');
[A1_qpi_symm, A1_qpi_symm_45,tform1, angle] = Symmetrizing2(squeeze(Aout_qpi_each(1,:,:,:)),'',angle, 'default');
[A2_qpi_symm, A2_qpi_symm_45,tform2, angle] = Symmetrizing2(squeeze(Aout_qpi_each(2,:,:,:)),'',angle, 'default');
[A3_qpi_symm, A3_qpi_symm_45,tform1, angle] = Symmetrizing2(squeeze(Aout_qpi_each(3,:,:,:)),'',angle, 'default',true);
[A4_qpi_symm, A4_qpi_symm_45,tform1, angle] = Symmetrizing2(squeeze(Aout_qpi_each(4,:,:,:)),'',angle, 'default',true);
[A5_qpi_symm, A5_qpi_symm_45,tform1, angle] = Symmetrizing2(squeeze(Aout_qpi_each(5,:,:,:)),'',angle, 'default');

%% Crop symmetrized output to match QPI_rec x-y size

Y_qpi_cropped = centerCropToTargetSize(Y_qpi_symm_45, target_size);
A1_qpi_cropped = centerCropToTargetSize(A1_qpi_symm_45, target_size);
A2_qpi_cropped = centerCropToTargetSize(A2_qpi_symm_45, target_size);
A3_qpi_cropped = centerCropToTargetSize(A3_qpi_symm_45, target_size);
A4_qpi_cropped = centerCropToTargetSize(A4_qpi_symm_45, target_size);
A5_qpi_cropped = centerCropToTargetSize(A5_qpi_symm_45, target_size);

%% Compare A1,A2 and Y in q-space
Y_qpi_norm = normalizeForDisplay(Y_qpi_cropped);
A1_qpi_cropped_norm = normalizeForDisplay(A1_qpi_cropped);
A2_qpi_cropped_norm = normalizeForDisplay(A2_qpi_cropped);
A3_qpi_cropped_norm = normalizeForDisplay(A3_qpi_cropped);
A4_qpi_cropped_norm = normalizeForDisplay(A4_qpi_cropped);
A5_qpi_cropped_norm = normalizeForDisplay(A5_qpi_cropped);
comparison_qpi = [Y_qpi_norm, A1_qpi_cropped_norm, A2_qpi_cropped_norm, ...
    A3_qpi_cropped_norm, A4_qpi_cropped_norm, A5_qpi_cropped_norm];

% Package key outputs into a result struct and clear intermediates
result = struct();
result.Y = Y;
result.Aout = Aout;
result.Y_qpi = Y_qpi_cropped;
result.Aout_qpi = zeros([size(A1_qpi_cropped),5]);
result.Aout_qpi(:,:,:,1) = A1_qpi_cropped;
result.Aout_qpi(:,:,:,2) = A2_qpi_cropped;
result.Aout_qpi(:,:,:,3) = A3_qpi_cropped;
result.Aout_qpi(:,:,:,4) = A4_qpi_cropped;
result.Aout_qpi(:,:,:,5) = A5_qpi_cropped;
result.comparison_qpi = comparison_qpi;
%%
figure; d3gridDisplay(result.comparison_qpi, 'dynamic', -1)

%%
clear Aout_qpi_each ...
      Y_qpi_symm Y_qpi_symm_45 tform0 tform1 tform2 ...
      A1_qpi_symm A1_qpi_symm_45 ...
      A2_qpi_symm A2_qpi_symm_45 ...
      A3_qpi_symm A3_qpi_symm_45 ...
      A4_qpi_symm A4_qpi_symm_45 ...
      A5_qpi_symm A5_qpi_symm_45 ...
      Y_qpi_norm A1_qpi_cropped_norm A2_qpi_cropped_norm ...
      A3_qpi_cropped_norm A4_qpi_cropped_norm A5_qpi_cropped_norm ...
      Y_qpi_cropped A1_qpi_cropped A2_qpi_cropped A3_qpi_cropped A4_qpi_cropped A5_qpi_cropped comparison_qpi;

%% Inspect rotating slices of Aout
naked = true;
energy_range = [-800,800]; % range in meV
% Create rotational slices
[~, A1_slice_angles, ~] = rotationalslices(result.Aout_qpi(:,:,:,1), 'global', 1, radius, naked, energy_range);
[~, A2_slice_angles, ~] = rotationalslices(result.Aout_qpi(:,:,:,2), 'global', 1, radius, naked, energy_range);
%[~, A3_slice_angles, ~] = rotationalslices(result.Aout_qpi(:,:,:,3), 'global', 1, radius, naked, energy_range);
%[~, A4_slice_angles, ~] = rotationalslices(result.Aout_qpi(:,:,:,4), 'global', 1, radius, naked, energy_range);
%[~, A5_slice_angles, ~] = rotationalslices(result.Aout_qpi(:,:,:,5), 'global', 1, radius, naked, energy_range);

% Save all inputs needed by the Figure 5 block
fig5_inputs = struct();
fig5_inputs.result = result;
fig5_inputs.radius = radius;
fig5_inputs.naked = true;
fig5_inputs.nos = 8;
fig5_inputs.energy_range = [-800, 800];
fig5_inputs.target_energies = [280, 220, 164];
%fig5_save_path = fullfile(fileparts(mfilename('fullpath')), 'figure5_inputs.mat');
%save(fig5_save_path, 'fig5_inputs');

%% Figure 5 (need Aout)
% figure 5 contains subplots: 
% a) a verticle cut(180 degree) of the defect type 1(Zr) dispersion 
% b)-d) cuts on energy [280, 220, 164] meV of Aout of the defect type 1(Zr)
% with a clim of 99 percentile of the coverage. 
% Plot each panel in a separate figure.
naked = true; % Figure-5 handle: set false for full annotations
nos = 8;
energy_range = [-800,800]; % range in meV

% Resolve Aout for defect type 1 (robust to 3D/4D storage in result struct)
if ndims(result.Aout_qpi) >= 4
    Aout_type1 = result.Aout_qpi(:,:,:,1);
else
    Aout_type1 = result.Aout_qpi;
end

% Energy axis (meV) for indexing slices
energy_axis = linspace(energy_range(1), energy_range(2), size(Aout_type1,3));

% Build rotational slices once for defect type 1
[A1_rot2D, A1_angles, ~] = rotationalslices(Aout_type1, 'global', 1, radius, naked, energy_range);

% (a) Vertical cut at 180 degrees
[~, angle_idx_180] = min(abs(rad2deg(A1_angles) - 180));
dispersion_180 = clipAndNormalize(A1_rot2D(:,:,angle_idx_180)', nos);  % [energy x position]
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

% (b-d) Energy cuts at requested meV values
target_energies = [280, 220, 164];
for ii = 1:numel(target_energies)
    [~, eidx] = min(abs(energy_axis - target_energies(ii)));
    map_e = clipAndNormalize(Aout_type1(:,:,eidx), nos);

    figure('Name', sprintf('Figure 5%c - Type1 energy cut %.0f meV', char('a'+ii), target_energies(ii)));
    imagesc(map_e);
    axis image;
    colormap(invgray);
    caxis([0, 1]);
    if naked
        axis off;
    else
        title(sprintf('Type 1 (Zr): energy cut %.0f meV (actual %.1f meV)', target_energies(ii), energy_axis(eidx)));
        xlabel('q_x pixel');
        ylabel('q_y pixel');
    end
end

%% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Supplmentary Figures~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

%% SI -- Compare the SNR before and after MCSBD_synthetic data
if ~exist('build_denoising_sigma_metrics', 'file') || ~exist('metrics2heat_by_snr_interpolated', 'file')
    script_dir = fileparts(mfilename('fullpath'));
    addpath(fullfile(script_dir, '..', '..', '..', '..', 'Dong_func'));
    addpath(fullfile(script_dir, '..', '..', '..', '..', 'Dong_func', 'phase_space'));
end
if ~exist('metrics', 'var') || isempty(metrics)
    error('SI synthetic comparison requires ''metrics'' in workspace.');
end

si_axis3_mode = 2;
si_activation_gate = 0.95;
si_metric_colormap = slanCM('viridis');
si_snr_targets = [3, 5, 7];
si_font_default = 18; % default large font
si_font_size = input(sprintf('Font size for SI synthetic plots (default=%d): ', si_font_default));
if isempty(si_font_size)
    si_font_size = si_font_default;
end
si_font_size = double(si_font_size);
si_side_ratio_default = 0.2233;
si_side_ratio_max = input(sprintf(['Side-length-ratio cutoff for SI 1/sqrt(Nobs) scatter ' ...
    '(default=%.4f): '], si_side_ratio_default));
if isempty(si_side_ratio_max)
    si_side_ratio_max = si_side_ratio_default;
end
si_side_ratio_max = double(si_side_ratio_max);

% 1) sigma ratio heatmap style plot (per-SNR slices)
if ~isfield(metrics, 'denoising_sigma_ratio_final') || isempty(metrics.denoising_sigma_ratio_final) || ...
        ~isfield(metrics, 'denoising_sigma_ratio_per_kernel') || isempty(metrics.denoising_sigma_ratio_per_kernel)
    metrics = build_denoising_sigma_metrics(metrics, si_activation_gate, ...
        'enableAlignment', false, ...
        'energyStride', 2, ...
        'sigmaMethod', 'mad');
end
metrics2heat_by_snr_interpolated(metrics, 'denoising', si_axis3_mode, 1, si_metric_colormap);
set(findall(gcf, '-property', 'FontSize'), 'FontSize', si_font_size);

% 2) 1/sqrt(Nobs) vs sigma_out by side length ratio (<= 0.2233), per-kernel
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
                cnt(k) = nnz(X0_slot(:,:,k) ~= 0);
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
        fprintf('SI side-ratio cutoff %.4f selects %d subplot bins.\n', si_side_ratio_max, numel(side_sel));
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
                'Position', [120 120 430*ncol 360*nrow]);

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
                            x_by_kernel{kk}(end+1,1) = n_k(kk); %#ok<AGROW>
                            y_by_kernel{kk}(end+1,1) = d_k(kk); %#ok<AGROW>
                            s_by_kernel{kk}(end+1,1) = s_k(kk); %#ok<AGROW>
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
                        'MarkerFaceColor', cmap(kk,:), ...
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

%% Supplementary comparison between crop and Aout

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
function selected_paths = chooseOrderedFilesFromFolder(num_required)
    if nargin < 1
        num_required = 3;
    end

    folder_path = uigetdir(pwd, 'Select folder containing run result MAT files');
    if isequal(folder_path, 0)
        error('No folder selected.');
    end

    entries = dir(fullfile(folder_path, '*.mat'));
    if isempty(entries)
        error('Selected folder has no files: %s', folder_path);
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
