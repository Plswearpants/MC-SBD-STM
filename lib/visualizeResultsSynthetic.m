function [data, viz_info] = visualizeResultsSynthetic(data, params, varargin)
%VISUALIZERESULTSSYNTHETIC Visualize synthetic all-slice reconstruction results.
%
%   [data, viz_info] = visualizeResultsSynthetic(data, params, ...)
%
%   Inputs:
%       data    - Data struct containing:
%                 data.synGen.Y
%                 data.synGen.X0
%                 data.mcsbd_slice.A0_used (preferred GT kernels)
%                 data.mcsbd_block.A, .X, .b, .extras (all-slice outputs)
%       params  - Params struct (flat or hierarchical)
%
%   Name-value options:
%       'run_data'              - fallback all-slice result struct when
%                                 data.mcsbd_block is missing (default: [])
%       'use_ui'                - open interactive UI (default: false)
%       'visualize_all_slices'  - true: all slices, false: ref slice only (default: true)
%       'save_figures'          - save each slice figure as .fig (default: false)
%       'figure_dir'            - folder for saved figures (default: pwd)
%       'figure_prefix'         - filename prefix for saved figures (default: 'synthetic')
%
%   Outputs:
%       data                    - Updated data struct with data.synGen.Y_reconstruct
%       viz_info                - Struct with visualization metadata

    p = inputParser;
    addRequired(p, 'data', @isstruct);
    addRequired(p, 'params', @isstruct);
    addParameter(p, 'run_data', [], @(x) isempty(x) || isstruct(x) || iscell(x));
    addParameter(p, 'use_ui', false, @islogical);
    addParameter(p, 'visualize_all_slices', true, @islogical);
    addParameter(p, 'save_figures', false, @islogical);
    addParameter(p, 'figure_dir', pwd, @ischar);
    addParameter(p, 'figure_prefix', 'synthetic', @ischar);
    parse(p, data, params, varargin{:});

    run_data = p.Results.run_data;
    use_ui = p.Results.use_ui;
    visualize_all_slices = p.Results.visualize_all_slices;
    save_figures = p.Results.save_figures;
    figure_dir = p.Results.figure_dir;
    figure_prefix = p.Results.figure_prefix;

    % Use flat params view for scalar settings like num_slices/ref_slice.
    if isfield(params, 'synGen')
        params = organizeParams(params, 'extract');
    end

    % Validate required data fields.
    if ~isfield(data, 'synGen') || ~isfield(data.synGen, 'Y') || ~isfield(data.synGen, 'X0')
        error('data.synGen.Y and data.synGen.X0 are required.');
    end
    if ~isfield(data, 'mcsbd_block') || ~isstruct(data.mcsbd_block)
        if isempty(run_data)
            error(['All-slice outputs are required. Provide data.mcsbd_block ', ...
                'or pass ''run_data'' (for example allslice_results).']);
        end
        data.mcsbd_block = run_data;
    end
    if ~isfield(data, 'mcsbd_slice') || ~isfield(data.mcsbd_slice, 'A0_used')
        error('data.mcsbd_slice.A0_used is required for ground-truth comparison.');
    end
    if ~isfield(params, 'num_slices') || ~isfield(params, 'num_kernels') || ~isfield(params, 'ref_slice')
        error('params.num_slices, params.num_kernels, and params.ref_slice are required.');
    end

    run_set = resolveSyntheticRunSet(data.mcsbd_block);
    Y_reconstruct = nan(size(data.synGen.Y));
    saved_figures = {};
    slices_visualized = [];

    if use_ui
        fprintf('  Opening synthetic visualization UI...\n');
        [Y_reconstruct, saved_figures, slices_visualized] = runSyntheticVisualizationUI(...
            data, params, run_set, Y_reconstruct, save_figures, figure_dir, figure_prefix);
    else
        % Pick slices to visualize.
        if visualize_all_slices
            slices_to_viz = 1:params.num_slices;
        else
            slices_to_viz = params.ref_slice;
        end

        for s = slices_to_viz
            fprintf('  Visualizing slice %d/%d...\n', s, params.num_slices);
            [Y_reconstruct(:,:,s), saved_now] = renderSyntheticSelection(...
                data.synGen.Y(:,:,s), data.synGen.X0, data.mcsbd_slice.A0_used, ...
                run_set(1), s, 1, ...
                true, true, true, save_figures, figure_dir, figure_prefix);
            saved_figures = [saved_figures, saved_now]; %#ok<AGROW>
        end
        slices_visualized = slices_to_viz;
    end

    % Keep reconstructed observation in data for downstream analysis/saving.
    data.synGen.Y_reconstruct = Y_reconstruct;

    viz_info = struct();
    viz_info.slices_visualized = unique(slices_visualized);
    viz_info.num_parameter_sets = numel(run_set);
    viz_info.saved_figures = saved_figures;
