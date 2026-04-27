%%% Run uTrack using only the raw localization output from Vutara! This
%%% script automatically tracks by cycle and concatenates all results. 
% Input: ExportedParticles-001.csv
% Output: tracksOrg

function Tracking(uTrackpath,uTrackSavepath,pixelSize_,gapWindow,minLength,minRadius,maxRadius,maxAngle,...
    mergeSplit,linearMotion,brownMult,localDensity,gapPenalty) 

% close all;
% clearvars 

%% Defaults
if nargin == 0
    warning("No parameters input. Using default values")
    uTrackpath = 'C:\Users\Victoria\Documents\uTrackAspen\u-track3D-master';
    uTrackSavepath = 'C:\Users\Victoria\Documents\uTrackAspen\u-track-save';
pixelSize_ = 99; % 99 nm for our scope
gapWindow = 6; % frames
minLength = 1; % frames
minRadius = 10; % nm
maxRadius = 400; % nm
maxAngle = 360; % degrees

% very optional parameters
mergeSplit = 0; % no merging/splitting considered
linearMotion = 1; % use linear Kalman filter
brownMult = 3;
localDensity = 1; % consider local density
gapPenalty = 1; % 1 for no penalty
end 

%% Set up: Parameters

% Anisotropy in XY
% Dimension of the data
probDim=3; % 2D currently not working lol


%% Set up: defining paths, parallel processing, 

% DEFINE ALL PATHS

% Generate tree of paths from the repo's root
path_to_main_code = uTrackpath;
% path_to_main_code = 'C:\Users\Victoria\Documents\uTrack\u-track3D-master';
addpath(genpath(path_to_main_code));

% Path to save all intermediate results
saveFolder = uTrackSavepath;
% saveFolder = 'C:\Users\Victoria\Documents\uTrack\u-track-save';
mkClrDir(saveFolder); %% WARNING, ALL FILES IN THE FOLDER WILL BE DELETED IF IT IS NOT EMPTY

% Check that the code has been loaded correctly
if(isempty(which('MovieData')))
    error('The code folder must be loaded first.');
end

% PARALLEL POOL
try
    parpool(8)
catch 
    disp('Parallel pool running');
end


%% Set up: split by cycle

% user input - modify w/ multi select? 
% FILE MANAGEMENT SET UP
rootdir = uigetdir(pwd,'Select folder containing single microscopy day');
s = filesep;
expdir = append(rootdir,s,'Experiments');
% only experimental gonad folders
top = dir(expdir);
top = natsortfiles(top); % get in order windows like it :)
folderlist = top([top.isdir]); 
explist = folderlist(~ismember({folderlist(:).name},{'.','..'}));
explist = folderlist(~startsWith({folderlist(:).name},'.')); % update to get rid of any extraneous files
numFolders = length(explist); % gonads
expName = {explist.name};

cd(expdir)
for f = 1:numFolders 
    naddir = append(expdir,s,string(expName(f))); % go into each gonad folder
    cd(naddir)
    sptStruct = dir(fullfile(naddir,'*ExportedParticles*.csv'));
    rawData = readtable(sptStruct.name);
    % registration adjustment - check tform occassionally using Registration script
    tform = affine2d([0.979923765	-0.000160466	0
    0.000130561	1.008543001	0
    25.28865177	25.25389902	1]);
    [tX,tY] = transformPointsForward(tform,(rawData.x)/99,(rawData.y)/99);
    rawData.x = tX*99; rawData.y = tY*99;
    
    % run uTrack for each file

