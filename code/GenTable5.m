% Gen Table 5
clear;clc;close;

dbstop if error
%% Load Template and Subject

global template_hemi hemi_cut hcpsub sid  N debug

debug =0;
% Load subject

dirinfo = dir([GenConsts.kDataHCP32URL,'*_32k_pRF_fMRI.mat']);

global DataBus
DataBus = [];
mkdir([GenConsts.kTablesURL, 'tmp_table5'])
for i_sid = 1:20
    sid = dirinfo(i_sid).name;

	matfn = sprintf('%stmp_table5/running_sub_%s.mat', GenConsts.kTablesURL, sid);
    if exist(matfn)
         loadstruct = load(matfn);
        DataBus = loadstruct.DataBus;
        continue
    end

    for lr = {'lh', 'rh'}
        lr = lr{1};
        % load subject
		fn = [GenConsts.kDataHCP32URL, sid];
        N = 100;
        rect = [-1 1 -1 1];

        hcpsub = load_hcp_subject_32k(fn);
        figure;plot_surf(hcpsub.lh.sphere.faces, hcpsub.lh.sphere.vertices, prf_value_2_color('ecc',hcpsub.lh.pRF(:,2),8)); view(24,10)
        %%
        hcp_subj_cut = cut_on_sphere_32k(hcpsub);
        hemi_cut = hcp_subj_cut.(lr);

        % load template
		load([GenConsts.kTemplatesURL,'HCPTemplate'],'template');
        template_hemi = template.(lr);

        %% prepare data
        moving.F = hemi_cut.F;
        moving.uv = hemi_cut.uv;
        moving.label = hemi_cut.atlas_hcp;
        % moving.feature = unit_cvt(hemi_cut.pRF(:,[2 1]),'p2c');
        moving.feature = double([hemi_cut.pRF(:,2) hemi_cut.pRF(:,1)/180*pi]);
        moving.R2 = double(hemi_cut.pRF(:,5));

        static.F = template_hemi.F;
        static.uv = template_hemi.uv;
        static.label = template_hemi.varea;
        % static.feature = unit_cvt([template_hemi.ecc template_hemi.ang],'p2c');
        static.feature = [template_hemi.ecc template_hemi.ang/180*pi];
        %
        bd = compute_bd(moving.F);
        bd_src = moving.uv(bd,:);
        bd_target = moving.uv(bd,:);

        %
        [landmark, target] = detect_landmark_by_R2(static, moving);
        ptdst = target;
        ptsrc = moving.uv(landmark,:);
        % ptsrc = [];
        % ptdst = [];
        % generate image for D-Demos
        x_t_fn = [GenConsts.kImageURL,'x_t.png'];
        y_t_fn = [GenConsts.kImageURL,'y_t.png'];

        x_s_fn = [GenConsts.kImageURL,'ang_s.png'];
        y_s_fn = [GenConsts.kImageURL,'ecc_s.png'];
		

        value2image(static.F, static.uv, static.feature(:,1), rect, x_t_fn);
        value2image(static.F, static.uv, static.feature(:,2), rect, y_t_fn);

        value2image(moving.F, moving.uv, moving.feature(:,1), rect, x_s_fn);
        value2image(moving.F, moving.uv, moving.feature(:,2), rect, y_s_fn);

        y_t = im2double(imread(y_t_fn));
        x_t = im2double(imread(x_t_fn));
        y_s = im2double(imread(y_s_fn));
        x_s = im2double(imread(x_s_fn));

        %% Register by methods
        % Raw data
        evaulate(moving.uv, moving.feature) % The databus will be udpated within evaulate function

        %% TPS: It use landmark        
        disp_tps = tpswarp2d(moving.uv, [ptsrc; bd_src], [ptdst; bd_target]);   
        evaulate(moving.uv+ disp_tps, moving.feature)
        
         %% Bayessian Method         
        disp_bayessian = bayessian_reg(moving.F, moving.uv, moving.feature, ...
            static.uv, static.feature, [ptsrc; bd_src], [ptdst ; bd_target]);
        
        evaulate(moving.uv + disp_bayessian, moving.feature)

        %% Bayessian Data

        [ecc,ang, sigma, varea] = load_benson_inference_cvt_to_32k(sid(1:6), lr);
        % Benson result means the values(ecc,ang) for  static.uv is different;
        % while in site registration is moving the uv, so we need different evaulation function
        evaulate_inference(static.uv, ecc, ang);

        %% Log Demo
        
        res = logdemo(x_s, x_t);
        for iter = 1:50
            res = logdemo(x_s, x_t,  res.vx, res.vy);
            res = logdemo(y_s, y_t, res.vx, res.vy);
        end
      
        evaulate( moving.uv + res2vxvy(res, moving.uv), moving.feature)

        %% Proposed without  landmark
        tic
        map  = disk_registration(static, moving, [], []);
        t1 = toc;
        evaulate(map, moving.feature)
        % %% Proposed with  landmark
        % map  = disk_registration(static, moving, landmark, ptdst);
        % evaulate(map, moving.feature)


    end
    save(matfn,'DataBus')
    close all
