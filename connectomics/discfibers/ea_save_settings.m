function ea_save_settings(tractset,save_as)
    % Saves the relevant settings of the tractset object to a mat file
    
    % Properties can't be saved as variables :(
    % Or with the struct flag because tractset is
    % a class and not a struct :(

    % Convert to variables first and then save
    calcthreshold = tractset.calcthreshold;
    posvisible = tractset.posvisible;
    negvisible = tractset.negvisible;
    showposamount = tractset.showposamount;
    shownegamount = tractset.shownegamount;
    connthreshold = tractset.connthreshold;
    efieldthreshold = tractset.efieldthreshold;
    statmetric = tractset.statmetric;
    corrtype = tractset.corrtype;
    efieldmetric = tractset.efieldmetric;
    multitractmode = tractset.multitractmode;
    numpcs = tractset.numpcs;
    doactualprediction = tractset.doactualprediction;
    predictionmodel = tractset.predictionmodel;
    showsignificantonly = tractset.showsignificantonly;
    alphalevel = tractset.alphalevel;
    multcompstrategy = tractset.multcompstrategy;
    basepredictionon = tractset.basepredictionon;
    mirrorsides = tractset.mirrorsides;
    modelNormalization = tractset.modelNormalization;
    numBins = tractset.numBins;
    Nperm = tractset.Nperm;
    kfold = tractset.kfold;
    Nsets = tractset.Nsets;
    adjustforgroups = tractset.adjustforgroups;

    save(save_as,...
    "calcthreshold",...
    "posvisible",...
    "negvisible",...
    "showposamount",...
    "shownegamount",...
    "connthreshold",...
    "efieldthreshold",...
    "statmetric",...
    "corrtype",...
    "efieldmetric",...
    "multitractmode",...
    "numpcs",...
    "doactualprediction",...
    "predictionmodel",...
    "showsignificantonly",...
    "alphalevel",...
    "multcompstrategy",...
    "basepredictionon",...
    "mirrorsides",...
    "modelNormalization",...
    "numBins",...
    "Nperm",...
    "kfold",...
    "Nsets",...
    "adjustforgroups")
end
