function [LOGcomment] = logUsedBlocks(LOGpath, LOGfile, block, LOGcomment ,initialize)
%Logging blocks used in the UBC_LAIR main script. 
%   The function creates and updates a .txt file that logs all the blocks
%   that were executed in the in the script with a time stamp.
%   
%   LOGpath     * path variable to the location of the log file
%   LOGfile     * file name 
%   block       unique block identifier (should be 5 charcters)
%   comment     free comment to be logged (e.g. list of parameters used in 
%               the functions executed within the corresponding block) 
%   initialize  1 = yes, 0 = no 
%
%   Empty LOGpath or LOGfile: no file is written (no-log callers).
%
%   * note that the strings LOGfile name and LOGpath should correspond to
%   the char [file path] returned by uigetfile() for a data file. 

 

arguments
    LOGpath     {mustBeText}    %string
    LOGfile     {mustBeText}    %string
    block       {mustBeText}    %string
    LOGcomment  {mustBeText}    %string
    initialize  {mustBeNumericOrLogical} = 0
end

% Empty path/file: caller is a no-log script (e.g. the simple example).
if strlength(strtrim(string(LOGpath))) == 0 || strlength(strtrim(string(LOGfile))) == 0
    LOGcomment = "";
    return;
end

% Build canonical log file path (cross-platform).
log_file_path = fullfile(char(LOGpath), [char(LOGfile) '_LOGfile.txt']);

% open or create file and write header in the initialization run
% clears the log file!
if initialize == 1
    fid = fopen(log_file_path,'w+');
    if fid == -1
        error('logUsedBlocks:FileOpenFailed', 'Could not create log file: %s', log_file_path);
    end
    %header = 'DATE                  BLOCK   COMMENT';
    fprintf(fid,'%21s %7s %s\r\n','DATE and TIME        ','BLOCK  ','COMMENT');
    initialize = 0;
    fclose(fid);
end

% append timestamp and executed block to the log file
if initialize == 0
    fid = fopen(log_file_path,'a+');
    if fid == -1
        error('logUsedBlocks:FileOpenFailed', 'Could not append log file: %s', log_file_path);
    end
    t = datetime;
    dtstr = string(t);
    M=convertStringsToChars(strcat(dtstr, "  ",block, "   ",LOGcomment));
    fprintf(fid,'%s\r\n',M);
    fclose(fid);
end

%resets LOGcomment so the next block doesn't accidently carry over an old
%string. 
LOGcomment = "";
end