end


save('Table5','DataBus')

%%
load('Table5','DataBus')
clc

for vi=1:12
    for mj=[1 2 5 4 6]
        meandata = median(DataBus((vi-1)+(mj-1)*12 + 1:72:end,[4 2]));% 4 2 is the visual diff and flip
        
        if mj==4 % we dont know how many flip, therefor, set ---
            fprintf('%1.4f/%s\t', meandata(1),'---')
        else
            fprintf('%1.4f/%d\t', meandata(1),round(meandata(2)))
        end
    end
    fprintf('\n')
end


%% evaulate metric and add to DataBus
function evaulate(map, moving_feature)

global DataBus template_hemi hemi_cut


template_vis = unit_cvt([template_hemi.ecc template_hemi.ang],'p2c');
visxfun =  scatteredInterpolant(template_hemi.uv, template_vis(:,1)); % rampa
visyfun =  scatteredInterpolant(template_hemi.uv, template_vis(:,2));
wrapfeature =unit_cvt([visxfun(map), visyfun(map)],'c2p');


% {'Unknown','V1v','V1d','V2v','V2d','V3v','V3d','hV4','VO1','VO2','PHC1','11','TO2','TO1','LO2','LO1','V3B','V3A','IPS0','IPS1','IPS2','IPS3','IPS4','IPS5','SPL1','FEF'}
aois =  [1 2
    3 4
    5 6
    7 7
    8 8
    9 9
    12 12
    13  13
    14 14
    15 15
    16 16
    17 17];
for roii = 1:size(aois,1)
    vid_from = aois(roii,1);
    vid_to = aois(roii,2);

    interested_id = find(hemi_cut.atlas_wang>=vid_from  &  hemi_cut.atlas_wang<=vid_to &  wrapfeature(:,1)<8);
    fMRI =[];
    for i=1:6
        fMRI(:,(i-1)*300+1:i*300) =  hemi_cut.fMRI{i}(interested_id,:);

    end

    pRF0 = hemi_cut.pRF(interested_id,:);
    pRF =  pRF0;

    [pRF0(:,1),pRF0(:,2)] = vis2xy_pixel([pRF0(:,2), pRF0(:,1)]);
    [pRF(:,1),pRF(:,2)] = vis2xy_pixel([wrapfeature(interested_id,1)  wrapfeature(interested_id,2)]);

    [NRMSE_raw, NRMSE_new, R2_raw,R2_new, AIC_raw, AIC_new, pc_raw, pc_new]= compute_fMRI_metrics(fMRI, pRF,pRF0);

    roiFflag = (ismember(hemi_cut.F(:,1), interested_id)| ismember(hemi_cut.F(:,2), interested_id) | ismember(hemi_cut.F(:,3), interested_id));
    roiF = hemi_cut.F(roiFflag,:);
    flipnum = length(find(abs(compute_bc(roiF, hemi_cut.uv, map))>1.05));


    mov_vis = unit_cvt([moving_feature(:,1)  moving_feature(:,2)/pi*180],'p2c');
    visualdiff = nanmean(vecnorm([visxfun(map(interested_id,:)), visyfun(map(interested_id,:))]'-mov_vis(interested_id,:)'));

    mu = abs(compute_bc(hemi_cut.F, hemi_cut.uv, map));
    mumean = mean(abs(mu));
    DataBus = [DataBus; visualdiff, flipnum, NRMSE_raw, NRMSE_new, R2_raw,R2_new, AIC_raw, AIC_new , mumean, pc_raw, pc_new 0 0]; % last 0 is allocate for time


