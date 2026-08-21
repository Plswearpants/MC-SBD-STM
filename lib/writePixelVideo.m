function outFile = writePixelVideo(data, V, varargin)
%WRITEPIXELVIDEO  Pixel-to-pixel stack movie with energy labels.
%
%   outFile = writePixelVideo(data, V)
%   outFile = writePixelVideo(data, V, outFile)
%   outFile = writePixelVideo(..., Name, Value)
%
%   Writes a video along the 3rd dimension of DATA. Each array pixel is
%   copied 1:1 into the frame (optional integer nearest-neighbor scale).
%   Frames are assembled as RGB arrays and passed to VideoWriter â€” no
%   figure capture, so the movie is not resampled by the display.
%
%   A 10-pixel margin is added on every side and the frame keeps the
%   aspect ratio of the data (see MatchAspect). Each frame is stamped
%   with the corresponding energy from V.
%
%   Optional panel labels: treat the frame as an nRow-by-nCol grid of
%   square channels and draw a static caption in each panel.
%
% Inputs
%   data     [H x W x N] grayscale stack, or [H x W x N x 3] RGB.
%   V        Length-N vector of energies (one per slice). A cell array of
%            strings is also accepted and used as the per-slice label.
%   outFile  Optional path. Default: stack_video.mp4 in the current folder.
%
%   Panel arguments may be positional after outFile:
%     writePixelVideo(data, V, [1 5], 'bl', {'All','Zr_2',...})
%     writePixelVideo(data, V, 'out.mp4', [1 5], 'bl', labels)
%
% Name-Value
%   FrameRate         frames per second (default 8)
%   Colormap          'gray' (default), 'invgray', or an N-by-3 colormap
%   Range             'global' (default, stable movie) or 'dynamic'
%   Margin            minimum pixels of padding on each side (default 10)
%   MatchAspect       true (default) keeps the frame proportional to the
%                     data/panel layout, so a 1-by-5 grid of square panels
%                     yields a 5:1 frame. Margin then grows on one axis.
%                     Set false for exactly Margin pixels on all four sides.
%   PixelScale        integer nearest-neighbor enlargement (default 1)
%   Unit              energy unit string, e.g. 'V', 'mV', 'meV' (default 'V')
%   EnergyScale       multiply V before formatting (default 1)
%   EnergyLabelHeight energy stamp height as a fraction of the data height
%                     (default 0.12). The top margin grows to fit it, so the
%                     stamp never overlaps the data.
%   Quality           MPEG-4 quality 0-100 (default 100)
%   Lossless          true writes Motion JPEG 2000 (.mj2) instead of MPEG-4
%   PanelGrid         [nRows nCols], e.g. [1 5]
%   PanelAnchor       'bl' (default), also 'tl','tr','br'
%   PanelLabels       cell/string array, one label per panel, row-major
%   PanelLabelHeight  caption block as a fraction of panel height (default 0.1)
%
% Example
%   writePixelVideo(Y, V);
%   writePixelVideo(Y, V, [1 5], 'bl', {'All','Zr_2','Te_1','Si_1h','Si_1v'});
%   writePixelVideo(Y, V, 'qpi_movie.mp4', [1 6], 'bl', ...
%       {'All','Zr_2','Te_1','Si_1h','Si_1v','Te_2'}, 'Unit', 'mV');

    nargoutchk(0, 1);
    narginchk(2, inf);

    if ismatrix(data) && ~isvector(data)
        data = reshape(data, size(data, 1), size(data, 2), 1);
    end

    [outFile, opt] = parseInputs(data, V, varargin{:});

    nSlice = size(data, 3);
    isRgb = (ndims(data) == 4 && size(data, 4) == 3);

    if isRgb
        rgbStack = normalizeRgbStack(data);
    else
        rgbStack = grayscaleToRgb(data, opt);
    end

    [H, W, ~, ~] = size(rgbStack);
    s = opt.PixelScale;
    m = opt.Margin;
    dataH = H * s;
    dataW = W * s;

    % Reserve a header band so the energy stamp never overlaps the data
    % or runs off the top edge.
    energyBoxH = max(12, round(opt.EnergyLabelHeight * dataH));
    gap = max(2, round(0.3 * m));
    marginTop = max(m, energyBoxH + 2 * gap);
    frameH = dataH + marginTop + m;
    frameW = dataW + 2 * m;

    if opt.MatchAspect
        % Keep the frame proportional to the panel layout (e.g. 1:5), so
        % margins do not squash the grid. Margin is the minimum, not exact.
        wantW = round(frameH * dataW / dataH);
        if wantW >= frameW
            frameW = wantW;
        else
            frameH = round(frameW * dataH / dataW);
        end
    end

    % MPEG-4 needs even dimensions.
    frameH = frameH + mod(frameH, 2);
    frameW = frameW + mod(frameW, 2);
    offsetC = floor((frameW - dataW) / 2);
    % Keep the header snug at the top; any extra height goes below the data.
    offsetR = min(marginTop, max(m, frameH - dataH - m));

    panelStamps = buildPanelStamps(dataH, dataW, offsetR, offsetC, opt);

    if opt.Lossless
        vw = VideoWriter(outFile, 'Archival');
    else
        vw = VideoWriter(outFile, 'MPEG-4');
        vw.Quality = opt.Quality;
    end
    vw.FrameRate = opt.FrameRate;
    open(vw);

    try
        for k = 1:nSlice
            sliceRgb = reshape(rgbStack(:, :, k, :), [H, W, 3]);
            if s > 1
                sliceRgb = repelem(sliceRgb, s, s);
            end
            frame = zeros(frameH, frameW, 3, 'uint8');
            r1 = offsetR + 1;
            r2 = offsetR + dataH;
            c1 = offsetC + 1;
            c2 = offsetC + dataW;
            frame(r1:r2, c1:c2, :) = sliceRgb;

            frame = applyStamps(frame, panelStamps);
            label = sliceLabel(V, k, opt);
            frame = overlayLabel(frame, label, gap, offsetC + 1, ...
                energyBoxH, dataW);

            writeVideo(vw, frame);
            if mod(k, 20) == 0 || k == nSlice
                fprintf('writePixelVideo: frame %d / %d\n', k, nSlice);
            end
        end
        close(vw);
    catch err
        try
            close(vw);
        catch
        end
        rethrow(err);
    end

    fprintf('Wrote %s  (%d x %d, %d frames, %g fps)\n', ...
        outFile, frameW, frameH, nSlice, opt.FrameRate);