end

function run_set = resolveSyntheticRunSet(mcsbd_block)
    if isstruct(mcsbd_block) && numel(mcsbd_block) > 1
        run_set = mcsbd_block;
    elseif iscell(mcsbd_block)
        run_set = [mcsbd_block{:}];
    else
        run_set = mcsbd_block;
    end

    required_block_fields = {'A', 'X', 'b', 'extras'};
    for p = 1:numel(run_set)
        for i = 1:numel(required_block_fields)
            if ~isfield(run_set(p), required_block_fields{i})
                error('mcsbd_block parameter set %d missing field: %s', p, required_block_fields{i});
            end
        end
    end
end

function [Y_reconstruct, saved_figures, slices_visualized] = runSyntheticVisualizationUI(...
    data, params, run_set, Y_reconstruct, save_figures, figure_dir, figure_prefix)

    saved_figures = {};
    slices_visualized = [];
    num_slices = params.num_slices;
    num_param_sets = numel(run_set);
    num_kernels = params.num_kernels;

    fig = uifigure('Name', 'Synthetic Visualization Dashboard', 'Position', [80 80 1400 860]);
    root = uigridlayout(fig, [1, 2]);
    root.ColumnWidth = {280, '1x'};
    root.RowHeight = {'1x'};
    root.ColumnSpacing = 10;
    root.Padding = [10 10 10 10];

    % Left-side controls
    ctrl = uipanel(root, 'Title', 'Controls');
    ctrl.Layout.Row = 1;
    ctrl.Layout.Column = 1;
    cgl = uigridlayout(ctrl, [14, 1]);
    cgl.RowHeight = {22, 22, 22, 22, 28, 22, 22, 22, 28, 28, 28, 28, '1x', 48};
    cgl.Padding = [8 8 8 8];
    cgl.RowSpacing = 6;

    uilabel(cgl, 'Text', 'Slice Number');
    ddSlice = uidropdown(cgl, ...
        'Items', arrayfun(@num2str, 1:num_slices, 'UniformOutput', false), ...
        'Value', num2str(params.ref_slice));

    uilabel(cgl, 'Text', 'Parameter Set Number');
    ddParam = uidropdown(cgl, ...
        'Items', arrayfun(@num2str, 1:num_param_sets, 'UniformOutput', false), ...
        'Value', '1');

    uilabel(cgl, 'Text', 'Kernel Number');
    ddKernel = uidropdown(cgl, ...
        'Items', arrayfun(@num2str, 1:num_kernels, 'UniformOutput', false), ...
        'Value', '1');

    uilabel(cgl, 'Text', 'Display Items');
    cbRecon = uicheckbox(cgl, 'Text', 'Original vs Reconstructed', 'Value', true);
    cbAct = uicheckbox(cgl, 'Text', 'Activation Similarity Analysis', 'Value', true);
    cbQPI = uicheckbox(cgl, 'Text', 'Kernel QPI Analysis', 'Value', true);

    btnRefresh = uibutton(cgl, 'Text', 'Update Dashboard');
    btnSave = uibutton(cgl, 'Text', 'Save Snapshot');
    btnClose = uibutton(cgl, 'Text', 'Done');
    lblStatus = uilabel(cgl, 'Text', 'Ready', 'WordWrap', 'on');
    lblStatus.Layout.Row = [13, 14];

    % Right-side dashboard tabs
    tabs = uitabgroup(root);
    tabs.Layout.Row = 1;
    tabs.Layout.Column = 2;

    tabRecon = uitab(tabs, 'Title', 'Reconstruction');
    tabAct = uitab(tabs, 'Title', 'Activation');
    tabQPI = uitab(tabs, 'Title', 'Kernel QPI');

    reconGrid = uigridlayout(tabRecon, [2, 2]);
    reconGrid.RowHeight = {'1x', '1x'};
    reconGrid.ColumnWidth = {'1x', '1x'};
    axOrig = uiaxes(reconGrid);
    axRecon = uiaxes(reconGrid);
    axResidual = uiaxes(reconGrid);
    txtRecon = uitextarea(reconGrid, 'Editable', 'off', 'Value', {'Reconstruction metrics'});

    actGrid = uigridlayout(tabAct, [2, 2]);
    actGrid.RowHeight = {'1x', '1x'};
    actGrid.ColumnWidth = {'1x', '1x'};
    axActX0 = uiaxes(actGrid);
    axActXout = uiaxes(actGrid);
    axActDiff = uiaxes(actGrid);
    txtAct = uitextarea(actGrid, 'Editable', 'off', 'Value', {'Activation metrics'});

    qpiGrid = uigridlayout(tabQPI, [2, 2]);
    qpiGrid.RowHeight = {'1x', '1x'};
    qpiGrid.ColumnWidth = {'1x', '1x'};
    axQpiOutKernel = uiaxes(qpiGrid);
    axQpiGtKernel = uiaxes(qpiGrid);
    axQpiOut = uiaxes(qpiGrid);
    axQpiGt = uiaxes(qpiGrid);

    btnRefresh.ButtonPushedFcn = @(~,~) refreshDashboard();
    ddSlice.ValueChangedFcn = @(~,~) refreshDashboard();
    ddParam.ValueChangedFcn = @(~,~) refreshDashboard();
    ddKernel.ValueChangedFcn = @(~,~) refreshDashboard();
    cbRecon.ValueChangedFcn = @(~,~) refreshDashboard();
    cbAct.ValueChangedFcn = @(~,~) refreshDashboard();
    cbQPI.ValueChangedFcn = @(~,~) refreshDashboard();
    btnSave.ButtonPushedFcn = @(~,~) saveSnapshot();
    btnClose.ButtonPushedFcn = @(~,~) closeUI();

    refreshDashboard();
    uiwait(fig);

    function refreshDashboard()
        slice_idx = str2double(ddSlice.Value);
        param_idx = str2double(ddParam.Value);
        kernel_idx = str2double(ddKernel.Value);
        run_data = run_set(param_idx);

        Y_slice = data.synGen.Y(:,:,slice_idx);
        X0 = data.synGen.X0;
        Xout = run_data.X;
        A0_slice = extractSliceKernels(data.mcsbd_slice.A0_used, slice_idx, num_kernels);
        Aout_slice = extractSliceKernels(run_data.A, slice_idx, num_kernels);
        bout_slice = run_data.b(slice_idx,:);

        kernel_size = zeros(num_kernels, 2);
        for kk = 1:num_kernels
            kernel_size(kk,:) = size(A0_slice{kk});
        end

        [Xout_aligned, offsets, align_quality] = alignActivationMaps(X0, Xout, kernel_size);
        [similarities, filtered_maps] = computeActivationSimilarity(...
            X0, Xout_aligned, kernel_size, false, [slice_idx, param_idx]);

        Y_slice_recon = zeros(size(Y_slice));
        for kk = 1:num_kernels
            Y_slice_recon = Y_slice_recon + convfft2(Aout_slice{kk}, Xout_aligned(:,:,kk));
            Y_slice_recon = Y_slice_recon + bout_slice(kk);
        end
        Y_reconstruct(:,:,slice_idx) = Y_slice_recon;
        if ~ismember(slice_idx, slices_visualized)
            slices_visualized(end+1) = slice_idx; %#ok<AGROW>
        end

        if cbRecon.Value
            imagesc(axOrig, Y_slice); axis(axOrig, 'image'); colorbar(axOrig); colormap(axOrig, gray);
            title(axOrig, sprintf('Original (Slice %d)', slice_idx));
            imagesc(axRecon, Y_slice_recon); axis(axRecon, 'image'); colorbar(axRecon); colormap(axRecon, gray);
            title(axRecon, sprintf('Reconstructed (Param %d)', param_idx));
            residual = Y_slice - Y_slice_recon;
            imagesc(axResidual, residual); axis(axResidual, 'image'); colorbar(axResidual);
            title(axResidual, 'Residual (Original - Reconstructed)');
            recon_mse = mean(residual(:).^2);
            recon_rmse = sqrt(recon_mse);
            txtRecon.Value = {
                sprintf('Slice: %d', slice_idx)
                sprintf('Parameter set: %d', param_idx)
                sprintf('MSE: %.6g', recon_mse)
                sprintf('RMSE: %.6g', recon_rmse)
                sprintf('Mean residual: %.6g', mean(residual(:)))
            };
        else
            cla(axOrig); cla(axRecon); cla(axResidual);
            title(axOrig, 'Disabled');
            title(axRecon, 'Disabled');
            title(axResidual, 'Disabled');
            txtRecon.Value = {'Reconstruction panel disabled.'};
        end

        if cbAct.Value
            imagesc(axActX0, filtered_maps(kernel_idx).X0); axis(axActX0, 'image'); colorbar(axActX0);
            title(axActX0, sprintf('K%d Filtered X0', kernel_idx));
            imagesc(axActXout, filtered_maps(kernel_idx).Xout); axis(axActXout, 'image'); colorbar(axActXout);
            title(axActXout, sprintf('K%d Filtered Xout', kernel_idx));
            imagesc(axActDiff, filtered_maps(kernel_idx).X0 - filtered_maps(kernel_idx).Xout);
            axis(axActDiff, 'image'); colorbar(axActDiff);
            title(axActDiff, sprintf('K%d Diff', kernel_idx));
            txtAct.Value = {
                sprintf('Kernel: %d', kernel_idx)
                sprintf('Similarity: %.4f', similarities(kernel_idx))
                sprintf('Offset: [%d, %d]', offsets(kernel_idx,1), offsets(kernel_idx,2))
                sprintf('Alignment peak: %.4f', align_quality(kernel_idx).primary_peak)
                sprintf('sigma: %.4f', filtered_maps(kernel_idx).sigma)
                sprintf('density: %.4g', filtered_maps(kernel_idx).density)
            };
        else
            cla(axActX0); cla(axActXout); cla(axActDiff);
            title(axActX0, 'Disabled');
            title(axActXout, 'Disabled');
            title(axActDiff, 'Disabled');
            txtAct.Value = {'Activation panel disabled.'};
        end

        if cbQPI.Value
            [qpi_score, qpi_out, qpi_gt] = kernel_QPI_metric(Aout_slice{kernel_idx}, A0_slice{kernel_idx});
            imagesc(axQpiOutKernel, Aout_slice{kernel_idx}); axis(axQpiOutKernel, 'image'); colorbar(axQpiOutKernel);
            title(axQpiOutKernel, sprintf('Output Kernel K%d', kernel_idx));
            imagesc(axQpiGtKernel, A0_slice{kernel_idx}); axis(axQpiGtKernel, 'image'); colorbar(axQpiGtKernel);
            title(axQpiGtKernel, sprintf('GT Kernel K%d', kernel_idx));
            imagesc(axQpiOut, log(qpi_out + 1)); axis(axQpiOut, 'image'); colorbar(axQpiOut);
            title(axQpiOut, sprintf('Output QPI K%d', kernel_idx));
            imagesc(axQpiGt, log(qpi_gt + 1)); axis(axQpiGt, 'image'); colorbar(axQpiGt);
            title(axQpiGt, sprintf('GT QPI K%d', kernel_idx));
            lblStatus.Text = sprintf('Updated: Slice %d | Param %d | Kernel %d | QPI Score %.4f', ...
                slice_idx, param_idx, kernel_idx, qpi_score);
        else
            cla(axQpiOutKernel); cla(axQpiGtKernel); cla(axQpiOut); cla(axQpiGt);
            title(axQpiOutKernel, 'Disabled');
            title(axQpiGtKernel, 'Disabled');
            title(axQpiOut, 'Disabled');
            title(axQpiGt, 'Disabled');
            lblStatus.Text = sprintf('Updated: Slice %d | Param %d | Kernel %d', ...
                slice_idx, param_idx, kernel_idx);
        end
        drawnow;
    end

    function saveSnapshot()
        if ~save_figures
            lblStatus.Text = 'Save disabled (set save_figures=true in VR01A).';
            return;
        end
        slice_idx = str2double(ddSlice.Value);
        param_idx = str2double(ddParam.Value);
        file_name = sprintf('%s_slice%02d_param%02d_dashboard.png', ...
            figure_prefix, slice_idx, param_idx);
        file_path = fullfile(figure_dir, file_name);
        if exist('exportapp', 'file') == 2
            exportapp(fig, file_path);
        else
            exportgraphics(fig, file_path);
        end
        saved_figures{end+1} = file_path; %#ok<AGROW>
        lblStatus.Text = sprintf('Saved snapshot: %s', file_name);
    end

    function closeUI()
        uiresume(fig);
        if isvalid(fig)
            delete(fig);
        end
    end
