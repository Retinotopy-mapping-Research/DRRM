%% Description  -- function Vi = fsaverage2fslr(Vq, lr)
%	Rotate convert fsaverage sphere coordinate to fs_LR
% Parameter(s): 
%		Vq[double array]   -- query point on the fsaverage sphere 
%		lr[string]         --  type of the hemisphere.
% Return: 
%		Vi[double array]   -- result of the query points in the fs_LR sphere space.
%
%%
function Vi = fsaverage2fslr(Vq, lr)
    if lr == 'lh'
        giifile=gifti('standard_mesh_atlas/L.sphere.59k_fs_LR.surf.gii');
        Vlr = double(giifile.vertices);

        giifile=gifti('standard_mesh_atlas/resample_fsaverage/fs_LR-deformed_to-fsaverage.L.sphere.59k_fs_LR.surf.gii');
        Vavg = double(giifile.vertices);

    else
        if   lr == 'rh'
            giifile=gifti('standard_mesh_atlas/R.sphere.59k_fs_LR.surf.gii');
            Vlr = double(giifile.vertices);

            giifile=gifti('standard_mesh_atlas/resample_fsaverage/fs_LR-deformed_to-fsaverage.R.sphere.59k_fs_LR.surf.gii');
            Vavg = double(giifile.vertices);
        else
            error('only lr or rh allowed');

        end
    end

    Vi = sphere_interpretation(Vavg, Vlr, double(Vq));

end