%% Clean up
clearvars
close all
% addpath(genpath('C:\Users\drguggiana\Dropbox\Bonhoeffer_code'))
%% Load the data structure

%define the main file path
model_path = 'R:\Share\Simon\Drago_Volker_Simon\Full_data_structure';

%load the file
%define the file tags
file_tags = {'_dataStruct'};
%allocate memory to store the data
all_data = cell(length(file_tags),1);

%for all the tags
for tags = 1:length(file_tags)
    %load the most recent file from the overlap ones
    listing = dir(strcat(model_path,'\*',file_tags{tags},'*.mat'));
    dates = datetime({listing.date});
    [~,ind] = max(dates);
    load_name = listing(ind).name;
    
    %load all the variables in the file
    load(fullfile(model_path,load_name));
end
%% Plot the distributions of the different values

close all

%define the fields to look at
field_list = {'excFracPerLayer','inhFracPerLayer','excRawPerLayer','inhRawPerLayer',...
    'excinhTotal','excSideBias','inhSideBias','overlapPerLayer'};
%define the layer list
layer_list = {'L2/3','L4','L5','L6'};
%define the polarity list
polar_list = {'Exc','Inh'};
%get the number of fields
field_num = length(field_list);

%for all the fields
for fields = 1:field_num
    %get the dimensionality of the field of interest
    field_dim = max(size(invitro_struct(1).(field_list{fields})));
    
    %show the distribution of the variables
    switch field_dim
        case 1
            figure
            %get the field of interest
            plot_mat = cat(2,invitro_struct(:).(field_list{fields}));
            histogram(plot_mat)
            title(field_list{fields})
        case 2
            figure
            %get the field of interest
            plot_mat = cat(2,invitro_struct(:).(field_list{fields}));
            %for the first dimension
            for fdim = 1:size(plot_mat,1)
                subplot(ceil(sqrt(size(plot_mat,1))),round(sqrt(size(plot_mat,1))),fdim)
                histogram(plot_mat(fdim,:))
                title(strcat(field_list{fields},' ',polar_list{fdim}))
            end
        case 4
            figure
            %get the field of interest
            plot_mat = cat(2,invitro_struct(:).(field_list{fields}));
            %for the second dimension, plot everything in subplots
            for fdim = 1:size(plot_mat,1)
                subplot(ceil(sqrt(size(plot_mat,1))),round(sqrt(size(plot_mat,1))),fdim)
                histogram(plot_mat(fdim,:))
                title(strcat(field_list{fields},' Layer: ',layer_list{fdim}))
            end     
    end
end
%% Assemble the matrix for PCA and clustering

%construct a single vector for each cell (normalized)
invitro_forpca = cat(1,[invitro_struct(:).excFracPerLayer],[invitro_struct(:).inhFracPerLayer],...
    [invitro_struct(:).excSideBias],[invitro_struct(:).inhSideBias],[invitro_struct(:).overlapPerLayer]);
%get rid of the NaNs
invitro_forpca(isnan(invitro_forpca)) = 0;

