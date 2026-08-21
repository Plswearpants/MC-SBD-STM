function summary = visualizeSigmaFitGoodness(input_metrics, varargin)
%VISUALIZESIGMAFITGOODNESS Visualize fit-quality diagnostics for sigma trust.
%   summary = visualizeSigmaFitGoodness(input_metrics, ...)
%
% Accepted input:
%   1) details struct from estimateKernelGaussianNoiseVsGT (fields .in/.out)
%   2) parent struct containing .kernel_sigma_details
%
% Name-value options:
%   'side'          : 'in' | 'out' | 'both' (default 'both')
%   'chi2PMin'      : minimum acceptable p-value for chi-square GOF (default 0.05)
%   'mreMax'        : maximum acceptable MRE (default 0.25)
%   'rmseQuantile'  : RMSE quantile used as threshold in (0,1], default 0.8
%   'showHist'      : show histogram panel (default true)
%   'showHeatmaps'  : show heatmap panel (default true)
%
% Output:
%   summary: struct with per-side pass masks and aggregate confidence stats.

    opts = parse_options(varargin{:});
    details = resolve_details_struct(input_metrics);
    sides = resolve_sides(opts.side);

    summary = struct();
    summary.options = opts;
    summary.energy_indices = getfield_if_exists(details, 'energy_indices', []); %#ok<GFLD>

    for i = 1:numel(sides)
        side_name = sides{i};
        if ~isfield(details, side_name)
            warning('visualizeSigmaFitGoodness:MissingSide', ...
                'details.%s is missing; skipping side.', side_name);
            continue;
        end
        side_data = details.(side_name);
        side_summary = compute_side_summary(side_data, opts);
        summary.(side_name) = side_summary;
        visualize_side(side_summary, side_name, opts);
    end

    print_text_summary(summary, sides);
end