end
end

 

%%
function evaulate_inference( BS_ecc32k, BS_ang32k, Bs_sigma32k)

 

global DataBus hemi_cut  template_hemi

map = hemi_cut.uv;
template_vis = unit_cvt([template_hemi.ecc template_hemi.ang],'p2c');
visxfun =  scatteredInterpolant(template_hemi.uv, template_vis(:,1)); % rampa
visyfun =  scatteredInterpolant(template_hemi.uv, template_vis(:,2));
wrapfeature =unit_cvt([visxfun(map), visyfun(map)],'c2p');


% Benson's 32k is for hemisphre, but we only need a portion, which can be
% get by id_in_cut_disk. Lucikly, we have the cut father index for disk.
id_in_cut_disk = hemi_cut.father;
BS_ecc_cut = BS_ecc32k(id_in_cut_disk);
BS_ang_cut = BS_ang32k(id_in_cut_disk);
BS_sigma_cut = Bs_sigma32k(id_in_cut_disk);
aois =  [1 2
    3 4
    5 6
    7 7
    8 8
    9 9
    12 12
    13  13
    14 14
    15 15
    16 16
    17 17];
for roii = 1:size(aois,1)
    vid_from = aois(roii,1);
    vid_to = aois(roii,2);
    
    % we only interested for specific visual area
    interested_id = find(hemi_cut.atlas_wang>=vid_from  &...
                         hemi_cut.atlas_wang<=vid_to & ...
                         wrapfeature(:,1)<8 );
    
    
    % now compute the visual coordinate distance of template and benson, which
    % is a metric about the registration
    flipnum = NaN;
    BS_vis = unit_cvt([BS_ecc_cut(interested_id)  BS_ang_cut(interested_id)],'p2c');
    pRF_vis = unit_cvt(hemi_cut.pRF(interested_id, [2 1]),'p2c');
    visualdiff = nanmean(vecnorm(pRF_vis'-BS_vis'));
    mumean = NaN;
    
    
    fMRI =[];
    for i=1:6
        fMRI(:,(i-1)*300+1:i*300) =  hemi_cut.fMRI{i}(interested_id,:);
    end
    pRF0 = hemi_cut.pRF(interested_id,:);
    pRF =  pRF0;
    [pRF0(:,1),pRF0(:,2)] = vis2xy_pixel([pRF0(:,2), pRF0(:,1)]);
    [pRF(:,1), pRF(:,2) ] = vis2xy_pixel([BS_ecc_cut(interested_id), BS_ang_cut(interested_id)]);
    pRF(:,6) = BS_sigma_cut(interested_id);
    % accurate
    [NRMSE_raw, NRMSE_new, R2_raw,R2_new, AIC_raw, AIC_new, pc_raw, pc_new]= compute_fMRI_metrics(fMRI, pRF,pRF0);
    
    
    DataBus = [DataBus; visualdiff, flipnum, NRMSE_raw, NRMSE_new, R2_raw,R2_new, AIC_raw, AIC_new , mumean, pc_raw, pc_new NaN NaN]; % last 0 is allocate for time
    
end

end

%%
function vxvy = res2vxvy(res, V)
N =100;
[x,y]=meshgrid(1:N,1:N);
vx = res.vx(:,:, end);
vy = res.vy(:,:, end);
Fx = scatteredInterpolant(x(:),y(:), vx(:));
Fy = scatteredInterpolant(x(:),y(:), vy(:));
vxvy = [Fx(V) Fy(V)];
end


%%
function  [landmark, target] = detect_landmark_by_R2(static, moving)
landmark = find(moving.R2 > 25);
for i=1:length(landmark)
    li = landmark(i);

    dis = norm((moving.feature(li,:) - static.feature)');
    dis(static.label~=moving.label(li)) = inf;
    [~, mid] = min(dis);
    target(i,:) = static.uv(mid,:);
end



end