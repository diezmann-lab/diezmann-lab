%% NOBIAS multi run
function NOBIAS_batch
% file path setup
% Zeroth step: get oriented to file structure
rootdir = uigetdir(pwd,'Select folder containing single microscopy day');
s = filesep;
expdir = append(rootdir,s,'Experiments');
top = dir(expdir);
top = natsortfiles(top);
folderlist = top([top.isdir]);
explist = folderlist(~ismember({folderlist(:).name},{'.','..'})); % only experimental gonad folders
explist = folderlist(~startsWith({folderlist(:).name},'.')); % update to get rid of any extraneous files
numFolders = length(explist); % gonads
expName = {explist.name};


w = waitbar(0, 'Starting NOBIAS analysis...');
% First step: grab NOBIAS data
for f = 1:numFolders 
    naddir = append(expdir,s,string(expName(f))); % go into each gonad folder
    cd(naddir)
    dataName = append(num2str(f),'NOBIAS_data.mat');
    data = open(dataName);
    data = data.data;
% run NOBIAS (make sure added on path)
    out = NOBIAS(data);
    clear data out
    waitbar(f/numFolders,w,sprintf('Progress: %d %%',floor(f/numFolders*100)))
    pause(0.1)
end 
close(w)