%normalize and transpose for the PCA
invitro_forpca = zscore(invitro_forpca');

%remove desired columns
invitro_forpca = invitro_forpca(:,[1 2 5 6 9:18]);

%show the matrix
figure
imagesc(invitro_forpca)
%% PCA the data

close all
%define the variable names
% invitro_vars = {'OL1','OL2/3','OL4','ODL','CL1','CL2/3','CL4','CDL','PD'};

%run a PCA on the normalized data
[invitro_coeff,invitro_score,invitro_latent] = pca(invitro_forpca);

figure
imagesc(invitro_score)
ylabel('Cells')
xlabel('PC space variables')
title('PC-weighted data')

figure
plot(invitro_latent./sum(invitro_latent))
hold('on')
yyaxis right
plot(cumsum(invitro_latent./sum(invitro_latent)))
title('PC normalized variance')

figure
imagesc(invitro_coeff)
% set(gca,'YTick',1:size(invitro_pca,2),'YTickLabels',invitro_vars)
set(gca,'XTick',1:size(invitro_forpca,1))
set(gca,'TickLabelInterpreter','none')
xlabel('PCs')
title('PCA loadings per variable')

%plot the first 3 PCs
figure
plot3(invitro_score(:,1),invitro_score(:,2),invitro_score(:,3),'*')
xlabel('PC1')
ylabel('PC2')
zlabel('PC3')
%% Determine the number of clusters

pc_num = 8;
link_type = 'complete';
dist_type = 'euclidean';
[shuf_cell,invitro_clunum,cutoff_dist] = shuffle_cluster_1(invitro_score,100,pc_num,invitro_forpca,link_type,dist_type,95);
%% Cluster the cells including the side bias index
close all
% %define the number of invitro_clusters
% invitro_clunum = 3;

%select the target PCs
ov_cluster = invitro_score(:,1:pc_num);
% %make NaNs 0s
% ov_cluster(isnan(ov_cluster)) = 0;

% ov_cluster = ov_cluster(1:48,:);

% %add the normalized depth information
% soma_norm = normr_2(soma_cent(:,2));
% side_norm = normr_2(side_bias);
% ov_cluster = cat(2,ov_cluster,soma_norm,side_norm);

% ov_cluster = ov_cluster(:,[2 3]);
%cluster using linkage and cluster so that I can get the indexes
l_tree = linkage(ov_cluster,link_type,dist_type);
invitro_clusters = cluster(l_tree,'maxclust',invitro_clunum);
%code to order the leaves more optimally
D = pdist(ov_cluster);
leafOrder = optimalleaforder(l_tree,D);
%plot the dendrogram
figure
dendrogram(l_tree,0,'orientation','top','Reorder',leafOrder)

% %get the limits of the soma center distribution (shifted to not leave the
% %last point at the edge
% soma_lim = [min(soma_cent(:,2))-1,max(soma_cent(:,2))+1];
soma_lim = cat(1,invitro_struct(:).pialD);
soma_lim = [min(soma_lim)-1,max(soma_lim)+1];
%plot maps of a set of invitro_clusters
%for all the invitro_clusters
for clu = 1:invitro_clunum
    %if the cluster only contains 1 cell
    if sum(invitro_clusters==clu)==1
        %skip it
        continue
    end
    %average the cells in question
%     clu_cells = squeeze(mean(invitro_maps(:,:,invitro_clusters==clu,:),3));

    %get the maps for this cluster
    clu_maps = cat(4,cat(3,invitro_struct(invitro_clusters==clu).excMap),...
        cat(3,invitro_struct(invitro_clusters==clu).inhMap));
    clu_cells = squeeze(mean(clu_maps,3));

    
    %create a figure for the combined plot
    h = figure;
    %plot the overlap map
    subplot(1,2,1)
    map_plot3(clu_cells,strcat('Cluster No:',num2str(clu),',Members:',num2str(sum(invitro_clusters==clu))),1,h,10,1)
    %get the depths in the cluster
    soma_clu = cat(1,invitro_struct(invitro_clusters==clu).pialD);
    %extract the side bias
    side_clu = cat(2,invitro_struct(invitro_clusters==clu).excSideBias);
    %use only the excitatory layer 2/3 one
    side_clu = side_clu(1,:); 
    %also plot the distribution of depths in the cluster
    subplot(1,2,2)
    plot(side_clu,soma_clu,'ok')
    hold('on')
    
    %and plot
    
%     %also plot the functional cells
%     [~,ia,ib] = intersect(soma_clu,soma_func(:,2));
%     %create a binary vector with the coordinates of the clu members
%     soma_bin = zeros(length(soma_func),1)==1;
%     soma_bin(ib) = 1;
%     %extract the cells of interest
%     soma_clu_func = soma_clu(ia);
%     %extract the side bias from the tar_par vector (selected above
%     %from the functional cells)
%     side_clu_func = side_clu(ia);
% 
%     %plot cells according to the criterion calculated above
%     soma_1 = soma_clu_func(tar_par(ib));
%     side_1 = side_clu_func(tar_par(ib));
%     soma_2 = soma_clu_func(~tar_par(ib));
%     side_2 = side_clu_func(~tar_par(ib));
%     plot(side_1,soma_1,'*r')
%     plot(side_2,soma_2,'*b')
    set(gca,'YLim',soma_lim,'XLim',[-1.1 1.1],'Ydir','reverse')
    %plot a cross in 0,0
    plot(zeros(2,1),get(gca,'YLim'),'-k')
    plot(get(gca,'XLim'),[sum(soma_lim)/2,sum(soma_lim)/2],'-k')
    %plot the average
    errorbar(mean(side_clu(:,1)),mean(soma_clu),std(soma_clu)./sqrt(length(soma_clu)),'go','MarkerFaceColor','g','MarkerSize',5,'LineWidth',3)
%     yyaxis right
%     ylabel(strcat('Soma depth,','Functional cells:',num2str(length(soma_clu_func))))
    xlabel('Side bias')
    ylabel('Soma depth')

    
    set(gca,'YTick',[],'YColor','k')

end
%% Calculate the cluster averages
close all
%allocate memory for the cluster average
invitro_cluave = zeros(invitro_clunum,size(invitro_norm,2));
%and for the number of cluster members
invitro_clumem = zeros(invitro_clunum,1);
%for all the clusters
for clu = 1:invitro_clunum
    %calculate the average of this cluster
    invitro_cluave(clu,:) = mean(invitro_norm(invitro_clusters==clu,:),1);
    %and the number of members
    invitro_clumem(clu) = sum(invitro_clusters==clu);
end

figure
imagesc(invitro_cluave)