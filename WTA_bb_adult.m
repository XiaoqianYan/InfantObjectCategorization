% 2021 bigideas
% winner-take-all maximum correlation classification: split half of the
% trials 
% this is for oddball response
% data is partly preprocessed beforehand:
% 1. low-pass 30hz
% 2. detrend: ddataOut

%% step1&2: set path and read in EEG data and extra analyses
clear;close all;clc;
dirpath = '';
cd(dirpath)

set(0,'DefaultAxesFontSize',14,...
    'defaultTextFontName','Calibri',...
    'defaultAxesFontName','Calibri');

% the run number needs to be iterated separately, otherwise, the data
% entries will not be updated correctly, as the 3 mo group has most
% subjects!!
for run = 1
    if run < 5
        file1 = 'New3Groups_arrange_no_concat.mat';
        load(file1)
        if run == 1
            newData = groupData1;
            subjList_short = idx1;
            groupname = '3-4 months';
        elseif run == 2
            newData = groupData2;
            subjList_short = idx2;
            groupname = '4-6 months';
        elseif run == 3
            newData = groupData3;
            subjList_short = idx3;
            groupname = '6-8 months';
        elseif run == 4
            newData = groupData4;
            subjList_short = idx4;
            groupname = '12-15 months';
        end
    elseif run == 5
        adpath = '';
        cd(adpath)
        load('concat_arranged_data_oddball_adult4Hz.mat');
        bbtrials = 60;
        newData = cellfun(@(x) x(:,:,[1:bbtrials]),cdataOut,'uni',false);
        subjList_short = subjList;
        groupname = 'Adults_4Hz';
        dirpath = adpath;
    end

    %read in dataIn
    dataIn = cellfun(@(x) x*10^6,newData,'uni',false); %update here!!!
    [nsubj,ncon] = size(dataIn);
    nsess = cellfun(@(x) size(x,3), dataIn,'Uni', false);
    nsess = cell2mat(nsess);
    mnsess = round(mean(nsess(:)),0)
    sprintf('valid trials across conditions: %d',mnsess)

    LeftOT_bb = [57 58 59 64 65 63 68]; %removed chan68,63, removed 50
    RightOT_bb = [90 91 95 96 100 94 99]; %removed 101
    Posterior_bb = [71 76 75 70 69 74 82 83 89];%removed 66 72 84
    % roiname = 'pos54';
    roiname = 'OT+OCC';

    % temporal sliding window
    Freqlist = [0.8572 4.286]; sampling = 490; odds = 1/5; tduration = 1167; %ms
    winLenSamp = 14; % Temporal window length, in samples; % 17*2 ms
    winHopSamp = 14; % Temporal window hop size, in samples; %no overlapping between windows
    wintime = winLenSamp*1000/420;
    temp = dataIn{1,1};
    nsubj = size(dataIn,1);
    [nTime, nSpace, nTrial] = size(temp); % Dimensions of input data matrix
    nWins = floor((nTime - winLenSamp) / winHopSamp + 1); % # classifications
    winLen = round(winLenSamp*tduration/sampling,1);
    ncon = 5;
    % normalize or not, do zsocre across conditions for each electrode
    withZ = 1;
    allnansTrain = {};
    allnansTest = {};

    for subj = 1:nsubj
        for nc = 1:ncon % different condition has different trials
            tempd = dataIn{subj,nc};
            ntr = size(tempd,3);
            if run < 5
                tr1 = 1:2:ntr;
                tr2 = setdiff([1:ntr],tr1);
            else
                tr1 = [1:10,21:30,41:50];
                tr2 = [11:20,31:40,51:60];
            end
            temptrain{nc} = tempd(:,:,tr1);
            temptest{nc} = tempd(:,:,tr2);
        end
        %avg across trials, 10-s long, get 2D matrix per cell, time x elec
        train = cellfun(@(x) squeeze(nanmean(x,3)), temptrain, 'uni', false);
        test = cellfun(@(x) squeeze(nanmean(x,3)), temptest, 'uni', false);

        nancount_train = cellfun(@(x) find(isnan(x)),train,'uni',false);
        nancount_test = cellfun(@(x) find(isnan(x)),test,'uni',false);

        allnansTrain(subj,:) = nancount_train;
        allnansTest(subj,:) = nancount_test;

        %z-scoring -use zscore_merge.m function
        %normalize amplitudes across conditions for each electrode
        tempTrainZ(subj,:) = zscore_merge(train);
        tempTestZ(subj,:) = zscore_merge(test);
    end

    %  RERUN HERE TO UPDATE DIFFERENT ROIS !!!
    % Classify the data in each time window
    dataInX = tempTrainZ;
    dataInY = tempTestZ;
    exdata = [];
    allWins = [];correctC = [];CorrValSym =[];
    for subj = 1:nsubj
        xdata = dataInX(subj,:);
        ydata = dataInY(subj,:);
        offdiag = [];
        for ii = 1:ncon %rows for train
            X = xdata{ii}; 
            if ~isempty(find(isnan(X)))
                sprintf('%s has missing entries in the training set',subjList_short{subj})
                Xout = imputeAllNaN129(X');% need to be chans x time, 128x490
                XX = Xout';
            else
                XX = X;
            end
            XXX = [reshape(XX(:,LeftOT_bb),size(XX(:,LeftOT_bb),1)*size(XX(:,LeftOT_bb),2),1);...
                reshape(XX(:,Posterior_bb),size(XX(:,Posterior_bb),1)*size(XX(:,Posterior_bb),2),1);...
                reshape(XX(:,RightOT_bb),size(XX(:,RightOT_bb),1)*size(XX(:,RightOT_bb),2),1)];
            for jj = 1:ncon %column for test
                Y = ydata{jj};
                if ~isempty(find(isnan(Y)))
                    sprintf('%s has missing entries in the testing set',subjList_short{subj})
                    Yout = imputeAllNaN129(Y');% need to be chans x time, 128x490
                    YY = Yout';
                else
                    YY = Y;
                end
                YYY = [reshape(YY(:,LeftOT_bb),size(YY(:,LeftOT_bb),1)*size(YY(:,LeftOT_bb),2),1);...
                    reshape(YY(:,Posterior_bb),size(YY(:,Posterior_bb),1)*size(YY(:,Posterior_bb),2),1);...
                    reshape(YY(:,RightOT_bb),size(YY(:,RightOT_bb),1)*size(YY(:,RightOT_bb),2),1)];
                [r,p] = corrcoef(XXX,YYY);
                corrmat(ii,jj,subj) = r(1,2);
                pmat(ii,jj,subj) = p(1,2);
            end
        end

        %cal symmetric RSMs
        for r = 1:5
            for c = 1:5
                CorrValSym(r,c,subj) = 0.5*(corrmat(r,c,subj)+corrmat(c,r,subj));
            end
        end

        %measure distinctiveness
        for cc = 1:5
            cc_rest = setdiff([1:5],cc);
            value1 = CorrValSym(cc,cc,subj);
            value2 = nanmean(CorrValSym(cc,cc_rest));
            DistValue(cc,subj) = value1 - value2;
        end

        %winner-take-all: corrmat
        for con = 1:5
            set1 = corrmat(con,:,subj);
            set2 = corrmat(:,con,subj);
            wtaR = find(set1 == max(set1));
            wtaC = find(set2 == max(set2));
            if wtaC == con && wtaR == con % if both predictions are correct
                correctC(con,subj) = 1;
            elseif wtaC == con && wtaR ~= con % column one correct but row incorrect
                correctC(con,subj) = 0.5;
            elseif wtaC ~= con && wtaR == con % row one correct but column incorrect
                correctC(con,subj) = 0.5;
            else % both are incorrect
                correctC(con,subj) = 0;
            end
        end
    end

    % average across nboots
    Final_CorrValSym = CorrValSym;
    RSM.withZ = CorrValSym;
    CorrectC_ROI = correctC; %5xnsubj
    % save(fullfile(dirpath,['WTAresults_',roiname,'_',num2str(groupname),'.mat']),'Final_CorrValSym','CorrectC_ROI');

    %save correlation matrix
    save(fullfile(dirpath,['WTAresults_Distinctiveness_kgsv_noconcat_noROIavg_',roiname,'_',num2str(groupname),'.mat']), ...
        'CorrValSym','DistValue','correctC');

    %% plot RSMs
    %CorrValSym(r,c,subj)
    dothis = 1; dotest = 1;
    if dothis
        withZname = 'zsocre';
        meanCorrValSym = squeeze(mean(CorrValSym,3));%average across subj
        % individual RSM
        figure('units','normalized','outerposition',[0 0 1 1],'color','w');
        for subj = 1:nsubj
            subplot(4,5,subj)
            imagesc(CorrValSym(:,:,subj), [-0.5 0.5]); axis('image');cmap=mrvColorMaps('coolhot'); colormap(cmap);colorbar;
            myTitle = sprintf('RSM - %s',subjList_short{subj});
            title(myTitle, 'Interpreter','none');
            labels = {'Faces','Limbs','Corridors','Characters','Cars'};
            set(gca,'Xtick', [1:1:5], 'XtickLabel',labels)
            set(gca,'Ytick', [1:1:5], 'YtickLabel',labels)
            set(gca,'fontsize',14,'linewidth',1.2)
            axis square
        end
        sgtilname = groupname;
        sgtitle(sgtilname,'FontSize',18)
        withZname = 'zsocre';
        %     figname=(['RSM-' withZname,'-',roiname,'-win-',num2str(round(wintime,0)),'ms-', ...
        %         num2str(nboots),'nboots-',num2str(months) 'months-N',num2str(nsubj),'.tiff']);
        %     print(gcf,'-dtiff',fullfile(dirpath,figname),'-r300')
        figname=(['RSM-individual-' withZname,'-',roiname,'-',groupname,'-N',num2str(nsubj),'-noconcat-noROIavg-new.tiff']);
        print(gcf,fullfile(dirpath,figname),'-dtiff','-r300')
        close

        % group mean
        figure('position',[100 100 350 350],'color','w')
        imagesc(meanCorrValSym, [-0.5 0.5]); axis('image');cmap=mrvColorMaps('coolhot'); colormap(cmap);colorbar;
        myTitle = sprintf('%s',groupname);
%         title(myTitle, 'Interpreter','none','fontsize',16);
        xtickangle(90)
        labels = {'Faces','Limbs','Corridors','Characters','Cars'};
        set(gca,'Xtick', [1:1:5], 'XtickLabel',labels)
        set(gca,'Ytick', [1:1:5], 'YtickLabel',labels)
        set(gca,'fontsize',14,'linewidth',1.2)
        axis square
        figname=(['RSM-mean-' withZname,'-',roiname,'-',groupname,'-N',num2str(nsubj),'-noconcat-noROIavg-new.tiff']);
        print(gcf,fullfile(dirpath,figname),'-dtiff','-r300')
%         close all
    end
    if dotest
        indiv_face_mat = squeeze(CorrValSym(1,1,:));
        mean(indiv_face_mat)
        std(indiv_face_mat)
        [h,p,ci,stats] = ttest(indiv_face_mat)
    end
end
    %% mean decoding acc - subplot -infant
    bbpath = '';
    myColor = [1,0,0;
        0.929,0.694,0.125;
        0.466,0.674,0.188;
        0.1,0.1,0.1;
        0,0.447,0.741;];
    mygroupcolor = [254,204,92;
    151,207,95;
    46,147,200;
    37,52,148]./255;
    grouplists = {'3-4 months' '4-6 months' '6-8 months' '12-15 months' 'Across categories'};
    catCorrC = [];

    figure('position',[100 100 1350 360],'color','w')
    for run = 1:5
        if run < 5
            clear correctC
            load(sprintf('WTAresults_Distinctiveness_kgsv_noconcat_noROIavg_OT+OCC_%s.mat',grouplists{run}));
        end
        nsubj = size(correctC,2);
        mcorrC = mean(correctC,2);
        sd = std(correctC,[],2);
        se = sd./sqrt(nsubj);
        if run < 5
            temp_catCorrC = mean(correctC,1);
            catCorrC(run).data = temp_catCorrC;
            catCorrC(run).mean = mean(temp_catCorrC);
            catCorrC(run).sd = std(temp_catCorrC);
            catCorrC(run).se = catCorrC(1).sd/sqrt(nsubj);
        end
        if run < 5
            subplot_tight(1,4+1,run+1,[0.28 0.04])
            tempAcc = [];
            ttest_res = [];
            for i = 1:5
                hold on;
                b = bar(i,mcorrC(i));
                %                 err = errorbar(i,mcorrC(i),se(i),'LineStyle','none','Color',myColor(i,:),'linewidth',1.2);
                b.FaceColor = myColor(i,:);
                b.FaceAlpha = 0.5;
                b.EdgeColor = myColor(i,:);
%                 tempAcc = correctC(i,:);
%                 [h,p,ci,stats] = ttest(tempAcc,0.2,'Tail','right');
%                 ttest_res(i).p = p;
%                 ttest_res(i).stats = stats;
            end

        elseif run == 5
            subplot_tight(1,4+1,1,[0.28 0.055])
            for j = 1:4
                hold on;
                b = bar(j,catCorrC(j).mean);
                err = errorbar(j,catCorrC(j).mean,catCorrC(j).se,'LineStyle','none','Color',mygroupcolor(j,:),'linewidth',1.2);
                b.FaceColor = mygroupcolor(j,:);
                b.FaceAlpha = 0.5;
                b.EdgeColor = mygroupcolor(j,:);

                [h,p,ci,stats] = ttest(catCorrC(j).data,0.2,'Tail','right');
                ttest_res(j).p = p;
                ttest_res(j).stats = stats;
            end
        end

        hold on; 
        plot([0 6],[0.2 0.2],'linewidth',1.2,'linestyle','--','color',[0.5 0.5 0.5])
        if run < 5
            xticks([0:6])
            xticklabels({'' 'Across categories' 'Faces' 'Limbs' 'Corridors'  'Characters' 'Cars' ''})
            xlim([0 6])
        elseif run == 5
            xticks([0:5])
            xticklabels({'' '3-4 mo' '4-6 mo' '6-8 mo' '12-15 mo' ''})
            xlim([0 5])
        end
        xtickangle(90)
        yticks([0:0.2:1])
        yticklabels([0:0.2:1]*100)
        ylim([0 1])
        if run == 5
            ylabel('Decoding accuracy (%)')
        end
        set(gca,'linewidth',1.2,'fontsize',16)
        title(grouplists{run},'fontsize',18)
        if run < 5
            ax = gca;
            ax.YAxis.Visible = 'off';
        end
    end
    tresname = sprintf('WTA_ttest_results_allgroups_noROIavg_concat.mat');
    save(fullfile(bbpath,tresname),'catCorrC','ttest_res');
    figname = sprintf('TimeDomain_WTA_decodingACC_newgroups_OCC+OTrois_%s_noconcat_noROIavg_new.tiff','allGroups');
    print(gcf,fullfile(bbpath,figname),'-dtiff','-r300');
    %% mean decoding acc - adult 
    myColor = [1,0,0;
        0.929,0.694,0.125;
        0.466,0.674,0.188;
        0.1,0.1,0.1;
        0,0.447,0.741;];
    figure('position',[100 100 400 360],'color','w')
    for run = 5
        nsubj = size(correctC,2);
        mcorrC = mean(correctC,2);
        mcorrC_cat = mean(correctC,1)
        sd = std(mcorrC_cat);
        se = sd./sqrt(nsubj-1);

        hold on;
        b = bar(1,mean(mcorrC_cat));
        err = errorbar(1,mean(mcorrC_cat),se,'LineStyle','none','Color','k','linewidth',1.2);
        b.FaceColor = 'w';
        b.EdgeColor = 'k';
        b.LineWidth = 1.2;
        for con = 1:5
            b2 = bar(con+1,mcorrC(con));
            b2.FaceColor = myColor(con,:);
            b2.FaceAlpha = 0.5;
            b2.EdgeColor = myColor(con,:);
        end
        [h,p,ci,stats] = ttest(mcorrC_cat,0.2,'Tail','right');
        ttest_res.p = p;
        ttest_res.stats = stats;
       
        hold on; 
        plot([0 7],[0.2 0.2],'linewidth',1.2,'linestyle','--','color',[0.5 0.5 0.5])
        xticks([0:6])
        xticklabels({'' 'Mean' 'Faces' 'Limbs' 'Corridors'  'Characters' 'Cars'})
        xlim([0 7])
        xtickangle(90)
        yticks([0:0.2:1])
        yticklabels([0:0.2:1]*100)
        ylim([0 1])
        ylabel('Decoding accuracy (%)')
        set(gca,'linewidth',1.2,'fontsize',16)
    end
    tresname = sprintf('WTA_ttest_results_adults_noROIavg_concat.mat');
    save(fullfile(adpath,tresname),'ttest_res');
    figname = sprintf('TimeDomain_WTA_decodingACC_newgroups_OCC+OTrois_%s_noconcat_noROIavg_new.tiff','adults');
    print(gcf,fullfile(adpath,figname),'-dtiff','-r300');

    



