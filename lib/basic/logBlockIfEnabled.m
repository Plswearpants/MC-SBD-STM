function LOGcomment = logBlockIfEnabled(log, block, comment)
%LOGBLOCKIFENABLED Append a log entry only when a log target is configured.
%   LOGcomment = logBlockIfEnabled(log, block, comment)
%
%   Wrappers are shared between trunk scripts that initialize logging
%   (scripts/real/run_real_block.m sets log.path and log.file) and trunks
%   that do not (historical/real/hist_run_real_data.m passes an empty struct). This
%   helper appends via logUsedBlocks when a target exists and is otherwise a
%   no-op, so adding logging to a shared wrapper cannot break either caller.
%
%   Always returns "" so callers can chain entries the same way they do with
%   logUsedBlocks directly.

    LOGcomment = "";

    if ~isstruct(log) || ~isfield(log, 'path') || ~isfield(log, 'file')
        return;
    end
    if isempty(log.path) || isempty(log.file)
        return;
    end

    log_path = log.path;
    log_file = log.file;
    if iscell(log_path); log_path = log_path{1}; end
    if iscell(log_file); log_file = log_file{1}; end

    try
        logUsedBlocks(char(log_path), char(log_file), block, comment, 0);
    catch ME
        warning('logBlockIfEnabled:LogFailed', ...
            'Could not write log entry for block %s: %s', char(block), ME.message);
    end
end
