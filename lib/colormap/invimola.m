function cmap = invimola(m)
%INVIMOLA  Inverted imola colormap for synthetic FT / QPI panels.
%   Same role as INVGRAY for real data: real-space uses IMOLA, Fourier
%   space uses INVIMOLA (flipud of the LUT).
%
%   Example:
%       colormap(invimola)
%       colormap(invimola(256))
%
%   See also IMOLA, INVGRAY, SBD_IMAGE_CMAP.

    if nargin < 1
        f = get(groot, 'CurrentFigure');
        if isempty(f)
            m = size(get(groot, 'DefaultFigureColormap'), 1);
        else
            m = size(f.Colormap, 1);
        end
    end
    cmap = flipud(imola(m));
end
