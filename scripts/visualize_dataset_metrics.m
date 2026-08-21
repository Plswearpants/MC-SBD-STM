% Compatibility stub — relocated under scripts/phase_space/visualize_dataset_metrics.m
% This stub will be removed in a future cleanup.
warning('MT-SBD:RelocatedScript', '%s has moved to scripts/%s', 'visualize_dataset_metrics.m', 'phase_space/visualize_dataset_metrics.m');
target = fullfile(fileparts(mfilename('fullpath')), 'phase_space/visualize_dataset_metrics.m');
if ~exist(target, 'file')
    error('Relocated script not found: %s', target);
end
run(target);
