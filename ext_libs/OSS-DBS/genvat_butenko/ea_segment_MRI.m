function settings = ea_segment_MRI(options, settings, outputPaths)
% Create segmentation into GM, WM, CSF either based on T1 or Atlas or just
% copy for templates/ when computing in Template space.
% By Butenko and Li, konstantinmgtu@gmail.com

arguments
    options     % Lead-DBS options for electrode reconstruction and stimulation
    settings    % parameters for OSS-DBS simulation
    outputPaths % various paths to conform with lead-dbs BIDS structure 
end

% Segment MRI
segmaskName = 'segmask.nii';

% Index of the tissue in segmented MRI data
settings.GM_index = 1;
settings.WM_index = 2;
settings.CSF_index = 3;
settings.default_material = 'GM'; % GM, WM or CSF
settings.MRI_data_name = [outputPaths.outputDir, filesep, segmaskName];

if options.native
    anchorImage = options.subj.preopAnat.(options.subj.AnchorModality).coreg;
end 

switch settings.butenko_segmAlg
    case 'SPM'
        if options.native
            [anchorImageDir, anchorImageName] = fileparts(anchorImage);
            anchorImageDir = [anchorImageDir, filesep];
            anchorImageName = [anchorImageName, '.nii'];

            mod = replace(options.subj.AnchorModality, textBoundary('start') + alphanumericsPattern + "_", "");
            c1File = setBIDSEntity(anchorImage, 'mod', mod, 'label', 'GM', 'suffix', 'mask');
            c2File = setBIDSEntity(anchorImage, 'mod', mod, 'label', 'WM', 'suffix', 'mask');
            c3File = setBIDSEntity(anchorImage, 'mod', mod, 'label', 'CSF', 'suffix', 'mask');
            if ~isfile(c1File) || ~isfile(c2File) || ~isfile(c3File)
                ea_newseg(anchorImage, 0, 1);
                movefile([anchorImageDir, 'c1', anchorImageName], c1File);
                movefile([anchorImageDir, 'c2', anchorImageName], c2File);
                movefile([anchorImageDir, 'c3', anchorImageName], c3File);
            end

            segMaskPath = setBIDSEntity(anchorImage, 'label', 'C123', 'mod', options.subj.AnchorModality, 'suffix', 'mask');
        else
            c1File = [ea_space, 'c1mask.nii'];
            c2File = [ea_space, 'c2mask.nii'];
            c3File = [ea_space, 'c3mask.nii'];
            if ~isfile(c1File) || ~isfile(c2File) || ~isfile(c3File)
                ea_newseg(fullfile(ea_space, [options.primarytemplate, '.nii']), 0, 1);
                movefile([ea_space, 'c1', options.primarytemplate, '.nii'], c1File);
                movefile([ea_space, 'c2', options.primarytemplate, '.nii'], c2File);
                movefile([ea_space, 'c3', options.primarytemplate, '.nii'], c3File);
            end

            segMaskPath = [ea_space, segmaskName];
        end

        if ~isfile(segMaskPath)
            % Binarize segmentations
            c1 = ea_load_nii(c1File);
            c2 = ea_load_nii(c2File);
            c3 = ea_load_nii(c3File);
            c1.img = c1.img>0.5;
            c2.img = c2.img>0.5;
            c3.img = c3.img>0.95;  % only high confidence CSF 

            % Fuse segmentations by voting in the order  CSF -> WM -> GM
            c2.img(c3.img) = 0;
            c1.img(c2.img | c3.img) = 0;
            c1.img = c1.img + c2.img*2 + c3.img*3;

            c1.fname = segMaskPath;
            c1.dt = [2 0]; % unit8 according to spm_type
            c1.descrip = 'Tissue 1 + 2 + 3';
            c1.pinfo(1:2) = [1,0]; % uint8 is enough for output values, no need for scaling

            ea_write_nii(c1);
        elseif options.native
            % load already created C123 and check if native
            c1 = ea_load_nii(segMaskPath);
        end

        if options.native
            % volume sanity check (at least 100 cm3 for WM and GM)
            GM_vol = length(find(c1.img == settings.GM_index)) * c1.voxsize(1,1)*c1.voxsize(1,2)*c1.voxsize(1,3) * 0.001; 
            WM_vol = length(find(c1.img == settings.WM_index)) * c1.voxsize(1,1)*c1.voxsize(1,2)*c1.voxsize(1,3) * 0.001; 

            % TBD: write a smarter auto-check
            if WM_vol < 100.0 || GM_vol < 100.0
                ea_warndlg("Brain segmentation with SPM failed for sub-%S", options.subj.subjId)
                % check if atropos segmentation was already done 
                % TBD: we can store atropos segmask_raw in coregistration
                % instead of stim folder
                if ~isfile([ea_path_helper(outputPaths.outputDir),filesep,'segmask_raw.nii'])
                    env = ea_conda_env('Lead-DBS');
                    if ~env.is_up_to_date
                        env.force_create;
                    end
                    %env.system('pip3 install antspyx')
                    system(['python ', ea_getearoot, '/ext_libs/OSS-DBS/genvat_butenko/atropos_segm.py ', [anchorImageDir,anchorImageName], ' ', ea_path_helper(outputPaths.outputDir)])
                end
                env = ea_conda_env('OSS-DBSv2');
                
                % ea_atropos2segmask will save segmask.nii in the stim folder
                ea_atropos2segmask([ea_path_helper(outputPaths.outputDir),filesep,'segmask_raw.nii'], options.subj.AnchorModality);
            else
                copyfile(segMaskPath, [outputPaths.outputDir, filesep, segmaskName]);
            end
        else
            % for MNI, copy without check
            copyfile(segMaskPath, [outputPaths.outputDir, filesep, segmaskName]);
        end


    case 'Atlas Based'

        % always overwrite in this case
        if isfile([outputPaths.outputDir, filesep, segmaskName])
            ea_delete([outputPaths.outputDir, filesep, segmaskName])
        end

        if options.native
            segMaskPath = [options.subj.atlasDir,filesep,options.atlasset,filesep,'segmask_atlas.nii'];
            ea_ptspecific_atl(options);
            atlas_gm_mask_path = [options.subj.atlasDir,filesep,options.atlasset,filesep,'gm_mask.nii.gz'];
            ea_convert_atlas2segmask(atlas_gm_mask_path, segMaskPath, 0.5)
            copyfile(segMaskPath, [outputPaths.outputDir, filesep, segmaskName]);
        else
            % save directly to stim folder
            segMaskPath = [outputPaths.outputDir,filesep,'segmask.nii'];
            atlas_gm_mask_path = [ea_space,filesep,'atlases',filesep,options.atlasset,filesep,'gm_mask.nii.gz'];
            ea_convert_atlas2segmask(atlas_gm_mask_path, segMaskPath, 0.5)
        end
    case'SynthSeg'
        ea_warndlg("SynthSeg segmentations are not supported yet")
        return
        %SynthSeg_segmask_image = ea_smart_BIDS_function_to_find_SynthSeg;
        %ea_convert_synthSeg2segmask(SynthSeg_segmask_image, segmask_output);
end