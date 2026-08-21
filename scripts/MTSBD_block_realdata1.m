% Compatibility stub — relocated under scripts/real/MTSBD_block_realdata1.m
% This stub will be removed in a future cleanup.
warning('MT-SBD:RelocatedScript', '%s has moved to scripts/%s', 'MTSBD_block_realdata1.m', 'real/MTSBD_block_realdata1.m');
target = fullfile(fileparts(mfilename('fullpath')), 'real/MTSBD_block_realdata1.m');
if ~exist(target, 'file')
    error('Relocated script not found: %s', target);
end
run(target);
