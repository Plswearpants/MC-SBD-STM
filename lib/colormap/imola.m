function cmap = imola(m)
%IMOLA  Sequential colormap for synthetic STM image panels.
%   IMOLA(M) returns an M-by-3 matrix. IMOLA, by itself, uses the current
%   figure colormap length (or the MATLAB default if no figure exists).
%
%   Prefers slanCM('imola') from 3rd party/slanCM. If that LUT file is
%   missing, interpolates the bundled Crameri imola table (imola.txt).
%   Real-data plots use GRAY; synthetic FT/QPI uses INVIMOLA.
%
%   Example:
%       colormap(imola)
%       colormap(imola(256))
%
%   See also INVIMOLA, GRAY, INVGRAY, SBD_IMAGE_CMAP, SLANCM.

    if nargin < 1
        f = get(groot, 'CurrentFigure');
        if isempty(f)
            m = size(get(groot, 'DefaultFigureColormap'), 1);
        else
            m = size(f.Colormap, 1);
        end
    end

    if isempty(m) || m < 1
        cmap = zeros(0, 3);
        return
    end

    base = load_imola_base();
    n0 = size(base, 1);
    if m == n0
        cmap = base;
    else
        t0 = linspace(0, 1, n0);
        t1 = linspace(0, 1, m);
        cmap = [interp1(t0, base(:,1), t1, 'linear')', ...
                interp1(t0, base(:,2), t1, 'linear')', ...
                interp1(t0, base(:,3), t1, 'linear')'];
    end
    cmap = min(max(cmap, 0), 1);
end

function base = load_imola_base()
    persistent cached
    if ~isempty(cached)
        base = cached;
        return
    end

    if exist('slanCM', 'file') == 2
        try
            cached = slanCM('imola', 256);
            base = cached;
            return
        catch
        end
    end

    txt = fullfile(fileparts(mfilename('fullpath')), 'imola.txt');
    if exist(txt, 'file') ~= 2
        error('imola:missingLut', ...
            ['Could not load slanCM(''imola'') or %s. ', ...
             'Add 3rd party/slanCM (with slanCM_Data.mat) to the path.'], txt);
    end
    cached = load(txt, '-ascii');
    if size(cached, 2) ~= 3
        error('imola:badLut', 'imola.txt must be N-by-3 RGB in [0,1].');
    end
    base = cached;
end
