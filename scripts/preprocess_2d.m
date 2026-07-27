%% 2D preprocessing pipeline (derived from scripts/preprocess.m)
%
% Assumption:
%   - `data_carried` already exists in the workspace as a 2D numeric matrix.
%
% Functional mapping from preprocess.m:
%   2.1 Remove Bragg peaks
%   2.2 Crop dataset
%   2.3 Local streak removal (single reference)
%   2.4 Interpolation of local streak pixels
%   2.5 Defect masking
%   2.6a Correct streaks
%   2.6b Heal streaks
%   2.6c Directional plane step omitted (3D-oriented workflow)
%   2.end Normalize background and save

%% Validate inputs and initialize
if ~exist('data_carried', 'var')
    error('preprocess_2d:MissingInput', ...
        'Expected 2D dataset variable `data_carried` in workspace.');
end
if ~isnumeric(data_carried) || ndims(data_carried) ~= 2
    error('preprocess_2d:InvalidInput', ...
        '`data_carried` must be a 2D numeric matrix.');
end

data_original = data_carried;
preprocessing_params = struct();
rangetype = 'dynamic'; %#ok<NASGU> kept for compatibility with existing helpers
preprocessing_params.slice_normalize = 1;

figure('Name', 'Input 2D Dataset');
imagesc(data_carried);
axis image;
colormap gray;
colorbar;
title('2D input dataset');

%% 2.1: Remove Bragg peaks (2D interactive, no d3gridDisplay)
[data_carried, preprocessing_params.normalize_region] = normalize2D(data_carried, []);
[data_braggremoved, bragg_mask2d, bragg_recipe] = removeBragg2D(data_carried);
data_carried = data_braggremoved;
preprocessing_params.bragg = struct('mask2d', bragg_mask2d, 'recipe', bragg_recipe);

%% 2.2: Crop dataset
mask = maskSquare(data_carried, 0, 1, 'square');
[data_cropped, ~] = gridCropMask(data_carried, mask);
data_carried = data_cropped;

%% 2.3: Local streak removal using single reference slice workflow
data3d = asSingleSlice3D(data_carried);
streak_mode = 'valley';
max_streak_width = 3;
[data_after_streak, streak_mask, streak_min_value] = removeLocalStreaks( ...
    data3d, 1, [], max_streak_width, streak_mode, false);
data_carried = squeeze(data_after_streak);
preprocessing_params.streak_params = struct( ...
    'nSlices', 1, ...
    'ref_idx', 1, ...
    'max_streak_width', max_streak_width, ...
    'mode', streak_mode, ...
    'min_value', streak_min_value, ...
    'streak_mask', streak_mask);

%% 2.4: Interpolation using single reference slice workflow
[data_after_interp, interp_mask, streak_indices, interp_min_value] = interpolateLocalStreaks( ...
    asSingleSlice3D(data_carried), 1, [], [], false);
data_carried = squeeze(data_after_interp);
preprocessing_params.interp_params = struct( ...
    'nSlices', 1, ...
    'ref_idx', 1, ...
    'min_value', interp_min_value, ...
    'interp_mask', interp_mask, ...
    'streak_indices', streak_indices);

%% 2.5: Defect masking
[data_carried, preprocessing_params.normalize_region] = normalize2D(data_carried, preprocessing_params.normalize_region);

figure('Name', 'Defect mask slice (2D)');
imagesc(data_carried);
axis image;
colormap gray;
colorbar;
title('Defect masking reference (single 2D slice)');

preprocessing_params.defect_slice = 1;
preprocessing_params.num_defect_type = input('Enter how many defect types to mask: ');
preprocessing_params.defect_masking_method = 'tg';

switch preprocessing_params.defect_masking_method
    case 'gw'
        [data_masked_3d, ~] = defect_masking(asSingleSlice3D(data_carried), 1);
    case 'tg'
        [data_masked_3d, preprocessing_params.defect_mask2, defect_centers2, sigmas2] = ...
            gaussianMaskDefects(asSingleSlice3D(data_carried), ...
                preprocessing_params.defect_slice, preprocessing_params.num_defect_type); %#ok<ASGLU>
    case 'threshold'
        [data_masked_3d, defect_mask] = thresholdDefects(asSingleSlice3D(data_carried), 1); %#ok<ASGLU>
    otherwise
        error('Unknown defect masking method. Choose "gw", "tg", or "threshold".');
end
data_masked = squeeze(data_masked_3d);
data_carried = data_masked;

%% 2.6a: Correct streak
[data_carried, preprocessing_params.normalize_region] = normalize2D(data_carried, preprocessing_params.normalize_region);
[data_streakremoved_3d, QPI_nostreaks] = RemoveStreaks(asSingleSlice3D(data_carried), 'Direction', 'vertical'); %#ok<ASGLU>
data_streakremoved = squeeze(data_streakremoved_3d);
data_carried = data_streakremoved;

