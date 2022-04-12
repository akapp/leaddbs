function [Ihat, Ihat_voters, Ihat_voters_train] = compute_fibscore_model(obj, fibsval, Ihat, Ihattrain, patientsel, training, test, Iperm_dummy)

    % args: vals, obj, I_hat, training, test, fibsval,
    % Iperm, patientsel, opt: Slope, Intercept

    if ~exist('Iperm', 'var')
        if obj.cvlivevisualize
            [vals,fibcell,usedidx] = ea_discfibers_calcstats(obj, patientsel(training));
            obj.draw(vals,fibcell,usedidx)
            %obj.draw(vals,fibcell);
            drawnow;
        else
            [vals,~,usedidx] = ea_discfibers_calcstats(obj, patientsel(training));
        end
    else
        if obj.cvlivevisualize
            [vals,fibcell,usedidx] = ea_discfibers_calcstats(obj, patientsel(training), Iperm);
            obj.draw(vals,fibcell,usedidx)
            %obj.draw(vals,fibcell);
            drawnow;
        else
            [vals,~,usedidx] = ea_discfibers_calcstats(obj, patientsel(training), Iperm);
        end
    end
    
    switch obj.modelNormalization
        case 'z-score'
            for s=1:length(vals)
                vals{s}=ea_nanzscore(vals{s});
            end
        case 'van Albada 2007'
            for s=1:length(vals)
                vals{s}=ea_normal(vals{s});
            end
    end
    
    Ihat_voters = [];
    Ihat_voters_train = [];
    for voter=1:size(vals,1)
        for side=1:size(vals,2)
            if ~isempty(vals{voter,side})
                switch obj.statmetric % also differentiate between methods in the prediction part.
                    case {1,3,4} % ttests / OSS-DBS / reverse t-tests
                        switch lower(obj.basepredictionon)
                            case 'mean of scores'
                                Ihat(test,side) = ea_nanmean(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test)),1);
                                    Ihattrain(training,side) = ea_nanmean(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training)),1);
                                
                            case 'sum of scores'
                                Ihat(test,side) = ea_nansum(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test)),1);
                                    Ihattrain(training,side) = ea_nansum(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training)),1);
                                
                            case 'peak of scores'
                                Ihat(test,side) = ea_nanmax(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test)),1);
                                    Ihattrain(training,side) = ea_nanmax(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training)),1);
                                
                            case 'peak 5% of scores'
                                ihatvals=vals{1,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test));
                                ihatvals=sort(ihatvals);
                                Ihat(test,side) = ea_nansum(ihatvals(1:ceil(size(ihatvals,1).*0.05),:),1);
                                    ihatvals=vals{1,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training));
                                    ihatvals=sort(ihatvals);
                                    Ihattrain(training,side) = ea_nansum(ihatvals(1:ceil(size(ihatvals,1).*0.05),:),1);
                                

                        end
                    case {2,5} % efields
                        switch lower(obj.basepredictionon)
                            case 'profile of scores: spearman'
                                Ihat(test,side) = (corr(vals{voter,side},fibsval{1,side}(usedidx{voter,side},patientsel(test)),'rows','pairwise','type','spearman'));
                                if any(isnan(Ihat(test,side)))
                                    Ihat(isnan(Ihat(test,side)),side)=0;
                                    warning('Profiles of scores could not be evaluated for some patients. Displaying these points as zero entries. Lower threshold or carefully check results.');
                                end
                                    Ihattrain(training,side) = atanh(corr(vals{voter,side},fibsval{1,side}(usedidx{voter,side},patientsel(training)),'rows','pairwise','type','spearman'));
                                
                            case 'profile of scores: pearson'
                                Ihat(test,side) = (corr(vals{voter,side},fibsval{1,side}(usedidx{voter,side},patientsel(test)),'rows','pairwise','type','pearson'));
                                if any(isnan(Ihat(test,side)))
                                    Ihat(isnan(Ihat(test,side)),side)=0;
                                    warning('Profiles of scores could not be evaluated for some patients. Displaying these points as zero entries. Lower threshold or carefully check results.');
                                end
                                    Ihattrain(training,side) = atanh(corr(vals{voter,side},fibsval{1,side}(usedidx{voter,side},patientsel(training)),'rows','pairwise','type','pearson'));
                                
                            case 'profile of scores: bend'
                                Ihat(test,side) = (ea_bendcorr(vals{voter,side},fibsval{1,side}(usedidx{voter,side},patientsel(test))));
                                if any(isnan(Ihat(test,side)))
                                    Ihat(isnan(Ihat(test,side)),side)=0;
                                    warning('Profiles of scores could not be evaluated for some patients. Displaying these points as zero entries. Lower threshold or carefully check results.');
                                end
                                    Ihattrain(training,side) = atanh(ea_bendcorr(vals{voter,side},fibsval{1,side}(usedidx{voter,side},patientsel(training))));
                                
                            case 'mean of scores'
                                if ~isempty(vals{voter,side})
                                    Ihat(test,side) = ea_nanmean(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test)),1);
                                end
                                    Ihattrain(training,side) = ea_nanmean(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training)),1);
                                
                            case 'sum of scores'
                                if ~isempty(vals{voter,side})
                                    Ihat(test,side) = ea_nansum(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test)),1);
                                end
                                    Ihattrain(training,side) = ea_nansum(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training)),1);
                                
                            case 'peak of scores'
                                if ~isempty(vals{voter,side})
                                    Ihat(test,side) = ea_nanmax(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test)),1);
                                end
                                    Ihattrain(training,side) = ea_nanmax(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training)),1);
                                
                            case 'peak 5% of scores'
                                if ~isempty(vals{voter,side})
                                    ihatvals=vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test));
                                end
                                ihatvals=sort(ihatvals);
                                Ihat(test,side) = ea_nansum(ihatvals(1:ceil(size(ihatvals,1).*0.05),:),1);
                                    ihatvals=vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training));
                                    ihatvals=sort(ihatvals);
                                    Ihattrain(training,side) = ea_nansum(ihatvals(1:ceil(size(ihatvals,1).*0.05),:),1);
                                
                        end

                    case 6 % Plain Connection
                        switch lower(obj.basepredictionon)
                            case 'mean of scores'
                                Ihat(test,side) = ea_nanmean(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test)),1);
                                    Ihattrain(training,side) = ea_nanmean(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training)),1);
                                
                            case 'sum of scores'
                                Ihat(test,side) = ea_nansum(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test)),1);
                                    Ihattrain(training,side) = ea_nansum(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training)),1);
                                
                            case 'peak of scores'
                                Ihat(test,side) = ea_nanmax(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test)),1);
                                Ihattrain(training,side) = ea_nanmax(vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training)),1);
                            case 'peak 5% of scores'
                                ihatvals=vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(test));
                                ihatvals=sort(ihatvals);
                                Ihat(test,side) = ea_nansum(ihatvals(1:ceil(size(ihatvals,1).*0.05),:),1);
                                ihatvals=vals{voter,side}.*fibsval{1,side}(usedidx{voter,side},patientsel(training));
                                ihatvals=sort(ihatvals);
                                Ihattrain(training,side) = ea_nansum(ihatvals(1:ceil(size(ihatvals,1).*0.05),:),1);
                        end
                end
            end
        end
% 
%         % weight hemiscores by number of selected fibers, sum and take
%         % atanh (only in some cases!)
%         total_num_sig = length(usedidx{voter,1})+length(usedidx{voter,2});
%         disp(Ihat(test))
%         Ihat(test,1) = atanh((Ihat(test,1)*length(usedidx{voter,1}) + Ihat(test,2)*length(usedidx{voter,2}))/total_num_sig);
%         Ihat(test,2) = Ihat(test,1);
%         disp(Ihat(test))
%         % add here block
%         % if nargout>2 % send out improvements of subscores
        
        Ihat_voters=cat(3,Ihat_voters,Ihat);
        Ihat_voters_train=cat(3,Ihat_voters_train,Ihattrain);
    end
end