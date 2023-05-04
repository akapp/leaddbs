function  ea_pat2pdf(uipatdir,handles)

options=ea_handles2options(handles);
options.native=0; % MNI space only

[options.root,options.patientname]=fileparts(uipatdir);
options.root=[options.root,filesep];
options=ea_resolve_elspec(options);
options.prefs=ea_prefs(options.patientname);
options.d2 = ea_tdhandles2options([], options.d2);
options.d3.expdf=1;
options.d3.verbose='off';

if ~ea_checkslicespresent(options)
    ea_writeplanes(options);
end

ea_elvis(options);

fname = [uipatdir, filesep, 'Lead-DBS_Electrode_Localization'];
movefile([fname, '.u3d'], [uipatdir, filesep, 'export', filesep, 'pdf']);
movefile([fname, '.pdf'], [uipatdir, filesep, 'export', filesep, 'pdf']);


function present = ea_checkslicespresent(options)
present = 1;
fileprefix = fullfile(options.root,options.patientname,'export', '2D', [options.patientname, '_desc-2D_view-']);

for tracor=1:3
    switch tracor
        case 1
            view = 'ax_';
            for elcnt=1:(options.elspec.numel)
                el = [elcnt, elcnt + options.elspec.numel];
                contactTag = strjoin(options.elspec.contactnames(el), '');
                contactTag = erase(contactTag, {' ', '(', ')'});

                if ~isfile([fileprefix, view, contactTag, '.png'])
                    present=0;
                    return;
                end
            end
        case 2
            view = 'cor_';
            for elcnt=1:(options.elspec.numel)
                el = [elcnt, elcnt + options.elspec.numel];
                contactTag = strjoin(options.elspec.contactnames(el), '');
                contactTag = erase(contactTag, {' ', '(', ')'});

                if ~isfile([fileprefix, view, contactTag, '.png'])
                    present=0;
                    return;
                end
            end
        case 3
            view = 'sag_';
            for el=1:length(options.elspec.contactnames)
                contactTag = strjoin(options.elspec.contactnames(el), '');
                contactTag = erase(contactTag, {' ', '(', ')'});

                if ~isfile([fileprefix, view, contactTag, '.png'])
                    present=0;
                    return;
                end
            end
    end
end
