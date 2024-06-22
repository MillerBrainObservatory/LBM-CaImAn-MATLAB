function [commitHash,branch] = getGitCommitHash(gitRepoPath)
    validateattributes(gitRepoPath,{'char'},{'row'});
    
    assert(logical(exist(gitRepoPath,'dir')),'Invalid gitRepoPath: %s',gitRepoPath);
    gitFolder = fullfile(gitRepoPath,'.git');
    assert(logical(exist(gitFolder,'dir')),'.git folder was not found');

    headFilePath = fullfile(gitFolder,'HEAD');
    assert(logical(exist(headFilePath,'file')),'.git/HEAD file was not found');
    
    fid = fopen(headFilePath);
    try
        line = fgetl(fid);
        fclose(fid);
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    
    [~,tokens] = regexpi(line,'^ref:\s*refs/heads/(.*)$','match','tokens');
    if isempty(tokens) || isempty(tokens{1})
        % detached head
        commitHash = line;
    else
        branch = tokens{1}{1};
        commitFilePath = fullfile(gitFolder,'refs','heads',tokens{1}{1});
        assert(logical(exist(commitFilePath,'file')),'Commit file was not found');
        
        fid = fopen(commitFilePath);
        try
            commitHash = fgetl(fid);
            fclose(fid);
        catch ME
            fclose(fid);
            rethrow(ME);
        end
    end
end

%--------------------------------------------------------------------------%
% getGitCommitHash.m                                                       %
% Copyright © 2019 Vidrio Technologies, LLC                                %
%                                                                          %
% ScanImage 2019 is premium software to be used under the purchased terms  %
% Code may be modified, but not redistributed without the permission       %
% of Vidrio Technologies, LLC                                              %
%--------------------------------------------------------------------------%
