function prefs = ea_setprefs(key, value, whichPrefs)
% Set LeadDBS preference
% 'whichPrefs' can be either 'machine' (default) to set 'prefs.machine.*'
% or 'user' to set 'prefs.*'

if ~exist('whichPrefs', 'var') || isempty(whichPrefs)
    % Set prefs.machine.* by default
    whichPrefs = 'machine';
end

switch lower(whichPrefs)
    case 'machine'
        prefs = ea_prefs;
        machine = prefs.machine;
        eval(['machine.', itemname, ' = value;']);
        try % may not have write permissions
            save([ea_gethome,'.ea_prefs.mat'],'machine');
        catch
            warning('Could not save preferences to user home directory. Please check permission.');
        end
    case 'user'
        if ~ischar(value)
            error('Input value should be a string!');
        end

        if isempty(str2num(value))
            % value to be set is str
            value = ['''', value, ''''];
        end

        % Replace prefs in .ea_prefs.m
        prefs = fileread([ea_gethome,'.ea_prefs.m']);
        pattern = [strrep(['prefs.',key], '.', '\.'), ' *= *.*?;'];
        prefs = regexprep(prefs, pattern, ['prefs.',key,' = ',value,';']);
        try % may not have write permissions
            fid = fopen([ea_gethome,'.ea_prefs.m'], 'w');
            fprintf(fid, prefs);
            fclose(fid);
        catch
            warning('Could not save preferences to user home directory. Please check permission.');
        end
end
