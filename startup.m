% Add project and vendor paths commonly needed outside init_sbd.
repo = fileparts(mfilename('fullpath'));
if isempty(repo); repo = pwd; end
addpath(genpath(fullfile(repo, 'colormap')));
if isfolder(fullfile(repo, 'vendor'))
    addpath(genpath(fullfile(repo, 'vendor')));
end