end

function [outFile, opt] = parseInputs(data, V, varargin)
    if ~(isnumeric(data) && (ndims(data) == 3 || ...
            (ndims(data) == 4 && size(data, 4) == 3)))
        error('writePixelVideo:data', ...
            'data must be [H x W x N] or [H x W x N x 3].');
    end
    nSlice = size(data, 3);
    if iscell(V)
        if numel(V) ~= nSlice
            error('writePixelVideo:V', ...
                'V must have one entry per slice (%d), got %d.', nSlice, numel(V));
        end
    else
        if ~isnumeric(V) || numel(V) ~= nSlice
            error('writePixelVideo:V', ...
                'V must be a numeric vector with %d energies, got %d.', ...
                nSlice, numel(V));
        end
        V = V(:);
    end

    args = varargin;
    outFile = '';
    known = {'FrameRate', 'Colormap', 'Range', 'Margin', 'PixelScale', ...
        'Unit', 'EnergyScale', 'Quality', 'Lossless', 'File', 'MatchAspect', ...
        'EnergyLabelHeight', ...
        'PanelGrid', 'PanelAnchor', 'PanelLabels', 'PanelLabelHeight'};
    if ~isempty(args) && (ischar(args{1}) || isstring(args{1}))
        tok = char(args{1});
        if ~any(strcmpi(tok, known))
            outFile = tok;
            args = args(2:end);
        end
    end

    panelGridPos = [];
    panelAnchorPos = '';
    panelLabelsPos = [];
    if ~isempty(args) && isnumeric(args{1}) && numel(args{1}) == 2
        panelGridPos = args{1}(:).';
        args = args(2:end);
        if ~isempty(args) && (ischar(args{1}) || isstring(args{1})) ...
                && ~any(strcmpi(char(args{1}), known))
            panelAnchorPos = char(args{1});
            args = args(2:end);
        end
        if ~isempty(args) && (iscell(args{1}) || isstring(args{1}))
            panelLabelsPos = args{1};
            args = args(2:end);
        end
    end

    p = inputParser;
    p.FunctionName = 'writePixelVideo';
    addParameter(p, 'File', '', @(s) ischar(s) || isstring(s));
    addParameter(p, 'FrameRate', 8, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'Colormap', 'gray', @(c) ischar(c) || isstring(c) || ...
        (isnumeric(c) && size(c, 2) == 3));
    addParameter(p, 'Range', 'dynamic', @(s) any(strcmpi(s, {'global', 'dynamic'})));
    addParameter(p, 'Margin', 10, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'PixelScale', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1 && mod(x, 1) == 0);
    addParameter(p, 'Unit', 'V', @(s) ischar(s) || isstring(s));
    addParameter(p, 'EnergyScale', 1, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'Quality', 100, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 100);
    addParameter(p, 'Lossless', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'MatchAspect', true, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'EnergyLabelHeight', 0.12, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
    addParameter(p, 'PanelGrid', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
    addParameter(p, 'PanelAnchor', 'bl', @(s) ischar(s) || isstring(s));
    addParameter(p, 'PanelLabels', {}, @(c) isempty(c) || iscell(c) || isstring(c));
    addParameter(p, 'PanelLabelHeight', 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
    parse(p, args{:});
    opt = p.Results;
    opt.Margin = round(opt.Margin);
    opt.Unit = char(opt.Unit);
    opt.Range = lower(char(opt.Range));
    if ~isempty(panelGridPos)
        opt.PanelGrid = panelGridPos;
    end
    if ~isempty(panelAnchorPos)
        opt.PanelAnchor = panelAnchorPos;
    end
    if ~isempty(panelLabelsPos)
        opt.PanelLabels = panelLabelsPos;
    end
    opt.PanelAnchor = lower(char(opt.PanelAnchor));
    opt.PanelLabels = normalizeLabelList(opt.PanelLabels);
    if ~isempty(opt.PanelGrid)
        opt.PanelGrid = round(opt.PanelGrid(:).');
    end
    validatePanelArgs(opt, data);

    if ~isempty(opt.File)
        outFile = char(opt.File);
    end
    if isempty(outFile)
        if opt.Lossless
            outFile = fullfile(pwd, 'stack_video.mj2');
        else
            outFile = fullfile(pwd, 'stack_video.mp4');
        end
    else
        outFile = char(outFile);
    end
    if opt.Lossless
        [~, ~, ext] = fileparts(outFile);
        if isempty(ext)
            outFile = [outFile '.mj2'];
        end
    else
        [~, ~, ext] = fileparts(outFile);
        if isempty(ext)
            outFile = [outFile '.mp4'];
        end
    end
end

function rgbStack = grayscaleToRgb(data, opt)
    data = double(data);
    data(~isfinite(data)) = NaN;
    cmap = resolveColormap(opt.Colormap);
    nSlice = size(data, 3);
    rgbStack = zeros(size(data, 1), size(data, 2), nSlice, 3, 'uint8');

    if strcmp(opt.Range, 'global')
        clim = robustClim(data(:));
    end

    for k = 1:nSlice
        sl = data(:, :, k);
        if strcmp(opt.Range, 'dynamic')
            clim = robustClim(sl(:));
        end
        rgbStack(:, :, k, :) = mapToRgb(sl, cmap, clim);
    end
end

function rgbStack = normalizeRgbStack(data)
    data = double(data);
    if max(data(:), [], 'omitnan') <= 1
        data = data * 255;
    end
    data = min(max(data, 0), 255);
    data(~isfinite(data)) = 0;
    rgbStack = uint8(data);
end

function rgb = mapToRgb(sl, cmap, clim)
    sl = double(sl);
    sl(~isfinite(sl)) = clim(1);
    span = clim(2) - clim(1);
    if span <= 0
        t = zeros(size(sl));
    else
        t = (sl - clim(1)) / span;
    end
    t = min(max(t, 0), 1);
    n = size(cmap, 1);
    idx = min(n, max(1, round(t * (n - 1)) + 1));
    rgb = uint8(reshape(cmap(idx(:), :), [size(sl), 3]) * 255);
end

function cmap = resolveColormap(c)
    if isnumeric(c)
        cmap = double(c);
        if max(cmap(:)) > 1
            cmap = cmap / 255;
        end
        return;
    end
    name = lower(char(c));
    switch name
        case 'gray'
            cmap = gray(256);
        case {'invgray', 'grayinv', 'flipgray'}
            cmap = flipud(gray(256));
        otherwise
            error('writePixelVideo:colormap', ...
                'Unknown colormap ''%s''. Use gray, invgray, or an N-by-3 matrix.', name);
    end
end

function clim = robustClim(vals)
    vals = vals(isfinite(vals));
    if isempty(vals)
        clim = [0, 1];
        return;
    end
    med = median(vals);
    sd = std(vals);
    nos = 8;
    lo = max(min(vals), med - nos * sd);
    hi = min(max(vals), med + nos * sd);
    if ~(isfinite(lo) && isfinite(hi)) || lo == hi
        lo = min(vals);
        hi = max(vals);
    end
    if lo == hi
        clim = [lo - 1, hi + 1];
    else
        clim = [lo, hi];
    end
end

function label = sliceLabel(V, k, opt)
    if iscell(V)
        label = char(string(V{k}));
        return;
    end
    v = opt.EnergyScale * V(k);
    if ~isfinite(v)
        label = sprintf('E = nan %s', opt.Unit);
        return;
    end
    av = abs(v);
    if av == 0
        fmt = '%.0f';
    elseif av >= 100
        fmt = '%.0f';
    elseif av >= 10
        fmt = '%.1f';
    elseif av >= 1
        fmt = '%.2f';
    else
        fmt = '%.3f';
    end
    label = sprintf(['E = ' fmt ' %s'], v, opt.Unit);
end

function labels = normalizeLabelList(labels)
    if isempty(labels)
        labels = {};
        return;
    end
    if isstring(labels)
        labels = cellstr(labels(:));
    elseif iscell(labels)
        labels = cellfun(@(s) char(string(s)), labels(:), 'UniformOutput', false);
    else
        error('writePixelVideo:panelLabels', 'PanelLabels must be a cell or string array.');
    end
end

function validatePanelArgs(opt, data)
    hasLabels = ~isempty(opt.PanelLabels);
    hasGrid = ~isempty(opt.PanelGrid);
    if ~hasLabels && ~hasGrid
        return;
    end
    if ~hasGrid
        error('writePixelVideo:panelGrid', ...
            'PanelGrid [nRows nCols] is required when PanelLabels are given.');
    end
    nR = opt.PanelGrid(1);
    nC = opt.PanelGrid(2);
    if nR < 1 || nC < 1
        error('writePixelVideo:panelGrid', 'PanelGrid entries must be positive.');
    end
    nPanel = nR * nC;
    if ~hasLabels
        error('writePixelVideo:panelLabels', ...
            'PanelLabels is required when PanelGrid is given (%d panels).', nPanel);
    end
    if numel(opt.PanelLabels) ~= nPanel
        error('writePixelVideo:panelLabels', ...
            ['PanelLabels must have %d entries for PanelGrid [%d %d], got %d. ' ...
            'For six captions use [1 6].'], ...
            nPanel, nR, nC, numel(opt.PanelLabels));
    end
    if ~any(strcmp(opt.PanelAnchor, {'tl', 'tr', 'bl', 'br'}))
        error('writePixelVideo:panelAnchor', ...
            'PanelAnchor must be tl, tr, bl, or br. Got ''%s''.', opt.PanelAnchor);
    end
    H = size(data, 1);
    W = size(data, 2);
    if mod(H, nR) ~= 0 || mod(W, nC) ~= 0
        error('writePixelVideo:panelGrid', ...
            'Data size %d x %d is not divisible by PanelGrid [%d %d].', H, W, nR, nC);
    end
end

function stamps = buildPanelStamps(dataH, dataW, offsetR, offsetC, opt)
    stamps = struct('r0', {}, 'c0', {}, 'patch', {});
    if isempty(opt.PanelLabels)
        return;
    end
    nR = opt.PanelGrid(1);
    nC = opt.PanelGrid(2);
    panelH = dataH / nR;
    panelW = dataW / nC;
    % Floor keeps captions legible on small panels (80 px panel at 10% is 8 px).
    boxH = max(12, round(opt.PanelLabelHeight * panelH));

    idx = 0;
    for i = 1:nR
        for j = 1:nC
            idx = idx + 1;
            str = opt.PanelLabels{idx};
            if isempty(str)
                continue;
            end
            patch = renderTextPatch(str, boxH, panelW);
            boxW = size(patch, 2);
            boxH_act = size(patch, 1);

            pr0 = offsetR + (i - 1) * panelH + 1;
            pc0 = offsetC + (j - 1) * panelW + 1;
            switch opt.PanelAnchor
                case 'tl'
                    r0 = pr0;
                    c0 = pc0;
                case 'tr'
                    r0 = pr0;
                    c0 = pc0 + panelW - boxW;
                case 'bl'
                    r0 = pr0 + panelH - boxH_act;
                    c0 = pc0;
                case 'br'
                    r0 = pr0 + panelH - boxH_act;
                    c0 = pc0 + panelW - boxW;
            end

            k = numel(stamps) + 1;
            stamps(k).r0 = round(r0);
            stamps(k).c0 = round(c0);
            stamps(k).patch = patch;
        end
    end
end

function frame = applyStamps(frame, stamps)
    for i = 1:numel(stamps)
        frame = pastePatch(frame, stamps(i).r0, stamps(i).c0, stamps(i).patch);
    end
end

function frame = overlayLabel(frame, str, r0, c0, boxH, maxW)
    maxW = max(8, min(maxW, size(frame, 2) - c0 + 1));
    patch = renderTextPatch(str, boxH, maxW);
    frame = pastePatch(frame, r0, c0, patch);
end

function frame = pastePatch(frame, r0, c0, patch)
    [ph, pw, ~] = size(patch);
    [fh, fw, ~] = size(frame);
    r1 = max(1, round(r0));
    c1 = max(1, round(c0));
    r2 = min(fh, r1 + ph - 1);
    c2 = min(fw, c1 + pw - 1);
    if r2 < r1 || c2 < c1
        return;
    end
    pr = r2 - r1 + 1;
    pc = c2 - c1 + 1;
    frame(r1:r2, c1:c2, :) = patch(1:pr, 1:pc, :);
end

function patch = renderTextPatch(str, boxH, maxW)
    % Arial text. Trailing _suffix (Zr_2, Si_1h) is drawn as a true subscript.
    % Text is rasterized large, cropped to its ink, then scaled down with the
    % aspect ratio locked, so captions never stretch or get clipped.
    str = char(str);
    boxH = max(6, round(boxH));
    maxW = max(6, round(maxW));
    try
        ink = rasterizeTextFigure(str);
    catch
        ink = rasterizeTextInsert(str);
    end
    pad = max(1, round(0.12 * boxH));
    patch = fitInkToBox(ink, boxH, maxW, pad);
end

function rgb = rasterizeTextFigure(str)
    fs = 64;
    pad = 24;
    [base, sub] = splitBaseSubscript(str);
    canvasW = round(0.95 * fs * (numel(base) + numel(sub))) + 4 * pad;
    canvasH = round(2.4 * fs);

    fig = figure('Visible', 'off', 'Units', 'pixels', ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Color', 'k', ...
        'HandleVisibility', 'off', 'IntegerHandle', 'off');
    cleaner = onCleanup(@() close(fig)); %#ok<NASGU>
    fig.Position = [100, 100, canvasW, canvasH];
    ax = axes('Parent', fig, 'Units', 'pixels', ...
        'Position', [0, 0, canvasW, canvasH], ...
        'XLim', [0, canvasW], 'YLim', [0, canvasH], ...
        'Visible', 'off', 'Color', 'k', 'XTick', [], 'YTick', []);

    tBase = text(ax, pad, canvasH / 2, base, ...
        'Color', 'w', 'FontName', 'Arial', 'FontWeight', 'bold', ...
        'FontUnits', 'pixels', 'FontSize', fs, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'Interpreter', 'none', 'Units', 'pixels');
    drawnow;
    if ~isempty(sub)
        ext = get(tBase, 'Extent');
        % Pixel units run bottom-up, so a smaller y is a subscript.
        text(ax, pad + ext(3), canvasH / 2 - 0.30 * fs, sub, ...
            'Color', 'w', 'FontName', 'Arial', 'FontWeight', 'bold', ...
            'FontUnits', 'pixels', 'FontSize', max(8, round(0.62 * fs)), ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
            'Interpreter', 'none', 'Units', 'pixels');
        drawnow;
    end
    rgb = getframe(ax).cdata;
end

function rgb = rasterizeTextInsert(str)
    if exist('insertText', 'file') ~= 2
        error('writePixelVideo:text', 'No text renderer available.');
    end
    fs = 64;
    pad = 24;
    str = applyUnicodeSubscripts(str);
    canvasW = round(0.95 * fs * numel(str)) + 4 * pad;
    canvasH = round(2.4 * fs);
    rgb = zeros(canvasH, canvasW, 3, 'uint8');
    rgb = insertText(rgb, [pad, round(canvasH / 2)], str, ...
        'FontSize', fs, 'BoxOpacity', 0, 'TextColor', 'white', ...
        'AnchorPoint', 'LeftCenter');
end

function patch = fitInkToBox(rgb, boxH, maxW, pad)
    ink = cropToInk(rgb);
    [h, w, ~] = size(ink);
    availH = max(1, boxH - 2 * pad);
    availW = max(1, maxW - 2 * pad);
    sc = min(availH / h, availW / w);
    newH = max(1, min(availH, round(h * sc)));
    newW = max(1, min(availW, round(w * sc)));
    if exist('imresize', 'file') == 2
        ink = imresize(ink, [newH, newW]);
    else
        ink = ink(round(linspace(1, h, newH)), round(linspace(1, w, newW)), :);
    end
    patch = zeros(newH + 2 * pad, newW + 2 * pad, 3, 'uint8');
    patch(pad + (1:newH), pad + (1:newW), :) = ink;
end

function ink = cropToInk(rgb)
    lum = max(rgb, [], 3);
    rows = find(max(lum, [], 2) > 20);
    cols = find(max(lum, [], 1) > 20);
    if isempty(rows) || isempty(cols)
        ink = rgb;
        return;
    end
    ink = rgb(rows(1):rows(end), cols(1):cols(end), :);
end

function [base, sub] = splitBaseSubscript(str)
    str = char(str);
    tok = regexp(str, '^(.*)_\{([^}]*)\}$', 'tokens', 'once');
    if ~isempty(tok)
        base = tok{1};
        sub = tok{2};
        return;
    end
    tok = regexp(str, '^(.*)_([^_]+)$', 'tokens', 'once');
    if ~isempty(tok)
        base = tok{1};
        sub = tok{2};
        return;
    end
    base = str;
    sub = '';
end

function out = applyUnicodeSubscripts(str)
    [base, sub] = splitBaseSubscript(str);
    if isempty(sub)
        out = base;
        return;
    end
    map = subscriptCharMap();
    chars = num2cell(sub);
    for i = 1:numel(chars)
        key = chars{i};
        if isKey(map, key)
            chars{i} = map(key);
        end
    end
    out = [base, sprintf('%s', chars{:})];
end

function map = subscriptCharMap()
    map = containers.Map('KeyType', 'char', 'ValueType', 'char');
    digits = '0123456789';
    subDigits = sprintf('%c', 8320:8329);  % ₀-₉
    for i = 1:10
        map(digits(i)) = subDigits(i);
    end
    map('h') = char(8341);   % ₕ
    map('H') = char(8341);
    map('v') = char(7525);   % ᵥ
    map('V') = char(7525);
    map('a') = char(8336);
    map('e') = char(8337);
    map('i') = char(7522);
    map('n') = char(8345);
    map('o') = char(8338);
    map('r') = char(7523);
    map('s') = char(8347);
    map('t') = char(8348);
    map('x') = char(8339);
end