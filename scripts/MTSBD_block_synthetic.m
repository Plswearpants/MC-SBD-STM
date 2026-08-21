% Compatibility stub — relocated under scripts/synthetic/MTSBD_block_synthetic.m
% This stub will be removed in a future cleanup.
warning('MT-SBD:RelocatedScript', '%s has moved to scripts/%s', 'MTSBD_block_synthetic.m', 'synthetic/MTSBD_block_synthetic.m');
target = fullfile(fileparts(mfilename('fullpath')), 'synthetic/MTSBD_block_synthetic.m');
if ~exist(target, 'file')
    error('Relocated script not found: %s', target);
end
run(target);