%% 2.6b: Heal
[data_carried, preprocessing_params.normalize_region] = normalize2D(data_carried, preprocessing_params.normalize_region);
preprocessing_params.heal_direction = input('Enter direction to heal (horizontal/vertical/none): ', 's');
data_streakremoved_healed = heal_streaks(asSingleSlice3D(data_carried), preprocessing_params.heal_direction);
data_carried = squeeze(data_streakremoved_healed);

%% 2.6c: Directional plane (omitted for 2D-only workflow)
% Intentionally omitted: d3plane_directional is part of 3D workflow.

%% 2.end: Normalize background
[Y, preprocessing_params.normalize_region] = normalize2D(data_carried, preprocessing_params.normalize_region);

%% 3: Save the preprocessed data
save('preprocessed_2d.mat', ...
    'data_original', 'Y', 'data_cropped', 'data_masked', 'data_streakremoved', 'preprocessing_params');

%% ------------------------ Local helper functions ------------------------
function data3d = asSingleSlice3D(data2d)
    data3d = reshape(data2d, size(data2d, 1), size(data2d, 2), 1);
end

function [data2d_norm, region] = normalize2D(data2d, region)
    if nargin < 2 || isempty(region)
        [tmp3d, ~, ~, region] = normalizeBackgroundToZeroMean3D(asSingleSlice3D(data2d), 'dynamic', 1);
    else
        [tmp3d, ~, ~, region] = normalizeBackgroundToZeroMean3D(asSingleSlice3D(data2d), 'dynamic', 1, region);
    end
    data2d_norm = squeeze(tmp3d);
end

function [Y_removed, mask2d, recipe] = removeBragg2D(Y)
    if ndims(Y) ~= 2
        error('removeBragg2D expects a 2D matrix.');
    end

    QPI = fftshift(fft2(Y));
    QPI_logabs = abs(QPI);

    figure('Name', 'Bragg removal - 2D');
    imagesc(QPI_logabs);
    axis image;
    colormap hot;
    colorbar;
    title('Select Bragg peaks to apply Gaussian window');

    num_peaks = input('Enter the number of unique Bragg peaks to process: ');
    removal_method = input('Choose removal method (1 Gaussian window, 2 complete removal): ');

    [rows, cols] = size(QPI);
    center_row = floor(rows / 2) + 1;
    center_col = floor(cols / 2) + 1;
    [X_grid, Y_grid] = meshgrid(1:cols, 1:rows);
    mask = ones(rows, cols);

    for i = 1:num_peaks
        disp(['Select Bragg peak #', num2str(i), ' with elliptical ROI']);
        h = drawellipse('Color', 'b');
        wait(h);

        center = h.Center;
        semi_axes = h.SemiAxes;
        rotation = h.RotationAngle;

        theta = deg2rad(rotation);

        X_rot = (X_grid - center(1)) * cos(theta) + (Y_grid - center(2)) * sin(theta);
        Y_rot = -(X_grid - center(1)) * sin(theta) + (Y_grid - center(2)) * cos(theta);
        ellipse_mask = (X_rot.^2 / semi_axes(1)^2 + Y_rot.^2 / semi_axes(2)^2) <= 1;

        sym_center = [2 * center_col - center(1), 2 * center_row - center(2)];
        X_sym_rot = (X_grid - sym_center(1)) * cos(theta) + (Y_grid - sym_center(2)) * sin(theta);
        Y_sym_rot = -(X_grid - sym_center(1)) * sin(theta) + (Y_grid - sym_center(2)) * cos(theta);
        sym_ellipse_mask = (X_sym_rot.^2 / semi_axes(1)^2 + Y_sym_rot.^2 / semi_axes(2)^2) <= 1;

        if removal_method == 1
            sigma_x = semi_axes(1);
            sigma_y = semi_axes(2);
            gaussian_window = exp(-(X_rot.^2 / (2 * sigma_x^2) + Y_rot.^2 / (2 * sigma_y^2)));
            peak_mask = 1 - gaussian_window .* ellipse_mask;

            sym_gaussian_window = exp(-(X_sym_rot.^2 / (2 * sigma_x^2) + Y_sym_rot.^2 / (2 * sigma_y^2)));
            sym_peak_mask = 1 - sym_gaussian_window .* sym_ellipse_mask;
        else
            peak_mask = 1 - ellipse_mask;
            sym_peak_mask = 1 - sym_ellipse_mask;
        end

        mask = mask .* peak_mask .* sym_peak_mask;
        delete(h);
    end
    close;

    QPI_removed = QPI .* mask;
    Y_removed = real(ifft2(ifftshift(QPI_removed)));
    mask2d = mask;
    recipe = struct('slice', 1, 'num_peaks', num_peaks, 'removal_method', removal_method);

    figure('Name', 'Bragg removal result - 2D');
    subplot(2,2,1); imagesc(Y); axis image; title('Original Image');
    subplot(2,2,2); imagesc(log(abs(QPI) + 1)); axis image; title('Original FFT');
    subplot(2,2,3); imagesc(Y_removed); axis image; title('Filtered Image');
    subplot(2,2,4); imagesc(log(abs(QPI_removed) + 1)); axis image; title('Filtered FFT');
end
