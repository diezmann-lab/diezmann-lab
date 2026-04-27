%% Sanity check for including NaNs as a part of SC tracks

% Regular JDs (i.e., definitely in SC)
SCjds = [];
nTracks = length(tracksToUse);
for i = 1:nTracks
    idx = ~isnan(tracksToUse(i).jd);
    hehe = tracksToUse(i).jd(idx);
    SCjds = vertcat(SCjds,hehe);   
end 
figure; hold on
SChist = histogram(SCjds,"Normalization","percentage","BinWidth",5); % blue

% NaN JDs (normalized for # dark frames) idk why I made it this
% complicated, but it works
NANjds = [];
nLags = 40;
for i = 1:nTracks
xDiffs = [];
yDiffs = [];
    id = isnan(tracksToUse(i).jd); % keep track of who supposed to be NaNs
    idNorm = zeros(length(id),1);
    for j = 1:length(id)
        if id(j) == 1 && j > 1
            idNorm(j) = idNorm(j-1) + id(j);
        elseif id(j) == 1 && j == 1 
            idNorm(j) = 1;
        else
            idNorm(j) = 0;
        end 
    end % get normalization factor
    if max(idNorm) == 0 % check if even need to do anything
    else 
    tempx = fillmissing(tracksToUse(i).xLoc,'previous');
    tempy = fillmissing(tracksToUse(i).yLoc,'previous');
    frames = length(tracksToUse(i).frame);
    for k = 1:min(nLags,frames-1)
        xDiffs(:,k) = [tempx(1+k:end)-tempx(1:end-k) ; nan(k-1,1)];
        yDiffs(:,k) = [tempy(1+k:end)-tempy(1:end-k) ; nan(k-1,1)];
    end 
    rawjd = sqrt(xDiffs(:,1).^2+yDiffs(:,1).^2); 
    rawjd(rawjd == 0) = NaN;
    nonzeroJDs = isnan(rawjd); % first filter index
    finalIdx = id - nonzeroJDs; finalIdx = logical(finalIdx); % get overlap with id NaN index (so only grab non-zero nans)
    nanjds = rawjd(finalIdx);
    norm = idNorm(finalIdx);
    for k = 1:length(norm)
    normalize(k) = norm(k)^(1/norm(k));
    end
    for z = 1:length(nanjds) % wasn't doing what I wanted it to do, so chucked in a for loop here
    normJD(z) = nanjds(z)/normalize(z); %sqrt(norm);
    end
    % grab only JDs that were once nans, normalize by dark frames
    NANjds = horzcat(NANjds,normJD);
    normalize = [];
    normJD = [];
    end
end 

NaNshist = histogram(NANjds,"Normalization","percentage","BinWidth",5); % orange

% for fun :) fails, but to be expected
[h,p,ks2stat] = kstest2(SChist.Data,NaNshist.Data);

% Nuc only JDs - from SC + Nuc tracks
% more indexing by inSC label... 
nucJDs = [];

for i = 1:nTracks
    for j = 1:length(tracksToUse(i).inSC)
        if tracksToUse(i).inSC(j) == 0 % in Nuc
            
        end 
    end 
end 