function opts = parse_options(varargin)
    p = inputParser;
    p.FunctionName = 'visualizeSigmaFitGoodness';
    addParameter(p, 'side', 'both', @(x) ischar(x) || isstring(x));
    addParameter(p, 'chi2PMin', 0.05, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0 && x <= 1);
    addParameter(p, 'mreMax', 0.25, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
    addParameter(p, 'rmseQuantile', 0.8, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0 && x <= 1);
    addParameter(p, 'showHist', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'showHeatmaps', true, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    opts = p.Results;
    opts.side = lower(string(opts.side));
end

function details = resolve_details_struct(input_metrics)
    if isstruct(input_metrics) && isfield(input_metrics, 'in') && isfield(input_metrics, 'out')
        details = input_metrics;
        return;
    end
    if isstruct(input_metrics) && isfield(input_metrics, 'kernel_sigma_details')
        details = input_metrics.kernel_sigma_details;
        if isstruct(details) && isfield(details, 'in') && isfield(details, 'out')
            return;
        end
    end
    error(['Input must be sigma details from estimateKernelGaussianNoiseVsGT ' ...
        'or a struct containing field kernel_sigma_details with .in/.out.']);
end

function sides = resolve_sides(side_opt)
    switch char(side_opt)
        case 'in'
            sides = {'in'};
        case 'out'
            sides = {'out'};
        case 'both'
            sides = {'in', 'out'};
        otherwise
            error('side must be ''in'', ''out'', or ''both''.');
    end
end

function side_summary = compute_side_summary(side_data, opts)
    required = {'mre', 'rmse', 'sigma'};
    for i = 1:numel(required)
        if ~isfield(side_data, required{i})
            error('Missing field side_data.%s for fit-quality visualization.', required{i});
        end
    end

    required_gauss = {'gauss_r2', 'gauss_chi2', 'gauss_pvalue', 'gauss_dof'};
    for i = 1:numel(required_gauss)
        if ~isfield(side_data, required_gauss{i})
            error('Missing side_data.%s for Gaussian fit-quality visualization.', required_gauss{i});
        end
    end
    r2 = double(side_data.gauss_r2);
    chi2 = double(side_data.gauss_chi2);
    pval = double(side_data.gauss_pvalue);
    dof = double(side_data.gauss_dof);
    mre = double(side_data.mre);
    rmse = double(side_data.rmse);
    sigma = double(side_data.sigma);

    rmse_valid = rmse(isfinite(rmse));
    if isempty(rmse_valid)
        rmse_thr = NaN;
    else
        rmse_thr = quantile(rmse_valid, opts.rmseQuantile);
    end

    pass_chi2 = isfinite(pval) & (pval >= opts.chi2PMin);
    pass_mre = isfinite(mre) & (mre <= opts.mreMax);
    pass_rmse = isfinite(rmse) & isfinite(rmse_thr) & (rmse <= rmse_thr);
    pass_all = pass_chi2 & pass_mre & pass_rmse & isfinite(sigma);

    side_summary = struct();
    side_summary.r2 = r2;
    side_summary.chi2 = chi2;
    side_summary.pvalue = pval;
    side_summary.dof = dof;
    side_summary.mre = mre;
    side_summary.rmse = rmse;
    side_summary.sigma = sigma;
    side_summary.pass_chi2 = pass_chi2;
    side_summary.pass_mre = pass_mre;
    side_summary.pass_rmse = pass_rmse;
    side_summary.pass_all = pass_all;
    side_summary.thresholds = struct( ...
        'chi2PMin', opts.chi2PMin, ...
        'mreMax', opts.mreMax, ...
        'rmseMax', rmse_thr, ...
        'rmseQuantile', opts.rmseQuantile);

    side_summary.pass_rate = mean(pass_all(:), 'omitnan');
    side_summary.sigma_median_all = median(sigma(:), 'omitnan');
    side_summary.sigma_median_pass = median(sigma(pass_all), 'omitnan');
    side_summary.r2_median = median(r2(:), 'omitnan');
    side_summary.chi2_median = median(chi2(:), 'omitnan');
    side_summary.pvalue_median = median(pval(:), 'omitnan');
    side_summary.mre_median = median(mre(:), 'omitnan');
    side_summary.rmse_median = median(rmse(:), 'omitnan');
end

function visualize_side(side_summary, side_name, opts)
    if ~(opts.showHeatmaps || opts.showHist)
        return;
    end

    n_tiles = 0;
    if opts.showHeatmaps
        n_tiles = n_tiles + 6;
    end
    if opts.showHist
        n_tiles = n_tiles + 1;
    end

    figure('Name', sprintf('Sigma Fit Quality (%s)', side_name), ...
        'Position', [120 120 max(1150, 260*n_tiles) 560]);
    t = tiledlayout(1, n_tiles, 'TileSpacing', 'compact', 'Padding', 'compact');

    if opts.showHeatmaps
        nexttile;
        imagesc(side_summary.chi2);
        axis image;
        colorbar;
        title('Gaussian \chi^2');
        xlabel('Energy index');
        ylabel('Kernel index');

        nexttile;
        imagesc(side_summary.pvalue, [0 1]);
        axis image;
        colorbar;
        title('Gaussian p-value');
        xlabel('Energy index');
        ylabel('Kernel index');

        nexttile;
        imagesc(side_summary.r2, [0 1]);
        axis image;
        colorbar;
        title('QQ-linearity R^2');
        xlabel('Energy index');
        ylabel('Kernel index');

        nexttile;
        imagesc(side_summary.mre);
        axis image;
        colorbar;
        title('MRE');
        xlabel('Energy index');
        ylabel('Kernel index');

        nexttile;
        imagesc(side_summary.rmse);
        axis image;
        colorbar;
        title('RMSE');
        xlabel('Energy index');
        ylabel('Kernel index');

        nexttile;
        imagesc(double(side_summary.pass_all), [0, 1]);
        axis image;
        colormap(gca, [0.85 0.2 0.2; 0.2 0.7 0.2]);
        colorbar('Ticks', [0, 1], 'TickLabels', {'fail', 'pass'});
        title('Confidence mask');
        xlabel('Energy index');
        ylabel('Kernel index');
    end

    if opts.showHist
        nexttile;
        sigma_all = side_summary.sigma(isfinite(side_summary.sigma));
        sigma_pass = side_summary.sigma(side_summary.pass_all);
        if ~isempty(sigma_all)
            histogram(sigma_all, 28, 'FaceColor', [0.6 0.65 0.8], 'EdgeColor', 'none', ...
                'DisplayName', 'all');
            hold on;
        end
        if ~isempty(sigma_pass)
            histogram(sigma_pass, 24, 'FaceColor', [0.2 0.7 0.35], 'EdgeColor', 'none', ...
                'FaceAlpha', 0.7, 'DisplayName', 'pass');
        end
        hold off;
        grid on;
        xlabel('\sigma');
        ylabel('count');
        title('\sigma distribution');
        legend('Location', 'best');
    end

    sgtitle(sprintf('%s fit quality | pass rate %.1f%% | p>=%.2f, MRE<=%.2f, RMSE<=Q%.0f', ...
        upper(side_name), ...
        100 * side_summary.pass_rate, ...
        side_summary.thresholds.chi2PMin, ...
        side_summary.thresholds.mreMax, ...
        100 * side_summary.thresholds.rmseQuantile));
end

function print_text_summary(summary, sides)
    fprintf('\nSigma fit-quality summary:\n');
    for i = 1:numel(sides)
        s = sides{i};
        if ~isfield(summary, s)
            continue;
        end
        d = summary.(s);
        fprintf('  [%s] pass %.1f%% | median chi^2=%.4g, p=%.4g, QQ-R^2=%.4g\n', ...
            upper(s), 100*d.pass_rate, d.chi2_median, d.pvalue_median, d.r2_median);
        fprintf('       median MRE=%.4g, RMSE=%.4g | sigma(all)=%.4g, sigma(pass)=%.4g, RMSE_thr(Q%.0f)=%.4g\n', ...
            d.mre_median, d.rmse_median, ...
            d.sigma_median_all, d.sigma_median_pass, ...
            100*d.thresholds.rmseQuantile, d.thresholds.rmseMax);
    end
end

function value = getfield_if_exists(s, name, fallback)
    if isstruct(s) && isfield(s, name)
        value = s.(name);
    else
        value = fallback;
    end
end