end

function [Y_slice_reconstruct, saved_figures] = renderSyntheticSelection(...
    Y_slice, X0, A0_used, run_data, slice_idx, param_idx, ...
    show_reconstruction, show_activation_similarity, show_kernel_qpi, ...
    save_figures, figure_dir, figure_prefix)

    num_kernels = size(X0, 3);
    saved_figures = {};
    Y_slice_reconstruct = zeros(size(Y_slice));

    A0_slice = extractSliceKernels(A0_used, slice_idx, num_kernels);
    Aout_slice = extractSliceKernels(run_data.A, slice_idx, num_kernels);
    bout_slice = run_data.b(slice_idx,:);
    Xout = run_data.X;

    kernel_size = zeros(num_kernels, 2);
    for k = 1:num_kernels
        kernel_size(k,:) = size(A0_slice{k});
    end

    [activation_metrics, aligned_maps] = evaluateActivationReconstruction(...
        X0, Xout, kernel_size, show_activation_similarity, [slice_idx, param_idx]);

    for k = 1:num_kernels
        Y_slice_reconstruct = Y_slice_reconstruct + convfft2(Aout_slice{k}, aligned_maps.Xout_aligned(:,:,k));
        Y_slice_reconstruct = Y_slice_reconstruct + bout_slice(k);
    end

    if show_reconstruction
        figure('Name', sprintf('Original vs Reconstructed (Slice %d, Param %d)', slice_idx, param_idx));
        subplot(1,2,1);
        imagesc(Y_slice);
        axis image;
        colorbar;
        title('Original Image');
        colormap(gray);

        subplot(1,2,2);
        imagesc(Y_slice_reconstruct);
        axis image;
        colorbar;
        title('Reconstructed Image');
        colormap(gray);
        sgtitle(sprintf('Slice %d, Parameter Set %d', slice_idx, param_idx));
        saved_figures = saveMaybe(saved_figures, save_figures, figure_dir, ...
            sprintf('%s_slice%02d_param%02d_reconstruction.fig', figure_prefix, slice_idx, param_idx));
    end

    if show_activation_similarity
        fprintf('\nActivation Reconstruction Metrics (Slice %d, Param %d):\n', slice_idx, param_idx);
        for k = 1:num_kernels
            fprintf('Kernel %d: Similarity %.4f, Offset [%d, %d], Align %.4f\n', ...
                k, activation_metrics.similarity(k), ...
                activation_metrics.offset(k,1), activation_metrics.offset(k,2), ...
                activation_metrics.alignment(k).primary_peak);
        end
        saved_figures = saveMaybe(saved_figures, save_figures, figure_dir, ...
            sprintf('%s_slice%02d_param%02d_activation.fig', figure_prefix, slice_idx, param_idx));
    end

    if show_kernel_qpi
        quality_factors = evaluateKernelQuality(Aout_slice, A0_slice, true, [slice_idx, param_idx]);
        fprintf('\nKernel QPI Quality (Slice %d, Param %d):\n', slice_idx, param_idx);
        for k = 1:num_kernels
            fprintf('Kernel %d: %.4f\n', k, quality_factors(k));
        end
        saved_figures = saveMaybe(saved_figures, save_figures, figure_dir, ...
            sprintf('%s_slice%02d_param%02d_qpi.fig', figure_prefix, slice_idx, param_idx));
    end
end

function kernels = extractSliceKernels(kernel_container, slice_idx, num_kernels)
    kernels = cell(1, num_kernels);
    for k = 1:num_kernels
        if iscell(kernel_container) && isvector(kernel_container)
            kernels{k} = kernel_container{k}(:,:,slice_idx);
        elseif iscell(kernel_container)
            kernels{k} = kernel_container{slice_idx,k};
        else
            error('Kernel container must be a cell array.');
        end
    end
end

function saved_figures = saveMaybe(saved_figures, save_figures_flag, figure_dir, fig_name)
    if ~save_figures_flag
        return;
    end
    fig_path = fullfile(figure_dir, fig_name);
    savefig(gcf, fig_path);
    saved_figures{end+1} = fig_path; %#ok<AGROW>
end