% regular setup - for reference
% [filename,fullpath] = uigetfile({'*.csv'},'Select Vutara localizations','MultiSelect','on');
% rawData = readtable(append(fullpath,'\',filename)); 
numCycles = max(rawData.cycle)+1; % +1 since count starts at 0

% initalize variables
movieinfo = struct; % temporary 
movieInfo = struct; % real 
std_error_on_positions = 0;
tracksOrg = struct([]);

uFrames = unique(rawData.image_ID);
realFrames = length(uFrames);
for i = 1:realFrames % grab only real frames, skip cycle breaks
    idx = rawData.image_ID == uFrames(i);
    movieinfo(i).xCoord = table2array(horzcat(rawData(idx,"x"),...
        array2table(std_error_on_positions .* ones(size(rawData(idx,"x"),1),1))));
    movieinfo(i).yCoord = table2array(horzcat(rawData(idx,"y"),...
        array2table(std_error_on_positions .* ones(size(rawData(idx,"y"),1),1))));
    movieinfo(i).zCoord = table2array(horzcat(rawData(idx,"z"),...
        array2table(std_error_on_positions .* ones(size(rawData(idx,"z"),1),1))));
    movieinfo(i).amp = table2array(horzcat(rawData(idx,"amp"),...
        array2table(std_error_on_positions .* ones(size(rawData(idx,"amp"),1),1))));
    % for splitting purposes
    cycle = table2array(rawData(idx,"cycle")+1);
    movieinfo(i).cycle = cycle(1); % only first element is needed
end 

%% cost matrix for gap closing
for j = 1:numCycles

    % select correct cycle
    cIdx = [movieinfo(:).cycle] == j;
    movieInfo = movieinfo(cIdx); 

gapCloseParam.timeWindow = gapWindow; %maximum allowed time gap (in frames) %between a track segment end and a track segment start that allows linking them.
gapCloseParam.mergeSplit = mergeSplit; %1 if merging and splitting are to be considered, 2 if only merging is to be considered, 3 if only splitting is to be considered, 0 if no merging or splitting are to be considered.
gapCloseParam.minTrackLen = minLength; %minimum length of track segments from linking to be used in gap closing.

%optional input:
gapCloseParam.diagnostics = 0; %1 to plot a histogram of gap lengths in the end; 0 or empty otherwise.

%% cost matrix for frame-to-frame linking
%function name
costMatrices(1).funcName = 'costMatRandomDirectedSwitchingMotionLink';

%parameters
parameters.linearMotion = linearMotion; %use linear motion Kalman filter.

parameters.minSearchRadius = minRadius; %minimum allowed search radius. The search radius is calculated on the spot in the code given a feature's motion parameters. If it happens to be smaller than this minimum, it will be increased to the minimum.
parameters.maxSearchRadius = maxRadius; %maximum allowed search radius. Again, if a feature's calculated search radius is larger than this maximum, it will be reduced to this maximum.
parameters.brownStdMult = brownMult; %multiplication factor to calculate search radius from standard deviation.

parameters.useLocalDensity = localDensity; %1 if you want to expand the search radius of isolated features in the linking (initial tracking) step.
parameters.nnWindow = gapCloseParam.timeWindow; %number of frames before the current one where you want to look to see a feature's nearest neighbor in order to decide how isolated it is (in the initial linking step).

parameters.kalmanInitParam = []; %Kalman filter initialization parameters.
%parameters.kalmanInitParam.searchRadiusFirstIteration = parameters.maxSearchRadius; %Kalman filter initialization parameters.
parameters.kalmanInitParam.searchRadiusFirstIteration = maxRadius;
%optional input
parameters.diagnostics = 0; %if you want to plot the histogram of linking distances up to certain frames, indicate their numbers; 0 or empty otherwise. Does not work for the first or last frame of a movie.

costMatrices(1).parameters = parameters;


%function name
costMatrices(2).funcName = 'costMatRandomDirectedSwitchingMotionCloseGaps';

%parameters needed all the time
parameters.linearMotion = linearMotion; %use linear motion Kalman filter.

parameters.minSearchRadius = minRadius; %minimum allowed search radius.
parameters.maxSearchRadius = maxRadius; %maximum allowed search radius, nm.
parameters.brownStdMult = 3*ones(gapCloseParam.timeWindow,1); %multiplication factor to calculate Brownian search radius from standard deviation.

%power for scaling the Brownian search radius with time, before and
%after timeReachConfB (next parameter). Note that it is only the gap
%value which is powered, then we have brownStdMult*powered_gap*sig*sqrt(dim)
parameters.brownScaling = [0.25 0.01];
% parameters.timeReachConfB = 3; %before timeReachConfB, the search radius grows with time with the power in brownScaling(1); after timeReachConfB it grows with the power in brownScaling(2).
parameters.timeReachConfB = gapCloseParam.timeWindow; %before timeReachConfB, the search radius grows with time with the power in brownScaling(1); after timeReachConfB it grows with the power in brownScaling(2).

parameters.ampRatioLimit = [0.7 4]; %for merging and splitting. Minimum and maximum ratios between the intensity of a feature after merging/before splitting and the sum of the intensities of the 2 features that merge/split.

parameters.lenForClassify = 5; %minimum track segment length to classify it as linear or random.

parameters.useLocalDensity = localDensity; %1 if you want to expand the search radius of isolated features in the gap closing and merging/splitting step.
parameters.nnWindow = gapCloseParam.timeWindow; %number of frames before/after the current one where you want to look for a track's nearest neighbor at its end/start (in the gap closing step).

parameters.linStdMult = 1*ones(gapCloseParam.timeWindow,1); %multiplication factor to calculate linear search radius from standard deviation.

parameters.linScaling = [0.25 0.01]; %power for scaling the linear search radius with time (similar to brownScaling).
% parameters.timeReachConfL = 4; %similar to timeReachConfB, but for the linear part of the motion.
parameters.timeReachConfL = gapCloseParam.timeWindow; %similar to timeReachConfB, but for the linear part of the motion.

parameters.maxAngleVV = maxAngle; %maximum angle between the directions of motion of two tracks that allows linking them (and thus closing a gap). Think of it as the equivalent of a searchRadius but for angles.

%optional; if not input, 1 will be used (i.e. no penalty)
parameters.gapPenalty = gapPenalty; %penalty for increasing temporary disappearance time (disappearing for n frames gets a penalty of gapPenalty^n).

%optional; to calculate MS search radius
%if not input, MS search radius will be the same as gap closing search radius
parameters.resLimit = []; %resolution limit, which is generally equal to 3 * point spread function sigma.

costMatrices(2).parameters = parameters;

%% Kalman filter function names

kalmanFunctions.reserveMem  = 'kalmanResMemLM';
kalmanFunctions.initialize  = 'kalmanInitLinearMotion';
kalmanFunctions.calcGain    = 'kalmanGainLinearMotion';
kalmanFunctions.timeReverse = 'kalmanReverseLinearMotion';

schemeName='U_track';

saveResults.dir =  [saveFolder filesep schemeName];
mkdir(saveResults.dir);

verbose=1;

%% Run tracker
[tracksFinal,kalmanInfoLink,errFlag,trackabilityData] = ...
    trackCloseGapsKalmanSparse(movieInfo,costMatrices, ... 
                               gapCloseParam,kalmanFunctions ,...
                               probDim,saveResults,verbose,'estimateTrackability',true);
tracks=TracksHandle(tracksFinal);

%% Converting tracksFinal into tracksOrg
tracksOr = struct;
nTrack = length(tracksFinal);
for i = 1:nTrack
    tracksOr(i).frame = tracks(i).t;
    tracksOr(i).xLoc = tracks(i).x;
    tracksOr(i).yLoc = tracks(i).y;
    tracksOr(i).zLoc = tracks(i).z;
    % for analysis purposes
    tracksOr(i).cycle = j;
end 
tracksOrg = horzcat(tracksOrg,tracksOr); % combine all cycles

end 

% for analysis purposes
for i = 1:length(tracksOrg)
    tracksOrg(i).track = i;
end 

save([num2str(f),'tracksOrg'],'tracksOrg')
end 


