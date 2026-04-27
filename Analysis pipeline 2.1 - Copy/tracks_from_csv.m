close all;
clearvars % -except swift locs;
tracksOrg = struct([]);

%% Set up to split by cycle

% user input - modify w/ uigetdir and loop for multiple files and cd to
% save to right place
fullpath = "C:\Users\Victoria\Documents\Analysis pipeline\ExportedParticles-001 test.csv";
rawData = readtable(fullpath); % image_ID is "real" frame
% rawData = table2array(rawData);
numCycles = max(rawData.cycle)+1; % +1 since count starts at 0

% extra stuff for diagnostic purposes
framesPerCycle = 300;
bleachFrames = 1;
splitBy = zeros(numCycles,1);
splitBy(1) = 0; 
for i = 1:numCycles
    splitBy(i+1) = splitBy(i) + framesPerCycle + bleachFrames;  
end 

% creating movieInfo
movieinfo = struct; % temp 
movieInfo = struct; % real, used in analysis
std_error_on_positions = 0;

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
%%%% DEFINE ALL PATHS

%% Generate tree of paths from the repo's root
path_to_main_code = 'C:\Users\Victoria\Documents\uTrackAspen\u-track3D-master';
addpath(genpath(path_to_main_code));

%% Path to save all intermediate results
saveFolder = 'C:\Users\Victoria\Documents\uTrackAspen\u-track-save';
mkClrDir(saveFolder); %% WARNING, ALL FILES IN THE FOLDER WILL BE DELETED IF IT IS NOT EMPTY

% Check that the code has been loaded correctly
if(isempty(which('MovieData')))
    error('The code folder must be loaded first.');
end

% Path to centroid data as .csv files.
% There should be one .csv file for each frame.
% Coordinates format should be XY(Z).

% fullpath = "E:\LvD008_20C_SPT_20260107\Late_Pachytene\S1G1R2\Tracking\Cycle 3\"; % loc output from vutara

%%%% END OF PATHS DEFINITION


% Start parallel pool for parallel computing
try
    parpool(8)
catch 
    disp('Parallel pool running');
end

% Anisotropy in XY
pixelSize_ = 99; % 99 nm for our scope
% Anisotropy in Z
% pixelSizeZ_ = NaN; % not needed at the moment

% Dimension of the data
probDim=3;

% cleaning/sorting - OLD IMPORT WHERE NEED INDIVIDUAL CSV FOR EACH FRAME
%{
directory_infos = dir(fullpath);
directory_infos([1,2],:) = [];

for i = 1:length(directory_infos)
    directory_infos(i).name = erase(directory_infos(i).name,'.xlsx');
    directory_infos(i).name = str2double(directory_infos(i).name);
end 
 [~,idx]=sort([directory_infos.name]);
directory_infos = directory_infos(idx);
for i = 1:length(directory_infos)
     directory_infos(i).name = num2str(directory_infos(i).name);
     directory_infos(i).name = strcat(directory_infos(i).name,'.xlsx');
end 


nFrames = length(directory_infos);

dCell=cell(1,nFrames);  
% ZXRatio=pixelSizeZ_/pixelSize_; not needed for our purposes at the moment

for fIdx=1:nFrames
    d = struct;
    % d=Detections();

    CSV = readtable(strcat(fullpath, directory_infos(fIdx).name));
    % CSV(:,1) = [];
    CSV = table2array(CSV);

    %%% go from ZYX format to XYZ
    %%CSV = CSV(:,[3,2,1]);
    
    % Manually provide the estimated uncertainty on positions
    std_error_on_positions = 0;

    % d from CSV
    d.xCoord = horzcat(CSV(:,1),std_error_on_positions .* ones(size(CSV,1),1));
    d.yCoord = horzcat(CSV(:,2),std_error_on_positions .* ones(size(CSV,1),1));
    d.zCoord = horzcat(CSV(:,3),std_error_on_positions .* ones(size(CSV,1),1));
    d.amp = horzcat(CSV(:,5),std_error_on_positions .* ones(size(CSV,1),1));
    % d = d.initFromPosMatrices(CSV,std_error_on_positions .* ones(size(CSV)));

    dCell{fIdx}=d;
end

movieInfo=[dCell{:}];
% movieInfo = load('input_to_trackCloseGapsKalmanSparse.mat');
%}
% gap_close = 6;
% radius = 700;

%% cost matrix for gap closing
for j = 1:numCycles

    % select correct cycle
    cIdx = [movieinfo(:).cycle] == j;
    movieInfo = movieinfo(cIdx); 

gapCloseParam.timeWindow = 41; %maximum allowed time gap (in frames) %between a track segment end and a track segment start that allows linking them.
gapCloseParam.mergeSplit = 0; %1 if merging and splitting are to be considered, 2 if only merging is to be considered, 3 if only splitting is to be considered, 0 if no merging or splitting are to be considered.
gapCloseParam.minTrackLen = 7; %minimum length of track segments from linking to be used in gap closing.

%optional input:
gapCloseParam.diagnostics = 0; %1 to plot a histogram of gap lengths in the end; 0 or empty otherwise.

%% cost matrix for frame-to-frame linking
%function name
costMatrices(1).funcName = 'costMatRandomDirectedSwitchingMotionLink';

%parameters
parameters.linearMotion = 1; %use linear motion Kalman filter.

parameters.minSearchRadius = 10; %minimum allowed search radius. The search radius is calculated on the spot in the code given a feature's motion parameters. If it happens to be smaller than this minimum, it will be increased to the minimum.
parameters.maxSearchRadius = 1000; %maximum allowed search radius. Again, if a feature's calculated search radius is larger than this maximum, it will be reduced to this maximum.
parameters.brownStdMult = 3; %multiplication factor to calculate search radius from standard deviation.

