function varargout=anovanFromSumStat(varargin)
% The program can perform n-way ANOVA (when run in 'calc' mode) on an array
% which has been created by the program run in 'gen' (=generation) mode. 
% The program runs in different modes depending on the arguments:
% - anovanFromSumStat('ver')
%   The version of the program is displayed.
%
% - anovaArray=anovanFromSumStat('gen')
%   An array is created holding the means, SDs and number of elements in 
%   each group of data. The program will ask for the number of factors and
%   you will have to give the number of levels of each factor using a GUI.
%   Then, the mean, SD and number of elements in each group will have to be
%   specified using another GUI. This GUI asks for the mean, SD and N in
%   the following manner:
%                   mean     SD     N
%   A(1)B(1)C(1) - mean, SD and N of levels 1,1,1 of factors A,B,C, resp.
%   A(1)B(1)C(2) - mean, SD and N of levels 1,1,2 of factors A,B,C, resp.
%   The data will be saved in an array with the following structure:
%   First dimension: levels of the first factor
%   ...
%   nth dimension: levels of the last factor
%   n+1 dimension: mean, SD and n of the group
%
% - anovaArray=anovanFromSumStat('gen',[l1,l2,l3...])
%   The same as above but the number of levels of each factor
%   [l1,l2,l3,...] is given as the second argument.
%
% - anovaArray=anovanFromSumStat('regen',anovaArray)
%   The program modifies the anovaArray created using the 'gen' option.
%
% - varargout=anovanFromSumStat('calc',anovaArray)
%   The program evaluates the anovaArray created when running the program
%   with 'gen' as the first argument. The matrix of marginal means is
%   returned as the first output argument. Example for the structure of 
%   this matrix:
%
%   means of the anovaArray:   number of elements     matrixOfMarginalMeans:
%                              of the anovaArray:
%      1  2  3                      10 20 30          1    2    3    2.33
%      4  5  6                      40 50 60          4    5    6    5.13
%                                                     3.4  4.1  5    4.33
%
%   (1*10+2*20+3*30)/(10+20+30)=2.33
%   (1*10+4*40)/(10+40)=3.4
%   The number in the lower right corner is the global mean.
%
%   Marginal frequencies are returned as the second output argument. The
%   structure of this matrix is the same as that of the first output
%   argument. For the example above:
%   10  20  30  60
%   40  50  60  150
%   50  70  90  210
%
%   Main effects and interaction effects are tested ('modell','full' option
%   of the anovan command of Matlab).
%   IF THE SAMPLE SIZES ARE UNEQUAL AND THE NUMBER OF FACTORS IS AT LEAST
%   TWO, THE HARMONIC MEAN OF THE SAMPLE SIZES IS USED (HOWELL:STATISTICAL
%   METHODS FOR PSYCHOLOGY). THIS WILL ONLY BE AN APPROXIMATION OF THE 
%   RESULTS OBTAINED BY THE TYPE 3 SUM OF SQUARES USED BY MOST STATISTICAL
%   PROGRAMS (E.G. ANOVAN IN MATLAB, SPSS, SIGMASTAT).
%
%   Output arguments:
%   varargout{1}=marginal means
%   varargout{2}=marginal frequencies
%   varargout{3}=table of main and interaction effects. Each row
%                corresponds to a term, each column corresponds to a
%                factor. Those factors are calculated which have 1s in
%                their column. This specification is similar to how
%                'modeltype' interprets the main and interaction effects in
%                the anovan command of Matlab. The MS, SS, df, F and p
%                arrays are arranged according to this table.
%   varargout{4}=array of sums of squares (SS)
%   varargout{5}=array of mean squares (MS)
%   varargout{6}=array of degrees of freedom
%   varargout{7}=array of F
%   varargout{8}=array of p
%   varargout{9}=[SSwithin,MSwithin] (SSwithin is a.k.a. SSerror)
%   varargout{10}=[SSbetween,MSbetween] (SSbetween is a.k.a. SScells)
%   varargout{11}=SStot;
%
% Written by Peter Nagy. (Email:peter.v.nagy@gmail.com, http://peternagy.webs.com).
versionText='1.01';
if nargin==0
    errordlg('Tell me what to do...','Oops');
    return;
end
typeOfAction=varargin{1};
switch typeOfAction
    case 'ver' % program version is displayed
        disp(['I''m version ',versionText,'.',char(13),'Written by Peter Nagy (Email:peter.v.nagy@gmail.com, http://peternagy.webs.com)']);
        varargout{1}=versionText;
    case {'gen','regen'} % generate or modify ANOVA matrix
        scrsz=get(0,'ScreenSize');
        btnsz=[60,30];
        switch typeOfAction
            case 'gen'
                switch nargin
                    case 1 % GUI input
                        dlgsz=[300,300];
                        dh=dialog('Name','Number of factors and levels','units','pixels','position',[scrsz(3)/2-dlgsz(1)/2,scrsz(4)/2-dlgsz(2)/2,dlgsz],'windowstyle','normal','toolbar','none','menubar','none');
                        uicontrol('parent',dh,'units','pixels','style','text','fontsize',10,'string','Number of factors','position',[10,dlgsz(2)-30,150,20]);
                        uicontrol('parent',dh,'units','pixels','style','edit','fontsize',10,'position',[200,dlgsz(2)-30,50,20],'callback',@editNFactor_callback);
                        uicontrol('parent',dh,'units','pixels','style','pushbutton','fontsize',10,'string','Done','position',[dlgsz(1)/3-btnsz(1)/2 10 btnsz],'callback',{@done_callback});
                        uicontrol('parent',dh,'units','pixels','style','pushbutton','fontsize',10,'string','Cancel','position',[2*dlgsz(1)/3-btnsz(1)/2 10 btnsz],'callback',{@cancel_callback});
                        set(dh,'closerequestfcn',@close_callback);
                        guidata(dh,{'',0,0});
                        % guidata
                        % 1 - type of exit
                        % 2 - table handle
                        % 3 - table data
                        uiwait(dh);
                        dataFromGui=guidata(dh);
                        delete(dh);
                        if strcmp(dataFromGui{1},'cancel')
                            varargout{1}=0;
                            return;
                        end
                        nLevels=dataFromGui{3};
                        nFactors=size(nLevels,1);
                    case 2
                        nLevels=varargin{2};
                        if ~iscolumn(nLevels)
                            nLevels=nLevels';
                        end
                        nFactors=numel(nLevels);
                    otherwise
                        errordlg('Number of arguments has to be either one (anovanFromSumStat(''gen'') - GUI input) or two (anovanFromSumStat(''gen'',[number of levels in each factor]) - command-line input','Oops');
                        varargout{1}=0;
                        return;
                end
            case 'regen'
                anovaDataInput=varargin{2};
                nFactors=ndims(anovaDataInput)-1;
                sADI=size(anovaDataInput);
                nLevels=sADI(1:end-1)';
        end
        % fill ANOVA matrix
        factorList=generateIndexArray(nLevels,ones(numel(nLevels),1));
        tableData=cell(prod(nLevels),4);
        maxLength=0;
        for i=1:prod(nLevels)
            rowname='';
            for j=1:nFactors
                rowname=[rowname,char(64+j),'(',num2str(factorList(i,j)+1),')'];
            end
            tableData{i,1}=rowname;
            if length(rowname)>maxLength,maxLength=length(rowname);end
        end
        rowTitleColWidth=maxLength*7+10;
        dlgsz2=[150+rowTitleColWidth+40,300];
        if strcmp(typeOfAction,'regen')
            anovaDataInput=permute(anovaDataInput,[nFactors:-1:1,nFactors+1]);
            anovaDataInput=reshape(anovaDataInput,prod(nLevels),3);
            tableData(:,2:4)=num2cell(anovaDataInput);
        end
        dh2=dialog('Name','Enter mean, SD and N','units','pixels','position',[scrsz(3)/2-dlgsz2(1)/2,scrsz(4)/2-dlgsz2(2)/2,dlgsz2],'windowstyle','normal','toolbar','none','menubar','none');
        uicontrol('parent',dh2,'units','pixels','style','pushbutton','fontsize',10,'string','Done','position',[dlgsz2(1)/3-btnsz(1)/2 10 btnsz],'callback',{@done_callback});
        uicontrol('parent',dh2,'units','pixels','style','pushbutton','fontsize',10,'string','Cancel','position',[2*dlgsz2(1)/3-btnsz(1)/2 10 btnsz],'callback',{@cancel_callback});
        handleOfTable=uitable('parent',dh2,'units','pixels','data',tableData,'ColumnName',{'','mean','SD','N'},'RowName',[],'columnformat',{'char','numeric','numeric','numeric'},'columnwidth',{rowTitleColWidth,50,50,50},'columneditable',[false,true,true,true],'Position',[10 50 rowTitleColWidth+170 220]);
        set(dh2,'closerequestfcn',@close_callback);
        guidata(dh2,{'',handleOfTable,0});
        % guidata
        % 1 - type of exit
        % 2 - table handle
        % 3 - table data
        uiwait(dh2);
        dataFromGui2=guidata(dh2);
        delete(dh2);
        if strcmp(dataFromGui2{1},'cancel')
            varargout{1}=0;
            return;
        end
        tempData=dataFromGui2{3}(:,2:end);
        indexOfEmpty=cellfun(@isempty,tempData);
        tempData(indexOfEmpty)={0};
        anovaData=cell2mat(tempData);
        anovaArray=reshape(anovaData,[fliplr(nLevels'),3]);
        anovaArray=permute(anovaArray,[nFactors:-1:1,nFactors+1]);
        varargout{1}=anovaArray;        
    case 'calc' % calculate n-way ANOVA
        switch nargin
            case 1
                errordlg('Number of arguments has to be two: anovanFromSumStat(''calc'',anovaArray)','Oops');
                varargout{1}=0;
                return;
            case 2
                anovaArray=varargin{2};
                nFactors=ndims(anovaArray)-1;
                nLevels=size(anovaArray);
                nLevels=nLevels(1:end-1);
                means=extractDimension(anovaArray,1);
                sds=extractDimension(anovaArray,2);
                ns=extractDimension(anovaArray,3);
                if nFactors>1 && sum(ns(1)==ns(:))~=numel(ns)
                    disp(['Since sample sizes are unequal, their harmonic mean will be used.',char(13),'Results will only be approximations of those obtained by the type III sum of squares.']);
                    corrNs=ones(size(ns))*numel(ns)/sum(1./ns(:));
                else
                    corrNs=ns;
                end
                numOfDiffMeans=2^nFactors-1;
                arrayOfDiffMeans=generateAllSubsets(numOfDiffMeans,1);
                % calculate marginal means
                corrMarginalMeans=zeros(nLevels+1);
                marginalMeans=zeros(nLevels+1);
                marginalNs=zeros(nLevels+1);
                corrMarginalNs=zeros(nLevels+1);
                for i=1:size(arrayOfDiffMeans,1)
                    % calculate mean(i..), mean(ij.), mean(ijk), ...
                    indexArray=generateIndexArray(nLevels,arrayOfDiffMeans(i,:));
                    if iscell(indexArray)
                        for j=1:numel(indexArray)
                            indicesToSum=sub2ind_nDimArrayOfSubs(size(means),indexArray{j}+1);
                            marginalMeans(sub2ind_nDimArrayOfSubs(size(marginalMeans),whereToStoreMarginalMean(arrayOfDiffMeans(i,:),indexArray{j},nLevels)))=sum(means(indicesToSum).*ns(indicesToSum))/sum(ns(indicesToSum));
                            corrMarginalMeans(sub2ind_nDimArrayOfSubs(size(marginalMeans),whereToStoreMarginalMean(arrayOfDiffMeans(i,:),indexArray{j},nLevels)))=sum(means(indicesToSum).*corrNs(indicesToSum))/sum(corrNs(indicesToSum));
                            marginalNs(sub2ind_nDimArrayOfSubs(size(marginalNs),whereToStoreMarginalMean(arrayOfDiffMeans(i,:),indexArray{j},nLevels)))=sum(ns(indicesToSum));
                            corrMarginalNs(sub2ind_nDimArrayOfSubs(size(marginalNs),whereToStoreMarginalMean(arrayOfDiffMeans(i,:),indexArray{j},nLevels)))=sum(corrNs(indicesToSum));
                        end
                    else
                        indicesToSum=sub2ind_nDimArrayOfSubs(size(means),indexArray+1);
                        marginalMeans(sub2ind_nDimArrayOfSubs(size(marginalMeans),indexArray+1))=means(indicesToSum);
                        corrMarginalMeans(sub2ind_nDimArrayOfSubs(size(marginalMeans),indexArray+1))=means(indicesToSum);
                        marginalNs(sub2ind_nDimArrayOfSubs(size(marginalNs),indexArray+1))=ns(indicesToSum);
                        corrMarginalNs(sub2ind_nDimArrayOfSubs(size(marginalNs),indexArray+1))=corrNs(indicesToSum);
                    end
                end
                % calculate sum of squares (SS)
                % ssWithin is a.k.a. ssError
                % ssBetween is a.k.a. ssCells
                grandMean=sum(means(:).*ns(:))/sum(ns(:));
                corrGrandMean=sum(means(:).*corrNs(:))/sum(corrNs(:));
                marginalMeans(end)=grandMean;
                marginalNs(end)=sum(ns(:));
                corrMarginalMeans(end)=corrGrandMean;
                corrMarginalNs(end)=sum(corrNs(:));
                ssBetween=sum((means(:)-corrGrandMean).^2.*corrNs(:));
                ssWithin=sum(sds(:).^2.*(corrNs(:)-1));
                ssTot=ssBetween+ssWithin;
                dfWithin=sum(corrNs(:))-prod(nLevels);
                dfBetween=prod(nLevels)-1;
                msWithin=ssWithin/dfWithin;
                msBetween=ssBetween/dfBetween;
                ssArray=zeros(size(arrayOfDiffMeans,1),1);
                dfArray=zeros(size(ssArray));
                for i=1:size(arrayOfDiffMeans,1)
                    indexArray2=generateIndexArray2(nLevels+1,arrayOfDiffMeans(i,:));
                    indicesToSum=zeros(size(indexArray2,1),size(indexArray2{1},1));
                    for j=1:size(indexArray2,1)
                        indicesToSum(j,:)=sub2ind_nDimArrayOfSubs(size(marginalMeans),indexArray2{j});
                    end
                    ssTemp=zeros(1,size(indicesToSum,2));
                    for j=1:size(indicesToSum,2)
                        ssTemp(j)=ssTemp(j)+sum(corrMarginalMeans(indicesToSum(:,j)).*cell2mat(indexArray2(:,2)));
                    end
                    ssTemp=ssTemp.^2;
                    ssArray(i)=sum(ssTemp.*corrMarginalNs(indicesToSum(1,:)));
                    dfArray(i)=prod(nLevels(arrayOfDiffMeans(i,:)==1)-1);
                end
                msArray=ssArray./dfArray;
                fArray=msArray/msWithin;
                pArray=1-fcdf(fArray,dfArray,dfWithin);
                % generate output arguments
                varargout{1}=marginalMeans;
                varargout{2}=marginalNs;
                varargout{3}=arrayOfDiffMeans;
                varargout{4}=ssArray;
                varargout{5}=msArray;
                varargout{6}=dfArray;
                varargout{7}=fArray;
                varargout{8}=pArray;
                varargout{9}=[ssWithin,msWithin];
                varargout{10}=[ssBetween,msBetween];
                varargout{11}=ssTot;
        end
    otherwise
        errordlg('First argument has to be ''gen'', ''regen'', ''calc'' or ''ver''.','Oops');
        varargout{1}=0;
end

function indexList3=generateIndexArray2(numLevels,whichMarginal)
% numLevels contains the size of the matrix holding the marginal means
numFactors=numel(numLevels);
indexList=zeros(prod(numLevels),numFactors);
cumNumLevels=generateCumNumLevels(numLevels,ones(numFactors,1));
for i=1:prod(numLevels)
    indexList(i,:)=dec2StrangeNumSys(i,cumNumLevels);
end
indexList2=zeros(sum((numLevels-1).*whichMarginal),numFactors);
counter=1;
for i=1:size(indexList,1)
    if sum(indexList(i,:)+1==(indexList(i,:)+1).*whichMarginal+(whichMarginal==0).*numLevels-(whichMarginal.*(indexList(i,:)+1)==numLevels))==size(indexList,2)
        indexList2(counter,:)=indexList(i,:)+1;
        counter=counter+1;
    end
end
onlyOnes=whichMarginal(whichMarginal==1);
arrayOfDiffMeans2=generateAllSubsets(2^sum(onlyOnes)-2,0);
indexList3=cell(size(arrayOfDiffMeans2,1)+1,2);
indexList3{1,1}=indexList2;
indexList3{1,2}=1;
for j=1:size(arrayOfDiffMeans2,1)
    tempArray=whichMarginal;
    tempArray(whichMarginal==1)=arrayOfDiffMeans2(j,:);
    tempList=indexList2;
    placeOfMismatch=tempArray~=whichMarginal;
    numLevelsExpanded=numLevels(ones(size(tempList,1),1),:);
    tempList(:,placeOfMismatch)=numLevelsExpanded(:,placeOfMismatch);
    indexList3{j+1,1}=tempList;
    numOfMismatch=sum(placeOfMismatch);
    if mod(numOfMismatch,2)==0
        indexList3{j+1,2}=1;
    else
        indexList3{j+1,2}=-1;
    end
end


function newArray=extractDimension(origArray,whichLastDim)
nLastDim=size(origArray,ndims(origArray));
nElementsInNMinusOneDim=numel(origArray)/nLastDim;
newArray=origArray(1+(whichLastDim-1)*nElementsInNMinusOneDim:whichLastDim*nElementsInNMinusOneDim);
sizeOfOrig=size(origArray);
newArray=reshape(newArray,sizeOfOrig(1:end-1));

function listOfIndices=sub2ind_nDimArrayOfSubs(sizeOfArray,matrixOfSubs)
shiftMatrix=-1*ones(1,size(matrixOfSubs,2));
shiftMatrix(1)=0;
shiftMatrix=shiftMatrix(ones(size(matrixOfSubs,1),1),:);
matrixOfSubs=matrixOfSubs+shiftMatrix;
multMatrix=cumprod(sizeOfArray(1:end-1));
if iscolumn(multMatrix),multMatrix=multMatrix';end
multMatrix=[1,multMatrix];
multMatrix=multMatrix(ones(size(matrixOfSubs,1),1),:);
listOfIndices=multMatrix.*matrixOfSubs;
listOfIndices=sum(listOfIndices,2);

function placeToStore=whereToStoreMarginalMean(indexOfMarginal,indexOfMeans,numLevels)
placeToStore=(indexOfMarginal==1).*(indexOfMeans(1,:)+1)+(indexOfMarginal==0).*(numLevels+1);

function indexList2=generateIndexArray(numLevels,whichMarginal)
numFactors=numel(numLevels);
indexList=zeros(prod(numLevels),numFactors);
cumNumLevels=generateCumNumLevels(numLevels,ones(numFactors,1));
for i=1:prod(numLevels)
    indexList(i,:)=dec2StrangeNumSys(i,cumNumLevels);
end
if sum(whichMarginal)==numel(whichMarginal) % if all elements of whichMarginal are 1
    indexList2=indexList;
else
    cellArraySize=prod(numLevels(whichMarginal==1));
    indexList2=cell(cellArraySize,1);
    for i=1:cellArraySize
        cumNumLevels2=generateCumNumLevels(numLevels,whichMarginal);
        indices=dec2StrangeNumSys(i,cumNumLevels2);
        counter=1;
        for j=1:size(indexList,1)
            if sum(indices~=indexList(j,whichMarginal==1))==0
                indexList2{i}(counter,:)=indexList(j,:);
                counter=counter+1;
            end
        end
    end
end

function cnl=generateCumNumLevels(numberOfLevels,whichChosen)
numberOfLevels2=numberOfLevels(whichChosen==1);
numberOfFactors2=numel(numberOfLevels2);
cnl=ones(numberOfFactors2,1);
for i=1:numberOfFactors2-1
    cnl(i)=prod(numberOfLevels2(i+1:numberOfFactors2));
end

function strangeNum=dec2StrangeNumSys(decimalValue,cumNumberOfLevels)
nFact=numel(cumNumberOfLevels);
strangeNum=zeros(1,nFact);
for j=1:nFact
    if j~=1
        currentValue=decimalValue-1-sum(strangeNum(1:j-1).*cumNumberOfLevels(1:j-1)');
    else
        currentValue=decimalValue-1;
    end
    strangeNum(j)=floor(currentValue/cumNumberOfLevels(j));
end

function strangeNum=dec2ArbNumSys(decimalValue,posValues,padding)
% CURRENTLY UNUSED
% The function converts decimalValue into an arbitrary numeric system whose positional
% values are given by posValues. If padding==1, then the same number of
% positional values are given as in posValues. If paddint==0, then the
% first zeros are eliminated. For the function to work, the last posValue
% has to be 1. If decimalValue cannot be represented using posValues, the
% output will be NaN.
strangeNum=zeros(numel(posValues),1);
i=1;
currentValue=decimalValue;
while i<=numel(posValues)
    strangeNum(i)=floor(currentValue/posValues(i));
    currentValue=currentValue-strangeNum(i)*posValues(i);
    i=i+1;
end
if currentValue~=0
    strangeNum=nan;
else
    if padding~=1 && strangeNum(1)==0
        whereZero=strangeNum==0;
        boundaryZero=diff(whereZero);
        lastZero=find(boundaryZero==-1,1);
        strangeNum=strangeNum(lastZero+1:end);
    end
end


function allSubsets=generateAllSubsets(numberOfValues,startValue)
nFactors=round(log(numberOfValues+1)/log(2));
if nFactors==0,nFactors=1;end
allSubsets=zeros(numberOfValues-startValue+1,nFactors);
counter=1;
for i=startValue:numberOfValues
    tempVal=dec2binPadded(i,nFactors);
    for j=1:nFactors
        allSubsets(counter,j)=str2double(tempVal(j));
    end
    counter=counter+1;
end

function binnedBin=dec2binPadded(decimalValue,paddedLength)
binnedBin=dec2bin(decimalValue);
if length(binnedBin)<paddedLength
    binnedBin=[repmat('0',[1,paddedLength-length(binnedBin)]),binnedBin];
end


function cancel_callback(src,evt)
tempData=guidata(src);
tempData{1}='cancel';
guidata(src,tempData);
uiresume;

function close_callback(src,evt)
tempData=guidata(src);
tempData{1}='cancel';
guidata(src,tempData);
uiresume;

function done_callback(src,evt)
tempData=guidata(src);
tempData{1}='done';
tempData{3}=get(tempData{2},'data');
guidata(src,tempData);
uiresume;


function editNFactor_callback(src,evt)
tempData=guidata(src);
handleOfTable=tempData{2};
handleOfDialog=get(src,'parent');
numFactors=str2double(get(src,'string'));
if handleOfTable~=0
    rownames=cell(numFactors,1);
    tableData=get(handleOfTable,'data');
    numRows=size(tableData,1);
    if numFactors>numRows
        tableData(numRows+1:numFactors)=0;
    elseif numFactors<numRows
        tableData=tableData(1:numFactors);
    end
    for i=1:numFactors
        rownames{i}=['Factor ',num2str(i)];
    end
    set(handleOfTable,'data',tableData,'RowName',rownames);
else
    rownames=cell(numFactors,1);
    tableData=zeros(numFactors,1);
    for i=1:numFactors
        rownames{i}=['Factor ',num2str(i)];
    end
    handleOfTable=uitable('parent',handleOfDialog,'units','pixels','data',tableData,'ColumnName',{'# of levels'},'RowName',rownames,'columnformat',{'numeric'},'columnwidth',{80},'columneditable',true,'Position',[50 50 200 200]);
end
tempData{2}=handleOfTable;
guidata(src,tempData);
