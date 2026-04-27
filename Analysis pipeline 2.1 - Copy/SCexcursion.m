%% file set-up (just like everything else!)
%{
s = filesep;
rootdir = uigetdir(pwd,'Select folder containing single microscopy day');
expdir = append(rootdir,s,'Experiments');
top = dir(expdir);
top = natsortfiles(top);
folderlist = top([top.isdir]);
explist = folderlist(~ismember({folderlist(:).name},{'.','..'})); % only experimental gonad folders
numFolders = length(explist); % gonads
expName = {explist.name};

cd(expdir)
for f = 1:numFolders
    naddir = append(expdir,s,string(expName(f))); % go into each gonad folder
    cd(naddir)
    tracksToUse = 
%}
%% on and off rates (SC+Nuc)
% STEP 0: replace inSC NaNs with 12 (this makes stuff a bit easier)

nTrack = length(tracksToUse);
for i = 1:nTrack
    for j = 1:length(tracksToUse(i).inSC)
        if isnan(tracksToUse(i).inSC(j))
            tracksToUse(i).inSC(j) = 12;
        end 
    end 
end 

% STEP 1: Get SC segments
subs = struct([]);
for n = 1:nTrack
    subsequences = struct([]);
    if isempty(find(tracksToUse(n).inSC==1, 1)) % nothing in SC, just as a double check
    else 
    startIdx = find(tracksToUse(n).inSC == 1);
    endIdx   = find(tracksToUse(n).inSC == 0);
    if isempty(endIdx) % entirely in SC
        endIdx = startIdx(end); % grab last 1
    else 
        endIdx = vertcat(find(tracksToUse(n).inSC==0),startIdx(end)); %startIdx; % otherwise, hm.... 
    end 
    
    lastEnd = 0; % Track last subsequence end index

    % Loop through start indices
    for i = 1:length(startIdx)
        if startIdx(i) <= lastEnd
            continue; % Skip if inside previous subsequence
        end

        % Find the first end index after this start
        nextEnd = endIdx(find(endIdx >= startIdx(i), 1, 'first'));
        if ~isempty(find(tracksToUse(n).inSC(startIdx(i):nextEnd)==0, 1))
            nextEnd = nextEnd - 1;
        end 

        if ~isempty(nextEnd)
            subsequences(end+1).seqs = tracksToUse(n).inSC(startIdx(i):nextEnd);
            subsequences(end).idx = startIdx(i):nextEnd;
            subsequences(end).track = n;
            lastEnd = nextEnd; % Update last end to avoid overlaps
        end
    end 
    end
    subs = horzcat(subs,subsequences);
end

% cleanup: kick out trailing 12s (because I am not inclined to figure it
% out in the above loop)

nSeqs = length(subs);
for i = 1:nSeqs
    if subs(i).seqs(end) == 12 % check if has trailing 12s
        lastOne = find(subs(i).seqs == 1, 1, 'last' );
        subs(i).seqs = [subs(i).seqs(1:lastOne)];
    end 
end 

% final filtering - not necessary here?
%{
ID = zeros(nSeqs,1);
for i = 1:nSeqs
    inSC = length(find(subs(i).seqs==1));
    Nans = length(find(subs(i).seqs==12));
    percSC = inSC/(inSC+Nans);
    if length(subs(i).seqs) >= minLocs && percSC >= maxBlink
        ID(i) = 1;
    end 
end 
ID = logical(ID);
subs = subs(ID);
%}

% get xLoc, yLoc, frame - for reference
nSeqs = length(subs);
for i = 1:nSeqs
    id = (subs(i).idx)';
    subs(i).xCoord = tracksToUse(subs(i).track).xLoc(id);
    subs(i).yCoord = tracksToUse(subs(i).track).yLoc(id);
    subs(i).frame = tracksToUse(subs(i).track).frame(id);
    subs(i).cycle = tracksToUse(subs(i).track).cycle(id);
    subs(i).sc = tracksToUse(subs(i).track).inSC(id);
    subs(i).length = length(subs(i).sc);
end 

% kick out "trailing" SC segments that never enter the nuc again
for i = 1:nSeqs
    track = subs(i).track;
    if subs(i).idx(end) == tracksToUse(track).length
        subs(i).length = [];
    end 
end 

% STEP 2: Actual analysis :)
locTime = 0.1; % conversion to seconds
data = (locTime*([subs(:).length])); data = data';
% histogram(data); % figure
figure;
h = histfit(data,[],'exponential'); % h(1) is histogram, h(2) is density curve, KEEP FIGURE OPEN
params = fitdist(data,'Exponential');
mu = params.mu; % for mean time in SC
std = sqrt(params.ParameterCovariance);
mu
std

Xdata = h(1).XData; Xdata = Xdata';
Ydata = h(1).YData; Ydata = Ydata'; 

[f,gof] = fit(Xdata,Ydata,"exp1");
f.b; % exponent term
gof.rsquare;
save('expFit2',"Xdata","Ydata","f","gof","mu","std")
%end

%% Junk -- for reference and scratch work
%{
%% SC excursion time - use with SConly segments
tracksToUse; % load in somehow
nTracks = length(tracksToUse);

% initialze
SCperc = zeros(nTracks,1);

% actual stuff
for i = 1:nTracks
    nLocs_inSC = sum([tracksToUse(i).inSC]);
    SCperc(i) = nLocs_inSC/tracksToUse.numLocs;
    maxSCperc(i)  % longest stretch of being in the SC/total locs
end 

%% combine all tracks lengths to get ensemble stats

data = ([tracksToUse(:).length])';
% histogram(data,"Normalization","pdf");
h = histfit(data,[],'exponential'); % h(1) is histogram, h(2) is density curve, KEEP OPEN
params = fitdist(data,'Exponential');
mu = params.mu;

Xdata = h(1).XData; Xdata = Xdata';
Ydata = h(1).YData; Ydata = Ydata'; 
% Yfit = exppdf(Xdata,mu);

[f,gof] = fit(Xdata,Ydata,"exp1");
f.b; % exponent term
gof.rsquare;
save('expFit',"Xdata","Ydata","f","gof","mu")

% Resids = Ydata - Yfit;


% try to do residual analysis

% Fit to a normal (or a different distribution if you choose) - great, this
% works, but normalizes everything to fitdist's pdf stuff... also, bins are
% technically not correct, but no way to change that in fitdist??? (don't
% start from 0, start from 10). Histfit automatically does this, but
% doesn't have correct scaling... so... 
%{
pd = fitdist(data,'Exponential');
% Find the pdf that spans the disribution
x_pdf = linspace(min(data),max(data));
y_pdf = pdf(pd,x_pdf);
% Plot
figure
hold
histogram(data,'Normalization','pdf')
line(x_pdf,y_pdf,'LineWidth',2)
%}

%% different way to do resid analysis
%  curveFitter for intuition
figure; hold on;
histfit(data,[],'exponential');
histfit(data,[],'Gamma');
pdExp = fitdist(data,'Exponential');
pdother = fitdist(data,'Gamma');


figure; hold on;
exp = qqplot(data,pdExp); % h(1) for dots, h(2) for line
exp(1).Color = 'r';
exp(2).Color = 'r';
other = qqplot(data,pdother);
other(1).Color = 'g';
other(2).Color = 'g';
mle

%% curve fitter version
[fitobject,gof,output]=fit(Xdata,Ydata,'exp1');
%}