parameters.useLocalDensity = 1; %1 if you want to expand the search radius of isolated features in the linking (initial tracking) step.
parameters.nnWindow = gapCloseParam.timeWindow; %number of frames before the current one where you want to look to see a feature's nearest neighbor in order to decide how isolated it is (in the initial linking step).

parameters.kalmanInitParam = []; %Kalman filter initialization parameters.
%parameters.kalmanInitParam.searchRadiusFirstIteration = parameters.maxSearchRadius; %Kalman filter initialization parameters.
parameters.kalmanInitParam.searchRadiusFirstIteration = 1000;
%optional input
parameters.diagnostics = 0; %if you want to plot the histogram of linking distances up to certain frames, indicate their numbers; 0 or empty otherwise. Does not work for the first or last frame of a movie.

costMatrices(1).parameters = parameters;


%function name
costMatrices(2).funcName = 'costMatRandomDirectedSwitchingMotionCloseGaps';

%parameters needed all the time
parameters.linearMotion = 1; %use linear motion Kalman filter.

parameters.minSearchRadius = 10; %minimum allowed search radius.
parameters.maxSearchRadius = 1000; %maximum allowed search radius, nm.
parameters.brownStdMult = 3*ones(gapCloseParam.timeWindow,1); %multiplication factor to calculate Brownian search radius from standard deviation.

%power for scaling the Brownian search radius with time, before and
%after timeReachConfB (next parameter). Note that it is only the gap
%value which is powered, then we have brownStdMult*powered_gap*sig*sqrt(dim)
parameters.brownScaling = [0.25 0.01];
% parameters.timeReachConfB = 3; %before timeReachConfB, the search radius grows with time with the power in brownScaling(1); after timeReachConfB it grows with the power in brownScaling(2).
parameters.timeReachConfB = gapCloseParam.timeWindow; %before timeReachConfB, the search radius grows with time with the power in brownScaling(1); after timeReachConfB it grows with the power in brownScaling(2).

parameters.ampRatioLimit = [0.7 4]; %for merging and splitting. Minimum and maximum ratios between the intensity of a feature after merging/before splitting and the sum of the intensities of the 2 features that merge/split.

parameters.lenForClassify = 5; %minimum track segment length to classify it as linear or random.

parameters.useLocalDensity = 1; %1 if you want to expand the search radius of isolated features in the gap closing and merging/splitting step.
parameters.nnWindow = gapCloseParam.timeWindow; %number of frames before/after the current one where you want to look for a track's nearest neighbor at its end/start (in the gap closing step).

parameters.linStdMult = 1*ones(gapCloseParam.timeWindow,1); %multiplication factor to calculate linear search radius from standard deviation.

parameters.linScaling = [0.25 0.01]; %power for scaling the linear search radius with time (similar to brownScaling).
% parameters.timeReachConfL = 4; %similar to timeReachConfB, but for the linear part of the motion.
parameters.timeReachConfL = gapCloseParam.timeWindow; %similar to timeReachConfB, but for the linear part of the motion.

parameters.maxAngleVV = 360; %maximum angle between the directions of motion of two tracks that allows linking them (and thus closing a gap). Think of it as the equivalent of a searchRadius but for angles.

%optional; if not input, 1 will be used (i.e. no penalty)
parameters.gapPenalty = 1; %penalty for increasing temporary disappearance time (disappearing for n frames gets a penalty of gapPenalty^n).

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

% movieInfo.getStruct()

%% Save results as JSON
%{
encoded = jsonencode(tracks);

fid = fopen(strcat(saveFolder,'tracks.json'),'w');
fprintf(fid,'%s',encoded);
fclose(fid); 
%}

%% Converting tracksFinal into something more manageable
tracksOr = struct;
nTrack = length(tracksFinal);
% be sure to have swift (really sim) as a double variable, NOT table (loses precision)!!!

for i = 1:nTrack
    tracksOr(i).frame = tracks(i).t;
    tracksOr(i).xLoc = tracks(i).x;
    tracksOr(i).yLoc = tracks(i).y;
    tracksOr(i).zLoc = tracks(i).z;
    %{
    for j = 1:length(tracksOrg(i).xLoc)
        rightX = swift(:,1) == tracks(i).x(j);
        rightY = swift(:,2) == tracks(i).y(j); 
        rightZ = swift(:,3) == tracks(i).z(j); 
        id = find(rightX & rightY & rightZ);
        if max(rightX) == 0 %important for when there's gaps
            tracksOrg(i).molID(j) = NaN;
        else 
        molID = swift(id,10); % col 10 has molID preserved
        tracksOrg(i).molID(j) = molID;
        end 
    end 
    %}
   %  tracksOrg(i).precisionx = % need to figure out if way to maybe draw
   %  this from movieInfo??? not really necessary at the moment
   % tracksOrg(i).precisiony = 
   % tracksOrg(i).precisionz = 

end 
tracksOrg = horzcat(tracksOrg,tracksOr); % combine all cycles
end 
save('tracksOrg640','tracksOrg')

% .tracksCoordAmpCG: The positions and amplitudes of the tracked
%                              features, after gap closing. Number of rows
%                              = number of track segments in compound
%                              track. Number of columns = 8 * number of
%                              frames the compound track spans. Each row
%                              consists of
%                              [x1 y1 z1 a1 dx1 dy1 dz1 da1 x2 y2 z2 a2 dx2 dy2 dz2 da2 ...]


%% Comparing to Swift (see Lexy data tracker)
%{
locs = zeros(length(tracksOrg),1);
for i = 1:length(tracksOrg)
locs(i) = length(tracksOrg(i).frame);
end 
length(find(locs>10));
%}
