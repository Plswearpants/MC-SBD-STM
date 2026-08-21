% Compatibility stub — relocated under scripts/real/run_real_data.m
% This stub will be removed in a future cleanup.
warning('MT-SBD:RelocatedScript', '%s has moved to scripts/%s', 'run_real_data.m', 'real/run_real_data.m');
target = fullfile(fileparts(mfilename('fullpath')), 'real/run_real_data.m');
if ~exist(target, 'file')
    error('Relocated script not found: %s', target);
end
run(target);
