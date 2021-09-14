function results = legacy2bids(source,dest,isdicom,dicom_source,move,doDcmConv)
%SANTIY: first check the existence of your source and dest directory. If it is not there,
%create a new directory.
for j=1:length(source)
    if ~exist(source{j},'dir')
        warndlg("The source directory you have specified does not exist")
    else
        addpath(source{j})
    end
    if isempty(dest)
        dest = source{j};
        addpath(dest{j});
    end
end
%when the app is used to run this script, there is an isempty check in the
%app also. This conflicts with whether it is empty in this script (i.e., if
%the user uses the app and doesn't input an output dir, then the output dir
%is automatically changed to the input dir. So this code will run. 
if exist('dest','var') 
   for dest_dir = 1:length(dest)
       if ~exist(dest{dest_dir},'dir')
            addpath(dest{dest_dir});
            mkdir(dest{dest_dir});
       end
   end
end



%if you have dicom files and have not provided a dicom source directory
%(this can also just be source directory,so refactor this) then throw
%an error
if isdicom && ~exist('dicom_source','var')
    warndlg("You have specified that you want dicom import, but have not specified a dicom source file. Please specific your dicom source directory!")
end

%define names of the new directorey structure
modes = {'anat','func'};
sessions = {'ses-preop','ses-postop'};
dicom_sessions = {'preop_mri','postop_ct'};
if exist('doDcmConv','var') && doDcmConv
    subfolder_cell = {'sourcedata','legacy_rawdata','derivatives'};
else
    subfolder_cell = {'sourcedata','rawdata','derivatives'};
end
pipelines = {'brainshift','coregistration','normalization','reconstruction','preprocessing','prefs','log','export','stimulations','current_headmodel','headmodel'};
%mapping will allow quick reference of the files to move
[brainshift,coregistration,normalization,preprocessing,reconstruction,prefs,stimulations,headmodel] = create_bids_mapping();
legacy_modalities = {'t1.nii','t2.nii','pd.nii','ct.nii','tra.nii','cor.nii','sag.nii'};
bids_modalities = {'T1w.nii.gz','T2w.nii.gz','PD.nii.gz','CT.nii.gz','ax.nii.gz','cor.nii.gz','sag.nii.gz'};
rawdata_containers = containers.Map(legacy_modalities,bids_modalities);
%dir without dots is a modified dir command that with return the
%directory contents without the dots. those evaluate to folders and
%cause issues.
%by default, use the sub- prefix. If the patient already has a sub-, this
%flag is set to zero.

%get all patient names, again this will be changed based on the dataset
%fetcher command
%perform moving for each pat
tic
for patients = 1:length(source)
    source_patient = source{patients};
    dest_patient = dest{patients};
    if isdicom
        dicom_patient = dicom_source{patients};
    end
    [~,patient_name,~] = fileparts(source_patient);
    if ~startsWith(patient_name,'sub-')
       patient_name = ['sub-',patient_name];
    end
    files_in_pat_folder = dir_without_dots(source_patient);
    file_names = {files_in_pat_folder.name};
    file_index = 1;
    for j=1:length(file_names)
        %add filenames. However, some files are inside folder (checkrreg
        %and scrf). They will be handled a bit later.
        files_to_move{file_index} = file_names{j};
        file_index = file_index + 1;
        
        %now let's deal with subfolders
    end
    
    
    %collect directory names inside the patient folder.
    dir_names = {files_in_pat_folder([files_in_pat_folder.isdir]).name};
    for j=1:length(dir_names)
        if j==1
            disp("Migrating Atlas folder...");
            if ismember(dir_names,'WarpDrive')
                disp("Migrating WarpDrive folder...");
            end
        end
        %%%for now, copy atlases, stimulations, headmodel and current
        %%%headmodel to their respective directories. Then you can crawl
        %%%through and rename. Renaming is handled a bit later.
        if strcmp(dir_names{j},'atlases') || strcmp(dir_names{j},'stimulations') || strcmp(dir_names{j},'headmodel') || strcmp(dir_names{j},'current_headmodel') || strcmp(dir_names{j},'WarpDrive')
            if move
                movefile(fullfile(source_patient,dir_names{j}),fullfile(dest_patient,'derivatives','leaddbs',patient_name,dir_names{j}));
            else
                copyfile(fullfile(source_patient,dir_names{j}),fullfile(dest_patient,'derivatives','leaddbs',patient_name,dir_names{j}));
            end
        else
            this_folder = dir_without_dots(fullfile(source_patient,dir_names{j}));
            files_in_folder = {this_folder.name};
            file_in_folder_indx = 1;
            for file_in_folder=1:length(files_in_folder)
                if exist('files_to_move','var')
                    files_to_move{end+1} = files_in_folder{file_in_folder};
                else
                    files_to_move{file_in_folder_indx} = files_in_folder{file_in_folder};
                    file_in_folder_indx = file_in_folder_indx + 1;
                end
            end
        end
    end
    %so we have created a list of the files to move, now we can create
    %the new dirrectory structure and move the correct files into the
    %correct "BIDS" directory
    for subfolders = 1:length(subfolder_cell)
        switch subfolder_cell{subfolders}
            case 'sourcedata'
                new_path = fullfile(dest_patient,subfolder_cell{subfolders},patient_name);
                if ~exist(new_path,'dir')
                    mkdir(new_path)
                end
                if ~isdicom
                    disp("There are no dicom images, source data folder will be empty")
                else
                    disp("Copying DICOM folder...");
                    if move
                        movefile(dicom_patient,new_path)
                    else
                        copyfile(dicom_patient,new_path)
                    end
                    
                end 
            case 'derivatives'
                disp("Migrating Derivatives folder...");
                new_path = fullfile(dest_patient,subfolder_cell{subfolders},'leaddbs',patient_name);
                for folders=1:length(pipelines)
                    if ~exist(fullfile(new_path,pipelines{folders}),'dir')
                        mkdir(fullfile(new_path,pipelines{folders}))
                    end
                    which_pipeline = pipelines{folders};
                    for files=1:length(files_to_move)
                        if strcmp(pipelines{folders},'coregistration')
                            if ismember(files_to_move{files},coregistration{:,1})
                                %if ~isempty(regexp(files_to_move{files},'^anat_t[1,2].nii||^postop_.*nii||.*rpostop.*||.*coreg.*') == 1)
                                %corresponding index of the new pat
                                which_file = files_to_move{files};
                                indx = cellfun(@(x)strcmp(x,files_to_move{files}),coregistration{:,1});
                                bids_name = coregistration{1,2}{indx};
                                move_derivatives2bids(source_patient,new_path,which_pipeline,which_file,patient_name,bids_name,move)
                            elseif ~isempty(regexp(files_to_move{files},'^coreg.*.log'))
                                if ~exist(fullfile(new_path,pipelines{folders},'log'),'dir')
                                    mkdir(fullfile(new_path,pipelines{folders},'log'));
                                end
                                which_file = files_to_move{files};
                                if exist(fullfile(source_patient,files_to_move{files}),'file')
                                   if move
                                      movefile(fullfile(source_patient,files_to_move{files}),fullfile(new_path,pipelines{folders},'log',files_to_move{files}));
                                   else
                                      copyfile(fullfile(source_patient,files_to_move{files}),fullfile(new_path,pipelines{folders},'log'));
                                   end
                               end
                            end
                        elseif strcmp(pipelines{folders},'brainshift')
                            if ismember(files_to_move{files},brainshift{:,1})
                                which_file = files_to_move{files};
                                indx = cellfun(@(x)strcmp(x,files_to_move{files}),brainshift{:,1});
                                bids_name = brainshift{1,2}{indx};
                                move_derivatives2bids(source_patient,new_path,which_pipeline,which_file,patient_name,bids_name,move)
                            end
                        elseif strcmp(pipelines{folders},'normalization')
                            if ismember(files_to_move{files},normalization{:,1})
                                %corresponding index of the new pat
                                which_file = files_to_move{files};
                                indx = cellfun(@(x)strcmp(x,files_to_move{files}),normalization{:,1});
                                bids_name = normalization{1,2}{indx};
                                move_derivatives2bids(source_patient,new_path,which_pipeline,which_file,patient_name,bids_name,move)
                                %only for normalization
                            elseif ~isempty(regexp(files_to_move{files},'^normalize_.*.log')) 
                                if ~exist(fullfile(new_path,pipelines{folders},'log'),'dir')
                                    mkdir(fullfile(new_path,pipelines{folders},'log'));
                                end
                                if exist(fullfile(source_patient,files_to_move{files}),'file')
                                    if move
                                        movefile(fullfile(source_patient,files_to_move{files}),fullfile(new_path,pipelines{folders},'log',files_to_move{files}));
                                    else
                                        copyfile(fullfile(source_patient,files_to_move{files}),fullfile(new_path,pipelines{folders},'log'));
                                    end
                                end
                            end
                            %special case for recon
                        elseif strcmp(pipelines{folders},'reconstruction')
                            recon_dir = fullfile(new_path,pipelines{folders});
                            if ~exist(recon_dir,'dir')
                                mkdir(recon_dir)
                            end
                            if ismember(files_to_move{files},reconstruction{:,1})
                                %corresponding index of the new pat
                                indx = cellfun(@(x)strcmp(x,files_to_move{files}),reconstruction{:,1});
                                if move
                                    movefile(fullfile(source_patient,files_to_move{files}),fullfile(recon_dir,files_to_move{files}));
                                else
                                    copyfile(fullfile(source_patient,files_to_move{files}),recon_dir)
                                end
                                movefile(fullfile(new_path,pipelines{folders},files_to_move{files}),fullfile(recon_dir,[patient_name,'_',reconstruction{1,2}{indx}]));
                            end
                        elseif strcmp(pipelines{folders},'preprocessing')
                            if ismember(files_to_move{files},preprocessing{:,1})
                                %corresponding index of the new pat
                                indx = cellfun(@(x)strcmp(x,files_to_move{files}),preprocessing{:,1});
                                bids_name = preprocessing{1,2}{indx};
                                move_derivatives2bids(source_patient,new_path,which_pipeline,which_file,patient_name,bids_name,move)
                            end
                        elseif strcmp(pipelines{folders},'prefs')
                            if ismember(files_to_move{files},prefs{:,1})
                                %corresponding index of the new pat
                                indx = cellfun(@(x)strcmp(x,files_to_move{files}),prefs{:,1});
                                bids_name = prefs{1,2}{indx};
                                move_derivatives2bids(source_patient,new_path,which_pipeline,which_file,patient_name,bids_name,move)
                            end
                            %special case for log dir
                        elseif strcmp(pipelines{folders},'log')
                            if exist(fullfile(source_patient,'ea_methods.txt'),'file')
                                if move
                                    movefile(fullfile(source_patient,'ea_methods.txt'),fullfile(new_path,pipelines{folders},'ea_methods.txt'));
                                else
                                    copyfile(fullfile(source_patient,'ea_methods.txt'),fullfile(new_path,pipelines{folders}));
                                end
                                movefile(fullfile(new_path,pipelines{folders},'ea_methods.txt'),fullfile(new_path,pipelines{folders},[patient_name,'_',files_to_move{files}]));
                            end
                        elseif strcmp(pipelines{folders},'stimulations')
                            %the stimulations folder should already be
                            %there in the dest directory.
                            if exist(fullfile(source_patient,pipelines{folders}),'dir') && exist(fullfile(new_path,pipelines{folders}),'dir')
                                pipeline = pipelines{folders};
                                [mni_files,native_files] = vta_walkpath(new_path,pipeline);
                                move_mni2bids(mni_files,native_files,stimulations,'',pipeline,patient_name)
                            end
                        elseif strcmp(pipelines{folders},'current_headmodel')
                            if exist(fullfile(source_patient,pipelines{folders}),'dir') && exist(fullfile(new_path,pipelines{folders}),'dir')
                                pipeline = pipelines{folders};
                                [mni_files,native_files] = vta_walkpath(new_path,pipeline);
                                move_mni2bids(mni_files,native_files,'',headmodel,pipeline,patient_name)
                                
                            end
                        elseif strcmp(pipelines{folders},'headmodel')
                            if exist(fullfile(source_patient,pipelines{folders}),'dir') && exist(fullfile(new_path,pipelines{folders}),'dir')
                                headmodel_contents = dir_without_dots(fullfile(new_path,pipelines{folders}));
                                headmodel_files = {headmodel_contents.name};
                                for headmodel_file = 1:length(headmodel_files)
                                    if ismember(headmodel_files{headmodel_file},headmodel{:,1})
                                        indx = cellfun(@(x)strcmp(x,headmodel_files{headmodel_file}),headmodel{:,1});
                                        movefile(fullfile(new_path,pipelines{folders},headmodel_files{headmodel_file}),fullfile(new_path,pipelines{folders},[patient_name,'_',headmodel{1,2}{indx}]));
                                    end
                                end
                            end
                            
                        end
                    end
                end
            otherwise
                for i=1:length(modes)
                    for j=1:length(sessions)
                        new_path = fullfile(dest_patient,subfolder_cell{subfolders},patient_name,sessions{j},modes{i});
                        if ~exist(new_path,'dir')
                            mkdir(new_path)
                        end
                        for files=1:length(files_to_move)
                            if strcmp(modes{i},'anat') && strcmp(sessions{j},'ses-preop')
                                %files to be moved into pre-op:raw_anat_*.nii
                                if regexp(files_to_move{files},'raw_anat_.*.nii')
                                    if exist(fullfile(source_patient,files_to_move{files}),'file')
                                        modality_str = strsplit(files_to_move{files},'_');
                                        modality_str = modality_str{end};
                                        bids_name = [sessions{j},'_',rawdata_containers(modality_str)];
                                        source_patient_path = source_patient;
                                        which_file = files_to_move{files};
                                        move_raw2bids(source_patient_path,new_path,which_file,patient_name,bids_name,move)
                                    end
                                end
                            elseif strcmp(modes{i},'anat') && strcmp(sessions{j},'ses-postop')
                                if ~isempty(regexp(files_to_move{files},'raw_postop_.*.nii')) || strcmp(files_to_move{files},'postop_ct.nii')
                                    if exist(fullfile(source_patient,files_to_move{files}),'file')
                                        modality_str = strsplit(files_to_move{files},'_');
                                        modality_str = modality_str{end};
                                        bids_name = [sessions{j},'_',rawdata_containers(modality_str)];
                                        source_patient_path = source_patient;
                                        which_file = files_to_move{files};
                                        move_raw2bids(source_patient_path,new_path,which_file,patient_name,bids_name,move)
                                    end
                                end
                            end
                        end
                        
                    end
                end  
        end
    end
    disp(['Process finished for Patient:' patient_name]);
end
toc;

function move_derivatives2bids(source_patient_path,new_path,which_pipeline,which_file,patient_name,bids_name,move)
    
    if strcmp(which_pipeline,'brainshift')
        source_patient_path = fullfile(source_patient_path,'scrf');
    end
        
    anat_dir = fullfile(new_path,which_pipeline,'anat');
    log_dir = fullfile(new_path,which_pipeline,'log');
    checkreg_dir = fullfile(new_path,which_pipeline,'checkreg');    
    transformations_dir = fullfile(new_path,which_pipeline,'transformations');
    if endsWith(which_file,'.nii')
        if ~exist(anat_dir,'dir')
            mkdir(anat_dir)
        end
        old_path = fullfile(source_patient_path,which_file);
        new_path = anat_dir;
    elseif endsWith(which_file,'.png')
        if ~exist(checkreg_dir,'dir')
            mkdir(checkreg_dir)
        end
        old_path = fullfile(source_patient_path,which_file);
        old_path_scrf = fullfile(source_patient_path,'checkreg',which_file);
        new_path = checkreg_dir;
    elseif endsWith(which_file,'.log') || ~isempty(regexp(which_file,'.*_approved||.*_applied.mat')) || endsWith(which_file,'.txt')
        if ~exist(log_dir,'dir')
            mkdir(log_dir)
        end
        old_path = fullfile(source_patient_path,which_file);
        new_path = log_dir;
    elseif endsWith(which_file,'.mat') || endsWith(which_file,'.gz')
        if ~exist(transformations_dir,'dir')
            mkdir(transformations_dir)
        end
        old_path = fullfile(source_patient_path,which_file);
        new_path = transformations_dir;
    end
    if exist(old_path,'file')
        %first move%
        if move
            move_path = fullfile(new_path,which_file);
            movefile(old_path,move_path);
        else
            copyfile(old_path,new_path);
        end
    elseif exist(old_path_scrf,'file')
        if move
            move_path = fullfile(new_path,which_file);
            movefile(old_path_scrf,move_path);
        else
            copyfile(old_path_scrf,new_path);
        end
    end

    %then rename%
    rename_path = fullfile(new_path,which_file);
    movefile(rename_path,fullfile(new_path,[patient_name,'_',bids_name]));
    
function move_raw2bids(source_patient_path,new_path,which_file,patient_name,bids_name,move)
    if exist(fullfile(source_patient_path,which_file),'file')
       
        if move
            movefile(fullfile(source_patient_path,which_file),fullfile(new_path,which_file));
        else
            copyfile(fullfile(source_patient_path,which_file),new_path);
        end
         if ~endsWith(which_file,'.gz')
            gzip(fullfile(new_path,which_file))
            ea_delete(fullfile(new_path,which_file))
            which_file = [which_file,'.gz'];
        end
        movefile(fullfile(new_path,which_file),fullfile(new_path,[patient_name,'_',bids_name]));
    end
function move_mni2bids(mni_files,native_files,stimulations,headmodel,which_pipeline,patient_name)
    if strcmp(which_pipeline,'stimulations')
        for mni_file = 1:length(mni_files)
            for mni_subfile = 1:length(mni_files{1,mni_file})
                [filepath,mni_filename,ext] = fileparts(mni_files{1,mni_file}{1,mni_subfile});
                if ismember([mni_filename,ext],stimulations{:,1})
                    indx = cellfun(@(x)strcmp(x,[mni_filename,ext]),stimulations{:,1});
                    movefile(mni_files{1,mni_file}{1,mni_subfile},fullfile(filepath,[patient_name,'_',stimulations{1,2}{indx}]));
                end
            end
        end
        for native_file = 1:length(native_files)
            for native_subfile = 1:length(native_files{1,native_file})
                [filepath,native_filename,ext] = fileparts(native_files{1,native_file}{1,native_subfile});
                if ismember([native_filename,ext],stimulations{:,1})
                    indx = cellfun(@(x)strcmp(x,[native_filename,ext]),stimulations{:,1});
                    movefile(native_files{1,native_file}{1,native_subfile},fullfile(filepath,[patient_name,'_',stimulations{1,2}{indx}]));
                end
            end
        end
    elseif strcmp(which_pipeline,'current_headmodel')
        for mni_file = 1:length(mni_files)
            [filepath,mni_filename,ext] = fileparts(mni_files{mni_file});
            if ismember([mni_filename,ext],headmodel{:,1})
                indx = cellfun(@(x)strcmp(x,[mni_filename,ext]),headmodel{:,1});
                movefile(mni_files{mni_file},fullfile(filepath,[patient_name,'_',headmodel{1,2}{indx}]));
            end
        end
        for native_file = 1:length(native_files)
            [filepath,native_filename,ext] = fileparts(native_files{native_file});
            if ismember([native_filename,ext],headmodel{:,1})
                indx = cellfun(@(x)strcmp(x,[native_filename,ext]),headmodel{:,1});
                movefile(native_files{native_file},fullfile(filepath,[patient_name,'_',headmodel{1,2}{indx}]));
            end
        end
    end
 


        



