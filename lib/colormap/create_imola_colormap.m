%CREATE_IMOLA_COLORMAP  Preview and optionally save imola.mat.
%   Live source is imola.m via slanCM('imola') or bundled imola.txt.

this_dir = fileparts(mfilename('fullpath'));
imola_map = imola(256);
save(fullfile(this_dir, 'imola.mat'), 'imola_map');

figure;
colormap(imola_map);
colorbar;
title('Imola (synthetic real-space)');

figure;
colormap(flipud(imola_map));
colorbar;
title('Invimola (synthetic FT / QPI)');
